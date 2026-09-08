import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/sync/backoff.dart';
import 'package:firestop_tracker/sync/pull_engine.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gateway en mémoire. L'interface n'ayant que trois méthodes, le double tient
/// en quelques lignes — c'était l'intérêt de la garder étroite.
class _FakeGateway implements RemoteGateway {
  final Map<PullEntity, List<Map<String, dynamic>>> tables = {};

  /// Bornes `since` reçues, pour vérifier la gestion du curseur.
  final List<DateTime?> sinceCalls = [];

  Object? failWith;

  void put(PullEntity entity, Map<String, dynamic> row) {
    tables.putIfAbsent(entity, () => []).add(row);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince({
    required PullEntity entity,
    required DateTime? since,
    required int offset,
    required int limit,
  }) async {
    if (failWith != null) throw failWith!;
    if (offset == 0) sinceCalls.add(since);

    final rows = (tables[entity] ?? const <Map<String, dynamic>>[])
        .where((r) =>
            since == null ||
            DateTime.parse(r['synced_at'] as String).isAfter(since))
        .toList()
      ..sort((a, b) =>
          (a['synced_at'] as String).compareTo(b['synced_at'] as String));

    if (offset >= rows.length) return [];
    return rows.sublist(offset, (offset + limit).clamp(0, rows.length));
  }

  @override
  Future<void> upsert(OutboxEntity entity, Map<String, Object?> payload) async {}

  @override
  Future<void> uploadPhoto({
    required String remotePath,
    required File file,
  }) async {}

  @override
  Future<Uint8List> downloadPhoto(String remotePath) async => Uint8List(0);

  @override
  Future<void> publishReport({
    required String projectId,
    required String remotePath,
    required Uint8List bytes,
  }) async {}

  @override
  Future<void> setUserRole(String userId, UserRole role) async {}

  @override
  Future<void> uploadLetterhead({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    String bucket = 'letterheads',
  }) async {}

  @override
  Future<Uint8List> downloadLetterhead(
    String remotePath, {
    String bucket = 'letterheads',
  }) async =>
      Uint8List(0);

  @override
  Future<void> upsertTemplate(Map<String, Object?> payload) async {}

  @override
  Future<void> attachTemplateToClient({
    required String clientId,
    required String templateId,
    String? logoPath,
  }) async {}
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;

  final t0 = DateTime.utc(2026, 5, 12, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
  });
  tearDown(() => db.close());

  Map<String, dynamic> profileRow(String id, {required DateTime at}) => {
        'id': id,
        'full_name': 'Operateur',
        'email': 'op@gexim.be',
        'role': 'operator',
        'updated_at': _iso(at),
        'synced_at': _iso(at),
      };

  Map<String, dynamic> clientRow({required DateTime at}) => {
        'id': 'c1',
        'name': 'Client Test',
        'contact_name': null,
        'contact_email': null,
        'contact_phone': null,
        'address': null,
        'logo_path': null,
        'template_id': null,
        'created_at': _iso(at),
        'updated_at': _iso(at),
        'deleted_at': null,
        'synced_at': _iso(at),
      };

  Map<String, dynamic> projectRow({
    required DateTime at,
    String name = 'Chantier A',
    String status = 'in_progress',
    DateTime? syncedAt,
  }) =>
      {
        'id': 'p1',
        'client_id': 'c1',
        'name': name,
        'description': null,
        'started_on': null,
        'ended_on': null,
        'status': status,
        'created_at': _iso(t0),
        'updated_at': _iso(at),
        'deleted_at': null,
        'synced_at': _iso(syncedAt ?? at),
      };

  Map<String, dynamic> pointRow({
    required DateTime at,
    String? description,
    int? refNumber,
  }) =>
      {
        'id': 'pt1',
        'project_id': 'p1',
        'ref_number': refNumber,
        'floor': 'R+2',
        'room': 'Local technique',
        'description': description,
        'author_id': 'u1',
        'captured_at': _iso(t0),
        'updated_at': _iso(at),
        'deleted_at': null,
        'synced_at': _iso(at),
      };

  /// Amorce le graphe minimal exigé par les clés étrangères locales.
  void seedRemoteGraph({required DateTime at}) {
    gateway
      ..put(PullEntity.profile, profileRow('u1', at: at))
      ..put(PullEntity.client, clientRow(at: at))
      ..put(PullEntity.project, projectRow(at: at));
  }

