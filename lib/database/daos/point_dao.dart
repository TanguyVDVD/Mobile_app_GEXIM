import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../sync/payloads.dart';
import '../database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'point_dao.g.dart';

/// Un point tel qu'il apparaît dans la liste d'un chantier.
typedef PointSummary = ({
  Point point,
  String label,
  bool isProvisional,
  bool hasBefore,
  bool hasAfter,
  int photoCount,
});

/// Écritures et lectures du domaine « traversée ».
///
/// **Invariant du fichier** : toute mutation écrit la table métier *et* met en
/// file l'écriture distante **dans la même transaction**. Un crash entre les
/// deux (kill Android, batterie vide) laisserait sinon une modification visible
/// à l'écran mais jamais synchronisée — la pire des pannes, parce que
/// silencieuse : l'opérateur croit son relevé enregistré.
@DriftAccessor(tables: [Points, Photos, PointMaterials, Materials])
class PointDao extends DatabaseAccessor<AppDatabase> with _$PointDaoMixin {
  PointDao(super.attachedDatabase);

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  /// Points d'un chantier, avec numéro d'affichage et état de complétude.
  ///
  /// Le tri par `id` donne l'ordre de création : les UUID v7 sont préfixés d'un
  /// timestamp, donc chronologiques. C'est ce qui permet de dériver un numéro
  /// provisoire du simple rang dans la liste, sans stocker de colonne dédiée.
  ///
  /// Tant que `refNumber` est nul, le numéro est marqué provisoire à l'écran :
  /// mentir sur un identifiant qui figurera dans un rapport de conformité
  /// serait plus grave que d'afficher une incertitude.
  ///
  /// `hasBefore` / `hasAfter` sont agrégés dans la même requête plutôt que
  /// chargés point par point. C'est l'information la plus utile de l'écran :
  /// avant de quitter le chantier, l'opérateur doit repérer d'un coup d'œil les
  /// traversées auxquelles il manque un cliché — y revenir coûte une
  /// demi-journée.
  Stream<List<PointSummary>> watchPoints(String projectId) =>
      _pointSummaryQuery(projectId).watch().map(_toSummaries);

  /// Même relevé, en **une seule lecture**.
  ///
  /// Pour le rapport PDF, qui est un instantané : il n'a rien à faire abonné à
  /// des flux vivants. Enchaîner des `.first` sur des `watch()` pendant qu'un
  /// cycle de synchronisation écrit dans les mêmes tables invalide et relance
  /// les requêtes sous les pieds de l'appelant, et une souscription peut
  /// attendre indéfiniment un événement déjà passé.
  Future<List<PointSummary>> pointSummaries(String projectId) async =>
      _toSummaries(await _pointSummaryQuery(projectId).get());

  Selectable<QueryRow> _pointSummaryQuery(String projectId) {
    return customSelect(
      '''
      SELECT p.*,
             MAX(CASE WHEN ph.kind = 'before' THEN 1 ELSE 0 END) AS has_before,
             MAX(CASE WHEN ph.kind = 'after'  THEN 1 ELSE 0 END) AS has_after,
             COUNT(ph.id) AS photo_count
        FROM points p
        LEFT JOIN photos ph
               ON ph.point_id = p.id AND ph.deleted_at IS NULL
       WHERE p.project_id = ?1 AND p.deleted_at IS NULL
       GROUP BY p.id
       ORDER BY p.id ASC
      ''',
      variables: [Variable<String>(projectId)],
      readsFrom: {points, photos},
    );
  }

  List<PointSummary> _toSummaries(List<QueryRow> rows) {
    return [
      for (final (int index, QueryRow row) in rows.indexed)
        () {
          final point = points.map(row.data);
          return (
            point: point,
            label: point.refNumber?.toString() ?? '${index + 1}',
            isProvisional: point.refNumber == null,
            hasBefore: row.read<int>('has_before') == 1,
            hasAfter: row.read<int>('has_after') == 1,
            photoCount: row.read<int>('photo_count'),
          );
        }(),
    ];
  }

