import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../database/database.dart';
import '../database/tables/enums.dart';
import '../features/capture/photo_storage.dart';
import 'payloads.dart';
import 'remote_gateway.dart';

/// Réplication descendante : serveur → base locale.
///
/// Sans elle, l'app est aveugle. L'admin crée un chantier, y affecte un
/// opérateur, et l'opérateur ne le voit jamais : la file d'attente ne sait que
/// pousser.
///
/// Les écritures se font **directement** en base, sans passer par les DAO :
/// une ligne reçue du serveur n'a rien à faire dans l'outbox, elle en vient.
class PullEngine {
  PullEngine(this._db, this._gateway, {int pageSize = 500})
      : _pageSize = pageSize;

  final AppDatabase _db;
  final RemoteGateway _gateway;

  /// Paramétrable pour que les tests puissent exercer la pagination sans
  /// fabriquer cinq cents lignes.
  final int _pageSize;

  /// Recouvrement appliqué au curseur à chaque passe.
  ///
  /// `synced_at` est posé au **début** de l'écriture, mais la ligne ne devient
  /// visible qu'au **commit**. Deux transactions concurrentes peuvent donc
  /// valider dans l'ordre inverse de leurs horodatages : une ligne estampillée
  /// 10:00:01 apparaît après qu'on a déjà lu jusqu'à 10:00:03, et le curseur
  /// l'enjambe — définitivement.
  ///
  /// Relire systématiquement les deux dernières minutes referme la fenêtre pour
  /// toute transaction plus courte que cela. Les doublons ainsi produits sont
  /// sans effet : l'application d'une ligne est idempotente.
  static const Duration _overlap = Duration(minutes: 2);

  /// Redescend toutes les entités. Rend le nombre de lignes reçues.
  Future<int> drain() async {
    var received = 0;
    // `PullEntity.values` est ordonné par dépendances : les clés étrangères
    // sont actives localement, un point inséré avant son chantier échouerait.
    for (final entity in PullEntity.values) {
      received += await _pullEntity(entity);
    }
    return received;
  }

  Future<int> _pullEntity(PullEntity entity) async {
    final cursor = await _cursorFor(entity);
    final since = cursor?.subtract(_overlap);

    DateTime? highWater = cursor;
    var offset = 0;
    var received = 0;

    while (true) {
      final rows = await _gateway.fetchSince(
        entity: entity,
        since: since,
        offset: offset,
        limit: _pageSize,
      );
      if (rows.isEmpty) break;

      var appliquees = 0;
      var differe = false;

      // Une page = une transaction. Les écrans, branchés sur des streams Drift,
      // ne voient donc jamais un lot à moitié appliqué.
      await _db.transaction(() async {
        for (final row in rows) {
          try {
            await _apply(entity, row);
          } on SqliteException catch (e) {
            if (!_parentManquant(e)) rethrow;
            // La ligne est **différée**, pas abandonnée : on quitte la boucle
            // sans toucher au curseur, ce qui la fera redescendre au cycle
            // suivant. Sortir de la fermeture valide au passage tout ce qui
            // précède — une transaction avortée reperdrait une page entière
            // pour une seule ligne en avance sur son parent.
            differe = true;
            return;
          }

          appliquees++;
          final stamp = syncedAtOf(row);
          final current = highWater;
          if (current == null || stamp.isAfter(current)) {
            highWater = stamp;
          }
        }
      });

      received += appliquees;
      if (differe) break;
      if (rows.length < _pageSize) break;
      offset += rows.length;
    }

    // Le curseur n'avance qu'une fois **toutes** les pages appliquées. Une
    // coupure en cours de route laisse le curseur en arrière : la passe suivante
    // reprend depuis le début plutôt que d'abandonner un trou dans les données.
    final finalCursor = highWater;
    if (finalCursor != null && finalCursor != cursor) {
      await _saveCursor(entity, finalCursor);
    }

    return received;
  }

  /// La ligne reçue désigne-t-elle un parent que la base locale n'a pas ?
  ///
  /// Le cas normal, et il n'a rien d'exceptionnel : une affectation de chantier
  /// peut arriver avant le chantier lui-même, si l'admin l'a créée pendant que
  /// la tablette parcourait déjà les entités suivantes.
  ///
  /// Avant ce garde-fou, l'insertion levait une `SqliteException` — ni une
  /// `SyncException`, ni rattrapée par `SyncEngine._runCycle`. Elle remontait
  /// donc jusqu'à un `unawaited(syncNow())` et disparaissait : **plus aucune
  /// descente n'aboutissait**, sur aucune entité, sans le moindre message. Le
  /// technicien voyait simplement son chantier ne jamais arriver.
  static bool _parentManquant(SqliteException e) {
    // 787 = SQLITE_CONSTRAINT_FOREIGNKEY. Le message sert de repli : les
    // exécuteurs ne remontent pas tous le code étendu.
    return e.extendedResultCode == 787 ||
        e.message.toUpperCase().contains('FOREIGN KEY');
  }

