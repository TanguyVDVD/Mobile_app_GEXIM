import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/sync/backoff.dart';
import 'package:firestop_tracker/sync/pull_engine.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gateway en mémoire. Seule la descente (`fetchSince`) sert ici ; le reste de
/// l'interface est inerte.
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
  Future<void> upsert(
      OutboxEntity entity, Map<String, Object?> payload) async {}

  @override
  Future<void> deleteProject(String projectId) async {}

  @override
  Future<void> uploadPhoto({
    required String remotePath,
    required File file,
  }) async {}

  @override
  Future<Uint8List> downloadPhoto(String remotePath) async => Uint8List(0);

  @override
  Future<void> setUserRole(String userId, UserRole role) async {}

  @override
  Future<void> uploadAsset({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    required String bucket,
  }) async {}

  @override
  Future<Uint8List> downloadAsset(
    String remotePath, {
    required String bucket,
  }) async =>
      Uint8List(0);
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

  Map<String, dynamic> clientRow({
    required DateTime at,
    String id = 'c1',
  }) =>
      {
        'id': id,
        'name': 'Client Test',
        'contact_name': null,
        'contact_email': null,
        'contact_phone': null,
        'address': 'Rue du Test 1, 4000 Liège',
        'logo_path': '$id/logo.png',
        'created_at': _iso(at),
        'updated_at': _iso(at),
        'deleted_at': null,
        'synced_at': _iso(at),
      };

  Map<String, dynamic> projectRow({
    required DateTime at,
    String id = 'p1',
    String clientId = 'c1',
    String name = 'Chantier A',
    String status = 'in_progress',
    DateTime? syncedAt,
  }) =>
      {
        'id': id,
        'client_id': clientId,
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

  Map<String, dynamic> memberRow({
    required DateTime at,
    String projectId = 'p1',
    String userId = 'u1',
    DateTime? deletedAt,
  }) =>
      {
        'project_id': projectId,
        'user_id': userId,
        'added_at': _iso(at),
        'updated_at': _iso(at),
        'deleted_at': deletedAt == null ? null : _iso(deletedAt),
        'synced_at': _iso(at),
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
        'purchase_order': 'PO-2026-118',
        'building': 'Bloc A',
        'floor_level': 2,
        'room': 'Local technique',
        'description': description,
        'configuration_id': null,
        'configuration_detail_id': null,
        'ei_level_id': null,
        'supplier_id': null,
        'product1_id': null,
        'product2_id': null,
        'product3_id': null,
        'product4_id': null,
        'product5_id': null,
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

  group('affectation posterieure a la derniere synchro', () {
    // Le scenario du terrain : une tablette a deja synchronise, donc son
    // curseur est en avance. L'admin affecte ensuite le technicien a un
    // chantier **qui existait deja**.
    //
    // La ligne d'affectation est neuve : elle descend. Le chantier, lui, n'a pas
    // bouge — son `synced_at` est plus ancien que le curseur, et la descente
    // incrementale l'enjambe. L'operateur recoit une affectation vers un
    // chantier dont il n'a jamais entendu parler.
    //
    // C'est exactement ce qui a ete observe : le chantier n'apparaissait pas sur
    // l'accueil du technicien.
    // Le curseur du technicien est **en avance** : il travaille deja sur un
    // chantier, donc sa derniere descente l'a fait monter a cette date-la.
    final ancien = t0;
    final recent = t0.add(const Duration(hours: 2));
    final affectation = t0.add(const Duration(hours: 5));

    /// Etat initial : le technicien est affecte au chantier « recent ».
    Future<void> dejaSurUnChantier() async {
      gateway
        ..put(PullEntity.profile, profileRow('u1', at: recent))
        ..put(PullEntity.client, clientRow(at: recent, id: 'c-recent'))
        ..put(
          PullEntity.project,
          projectRow(at: recent, id: 'p-recent', clientId: 'c-recent'),
        )
        ..put(
          PullEntity.projectMember,
          memberRow(at: recent, projectId: 'p-recent'),
        );
      await PullEngine(db, gateway).drain();
    }

    // La cause racine est **cote serveur** : un chantier qui devient visible doit
    // porter un `synced_at` neuf, sinon la descente incrementale l'enjambe. Le
    // trigger `refresh_project_visibility` s'en charge, et c'est le banc d'essai
    // SQL qui le prouve — test 18 de `docker/rls_tests.sql`. Une passerelle
    // simulee ne peut pas le demontrer : ici, c'est elle, le serveur.
    //
    // Ce que ce test-ci verrouille, c'est le contrat cote client : **quand** le
    // serveur reestampille, le chantier arrive avec son client et son
    // affectation. Il tomberait si l'ordre de `PullEntity` changeait — les cles
    // etrangeres etant actives localement, une affectation appliquee avant son
    // chantier echouerait.
    test('un chantier reestampille arrive avec tout ce qui le rend utilisable',
        () async {
      await dejaSurUnChantier();

      // Le chantier date d'`ancien` — c'est `updated_at` qui le dit — mais le
      // serveur vient de le reestampiller au moment de l'affectation.
      gateway
        ..put(
          PullEntity.client,
          clientRow(at: ancien, id: 'c-ancien')
            ..['synced_at'] = _iso(affectation),
        )
        ..put(
          PullEntity.project,
          projectRow(
            at: ancien,
            id: 'p-ancien',
            clientId: 'c-ancien',
            syncedAt: affectation,
          ),
        )
        ..put(
          PullEntity.projectMember,
          memberRow(at: affectation, projectId: 'p-ancien'),
        );

      await PullEngine(db, gateway).drain();

      expect(
        [for (final p in await db.select(db.projects).get()) p.id],
        contains('p-ancien'),
      );
      expect(
        [for (final m in await db.select(db.projectMembers).get()) m.projectId],
        contains('p-ancien'),
        reason: "sans l'affectation, le chantier n'apparait pas sur l'accueil "
            'du technicien',
      );
    });

    test('la descente ne casse pas quand le parent manque encore', () async {
      await dejaSurUnChantier();
      // Le meme scenario, vu comme un probleme d'integrite. `project_members`
      // reference `projects` par cle etrangere **jusque dans la base locale** :
      // appliquer l'affectation sans son chantier leve une SqliteException, qui
      // n'est ni une SyncException ni rattrapee par `SyncEngine._runCycle`.
      //
      // Elle remonte donc jusqu'a un `unawaited(syncNow())` : plus aucune
      // descente n'aboutit, le bandeau reste sur « synchronisation », et rien
      // n'est journalise. Une panne totale et muette.
      gateway.put(
        PullEntity.projectMember,
        memberRow(at: affectation, projectId: 'p-inconnu'),
      );

      await expectLater(
        PullEngine(db, gateway).drain(),
        completes,
        reason: 'une ligne orpheline doit etre differee, pas faire tout tomber',
      );

      // Et surtout : elle ne doit pas etre perdue. Le curseur ne doit pas avoir
      // enjambe la ligne differee, sinon elle ne redescendrait jamais.
      gateway.put(
        PullEntity.project,
        projectRow(at: affectation, id: 'p-inconnu', clientId: 'c-recent'),
      );
      await PullEngine(db, gateway).drain();

      expect(
        [for (final m in await db.select(db.projectMembers).get()) m.projectId],
        contains('p-inconnu'),
        reason: 'l\'affectation differee doit revenir au cycle suivant',
      );
    });
  });

  group('last-write-wins', () {
    test('une version serveur plus ancienne n\'ecrase pas la saisie locale',
        () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.point, pointRow(at: t0, description: 'v1'));
      await PullEngine(db, gateway).drain();

      // L'operateur retouche le point ; l'envoi n'est pas encore parti.
      await db.pointDao.updatePoint(
        'pt1',
        description: const Value('saisie locale'),
      );

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

  group('chantier supprime definitivement', () {
    // Une ligne effacée du serveur ne redescend plus : sans la trace que le
    // serveur garde de la suppression, les autres appareils afficheraient le
    // chantier pour toujours.
    Map<String, dynamic> trace(String id, {required DateTime at}) =>
        {'id': id, 'deleted_at': _iso(at), 'synced_at': _iso(at)};

    test('la trace efface le chantier et tout ce qui en depend', () async {
      seedRemoteGraph(at: t0);
      gateway
        ..put(PullEntity.projectMember, memberRow(at: t0))
        ..put(PullEntity.point, pointRow(at: t0, refNumber: 1));
      await PullEngine(db, gateway).drain();
      expect(await db.select(db.points).get(), hasLength(1));

      gateway.put(
        PullEntity.deletedProject,
        trace('p1', at: t0.add(const Duration(minutes: 5))),
      );
      await PullEngine(db, gateway).drain();

      expect(await db.select(db.projects).get(), isEmpty);
      expect(await db.select(db.projectMembers).get(), isEmpty);
      expect(await db.select(db.points).get(), isEmpty);
      // Le client et le profil, eux, n'appartiennent pas au chantier.
      expect(await db.select(db.clients).get(), hasLength(1));
      expect(await db.select(db.profiles).get(), hasLength(1));
    });

    test('la trace d\'un chantier jamais recu est sans effet', () async {
      seedRemoteGraph(at: t0);
      gateway.put(PullEntity.deletedProject, trace('ailleurs', at: t0));

      await PullEngine(db, gateway).drain();

      expect(await db.select(db.projects).get(), hasLength(1));
    });

    test('la trace emporte aussi le travail non envoye de l\'appareil',
        () async {
      // Le sens de « définitivement » : un relevé resté sur une tablette
      // n'a plus de chantier où aller. Le garder en file le laisserait en
      // échec, à bloquer la déconnexion.
      seedRemoteGraph(at: t0);
      await PullEngine(db, gateway).drain();
      await db.pointDao.createPoint(projectId: 'p1', authorId: 'u1');
      expect(await db.select(db.outboxEntries).get(), hasLength(1));

      gateway.put(
        PullEntity.deletedProject,
        trace('p1', at: t0.add(const Duration(minutes: 5))),
      );
      await PullEngine(db, gateway).drain();

      expect(await db.select(db.points).get(), isEmpty);
      expect(await db.select(db.outboxEntries).get(), isEmpty);
    });
  });
}
