import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/outbox_dao.dart';
import 'daos/point_dao.dart';
import 'daos/project_dao.dart';
// Requis par `database.g.dart` : le fichier généré est un `part` de cette
// bibliothèque et hérite donc de ses imports. Sans lui, les colonnes `textEnum`
// ne compilent pas — l'analyseur ne le signale pas, seul le build échoue.
import 'tables/enums.dart';
import 'tables/tables.dart';

part 'database.g.dart';

/// Base SQLite locale — **la** source de vérité de l'application.
///
/// L'UI ne parle jamais au réseau : elle lit des streams issus de cette base et
/// y écrit directement. L'écran se met donc à jour instantanément, en avion
/// comme en 4G, et `SyncEngine` rattrape le serveur en arrière-plan.
@DriftDatabase(
  tables: [
    Profiles,
    ReportTemplates,
    Clients,
    Projects,
    ProjectMembers,
    Points,
    Materials,
    PointMaterials,
    Photos,
    OutboxEntries,
    SyncCursors,
    AppSettings,
  ],
  daos: [ProjectDao, PointDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur de test : base en mémoire, sans I/O disque.
  ///
  // Pas de paramètre `super` : le constructeur généré nomme le sien `e`, et
  // `AppDatabase.forTesting(super.e)` se lirait nettement moins bien.
  // ignore: use_super_parameters
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        beforeOpen: (OpeningDetails details) async {
          // Drift n'active pas les clés étrangères par défaut : SQLite les
          // ignore silencieusement sans ce pragma, et le schéma relationnel
          // ne serait plus qu'une intention.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    // Chemins réellement empruntés par l'app : liste des points d'un chantier,
    // photos d'un point, et sélection de la prochaine entrée d'outbox.
    await customStatement(
      'CREATE INDEX idx_points_project ON points (project_id, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX idx_photos_point ON photos (point_id, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX idx_photos_pending '
      'ON photos (upload_state, next_upload_at)',
    );
    await customStatement(
      'CREATE INDEX idx_outbox_drain '
      'ON outbox_entries (status, next_attempt_at, created_at)',
    );
    // Recherche de l'entrée à fusionner lors d'un enqueue (voir OutboxDao).
    await customStatement(
      'CREATE INDEX idx_outbox_entity '
      'ON outbox_entries (entity_type, entity_id, status)',
    );
  }

  /// Nombre d'écritures encore locales — métadonnées en attente + binaires non
  /// transférés. Alimente le badge « N éléments à synchroniser » de l'UI.
  ///
  /// Sur un chantier sans réseau, ce compteur est la seule preuve visible pour
  /// l'opérateur que son travail n'est pas perdu. Il doit être exact.
  ///
  /// Une seule requête plutôt que deux streams recombinés : `readsFrom` fait
  /// réémettre drift dès que l'une **ou** l'autre table bouge. Combiner deux
  /// streams laisserait le compteur figé pendant les transferts de photos,
  /// puisque seule la table `photos` change alors.
  /// Profil de l'utilisateur connecté. Porte son rôle, donc ce que l'interface
  /// doit lui proposer.
  Stream<Profile?> watchProfile(String userId) =>
      (select(profiles)..where((t) => t.id.equals(userId))).watchSingleOrNull();

  Stream<int> watchPendingCount() =>
      _pendingQuery().watchSingle().map((row) => row.read<int>('pending'));

  /// Même compte, en une seule lecture.
  ///
  /// Interrogé avant une déconnexion ou un changement de compte : ces deux
  /// gestes détruisent des données locales, et doivent être refusés tant qu'il
  /// reste du travail non transmis.
  Future<int> pendingCount() async =>
      (await _pendingQuery().getSingle()).read<int>('pending');

  Selectable<QueryRow> _pendingQuery() {
    return customSelect(
      'SELECT (SELECT COUNT(*) FROM outbox_entries WHERE status = ?) '
      '     + (SELECT COUNT(*) FROM photos '
      '        WHERE upload_state IN (?, ?) AND deleted_at IS NULL) AS pending',
      variables: const [
        Variable<String>('pending'),
        Variable<String>('ready'),
        Variable<String>('captured'),
      ],
      readsFrom: {outboxEntries, photos},
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'firestop.sqlite'));

    // Répare le résolveur de tmpdir sur certains Android, faute de quoi les
    // requêtes qui débordent en mémoire échouent sur appareil bas de gamme.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}
