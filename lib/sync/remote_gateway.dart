import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/tables/enums.dart';
import 'backoff.dart';
import 'payloads.dart' show UserRoleWire;

/// Contrat vers le backend : pousser et recevoir des lignes, déposer et
/// rapatrier des fichiers, et deux gestes d'administration en ligne.
///
/// Rien de la politique de rejeu n'y vit — ordre, temporisation, abandon
/// appartiennent au moteur de synchro. Cette frontière rend le remplacement du
/// fournisseur ou le passage en self-host Docker sans effet sur le reste du
/// code, et permet en test un faux gateway qui n'implémente que ce qu'il
/// exerce.
///
/// Toute implémentation doit **borner ses appels dans le temps** et traduire
/// le dépassement en [SyncException] transitoire — voir
/// [SupabaseRemoteGateway.delaiRequete] pour ce qui arrive sinon.
abstract interface class RemoteGateway {
  Future<void> upsert(OutboxEntity entity, Map<String, Object?> payload);

  Future<void> uploadPhoto({
    required String remotePath,
    required File file,
  });

  /// Récupère le binaire d'une photo prise par un autre appareil.
  ///
  /// Appelé à l'affichage, jamais en lot : un chantier représente plusieurs
  /// gigaoctets, les pré-charger viderait le forfait et le stockage de la
  /// tablette pour des clichés que personne ne regardera.
  Future<Uint8List> downloadPhoto(String remotePath);

  /// Dépose un fichier d'habillage — aujourd'hui le logo d'un client.
  ///
  /// Hors file d'attente : c'est un geste d'administration fait au bureau, et
  /// un fichier de plusieurs mégaoctets n'a rien à faire dans une file destinée
  /// aux relevés de terrain. Le chemin, lui, repasse par la file comme le reste
  /// de la fiche client.
  Future<void> uploadAsset({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    required String bucket,
  });

  Future<Uint8List> downloadAsset(String remotePath, {required String bucket});

  /// Change le rôle d'un utilisateur. **Exige du réseau.**
  ///
  /// Délibérément hors de la file d'attente, contrairement aux affectations de
  /// chantier. Une élévation de privilèges en attente d'envoi serait une très
  /// mauvaise idée : elle s'appliquerait des heures plus tard, éventuellement
  /// après que l'admin a changé d'avis, et une file rejouée pourrait
  /// re-promouvoir quelqu'un qu'on vient de rétrograder. Un geste qui étend les
  /// droits doit être immédiat, ou ne pas avoir lieu.
  Future<void> setUserRole(String userId, UserRole role);

  /// Dépose un rapport et enregistre sa génération.
  ///
  /// Hors du circuit de la file d'attente, et volontairement : un PDF est une
  /// donnée **dérivée**, reconstructible à tout moment depuis les traversées.
  /// Faire transiter plusieurs dizaines de mégaoctets par l'outbox pour un
  /// document que l'on sait régénérer serait un mauvais échange.
  Future<void> publishReport({
    required String projectId,
    required String remotePath,
    required Uint8List bytes,
  });

  /// Lignes dont le serveur a accusé réception après [since].
  ///
  /// Le filtre porte sur `synced_at`, horodatage serveur, et jamais sur
  /// `updated_at` qui vient des tablettes. RLS borne le résultat au périmètre
  /// de l'utilisateur : aucun filtre d'affectation n'est nécessaire ici.
  Future<List<Map<String, dynamic>>> fetchSince({
    required PullEntity entity,
    required DateTime? since,
    required int offset,
    required int limit,
  });
}

class SupabaseRemoteGateway implements RemoteGateway {
  const SupabaseRemoteGateway(
    this._client, {
    this.delaiRequete = const Duration(seconds: 30),
    this.delaiTransfert = const Duration(minutes: 5),
  });

  final SupabaseClient _client;