  group('descente', () {
    test('applique un graphe complet dans l\'ordre des dependances', () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0, refNumber: 1));

      final received = await PullEngine(db, gateway).drain();

      expect(received, 4);
      final point = await db.select(db.points).getSingle();
      expect(point.projectId, 'p1');
      expect(point.refNumber, 1);
    });

    test('le numero definitif du serveur remplace le provisoire', () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0, refNumber: null));
      await PullEngine(db, gateway).drain();

      expect((await db.select(db.points).getSingle()).refNumber, isNull);

      // Le serveur attribue le numero et le renvoie.
      gateway.tables[PullEntity.point]!.clear();
      gateway.put(
        PullEntity.point,
        pointRow(at: t0.add(const Duration(minutes: 5)), refNumber: 47),
      );
      await PullEngine(db, gateway).drain();

      expect((await db.select(db.points).getSingle()).refNumber, 47);
    });
  });

  group('last-write-wins', () {
    test('une version serveur plus ancienne n\'ecrase pas la saisie locale',
        () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0, description: 'v1'));
      await PullEngine(db, gateway).drain();

      // L'operateur retouche le point ; l'envoi n'est pas encore parti.
      await db.pointDao.updatePoint('pt1', description: 'saisie locale');

      // Le serveur renvoie sa version, plus ancienne, lors d'une redescente
      // provoquee par le recouvrement du curseur.
      gateway.tables[PullEntity.point]!.clear();
      gateway.put(
        PullEntity.point,
        pointRow(at: t0, description: 'v1')
          ..['synced_at'] = _iso(t0.add(const Duration(hours: 1))),
      );
      await PullEngine(db, gateway).drain();

      expect(
        (await db.select(db.points).getSingle()).description,
        'saisie locale',
        reason: 'la redescente a ecrase une modification non encore envoyee',
      );
    });

    test('une version serveur plus recente gagne', () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0, description: 'v1'));
      await PullEngine(db, gateway).drain();

      gateway.tables[PullEntity.point]!.clear();
      gateway.put(
        PullEntity.point,
        pointRow(at: t0.add(const Duration(hours: 2)), description: 'v2'),
      );
      await PullEngine(db, gateway).drain();

      expect((await db.select(db.points).getSingle()).description, 'v2');
    });

    test('la redescente d\'une photo preserve le fichier local', () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0));
      await PullEngine(db, gateway).drain();

      final photoId = await db.pointDao.registerPhoto(
        pointId: 'pt1',
        kind: PhotoKind.after,
        localPath: '/data/photos/abc.jpg',
        bytes: 412000,
        width: 2667,
        height: 2000,
        sha256: 'deadbeef',
      );

      // `registerPhoto` horodate avec l'heure courante : la version serveur doit
      // lui etre posterieure, sinon c'est le garde-fou LWW qui la rejette et le
      // test ne prouve plus rien sur la preservation du chemin local.
      final local = await db.select(db.photos).getSingle();
      final serverStamp = local.updatedAt.add(const Duration(hours: 1));

      gateway.put(PullEntity.photo, {
        'id': photoId,
        'point_id': 'pt1',
        'kind': 'after',
        'storage_path': 'p1/pt1/$photoId.jpg',
        'width': 2667,
        'height': 2000,
        'bytes': 412000,
        'sha256': 'deadbeef',
        'sort_order': 0,
        'taken_at': _iso(t0),
        'updated_at': _iso(serverStamp),
        'synced_at': _iso(serverStamp),
        'deleted_at': null,
      });

      await PullEngine(db, gateway).drain();

      final photo = await db.select(db.photos).getSingle();
      expect(
        photo.localPath,
        '/data/photos/abc.jpg',
        reason: 'effacer le chemin local forcerait un retelechargement inutile',
      );
      expect(photo.remotePath, 'p1/pt1/$photoId.jpg');
    });
  });

  group('curseur', () {
    test('avance, et rejoue les deux dernieres minutes', () async {
      seedRemoteGraph(at: t0);
      await PullEngine(db, gateway).drain();

      final cursor = await (db.select(db.syncCursors)
            ..where((t) => t.entity.equals(PullEntity.project.name)))
          .getSingle();
      expect(cursor.syncedAt.toUtc(), t0);

      gateway.sinceCalls.clear();
      await PullEngine(db, gateway).drain();

      // Le recouvrement referme la fenetre pendant laquelle deux transactions
      // concurrentes peuvent valider dans l'ordre inverse de leur synced_at.
      final since = gateway.sinceCalls
          .elementAt(PullEntity.values.indexOf(PullEntity.project));
      expect(since!.toUtc(), t0.subtract(const Duration(minutes: 2)));
    });

    test('n\'avance pas si une page echoue', () async {
      seedRemoteGraph(at: t0);
      await PullEngine(db, gateway).drain();

      gateway
        ..put(
          PullEntity.project,
          projectRow(at: t0.add(const Duration(hours: 1)), name: 'Renomme'),
        )
        ..failWith = const SyncException.network('coupure');

      await expectLater(
        PullEngine(db, gateway).drain(),
        throwsA(isA<SyncException>()),
      );

      final cursor = await (db.select(db.syncCursors)
            ..where((t) => t.entity.equals(PullEntity.project.name)))
          .getSingle();
      expect(
        cursor.syncedAt.toUtc(),
        t0,
        reason: 'avancer malgre l\'echec laisserait un trou definitif',
      );
    });

    test('la pagination ne saute ni ne duplique de ligne', () async {
      seedRemoteGraph(at: t0);
      for (var i = 0; i < 7; i++) {
        gateway.put(PullEntity.point, {
          ...pointRow(at: t0.add(Duration(minutes: i))),
          'id': 'pt$i',
        });
      }

      final received = await PullEngine(db, gateway, pageSize: 2).drain();

      expect(received, 3 + 7);
      expect(await db.select(db.points).get(), hasLength(7));
    });
  });
}
