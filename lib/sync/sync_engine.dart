import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/enums.dart';
import 'backoff.dart';
import 'photo_uploader.dart';
import 'pull_engine.dart';
import 'remote_gateway.dart';

/// Ce que l'opérateur voit dans la barre d'état de l'app.
enum SyncState {
  /// Tout est poussé.
  idle,

  /// Cycle en cours.
  syncing,

  /// Pas de réseau exploitable — situation normale sur un chantier.
  offline,

  /// Synchronisation bloquée : une écriture a été définitivement refusée, ou
  /// la descente s'est interrompue sur une erreur inattendue. Un humain doit
  /// trancher.
  needsAttention,
}

/// Vide l'outbox et le magasin de photos vers le backend.
///
/// Rien dans l'UI n'attend jamais ce moteur : les écrans lisent la base locale
/// et se mettent à jour aussitôt. Ce composant ne fait que rattraper le serveur
/// quand le réseau le permet.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required RemoteGateway gateway,
    Connectivity? connectivity,
    Duration period = const Duration(minutes: 15),
  })  : _db = db,
        _photos = PhotoUploader(db, gateway),
        _pull = PullEngine(db, gateway),
        _gateway = gateway,
        _connectivity = connectivity ?? Connectivity(),
        _period = period;

  final AppDatabase _db;
  final RemoteGateway _gateway;
  final PhotoUploader _photos;
  final PullEngine _pull;
  final Connectivity _connectivity;
  final Duration _period;

  final StreamController<SyncState> _states =
      StreamController<SyncState>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  Future<void>? _inFlight;

  Stream<SyncState> get states => _states.stream;

  /// Arme les déclencheurs et rattrape ce qui traînait.
  Future<void> start() async {
    // Une entrée restée `inflight` signifie que le processus est mort au milieu
    // d'une requête. Sans cette reprise elle serait bloquée à jamais, et le
    // relevé d'un opérateur perdu sans le moindre signal.
    await _db.outboxDao.recoverInflight();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(syncNow());
    });

    // Filet de sécurité : le Wi-Fi du bureau peut être « connecté » sans que
    // l'événement de connectivité ne se déclenche (portail captif franchi,
    // bascule de VPN). Un battement lent rattrape ces cas.
    _timer = Timer.periodic(_period, (_) => unawaited(syncNow()));

    unawaited(syncNow());
  }

  /// Déclenche un cycle, ou rend celui déjà en cours.
  ///
  /// Le retour du réseau et la reprise au premier plan arrivent souvent dans la
  /// même seconde — sortir la tablette du camion, par exemple. Sans cette
  /// coalescence, deux cycles pousseraient les mêmes entrées en parallèle.
  Future<void> syncNow() {
    return _inFlight ??= _runCycle().whenComplete(() => _inFlight = null);
  }

  /// Réarme les envois définitivement abandonnés, puis relance un cycle.
  ///
  /// Une entrée refusée pour de bon — policy RLS, chantier clôturé entre-temps —
  /// n'est jamais retentée seule : insister toutes les trente minutes viderait
  /// la batterie sans aucune chance d'aboutir.
  ///
  /// Mais la cause est souvent réparable côté serveur : un administrateur
  /// rouvre le chantier, réaffecte le technicien. Sans ce geste, le relevé
  /// resterait bloqué jusqu'à réinstallation de l'application.
  ///
  /// Les **deux** files sont réarmées, et pas seulement l'outbox : un cliché
  /// refusé bascule en `failed` de son côté, `_hasPermanentFailures` le compte,
  /// et n'en réarmer aucun laissait le bandeau réclamer une intervention que
  /// l'appui ne pouvait pas satisfaire — la photo manquait alors au rapport
  /// sans le moindre signal.
  Future<void> retryFailed() async {
    await _db.outboxDao.retryAllFailed();
    await _photos.retryFailed();
    await syncNow();
  }

  Future<void> _runCycle() async {
    _emit(SyncState.syncing);

    try {
      // 1. Métadonnées : un point doit exister côté serveur avant qu'une photo
      //    ne le référence.
      await _drainOutbox();

      // 2. Binaires photo.
      await _photos.drain();

      // 3. Second passage. L'étape 2 met en file la métadonnée de chaque photo
      //    transférée ; ce passage la pousse dans le même cycle plutôt que de
      //    la laisser attendre le suivant, potentiellement hors de portée du
      //    réseau.
      await _drainOutbox();

      // 4. Descente. Après la montée, et non avant : le travail de l'opérateur
      //    est ce qui n'existe qu'à un seul endroit tant qu'il n'est pas parti.
      //    Il quitte l'appareil en premier, même si le réseau se referme juste
      //    après et que la descente est perdue pour ce cycle.
      await _pull.drain();

      _emit(
        await _hasPermanentFailures()
            ? SyncState.needsAttention
            : SyncState.idle,
      );
    } on _CycleAborted {
      _emit(SyncState.offline);
    } on SyncException catch (e) {
      // Remontée par la descente, qui n'a pas de file d'attente où consigner
      // l'échec : elle est sans état, la passe suivante repartira du curseur.
      _emit(e.isTransient ? SyncState.offline : SyncState.needsAttention);
    } on Object catch (e, pile) {
      // Tout ce qui n'est pas une `SyncException` : une ligne indécodable, une
      // contrainte locale qui n'est pas un parent manquant… Ces erreurs
      // remontaient jusqu'à un `unawaited(syncNow())` et y disparaissaient :
      // la descente s'arrêtait sur toutes les entités qui suivent, et le
      // bandeau restait sur « Envoi en cours ».
      //
      // Constaté le 11 septembre 2026 : un poste compilé avant la liste
      // `product_type` recevait ces options, levait une `FormatException`, et
      // n'a plus rien reçu ensuite — ni client, ni logo. Ses rapports sortaient
      // avec le nom du client à la place du logo, sans un mot.
      developer.log(
        'Cycle de synchronisation interrompu',
        name: 'sync',
        error: e,
        stackTrace: pile,
      );
      _emit(SyncState.needsAttention);
    }
  }

  /// Pousse les écritures en attente, une par une, dans l'ordre de création.
  Future<void> _drainOutbox() async {
    while (true) {
      final entry = await _db.outboxDao.claimNext();
      if (entry == null) return;

      try {
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
        await _gateway.upsert(entry.entityType, payload);
        await _db.outboxDao.markSent(entry.id);
      } on SyncException catch (e) {
        if (e.isTransient) {
          await _db.outboxDao.markRetry(entry, e);
          // Le réseau vient de lâcher. Poursuivre le drain n'accumulerait que
          // des échecs et viderait la batterie : on abandonne le cycle entier.
          throw const _CycleAborted();
        }

        // Refus définitif (RLS, charge utile invalide). L'entrée est mise de
        // côté pour arbitrage humain, mais les suivantes n'ont aucune raison
        // d'en pâtir : le drain continue.
        //
        // Réserve assumée : les enfants d'une entité définitivement refusée
        // échoueront en violation de clé étrangère, classée transitoire, donc
        // retentée indéfiniment — à cadence plafonnée à 30 min. C'est le
        // comportement voulu tant que l'admin n'a pas traité le parent, qui
        // apparaît lui à l'écran de synchronisation.
        await _db.outboxDao.markFailed(entry, e);
      }
    }
  }

  Future<bool> _hasPermanentFailures() async {
    final outbox = await _db.outboxEntries
        .count(where: (t) => t.status.equalsValue(OutboxStatus.failed))
        .getSingle();
    if (outbox > 0) return true;

    final photos = await _db.photos
        .count(where: (t) => t.uploadState.equalsValue(PhotoUploadState.failed))
        .getSingle();
    return photos > 0;
  }

  void _emit(SyncState state) {
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySub?.cancel();
    await _states.close();
  }
}

/// Signal interne : le réseau a lâché, on arrête le cycle proprement.
class _CycleAborted implements Exception {
  const _CycleAborted();
}
