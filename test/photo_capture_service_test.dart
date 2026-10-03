import 'dart:io';

// `show Value` et non l'import complet : `drift.dart` exporte `isNull` et
// `isNotNull`, qui entreraient en collision avec les matchers de `flutter_test`.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/features/capture/image_compressor.dart';
import 'package:firestop_tracker/features/capture/photo_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compresseur factice : la compression réelle passe par un plugin natif,
/// indisponible hors appareil. C'est pour cela que `PhotoProcessor` est une
/// interface.
class _FakeProcessor implements PhotoProcessor {
  _FakeProcessor(this._dir);

  final Directory _dir;
  int calls = 0;

  @override
  Future<CompressedPhoto> compress(File source) async {
    calls++;
    final target = File('${_dir.path}/compressed_$calls.jpg')
      ..writeAsBytesSync(List<int>.filled(400, 0));
    return (
      path: target.path,
      bytes: 400,
      width: 2667,
      height: 2000,
      sha256: 'sha$calls',
    );
  }
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late _FakeProcessor processor;
  late PhotoCaptureService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('firestop_capture_');
    processor = _FakeProcessor(tmp);
    service = PhotoCaptureService(dao: db.pointDao, processor: processor);

    final now = DateTime(2026, 6, 1);
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

  /// Simule le fichier temporaire produit par la caméra.
  File shot(String name) => File('${tmp.path}/$name')
    ..writeAsBytesSync(List<int>.filled(4000, 1));

  test('le cliché brut est effacé après compression', () async {
    final original = shot('brut.jpg');

    await service.capture(
      pointId: 'pt1',
      kind: PhotoKind.before,
      original: original,
    );

    expect(
      original.existsSync(),
      isFalse,
      reason: 'a 4 Mo piece, garder les originaux remplit la tablette',
    );
    expect(processor.calls, 1);
  });

  test('la photo enregistrée est prête à partir, sans chemin distant',
      () async {
    await service.capture(
      pointId: 'pt1',
      kind: PhotoKind.before,
      original: shot('brut.jpg'),
    );

    final photo = await db.select(db.photos).getSingle();
    expect(photo.uploadState, PhotoUploadState.ready);
    expect(photo.remotePath, isNull);
    expect(photo.localPath, isNotNull);
    expect(photo.bytes, 400);
  });

  test('aucune entrée d\'outbox tant que le binaire n\'est pas transféré',
      () async {
    await service.capture(
      pointId: 'pt1',
      kind: PhotoKind.after,
      original: shot('brut.jpg'),
    );

    expect(
      await db.select(db.outboxEntries).get(),
      isEmpty,
      reason: 'la metadonnee pointerait vers un objet absent du bucket',
    );
  });

  group('suppression d\'une traversee', () {
    test(
      'emporte ses cliches, pour ne pas televerser un travail abandonne',
      () async {
        await service.capture(
          pointId: 'pt1',
          kind: PhotoKind.before,
          original: shot('a.jpg'),
        );

        // Ce cliche est deja en ligne : sa suppression doit voyager.
        final photo = await db.select(db.photos).getSingle();
        await db.update(db.photos).replace(
              photo.copyWith(
                remotePath: const Value('p1/pt1/a.jpg'),
                uploadState: PhotoUploadState.uploaded,
              ),
            );

        await db.pointDao.deletePoint('pt1');

        expect(await db.pointDao.photosOf('pt1'), isEmpty);
        expect(
          (await db.select(db.photos).getSingle()).deletedAt,
          isNotNull,
          reason: 'sans cela PhotoUploader continuerait de televerser les '
              'binaires d\'une traversee abandonnee',
        );
        expect(await db.pointDao.pointSummaries('p1'), isEmpty);
      },
    );
  });