  /// Délai de garde d'une requête ordinaire : une ligne, une page de descente.
  ///
  /// Le client Supabase n'en impose **aucun**. Sur un réseau qui accepte la
  /// connexion sans jamais répondre — portail captif, Wi-Fi de chantier
  /// saturé — un appel restait suspendu indéfiniment. Et comme
  /// `SyncEngine.syncNow` rend le cycle déjà en cours plutôt que d'en lancer un
  /// second, **toute la synchronisation se figeait** jusqu'au redémarrage de
  /// l'application : bandeau sur « Envoi en cours », relevés sur la tablette.
  ///
  /// Le dépassement devient une [SyncException] transitoire : le cycle
  /// s'interrompt proprement, et le suivant réessaiera. Abandonner l'attente ne
  /// coûte rien — chaque écriture est un upsert idempotent.
  final Duration delaiRequete;

  /// Délai de garde d'un transfert de fichier : cliché, logo.
  ///
  /// Bien plus large : quelques centaines de kilo-octets sur la 4G d'un
  /// sous-sol peuvent légitimement prendre une minute. Un rapport, qui pèse
  /// des dizaines de mégaoctets, en reçoit le triple.
  final Duration delaiTransfert;

  static const String bucket = 'point-photos';

  /// Borne [appel] à [delai], et fait du dépassement une coupure réseau.
  static Future<T> _borne<T>(Future<T> Function() appel, Duration delai) {
    return appel().timeout(
      delai,
      onTimeout: () => throw SyncException.network(
        'Le serveur ne répond pas (aucune réponse en ${delai.inSeconds} s).',
      ),
    );
  }

  static String _tableFor(OutboxEntity entity) => switch (entity) {
        OutboxEntity.client => 'clients',
        OutboxEntity.project => 'projects',
        OutboxEntity.projectMember => 'project_members',
        OutboxEntity.settingOption => 'setting_options',
        OutboxEntity.point => 'points',
        OutboxEntity.photo => 'photos',
      };

