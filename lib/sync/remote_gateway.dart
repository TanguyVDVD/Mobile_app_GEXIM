import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/tables/enums.dart';
import 'backoff.dart';
import 'payloads.dart' show UserRoleWire;

/// Contrat minimal vers le backend.
///
/// Volontairement réduit à deux opérations : pousser une ligne, pousser un
/// fichier. Tout le reste (rejeu, ordre, temporisation) appartient au moteur de
/// synchro. Cette frontière étroite rend le remplacement du fournisseur ou le
/// passage en self-host Docker sans effet sur le reste du code — et permet un
/// faux gateway trivial en test.
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

  /// Dépose un papier à en-tête, ou un logo client.
  ///
  /// Hors file d'attente : ce sont des gestes d'administration faits au bureau,
  /// et un fichier de plusieurs mégaoctets n'a rien à faire dans une file
  /// destinée aux relevés de terrain.
  Future<void> uploadLetterhead({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    String bucket,
  });

  Future<Uint8List> downloadLetterhead(String remotePath, {String bucket});

  /// Enregistre une mise en page. **Exige du réseau.**
  ///
  /// `report_templates` est une table purement descendante : elle n'a pas de
  /// place dans la file d'attente, qui sert les relevés de terrain.
  Future<void> upsertTemplate(Map<String, Object?> payload);

  /// Rattache une mise en page à un client, et enregistre son logo.
  Future<void> attachTemplateToClient({
    required String clientId,
    required String templateId,
    String? logoPath,
  });

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
  const SupabaseRemoteGateway(this._client);

  final SupabaseClient _client;

  static const String bucket = 'point-photos';

  static String _tableFor(OutboxEntity entity) => switch (entity) {
        OutboxEntity.client => 'clients',
        OutboxEntity.project => 'projects',
        OutboxEntity.projectMember => 'project_members',
        OutboxEntity.point => 'points',
        OutboxEntity.pointMaterial => 'point_materials',
        OutboxEntity.photo => 'photos',
      };

  @override
  Future<void> upsert(OutboxEntity entity, Map<String, Object?> payload) async {
    try {
      // `upsert` et non `insert` : la clé primaire venant du client, rejouer un
      // envoi dont l'accusé de réception s'est perdu réécrit simplement la même
      // ligne. C'est ce qui rend le rejeu sûr sans table de déduplication.
      await _client.from(_tableFor(entity)).upsert(payload);
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
      await _client.storage.from(bucket).upload(
            remotePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              // Idempotence : une reprise après coupure en fin de transfert
              // réécrit l'objet au lieu d'échouer sur « déjà existant ».
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      throw status == null
          ? SyncException(e.message, isTransient: false)
          : SyncException.fromStatus(status, e.message);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<Uint8List> downloadPhoto(String remotePath) async {
    try {
      return await _client.storage.from(bucket).download(remotePath);
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      throw status == null
          ? SyncException(e.message, isTransient: false)
          : SyncException.fromStatus(status, e.message);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> uploadLetterhead({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    String bucket = 'letterheads',
  }) async {
    try {
      await _client.storage.from(bucket).uploadBinary(
            remotePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      throw status == null
          ? SyncException(e.message, isTransient: false)
          : SyncException.fromStatus(status, e.message);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<Uint8List> downloadLetterhead(
    String remotePath, {
    String bucket = 'letterheads',
  }) async {
    try {
      return await _client.storage.from(bucket).download(remotePath);
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      throw status == null
          ? SyncException(e.message, isTransient: false)
          : SyncException.fromStatus(status, e.message);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> upsertTemplate(Map<String, Object?> payload) async {
    try {
      await _client.from('report_templates').upsert(payload);
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
  }

  @override
  Future<void> attachTemplateToClient({
    required String clientId,
    required String templateId,
    String? logoPath,
  }) async {
    try {
      // `.select()` : un UPDATE écarté par RLS renvoie 200 avec zéro ligne.
      // Sans ce contrôle, l'interface annoncerait un enregistrement qui n'a pas
      // eu lieu — voir la note sur `setUserRole`.
      final rows = await _client
          .from('clients')
          .update({
            'template_id': templateId,
            'logo_path': logoPath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', clientId)
          .select();

      if (rows.isEmpty) {
        throw const SyncException(
          'Le serveur a refusé la modification du client. Vérifiez que vous '
          'êtes toujours administrateur.',
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
      final rows = await _client
          .from('profiles')
          .update({
            'role': role.wire,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select();

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
      await _client.storage.from('reports').uploadBinary(
            remotePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              // Regénérer écrase : le chemin est déterministe par rapport.
              upsert: true,
            ),
          );

      // La ligne n'est écrite qu'après le dépôt : jamais de rapport référencé
      // sans son fichier.
      await _client.from('reports').insert({
        'project_id': projectId,
        'storage_path': remotePath,
      });
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      throw status == null
          ? SyncException(e.message, isTransient: false)
          : SyncException.fromStatus(status, e.message);
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
        PullEntity.reportTemplate => 'report_templates',
        PullEntity.client => 'clients',
        PullEntity.project => 'projects',
        PullEntity.projectMember => 'project_members',
        PullEntity.point => 'points',
        PullEntity.material => 'materials',
        PullEntity.pointMaterial => 'point_materials',
        PullEntity.photo => 'photos',
      };

  /// Clé de départage, appliquée après `synced_at`.
  ///
  /// Indispensable : la pagination se fait par `range`, donc par décalage. Sans
  /// tri totalement déterministe, deux lignes partageant le même `synced_at`
  /// peuvent permuter entre deux pages — l'une servie deux fois, l'autre
  /// jamais. `point_materials` n'ayant pas de colonne `id`, sa clé composite
  /// joue ce rôle.
  static List<String> _orderKeys(PullEntity entity) => switch (entity) {
        PullEntity.pointMaterial => const ['point_id', 'material_id'],
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

      final rows = await query.range(offset, offset + limit - 1);
      return [for (final row in rows) Map<String, dynamic>.from(row)];
    } on PostgrestException catch (e) {
      throw _classify(e);
    } on SocketException catch (e) {
      throw SyncException.network(e.message);
    } on HandshakeException catch (e) {
      throw SyncException.network(e.message);
    }
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
