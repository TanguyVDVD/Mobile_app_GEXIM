import 'dart:io';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/enums.dart';
import 'backoff.dart';
import 'payloads.dart';
import 'remote_gateway.dart';

/// Transfert des binaires photo vers le bucket distant.
///
/// Séparé du drain de l'outbox parce que la nature du travail diffère : des
/// charges utiles de plusieurs centaines de kilo-octets, sensibles à la coupure,
/// avec un fichier local à vérifier. Les mélanger ferait qu'une photo bloquée
/// retiendrait en otage la synchro de toutes les métadonnées.
class PhotoUploader {
  const PhotoUploader(this._db, this._gateway);

  final AppDatabase _db;
  final RemoteGateway _gateway;

  /// Transfère les photos éligibles. Rend le nombre de succès.
  ///
  /// Les envois sont **séquentiels** et non parallèles. Sur la 4G intermittente
  /// d'un chantier, trois transferts concurrents se disputent une bande passante
  /// déjà maigre : ils échouent ensemble au lieu d'en réussir un.
  Future<int> drain({int limit = 10, DateTime? now}) async {
    final at = now ?? DateTime.now();
    final due = await _due(limit, at);
    var uploaded = 0;

    for (final (photo, projectId) in due) {
      final ok = await _uploadOne(photo, projectId, at);
      if (ok) uploaded++;
    }
    return uploaded;
  }

  /// Photos prêtes à partir, jointes à leur chantier pour construire le chemin
  /// de stockage.
  Future<List<(Photo, String)>> _due(int limit, DateTime at) async {
    final query = _db.select(_db.photos).join([
      innerJoin(_db.points, _db.points.id.equalsExp(_db.photos.pointId)),
    ])
      ..where(
        _db.photos.uploadState.equalsValue(PhotoUploadState.ready) &
            _db.photos.deletedAt.isNull() &
            (_db.photos.nextUploadAt.isSmallerOrEqualValue(at) |
                _db.photos.nextUploadAt.isNull()),
      )
      ..orderBy([OrderingTerm.asc(_db.photos.takenAt)])
      ..limit(limit);

    final rows = await query.get();
    return [
      for (final row in rows)
        (row.readTable(_db.photos), row.readTable(_db.points).projectId),
    ];
  }

  Future<bool> _uploadOne(Photo photo, String projectId, DateTime at) async {
    final localPath = photo.localPath;
    if (localPath == null) {
      await _fail(photo, 'Chemin local absent.');
      return false;
    }

    final file = File(localPath);
    if (!file.existsSync()) {
      // Android peut purger le cache de l'app sous pression de stockage. Le
      // fichier est irrécupérable : aucune tentative ne le fera revenir, et
      // l'opérateur doit reprendre le cliché.
      await _fail(photo, 'Fichier introuvable : $localPath');
      return false;
    }

    // Chemin déterministe. Il rejoue à l'identique après une coupure, ce qui
    // rend le transfert idempotent (avec `upsert` côté bucket), et reste lisible
    // pour l'inspection manuelle ou la génération du rapport côté serveur.
    final remotePath = '$projectId/${photo.pointId}/${photo.id}.jpg';

    try {
      await _gateway.uploadPhoto(remotePath: remotePath, file: file);
    } on SyncException catch (e) {
      if (e.isTransient) {
        await _retry(photo, e, at);
      } else {
        await _fail(photo, e.toString());
      }
      return false;
    }

    // Le binaire est en place : la métadonnée peut désormais le référencer sans
    // risque de pointer vers un objet absent.
    final synced = photo.copyWith(
      remotePath: Value(remotePath),
      uploadState: PhotoUploadState.uploaded,
      uploadAttempts: 0,
      lastError: const Value(null),
      updatedAt: at,
    );

    await _db.transaction(() async {
      await _db.update(_db.photos).replace(synced);
      await _db.outboxDao.enqueue(
        entityType: OutboxEntity.photo,
        entityId: synced.id,
        payload: photoPayload(synced),
      );
    });

    return true;
  }

  /// Réarme les clichés abandonnés dont le fichier est **toujours là**.
  ///
  /// Sans ce geste, un cliché passé en `failed` n'en ressortait jamais : rien,
  /// nulle part, ne le ramenait à `ready`. Le bandeau de synchronisation
  /// annonçait « touchez pour réessayer » indéfiniment, l'appui ne réarmait que
  /// l'outbox, et la photo manquait au rapport de conformité sans que personne
  /// n'en soit averti — la panne silencieuse que toute l'architecture cherche à
  /// éviter.
  ///
  /// Un cliché dont le fichier local a disparu reste `failed` : Android a purgé
  /// le cache, aucune tentative ne le fera revenir, et insister ferait clignoter
  /// le bandeau à chaque cycle. Celui-là, l'opérateur doit le reprendre.
  ///
  /// Rend le nombre de clichés réarmés.
  Future<int> retryFailed({DateTime? now}) async {
    final at = now ?? DateTime.now();

    final failed = await (_db.select(_db.photos)
          ..where(
            (t) =>
                t.uploadState.equalsValue(PhotoUploadState.failed) &
                t.deletedAt.isNull(),
          ))
        .get();

    var rearmed = 0;
    for (final photo in failed) {
      final localPath = photo.localPath;
      if (localPath == null || !File(localPath).existsSync()) continue;

      await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
        PhotosCompanion(
          uploadState: const Value(PhotoUploadState.ready),
          uploadAttempts: const Value(0),
          nextUploadAt: Value(at),
          lastError: const Value(null),
        ),
      );
      rearmed++;
    }
    return rearmed;
  }

  Future<void> _retry(Photo photo, Object error, DateTime at) {
    return (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(
        uploadAttempts: Value(photo.uploadAttempts + 1),
        nextUploadAt: Value(at.add(backoffDelay(photo.uploadAttempts))),
        lastError: Value(error.toString()),
      ),
    );
  }

  Future<void> _fail(Photo photo, String reason) {
    return (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(
        uploadState: const Value(PhotoUploadState.failed),
        uploadAttempts: Value(photo.uploadAttempts + 1),
        lastError: Value(reason),
      ),
    );
  }
}