  Future<void> _apply(PullEntity entity, Map<String, dynamic> row) {
    return switch (entity) {
      PullEntity.profile => _upsert(_db.profiles, profileFromRemote(row)),
      PullEntity.settingOption =>
        _upsert(_db.settingOptions, settingOptionFromRemote(row)),
      PullEntity.client => _upsert(_db.clients, clientFromRemote(row)),
      PullEntity.project => _upsert(_db.projects, projectFromRemote(row)),
      PullEntity.projectMember =>
        _upsert(_db.projectMembers, projectMemberFromRemote(row)),
      PullEntity.point => _upsert(_db.points, pointFromRemote(row)),
      PullEntity.photo => _upsert(_db.photos, photoFromRemote(row)),
      PullEntity.deletedProject => _purger(row['id'] as String),
      PullEntity.deletedPoint => _purgerPoint(
          projectId: row['project_id'] as String,
          pointId: row['id'] as String,
        ),
    };
  }

  /// Un chantier a été supprimé définitivement : cet appareil efface sa copie,
  /// fichiers de clichés compris. Sans effet si le chantier n'y est pas.
  Future<void> _purger(String projectId) async {
    await PhotoStorage.effacer(await _db.projectDao.purgeProject(projectId));
  }

  /// Une traversée a été supprimée définitivement : cet appareil efface sa
  /// copie, puis fait le ménage du stockage.
  ///
  /// Le ménage est fait ici, par l'appareil qui reçoit la trace, parce que
  /// c'est le premier moment où l'on est sûr d'être en ligne — la suppression,
  /// elle, a pu être décidée sans réseau. Il est **sans engagement** : un
  /// échec ne doit pas arrêter la descente, ni la faire reprendre en boucle
  /// sur cette trace. Au pire, des fichiers restent dans le bucket ; un autre
  /// appareil, ou la suppression du chantier, les emportera.
  Future<void> _purgerPoint({
    required String projectId,
    required String pointId,
  }) async {
    final fichiers = await _db.pointDao.purgePoint(pointId);
    // La descente relit toujours ses deux dernières minutes (`_overlap`) : la
    // même trace repasse donc ici à chaque cycle, tant qu'elle est la plus
    // récente. Le ménage ne part que la première fois — quand la traversée
    // était encore là.
    if (fichiers == null) return;

    await PhotoStorage.effacer(fichiers);
    try {
      await _gateway.removePointFiles(projectId: projectId, pointId: pointId);
    } on Object {
      // Voir ci-dessus : refus du serveur (chantier clôturé pour un
      // technicien), réseau qui tombe — rien qui justifie d'échouer.
    }
  }

  /// Insère, ou met à jour **seulement si la version reçue est plus récente**.
  ///
  /// Le garde-fou est dans le `WHERE` du `ON CONFLICT`, donc évalué par SQLite
  /// dans la même instruction. Le faire en Dart imposerait un lire-puis-écrire :
  /// entre les deux, l'opérateur peut avoir modifié le point à l'écran, et sa
  /// saisie serait écrasée par une version serveur plus ancienne.
  ///
  /// C'est exactement la règle appliquée côté serveur par `reject_stale_write`.
  /// Les deux extrémités arbitrent donc à l'identique : une modification locale
  /// en attente d'envoi survit à une redescente, et si le serveur détient plus
  /// récent, c'est lui qui gagne — des deux côtés.
  Future<void> _upsert<T extends Table, D>(
    TableInfo<T, D> table,
    Insertable<D> row,
  ) async {
    await _db.into(table).insert(
          row,
          onConflict: DoUpdate.withExcluded(
            (old, excluded) => row,
            where: (old, excluded) => _updatedAt(excluded).isBiggerThan(
              _updatedAt(old),
            ),
          ),
        );
  }

  /// Toutes les tables répliquées portent `updated_at`, mais rien dans le type
  /// `Table` ne l'exprime. On le récupère par son nom SQL.
  Expression<DateTime> _updatedAt(Table table) {
    return (table as TableInfo<Table, Object?>)
        .columnsByName['updated_at']! as Expression<DateTime>;
  }

  Future<DateTime?> _cursorFor(PullEntity entity) async {
    final row = await (_db.select(_db.syncCursors)
          ..where((t) => t.entity.equals(entity.name)))
        .getSingleOrNull();
    return row?.syncedAt;
  }

  Future<void> _saveCursor(PullEntity entity, DateTime syncedAt) {
    return _db.into(_db.syncCursors).insertOnConflictUpdate(
          SyncCursor(entity: entity.name, syncedAt: syncedAt),
        );
  }
}