  Stream<Point?> watchPoint(String pointId) =>
      (select(points)..where((t) => t.id.equals(pointId))).watchSingleOrNull();

  Stream<List<Photo>> watchPhotos(String pointId) =>
      _photosQuery(pointId).watch();

  /// Mêmes clichés, en une seule lecture — voir [pointSummaries].
  Future<List<Photo>> photosOf(String pointId) => _photosQuery(pointId).get();

  MultiSelectable<Photo> _photosQuery(String pointId) {
    return select(photos)
      ..where((t) => t.pointId.equals(pointId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.takenAt),
      ]);
  }

  /// Catalogue des matériaux sélectionnables.
  ///
  /// Administré côté serveur : un opérateur choisit dans la liste, il ne
  /// l'étend pas. Une référence saisie librement sur le terrain ne serait pas
  /// traçable en audit de conformité.
  Stream<List<MaterialItem>> watchMaterials() {
    return (select(materials)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .watch();
  }

  Stream<List<PointMaterial>> watchPointMaterials(String pointId) {
    return (select(pointMaterials)
          ..where((t) => t.pointId.equals(pointId) & t.deletedAt.isNull()))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Écriture
  // ---------------------------------------------------------------------------

  /// Crée un point. Rend la main immédiatement, réseau ou pas.
  Future<String> createPoint({
    required String projectId,
    required String authorId,
    String? floor,
    String? room,
    String? description,
  }) async {
    final now = DateTime.now();
    final row = Point(
      id: newId(),
      projectId: projectId,
      refNumber: null, // attribué par le serveur à la synchro
      floor: floor,
      room: room,
      description: description,
      authorId: authorId,
      capturedAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _persistPoint(row);
    return row.id;
  }

  Future<void> updatePoint(
    String pointId, {
    String? floor,
    String? room,
    String? description,
  }) async {
    final current =
        await (select(points)..where((t) => t.id.equals(pointId))).getSingle();

    await _persistPoint(
      current.copyWith(
        floor: Value(floor ?? current.floor),
        room: Value(room ?? current.room),
        description: Value(description ?? current.description),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Suppression **logique**.
  ///
  /// Un DELETE physique serait annulé au prochain réveil d'un appareil resté
  /// hors-ligne : il repousserait sa copie de la ligne, qui ressusciterait.
  ///
  /// Les clichés suivent. Sans cela, `PhotoUploader` continuerait de téléverser
  /// les binaires d'une traversée abandonnée — plusieurs centaines de kilooctets
  /// pièce, sur le forfait data d'un chantier, pour des images que plus rien
  /// n'affichera.
  Future<void> deletePoint(String pointId) async {
    final now = DateTime.now();

    await transaction(() async {
      for (final photo in await photosOf(pointId)) {
        await retirePhoto(photo.id);
      }

      final current = await (select(points)..where((t) => t.id.equals(pointId)))
          .getSingle();
      await _persistPoint(
        current.copyWith(deletedAt: Value(now), updatedAt: now),
      );
    });
  }

  /// Enregistre une photo déjà compressée et écrite sur le disque.
  ///
  /// Aucune mise en file d'outbox ici, volontairement : la métadonnée ne sera
  /// poussée qu'une fois le binaire présent dans le bucket (voir
  /// `PhotoUploader`), pour que la base distante ne pointe jamais vers un objet
  /// inexistant.
  Future<String> registerPhoto({
    required String pointId,
    required PhotoKind kind,
    required String localPath,
    required int bytes,
    required int width,
    required int height,
    required String sha256,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();
    final row = Photo(
      id: newId(),
      pointId: pointId,
      kind: kind,
      localPath: localPath,
      remotePath: null,
      width: width,
      height: height,
      bytes: bytes,
      sha256: sha256,
      sortOrder: sortOrder,
      takenAt: now,
      uploadState: PhotoUploadState.ready,
      uploadAttempts: 0,
      nextUploadAt: now,
      lastError: null,
      updatedAt: now,
      deletedAt: null,
    );

    await into(photos).insert(row);
    return row.id;
  }

  /// Photos vivantes d'un point pour une nature donnée.
  Future<List<Photo>> photosOfKind(String pointId, PhotoKind kind) {
    return (select(photos)
          ..where(
            (t) =>
                t.pointId.equals(pointId) &
                t.kind.equalsValue(kind) &
                t.deletedAt.isNull(),
          ))
        .get();
  }

  /// Rang d'affichage de la prochaine photo complémentaire.
  Future<int> nextSortOrder(String pointId) async {
    final row = await (selectOnly(photos)
          ..addColumns([photos.sortOrder.max()])
          ..where(photos.pointId.equals(pointId) & photos.deletedAt.isNull()))
        .getSingle();
    return (row.read(photos.sortOrder.max()) ?? -1) + 1;
  }

  /// Retire une photo du dossier d'un point.
  ///
  /// Rend le chemin du fichier devenu inutile, à charge de l'appelant de
  /// l'effacer — le DAO ne touche pas au disque.
  ///
  /// Deux cas, et la distinction compte :
  ///
  ///  - Le binaire n'est jamais parti : le serveur ignore l'existence de cette
  ///    photo. On efface la ligne pour de bon. Faire voyager un tombstone pour
  ///    une donnée que personne d'autre n'a vue encombrerait la file pour rien.
  ///
  ///  - Le binaire est en ligne : d'autres appareils l'ont peut-être déjà. Il
  ///    faut la suppression logique habituelle, sans quoi la photo
  ///    ressusciterait à la prochaine descente.
  Future<String?> retirePhoto(String photoId) async {
    final photo =
        await (select(photos)..where((t) => t.id.equals(photoId))).getSingle();

    if (photo.remotePath == null) {
      await (delete(photos)..where((t) => t.id.equals(photoId))).go();
      return photo.localPath;
    }

    final now = DateTime.now();
    final retired = photo.copyWith(deletedAt: Value(now), updatedAt: now);

    await transaction(() async {
      await update(photos).replace(retired);
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.photo,
        entityId: retired.id,
        payload: photoPayload(retired),
      );
    });

    // Le fichier reste : il sert encore de cache d'affichage tant que la ligne
    // existe. Le balayage des orphelins s'en chargera le jour où elle
    // disparaîtra.
    return null;
  }

  /// Remplace la liste des matériaux d'un point.
  ///
  /// Les associations retirées sont marquées supprimées plutôt qu'effacées :
  /// la table est synchronisée comme les autres, et une ligne disparue
  /// localement serait invisible pour le serveur.
  Future<void> setMaterials(
    String pointId,
    Map<String, double?> quantitiesByMaterialId,
  ) async {
    final now = DateTime.now();

    await transaction(() async {
      final existing = await (select(pointMaterials)
            ..where((t) => t.pointId.equals(pointId)))
          .get();

      final desired = quantitiesByMaterialId.keys.toSet();

      for (final row in existing.where((r) => !desired.contains(r.materialId))) {
        if (row.deletedAt != null) continue;
        await _persistPointMaterial(
          row.copyWith(deletedAt: Value(now), updatedAt: now),
        );
      }

      for (final entry in quantitiesByMaterialId.entries) {
        await _persistPointMaterial(
          PointMaterial(
            pointId: pointId,
            materialId: entry.key,
            quantity: entry.value,
            updatedAt: now,
            deletedAt: null,
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Persistance atomique : table métier + outbox
  // ---------------------------------------------------------------------------

  Future<void> _persistPoint(Point row) {
    return transaction(() async {
      // `toCompanion(false)` : sans lui, une colonne remise à `null` serait
      // omise du SET et l'ancienne valeur survivrait au conflit. Voir la note
      // détaillée dans `ProjectDao`.
      await into(points).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.point,
        entityId: row.id,
        payload: pointPayload(row),
      );
    });
  }

  Future<void> _persistPointMaterial(PointMaterial row) {
    return transaction(() async {
      await into(pointMaterials).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.pointMaterial,
        // Clé composite : l'identité d'une association est la paire.
        entityId: '${row.pointId}:${row.materialId}',
        payload: pointMaterialPayload(row),
      );
    });
  }
}
