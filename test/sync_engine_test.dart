import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:firestop_tracker/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serveur factice : sert les lignes prévues, une seule page par entité.
///
/// Rien d'autre n'est implémenté : outbox et clichés sont vides, un appel
/// inattendu doit faire échouer le test plutôt que passer inaperçu.
class _Gateway implements RemoteGateway {
  _Gateway(this.lignes);

  final Map<PullEntity, List<Map<String, dynamic>>> lignes;

  @override
  Future<List<Map<String, dynamic>>> fetchSince({
    required PullEntity entity,
    required DateTime? since,
    required int offset,
    required int limit,
  }) async =>
      offset == 0 ? (lignes[entity] ?? const []) : const [];

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// `start()` n'est jamais appelé : la connectivité ne sert qu'à armer les
/// déclencheurs. Un double évite d'instancier le greffon.
class _Connectivity implements Connectivity {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// La descente ne doit jamais s'arrêter en silence.
///
/// Constaté le 11 septembre 2026 sur le poste Windows : une build antérieure à
/// la liste `product_type` recevait ces options et levait une
/// `FormatException`. Ni `PullEngine` ni `_runCycle` ne l'attrapaient — seules
/// les `SyncException` l'étaient. L'exception se perdait dans un
/// `unawaited(syncNow())`, la descente s'arrêtait sur toutes les entités
/// suivantes, et les logos clients n'atteignaient jamais le poste qui produit
/// les rapports. Le bandeau, lui, restait sur « Envoi en cours ».
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<SyncState>> cycle(
    Map<PullEntity, List<Map<String, dynamic>>> lignes,
  ) async {
    final engine = SyncEngine(
      db: db,
      gateway: _Gateway(lignes),
      connectivity: _Connectivity(),
    );
    final etats = <SyncState>[];
    final abonnement = engine.states.listen(etats.add);

    await engine.syncNow();
    // Le flux est diffusé de façon asynchrone : laisser passer la livraison.
    await Future<void>.delayed(Duration.zero);
    await abonnement.cancel();
    return etats;
  }

  test('un cycle sans rien a echanger se termine au repos', () async {
    expect((await cycle({})).last, SyncState.idle);
  });

  test('une ligne indecodable signale le blocage au lieu de disparaitre',
      () async {
    final etats = await cycle({
      PullEntity.settingOption: [
        {
          'id': 'opt-1',
          // Une liste que cette version de l'application ne connaît pas.
          'kind': 'liste_inconnue',
          'label': 'Mousse 2 comp',
          'sort_order': 0,
          'updated_at': '2026-09-11T10:00:00Z',
          'synced_at': '2026-09-11T10:00:00Z',
          'deleted_at': null,
        },
      ],
    });

    expect(
      etats.last,
      SyncState.needsAttention,
      reason: 'un bandeau resté sur « Envoi en cours » ne dit à personne que '
          'plus rien ne descend',
    );
  });
}
