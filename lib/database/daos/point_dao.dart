import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../core/numero_point.dart';
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
  int photoCount,

  /// Nombre de champs de la fiche encore vides. Voir
  /// [PointDao.valeursManquantes].
  int missingValues,
});

/// Une fiche est complète quand il ne lui manque aucune valeur et qu'elle
/// porte au moins un cliché — la fiche en admet un ou deux.
extension Completude on PointSummary {
  bool get isComplete => missingValues == 0 && photoCount > 0;
}

/// Ce qu'une fiche dit de son chantier, écarts de la traversée appliqués.
typedef Identification = ({String? code, String name, String? purchaseOrder});

/// Écritures et lectures du domaine « traversée ».
///
/// **Invariant du fichier** : toute mutation écrit la table métier *et* met en
/// file l'écriture distante **dans la même transaction**. Un crash entre les
/// deux (kill Android, batterie vide) laisserait sinon une modification visible
/// à l'écran mais jamais synchronisée — la pire des pannes, parce que
/// silencieuse : l'opérateur croit son relevé enregistré.
@DriftAccessor(tables: [Points, Photos, SettingOptions, Projects])
class PointDao extends DatabaseAccessor<AppDatabase> with _$PointDaoMixin {
  PointDao(super.attachedDatabase);

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  /// Points d'un chantier, avec numéro d'affichage et état de complétude.
  ///
  /// Triés par **numéro saisi**, les fiches sans numéro à la fin. À numéro
  /// égal ou absent, l'`id` départage par ordre de création : les UUID v7 sont
  /// préfixés d'un timestamp, donc chronologiques. Le classeur Excel suit le
  /// même ordre, feuille après feuille.
  ///
  /// Une fiche sans numéro est marquée comme telle (`isProvisional`) et
  /// affiche un tiret : inventer un rang à sa place mettrait sur une fiche de
  /// conformité un identifiant que personne n'a choisi.
  ///
  /// Le nombre de clichés est agrégé dans la même requête plutôt que chargé
  /// point par point. Avec le nombre de valeurs manquantes, c'est
  /// l'information la plus utile de l'écran : avant de quitter le chantier,
  /// l'opérateur doit repérer d'un coup d'œil les traversées à compléter — y
  /// revenir coûte une demi-journée.
  Stream<List<PointSummary>> watchPoints(String projectId) =>
      _pointSummaryQuery(projectId).watch().map(_toSummaries);