  @override
  Future<void> upsert(OutboxEntity entity, Map<String, Object?> payload) async {
    try {
      // `upsert` et non `insert` : la clé primaire venant du client, rejouer un
      // envoi dont l'accusé de réception s'est perdu réécrit simplement la même
      // ligne. C'est ce qui rend le rejeu sûr sans table de déduplication.
      await _borne(
        () => _client.from(_tableFor(entity)).upsert(payload),
        delaiRequete,
      );
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> uploadPhoto({
    required String remotePath,
    required File file,
  }) async {
    try {
      await _borne(
        () => _client.storage.from(bucket).upload(
              remotePath,
              file,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                // Idempotence : une reprise après coupure en fin de transfert
                // réécrit l'objet au lieu d'échouer sur « déjà existant ».
                upsert: true,
              ),
            ),
        delaiTransfert,
      );
    } on StorageException catch (e) {
      throw _classifyStorage(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<Uint8List> downloadPhoto(String remotePath) async {
    try {
      return await _borne(
        () => _client.storage.from(bucket).download(remotePath),
        delaiTransfert,
      );
    } on StorageException catch (e) {
      throw _classifyStorage(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> uploadAsset({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    required String bucket,
  }) async {
    try {
      await _borne(
        () => _client.storage.from(bucket).uploadBinary(
              remotePath,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            ),
        delaiTransfert,
      );
    } on StorageException catch (e) {
      throw _classifyStorage(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<Uint8List> downloadAsset(
    String remotePath, {
    required String bucket,
  }) async {
    try {
      return await _borne(
        () => _client.storage.from(bucket).download(remotePath),
        delaiTransfert,
      );
    } on StorageException catch (e) {
      throw _classifyStorage(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> setUserRole(String userId, UserRole role) async {
    try {
      // `.select()` n'est pas décoratif : un UPDATE écarté par la clause
      // `using` d'une policy ne lève **aucune erreur**. PostgREST répond 200
      // avec zéro ligne modifiée, et sans cette vérification l'interface
      // annoncerait « untel est désormais administrateur » alors que rien n'a
      // changé côté serveur.
      //
      // Le cas se produit dès qu'un compte a perdu ses droits entre l'affichage
      // de l'écran et le clic — exactement le moment où se tromper coûte cher.
      final rows = await _borne(
        () => _client
            .from('profiles')
            .update({
              'role': role.wire,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId)
            .select(),
        delaiRequete,
      );

      if (rows.isEmpty) {
        throw const SyncException(
          'Le serveur a refusé le changement de rôle. Vérifiez que vous êtes '
          'toujours administrateur.',
          isTransient: false,
        );
      }
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> publishReport({
    required String projectId,
    required String remotePath,
    required Uint8List bytes,
  }) async {
    try {
      await _borne(
        () => _client.storage.from('reports').uploadBinary(
              remotePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                // Regénérer écrase : le chemin est déterministe par rapport.
                upsert: true,
              ),
            ),
        delaiTransfert * 3,
      );

      // La ligne n'est écrite qu'après le dépôt : jamais de rapport référencé
      // sans son fichier.
      await _borne(
        () => _client.from('reports').insert({
          'project_id': projectId,
          'storage_path': remotePath,
        }),
        delaiRequete,
      );
    } on StorageException catch (e) {
      throw _classifyStorage(e);
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  static String _pullTableFor(PullEntity entity) => switch (entity) {
        PullEntity.profile => 'profiles',
        PullEntity.settingOption => 'setting_options',
        PullEntity.client => 'clients',
        PullEntity.project => 'projects',
        PullEntity.projectMember => 'project_members',
        PullEntity.point => 'points',
        PullEntity.photo => 'photos',
      };

  /// Clé de départage, appliquée après `synced_at`.
  ///
  /// Indispensable : la pagination se fait par `range`, donc par décalage. Sans
  /// tri totalement déterministe, deux lignes partageant le même `synced_at`
  /// peuvent permuter entre deux pages — l'une servie deux fois, l'autre
  /// jamais. `project_members` n'ayant pas de colonne `id`, sa clé composite
  /// joue ce rôle.
  static List<String> _orderKeys(PullEntity entity) => switch (entity) {
        PullEntity.projectMember => const ['project_id', 'user_id'],
        _ => const ['id'],
      };

  @override
  Future<List<Map<String, dynamic>>> fetchSince({
    required PullEntity entity,
    required DateTime? since,
    required int offset,
    required int limit,
  }) async {
    try {
      final table = _pullTableFor(entity);

      var filter = _client.from(table).select();
      if (since != null) {
        filter = filter.gt('synced_at', since.toUtc().toIso8601String());
      }

      var query = filter.order('synced_at', ascending: true);
      for (final key in _orderKeys(entity)) {
        query = query.order(key, ascending: true);
      }

      final page = query;
      final rows = await _borne(
        () => page.range(offset, offset + limit - 1),
        delaiRequete,
      );
      return [for (final row in rows) Map<String, dynamic>.from(row)];
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  /// Qualifie une erreur de stockage d'après son code HTTP.
  static SyncException _classifyStorage(StorageException e) {
    final status = int.tryParse(e.statusCode ?? '');
    return status == null
        ? SyncException(e.message, isTransient: false)
        : SyncException.fromStatus(status, e.message);
  }

  /// Qualifie une erreur Postgrest en « à retenter » ou « définitive ».
  ///
  /// La distinction pilote directement la consommation de batterie : rejouer
  /// indéfiniment un refus RLS réveille la radio toutes les 30 minutes sans
  /// aucune chance d'aboutir.
  static SyncException _classify(PostgrestException e) {
    final code = e.code;

    // Un code SQLSTATE fait 5 caractères ; sa classe (2 premiers) suffit.
    if (code != null && code.length == 5) {
      const transientClasses = <String>{
        '08', // erreur de connexion
        '40', // rollback pour conflit de sérialisation
        '53', // ressources serveur insuffisantes
        '57', // intervention opérateur (redémarrage, arrêt en cours)
      };
      if (transientClasses.contains(code.substring(0, 2))) {
        return SyncException(e.message, isTransient: true);
      }

      // 23503 — violation de clé étrangère : la ligne parente n'est pas encore
      // arrivée. L'ordre de l'outbox l'exclut en principe, mais un lot dont le
      // parent vient d'échouer peut la produire. Le parent sera retenté, donc
      // l'enfant aussi : transitoire.
      if (code == '23503') {
        return SyncException(e.message, isTransient: true);
      }

      // Tout le reste (42501 refus RLS, 22P02 saisie invalide, 23514 contrainte
      // métier) exige une correction humaine.
      return SyncException(e.message, isTransient: false);
    }

    final status = int.tryParse(code ?? '');
    return status == null
        ? SyncException(e.message, isTransient: false)
        : SyncException.fromStatus(status, e.message);
  }
}
