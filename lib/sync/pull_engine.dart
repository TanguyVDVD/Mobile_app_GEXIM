import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/enums.dart';
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

      // Une page = une transaction. Les écrans, branchés sur des streams Drift,
      // ne voient donc jamais un lot à moitié appliqué.
      await _db.transaction(() async {
        for (final row in rows) {
          await _apply(entity, row);

          final stamp = syncedAtOf(row);
          final current = highWater;
          if (current == null || stamp.isAfter(current)) {
            highWater = stamp;
          }
        }
      });

      received += rows.length;
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

  Future<void> _apply(PullEntity entity, Map<String, dynamic> row) {
    return switch (entity) {
      PullEntity.profile => _upsert(_db.profiles, profileFromRemote(row)),
      PullEntity.reportTemplate =>
        _upsert(_db.reportTemplates, reportTemplateFromRemote(row)),
      PullEntity.client => _upsert(_db.clients, clientFromRemote(row)),
      PullEntity.project => _upsert(_db.projects, projectFromRemote(row)),
      PullEntity.projectMember =>
        _upsert(_db.projectMembers, projectMemberFromRemote(row)),
      PullEntity.point => _upsert(_db.points, pointFromRemote(row)),
      PullEntity.material => _upsert(_db.materials, materialFromRemote(row)),
      PullEntity.pointMaterial =>
        _upsert(_db.pointMaterials, pointMaterialFromRemote(row)),
      PullEntity.photo => _upsert(_db.photos, photoFromRemote(row)),
    };
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