  /// Même relevé, en **une seule lecture**.
  ///
  /// Pour l'export Excel, qui est un instantané : il n'a rien à faire abonné à
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
             pr.code           AS chantier_code,
             pr.name           AS chantier_name,
             pr.purchase_order AS chantier_purchase_order,
             COUNT(ph.id) AS photo_count
        FROM points p
        JOIN projects pr ON pr.id = p.project_id
        LEFT JOIN photos ph
               ON ph.point_id = p.id AND ph.deleted_at IS NULL
       WHERE p.project_id = ?1 AND p.deleted_at IS NULL
       GROUP BY p.id
       ORDER BY p.id ASC
      ''',
      variables: [Variable<String>(projectId)],
      // `projects` aussi : corriger le chantier change ce qui manque à ses
      // fiches, et la liste doit se rafraîchir.
      readsFrom: {points, photos, projects},
    );
  }

  List<PointSummary> _toSummaries(List<QueryRow> rows) {
    // Triés ici et non par SQL : un numéro est un texte, et l'ordre
    // alphabétique rangerait « 10 » avant « 2 ». La requête livre l'ordre de
    // création, qui départage les numéros égaux ou absents — le tri de Dart
    // est stable.
    final tries = [...rows]..sort(
        (a, b) => comparerNumeros(
          a.readNullable<String>('ref_number'),
          b.readNullable<String>('ref_number'),
        ),
      );

    return [
      for (final row in tries)
        () {
          final point = points.map(row.data);
          return (
            point: point,
            label: point.refNumber ?? '—',
            isProvisional: point.refNumber == null,
            photoCount: row.read<int>('photo_count'),
            missingValues: valeursManquantes(
              point,
              // Même règle que `identification` : l'écart de la traversée,
              // sinon la valeur du chantier.
              (
                code: point.projectCode ?? row.read<String?>('chantier_code'),
                name: point.projectName ?? row.read<String>('chantier_name'),
                purchaseOrder: point.purchaseOrder ??
                    row.read<String?>('chantier_purchase_order'),
              ),
            ),
          );
        }(),
    ];
  }

  /// Nombre de champs de la fiche encore vides.
  ///
  /// Douze au plus : numéro de projet, intitulé, Purchase Order, numéro du
  /// point, bâtiment, étage, configuration, configuration détaillée, niveau
  /// EI, fournisseur, type de produit, et **un** produit — la fiche offre
  /// cinq emplacements, mais une traversée n'en demande qu'un.
  ///
  /// Les trois premiers viennent du chantier, et comptent quand même — c'est
  /// la valeur **portée par la fiche** qui est jugée ([identification]). Un
  /// numéro de projet effacé par mégarde sur le chantier doit se voir sur
  /// chacune de ses fiches, pas se découvrir dans le classeur exporté.
  ///
  /// N'y figurent pas : la date, toujours renseignée, et les clichés, comptés
  /// à part.
  static int valeursManquantes(Point point, Identification chantier) {
    bool vide(String? valeur) => valeur == null || valeur.trim().isEmpty;

    final aucunProduit = [
      point.product1Id,
      point.product2Id,
      point.product3Id,
      point.product4Id,
      point.product5Id,
    ].every((id) => id == null);

    return [
      vide(chantier.code),
      vide(chantier.name),
      vide(chantier.purchaseOrder),
      vide(point.refNumber),
      vide(point.building),
      point.floorId == null,
      point.configurationId == null,
      point.configurationDetailId == null,
      point.eiLevelId == null,
      point.supplierId == null,
      point.productTypeId == null,
      aucunProduit,
    ].where((manque) => manque).length;
  }

  /// Numéro de projet, intitulé et Purchase Order **tels que la fiche les
  /// porte** : l'écart de la traversée s'il y en a un, la valeur du chantier
  /// sinon. Voir « Écarts au chantier » dans `Points`.
  ///
  /// L'écran de saisie et l'export passent tous deux par ici : écrite à deux
  /// endroits, la règle finirait par différer, et la fiche exportée ne dirait
  /// plus ce que le technicien avait sous les yeux.
  static Identification identification(Point point, Project project) => (
        code: point.projectCode ?? project.code,
        name: point.projectName ?? project.name,
        purchaseOrder: point.purchaseOrder ?? project.purchaseOrder,
      );

  /// Un **autre** point vivant du chantier porte-t-il déjà ce numéro ?
  ///
  /// Rien n'interdit le doublon — voir `Points.refNumber` — mais la fiche le
  /// signale : c'est le seul garde-fou, et il ne vaut que pour ce que
  /// l'appareil connaît. Le doublon né de deux tablettes hors ligne n'apparaît
  /// qu'après la synchronisation.
  Stream<bool> watchRefNumberTaken(String pointId) {
    return customSelect(
      '''
      SELECT EXISTS (
        SELECT 1
          FROM points moi
          JOIN points autre
            ON autre.project_id = moi.project_id
           AND autre.ref_number = moi.ref_number
           AND autre.id <> moi.id
           AND autre.deleted_at IS NULL
         WHERE moi.id = ?1
      ) AS pris
      ''',
      variables: [Variable<String>(pointId)],
      readsFrom: {points},
    ).watchSingle().map((row) => row.read<bool>('pris'));
  }

  Stream<Point?> watchPoint(String pointId) =>
      (select(points)..where((t) => t.id.equals(pointId))).watchSingleOrNull();

  /// Ce qui situe une traversée pour quelqu'un qui n'a pas la fiche sous les
  /// yeux : l'intitulé de son chantier et son numéro. `null` si elle n'est
  /// plus sur l'appareil.
  Future<({String chantier, String? numero})?> repere(String pointId) async {
    final point = await (select(points)..where((t) => t.id.equals(pointId)))
        .getSingleOrNull();
    if (point == null) return null;

    final project = await (select(projects)
          ..where((t) => t.id.equals(point.projectId)))
        .getSingleOrNull();
    if (project == null) return null;

    return (chantier: project.name, numero: point.refNumber);
  }

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

  // ---------------------------------------------------------------------------
  // Écriture
  // ---------------------------------------------------------------------------

  /// Crée un point. Rend la main immédiatement, réseau ou pas.
  ///
  /// Seuls le chantier et l'auteur sont exigés : une traversée se photographie
  /// devant le mur et se caractérise ensuite, souvent de retour au bureau.
  /// Réclamer toutes les listes déroulantes avant de pouvoir déclencher l'appareil
  /// inverserait l'ordre réel du travail.
  ///
  /// [capturedAt] est la « Date » de la fiche. Paramétrable parce qu'un relevé
  /// se saisit parfois le lendemain, et que la date qui figurera au rapport de
  /// conformité est celle de l'intervention, pas celle de la frappe.
  ///
  /// Deux champs arrivent **préremplis**, et restent modifiables sur la fiche :
  ///
  ///  * le bâtiment reprend celui que le chantier propose par défaut ;
  ///  * [refNumber] propose le suivant du dernier point relevé (« 1.40 » →
  ///    « 1.41 »). Une proposition, pas une attribution : le technicien la
  ///    corrige si son repérage ne suit pas l'ordre de saisie.
  Future<String> createPoint({
    required String projectId,
    required String authorId,
    DateTime? capturedAt,
    String? refNumber,
  }) {
    // Une transaction : la lecture du plus grand numéro et l'insertion ne
    // doivent pas être séparées par une autre création.
    return transaction(() async {
      final project = await (select(projects)
            ..where((t) => t.id.equals(projectId)))
          .getSingle();

      final now = DateTime.now();
      final row = Point(
        id: newId(),
        projectId: projectId,
        refNumber: refNumber ?? await _nextRefNumber(projectId),
        building: project.building,
        authorId: authorId,
        capturedAt: capturedAt ?? now,
        updatedAt: now,
        deletedAt: null,
      );
      await _persistPoint(row);
      return row.id;
    });
  }

  /// Le numéro à proposer : celui qui suit le **dernier point relevé** du
  /// chantier, « 1 » s'il n'y en a aucun.
  ///
  /// Le dernier relevé et non « le plus grand » : avec des numéros en texte,
  /// le plus grand n'a pas de sens sûr, alors qu'un technicien qui vient de
  /// faire le 1.40 fait presque toujours le 1.41 ensuite. Les points
  /// supprimés ne comptent pas : leur numéro est libre.
  ///
  /// `null` si ce dernier point n'a pas de numéro, ou un numéro sans chiffre :
  /// le champ reste vide plutôt que de recevoir une invention.
  Future<String?> _nextRefNumber(String projectId) async {
    final dernier = await (select(points)
          ..where(
            (t) => t.projectId.equals(projectId) & t.deletedAt.isNull(),
          )
          // Les identifiants sont des UUID v7 : leur ordre est celui de la
          // création.
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();

    if (dernier == null) return '1';
    final numero = dernier.refNumber;
    return numero == null ? null : numeroSuivant(numero);
  }

  /// Modifie une fiche, champ par champ.
  ///
  /// Chaque paramètre est un `Value` **optionnel**, et la distinction est
  /// essentielle sur un formulaire où presque tout est facultatif :
  ///
  ///  * absent (`null`) ⇒ le champ n'est pas touché ;
  ///  * `Value(null)`   ⇒ le champ est **effacé**.
  ///
  /// L'ancienne signature prenait des `String?` et appliquait `valeur ?? valeur
  /// actuelle` : désélectionner une liste déroulante était alors impossible,
  /// l'effacement se lisant comme « ne rien changer ». Sur une fiche qui en
  /// compte neuf, l'erreur se serait vue à la première correction.
  Future<void> updatePoint(
    String pointId, {
    Value<DateTime>? capturedAt,
    Value<String?>? refNumber,
    Value<String?>? projectCode,
    Value<String?>? projectName,
    Value<String?>? purchaseOrder,
    Value<String?>? building,
    Value<String?>? floorId,
    Value<String?>? description,
    Value<String?>? configurationId,
    Value<String?>? configurationDetailId,
    Value<String?>? eiLevelId,
    Value<String?>? supplierId,
    Value<String?>? productTypeId,
    Value<String?>? product1Id,
    Value<String?>? product2Id,
    Value<String?>? product3Id,
    Value<String?>? product4Id,
    Value<String?>? product5Id,
  }) async {
    final current =
        await (select(points)..where((t) => t.id.equals(pointId))).getSingle();

    await _persistPoint(
      current.copyWith(
        capturedAt: capturedAt?.value,
        refNumber: refNumber ?? Value(current.refNumber),
        projectCode: projectCode ?? Value(current.projectCode),
        projectName: projectName ?? Value(current.projectName),
        purchaseOrder: purchaseOrder ?? Value(current.purchaseOrder),
        building: building ?? Value(current.building),
        floorId: floorId ?? Value(current.floorId),
        description: description ?? Value(current.description),
        configurationId: configurationId ?? Value(current.configurationId),
        configurationDetailId:
            configurationDetailId ?? Value(current.configurationDetailId),
        eiLevelId: eiLevelId ?? Value(current.eiLevelId),
        supplierId: supplierId ?? Value(current.supplierId),
        productTypeId: productTypeId ?? Value(current.productTypeId),
        product1Id: product1Id ?? Value(current.product1Id),
        product2Id: product2Id ?? Value(current.product2Id),
        product3Id: product3Id ?? Value(current.product3Id),
        product4Id: product4Id ?? Value(current.product4Id),
        product5Id: product5Id ?? Value(current.product5Id),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Change le fournisseur, et **vide les produits qui ne sont pas les siens**.
  ///
  /// La fiche ne propose que les produits du fournisseur choisi ; en changer
  /// en laissant les anciens produits ferait sortir un rapport qui attribue à
  /// un fabricant les références d'un autre. Une seule écriture, donc une seule
  /// entrée d'outbox : aucun état intermédiaire incohérent ne part au serveur.
  ///
  /// Les emplacements vidés ne se tassent pas : la position est signifiante,
  /// « Produit utilisé (3) » reste le troisième même si le deuxième est vide.
  Future<void> setSupplier(String pointId, String? supplierId) {
    return transaction(() async {
      final current = await (select(points)..where((t) => t.id.equals(pointId)))
          .getSingle();

      final siens = supplierId == null
          ? const <String>{}
          : {
              for (final produit in await (select(settingOptions)
                    ..where((t) => t.parentId.equals(supplierId)))
                  .get())
                produit.id,
            };
      Value<String?> garde(String? id) =>
          Value(id != null && siens.contains(id) ? id : null);

      await updatePoint(
        pointId,
        supplierId: Value(supplierId),
        product1Id: garde(current.product1Id),
        product2Id: garde(current.product2Id),
        product3Id: garde(current.product3Id),
        product4Id: garde(current.product4Id),
        product5Id: garde(current.product5Id),
      );
    });
  }

  /// Efface **physiquement** une traversée de cet appareil : ses clichés, et
  /// ce qui attendait d'être envoyé pour eux. Rend les chemins des fichiers de
  /// clichés, que l'appelant retire du disque.
  ///
  /// N'est appelée que par `PullEngine`, à la réception de la trace que le
  /// serveur garde d'une suppression : le serveur a alors déjà effacé la
  /// ligne. Le geste de l'utilisateur, lui, reste [deletePoint].
  ///
  /// Rend `null` si la traversée n'était pas sur cet appareil : il n'y avait
  /// rien à faire, et l'appelant n'a pas de ménage à lancer.
  Future<List<String>?> purgePoint(String pointId) {
    final point = [Variable<String>(pointId)];

    return transaction(() async {
      final presente = await (select(points)
            ..where((t) => t.id.equals(pointId)))
          .getSingleOrNull();
      if (presente == null) return null;

      final fichiers = await customSelect(
        'SELECT local_path FROM photos '
        'WHERE point_id = ?1 AND local_path IS NOT NULL',
        variables: point,
      ).map((row) => row.read<String>('local_path')).get();

      await customUpdate(
        '''
        DELETE FROM outbox_entries
         WHERE (entity_type = 'point' AND entity_id = ?1)
            OR (entity_type = 'photo' AND entity_id IN
                 (SELECT id FROM photos WHERE point_id = ?1))
        ''',
        variables: point,
        updates: {attachedDatabase.outboxEntries},
        updateKind: UpdateKind.delete,
      );
      await (delete(photos)..where((t) => t.pointId.equals(pointId))).go();
      await (delete(points)..where((t) => t.id.equals(pointId))).go();

      return fichiers;
    });
  }

  /// Suppression d'une traversée, **telle que l'utilisateur la demande**.
  ///
  /// La ligne est marquée (`deleted_at`) et mise en file, comme toute autre
  /// modification : c'est ce qui permet de supprimer une fiche hors ligne,
  /// devant le mur. Elle disparaît aussitôt de l'écran. Le **serveur**, en
  /// recevant la marque, efface réellement le point et ses clichés et en
  /// garde une trace ; cette trace redescend, et [purgePoint] efface alors la
  /// ligne de cet appareil aussi.
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
}