  group('lectures ponctuelles du rapport', () {
    test('rendent la meme chose que les flux, sans souscription', () async {
      await service.capture(
        pointId: 'pt1',
        kind: PhotoKind.before,
        original: shot('a.jpg'),
      );
      await service.capture(
        pointId: 'pt1',
        kind: PhotoKind.extra,
        original: shot('b.jpg'),
      );

      final ponctuel = await db.pointDao.pointSummaries('p1');
      final flux = await db.pointDao.watchPoints('p1').first;

      expect(ponctuel.map((s) => s.point.id), flux.map((s) => s.point.id));
      expect(ponctuel.single.photoCount, 2);

      expect(
        (await db.pointDao.photosOf('pt1')).length,
        2,
        reason: 'le rapport lit un instantane : s\'abonner a des requetes '
            'vivantes pendant une synchro expose a attendre sans fin un '
            'evenement deja passe',
      );
    });

    test('ignorent les cliches retires', () async {
      await service.capture(
        pointId: 'pt1',
        kind: PhotoKind.extra,
        original: shot('a.jpg'),
      );
      final photo = await db.select(db.photos).getSingle();
      await service.retire(photo.id);

      expect(await db.pointDao.photosOf('pt1'), isEmpty);
      expect((await db.pointDao.pointSummaries('p1')).single.photoCount, 0);
    });
  });

  group('emplacements uniques', () {
    test('reprendre le cliché « avant » remplace le précédent', () async {
      await service.capture(
        pointId: 'pt1',
        kind: PhotoKind.before,
        original: shot('a.jpg'),
      );
      await service.capture(
        pointId: 'pt1',
        kind: PhotoKind.before,
        original: shot('b.jpg'),
      );

      final vivantes = await db.pointDao.photosOfKind('pt1', PhotoKind.before);
      expect(
        vivantes,
        hasLength(1),
        reason: 'deux cliches « avant » contradictoires seraient indefendables '
            'en audit',
      );
      expect(vivantes.single.sha256, 'sha2');
    });

    test(
      'remplacer un cliché déjà en ligne laisse un tombstone à synchroniser',
      () async {
        await service.capture(
          pointId: 'pt1',
          kind: PhotoKind.before,
          original: shot('a.jpg'),
        );

        // Le transfert a eu lieu : le serveur connaît cette photo.
        final premiere = await db.select(db.photos).getSingle();
        await db.update(db.photos).replace(
              premiere.copyWith(
                remotePath: const Value('p1/pt1/a.jpg'),
                uploadState: PhotoUploadState.uploaded,
              ),
            );

        await service.capture(
          pointId: 'pt1',
          kind: PhotoKind.before,
          original: shot('b.jpg'),
        );

        final retiree = await (db.select(db.photos)
              ..where((t) => t.id.equals(premiere.id)))
            .getSingle();
        expect(retiree.deletedAt, isNotNull);

        final outbox = await db.select(db.outboxEntries).get();
        expect(
          outbox.map((e) => e.entityId),
          contains(premiere.id),
          reason: 'sans tombstone, la photo ressusciterait a la redescente',
        );
      },
    );

    test('les clichés complémentaires s\'empilent au lieu de se remplacer',
        () async {
      for (var i = 0; i < 3; i++) {
        await service.capture(
          pointId: 'pt1',
          kind: PhotoKind.extra,
          original: shot('extra$i.jpg'),
        );
      }

      final extras = await db.pointDao.photosOfKind('pt1', PhotoKind.extra);
      expect(extras, hasLength(3));
      expect(
        extras.map((p) => p.sortOrder).toSet(),
        hasLength(3),
        reason: 'des rangs identiques rendraient l\'ordre du rapport aleatoire',
      );
    });

    test(
      'retirer un cliché jamais transféré efface la ligne et le fichier',
      () async {
        await service.capture(
          pointId: 'pt1',
          kind: PhotoKind.extra,
          original: shot('a.jpg'),
        );

        final photo = await db.select(db.photos).getSingle();
        final file = File(photo.localPath!);
        expect(file.existsSync(), isTrue);

        await service.retire(photo.id);

        expect(await db.select(db.photos).get(), isEmpty);
        expect(file.existsSync(), isFalse);
        expect(
          await db.select(db.outboxEntries).get(),
          isEmpty,
          reason: 'inutile d\'annoncer au serveur une photo qu\'il n\'a '
              'jamais vue',
        );
      },
    );
  });
}
