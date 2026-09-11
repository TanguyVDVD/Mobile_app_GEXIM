import 'dart:io';

// `show Value` et non l'import complet : `drift.dart` exporte `isNull` et
// `isNotNull`, qui entreraient en collision avec les matchers de `flutter_test`.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/sync/photo_uploader.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le bouton « Réessayer » du bandeau de synchronisation est le **seul** recours
/// de l'opérateur après un refus définitif. S'il ne réarme pas tout ce que
/// `needsAttention` compte, le bandeau réclame indéfiniment une intervention
/// que l'appui ne peut pas satisfaire — et le travail reste sur la tablette.
class _FakeGateway implements RemoteGateway {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late PhotoUploader uploader;

  final now = DateTime(2026, 6, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('firestop_retry_');
    uploader = PhotoUploader(db, _FakeGateway());

    await db.into(db.profiles).insert(
          Profile(
            id: 'u1',
            fullName: 'Operateur',
            email: 'op@gexim.be',
            role: UserRole.operator,
            updatedAt: now,
          ),
        );
    await db.into(db.clients).insert(
          Client(
            id: 'c1',
            name: 'Client',
            address: 'Rue du Test 1, 4000 Liège',
            logoPath: 'c1/logo.png',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.projects).insert(
          Project(
            id: 'p1',
            clientId: 'c1',
            name: 'Chantier',
            status: ProjectStatus.inProgress,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.points).insert(
          Point(
            id: 'pt1',
            projectId: 'p1',
            authorId: 'u1',
            capturedAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Insère un cliché abandonné. `avecFichier` décide si le binaire local
  /// existe encore — c'est toute la différence entre un échec réparable et un
  /// cliché à reprendre.
  Future<void> clicheAbandonne(String id, {required bool avecFichier}) async {
    final chemin = '${tmp.path}/$id.jpg';
    if (avecFichier) File(chemin).writeAsBytesSync(List<int>.filled(400, 1));

    await db.into(db.photos).insert(
          Photo(
            id: id,
            pointId: 'pt1',
            kind: PhotoKind.before,
            localPath: chemin,
            sortOrder: 0,
            takenAt: now,
            uploadState: PhotoUploadState.failed,
            uploadAttempts: 5,
            lastError: 'refus serveur',
            updatedAt: now,
          ),
        );
  }

  group('outbox', () {
    test('retryAllFailed rearme tout en une seule lecture', () async {
      for (var i = 0; i < 3; i++) {
        await db.outboxDao.enqueue(
          entityType: OutboxEntity.point,
          entityId: 'pt$i',
          payload: {'id': 'pt$i'},
          now: now,
        );
        final entry = await db.outboxDao.claimNext(now: now);
        await db.outboxDao.markFailed(entry!, 'RLS: refus');
      }

      expect(await db.outboxDao.retryAllFailed(now: now), 3);

      final entries = await db.select(db.outboxEntries).get();
      expect(entries.every((e) => e.status == OutboxStatus.pending), isTrue);
      expect(entries.every((e) => e.attempts == 0), isTrue);
      expect(
        entries.every((e) => e.lastError == null),
        isTrue,
        reason: 'une entree rearmee ne doit plus porter son ancien refus',
      );
      expect(await db.outboxDao.claimNext(now: now), isNotNull);
    });

    test('retryAllFailed ne touche pas aux entrees encore en attente',
        () async {
      await db.outboxDao.enqueue(
        entityType: OutboxEntity.point,
        entityId: 'pt-vivant',
        payload: {'id': 'pt-vivant'},
        now: now,
      );

      expect(await db.outboxDao.retryAllFailed(now: now), 0);

      final entry = await db.select(db.outboxEntries).getSingle();
      expect(entry.status, OutboxStatus.pending);
    });
  });

  group('clichés', () {
    test('un cliché abandonné dont le fichier survit repart', () async {
      await clicheAbandonne('ph1', avecFichier: true);

      expect(await uploader.retryFailed(now: now), 1);

      final photo = await db.select(db.photos).getSingle();
      expect(photo.uploadState, PhotoUploadState.ready);
      expect(photo.uploadAttempts, 0);
      expect(photo.lastError, isNull);
    });

    test(
      'un cliché dont le fichier a disparu reste abandonné',
      () async {
        await clicheAbandonne('ph1', avecFichier: false);

        expect(
          await uploader.retryFailed(now: now),
          0,
          reason: 'aucune tentative ne fera revenir un fichier purge par '
              'Android : insister ferait clignoter le bandeau a chaque cycle',
        );

        final photo = await db.select(db.photos).getSingle();
        expect(photo.uploadState, PhotoUploadState.failed);
      },
    );

    test('un cliché supprimé n\'est jamais réarmé', () async {
      await clicheAbandonne('ph1', avecFichier: true);
      await (db.update(db.photos)..where((t) => t.id.equals('ph1')))
          .write(PhotosCompanion(deletedAt: Value(now)));

      expect(
        await uploader.retryFailed(now: now),
        0,
        reason: 'televerser un cliche retire par l\'operateur serait un retour '
            'en arriere silencieux',
      );
    });

    test('le réarmement rend le cliché éligible au prochain drain', () async {
      await clicheAbandonne('ph1', avecFichier: true);
      await uploader.retryFailed(now: now);

      // Le gateway factice lève sur `uploadPhoto` : que le drain aille jusqu'à
      // l'appeler prouve que le cliché est bien redevenu éligible.
      await expectLater(
        uploader.drain(now: now),
        throwsUnimplementedError,
      );
    });
  });
}
