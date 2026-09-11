import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../core/emplacements.dart';
import 'daos/outbox_dao.dart';
import 'daos/point_dao.dart';
import 'daos/project_dao.dart';
import 'daos/settings_dao.dart';
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
    Clients,
    Projects,
    ProjectMembers,
    SettingOptions,
    Points,
    Photos,
    OutboxEntries,
    SyncCursors,
    AppSettings,
  ],
  daos: [ProjectDao, PointDao, SettingsDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur de test : base en mémoire, sans I/O disque.
  ///
  // Pas de paramètre `super` : le constructeur généré nomme le sien `e`, et
  // `AppDatabase.forTesting(super.e)` se lirait nettement moins bien.
  // ignore: use_super_parameters
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  /// Première version du schéma.
  ///
  /// Toute modification de table devra s'accompagner d'une migration, et d'un
  /// test qui la rejoue : les pièges rencontrés avant la remise à plat du
  /// schéma sont décrits dans `CLAUDE.md` (« Une migration est écrite hier mais
  /// s'exécute avec le code d'aujourd'hui »).
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        // Aucune autre version n'existe. Une base qui en porte une vient d'une
        // build de développement antérieure : le dire en clair, plutôt que le
        // message générique de drift, qui parle de « strategy » à un
        // technicien. L'écran de démarrage affiche ce texte tel quel.
        onUpgrade: (Migrator m, int from, int to) async => throw StateError(
          'La base locale de cet appareil est en version $from, que cette '
          'version de l\'application (schéma $to) ne sait pas lire.',
        ),
        beforeOpen: (OpeningDetails details) async {
          // Drift n'active pas les clés étrangères par défaut : SQLite les
          // ignore silencieusement sans ce pragma, et le schéma relationnel
          // ne serait plus qu'une intention.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    // Chemins réellement empruntés par l'app : liste des points d'un chantier,
    // photos d'un point, clichés en attente d'envoi, et sélection de la
    // prochaine entrée d'outbox.
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
    // Une liste déroulante à la fois.
    await customStatement(
      'CREATE INDEX idx_setting_options_kind '
      'ON setting_options (kind, deleted_at, sort_order)',
    );
  }

  /// Profil de l'utilisateur connecté. Porte son rôle, donc ce que l'interface
  /// doit lui proposer.
  Stream<Profile?> watchProfile(String userId) =>
      (select(profiles)..where((t) => t.id.equals(userId))).watchSingleOrNull();

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
  Stream<int> watchPendingCount() =>
      _pendingQuery().watchSingle().map((row) => row.read<int>('pending'));

  /// Travail qui n'existe encore que sur cet appareil, **refus compris**.
  ///
  /// Interrogé avant une déconnexion ou un changement de compte : ces deux
  /// gestes ouvrent la voie à la purge de la base, et doivent être refusés tant
  /// qu'il reste quelque chose à transmettre.
  ///
  /// Plus large que [watchPendingCount], et c'est tout son objet. Le badge
  /// compte ce qui *va* partir ; ici on compte aussi ce que le serveur a
  /// **refusé** — entrées d'outbox et clichés en `failed`. Ne compter que
  /// l'attente laissait un autre compte se connecter et purger ces refus sans
  /// un mot : un relevé bloqué par la clôture d'un chantier, le temps qu'un
  /// administrateur la lève, disparaissait de la tablette de son auteur.
  Future<({int enAttente, int refuses})> travailNonTransmis() async {
    final row = await customSelect(
      'SELECT '
      '  (SELECT COUNT(*) FROM outbox_entries WHERE status <> ?1) '
      '+ (SELECT COUNT(*) FROM photos '
      '    WHERE upload_state = ?2 AND deleted_at IS NULL) AS en_attente, '
      '  (SELECT COUNT(*) FROM outbox_entries WHERE status = ?1) '
      '+ (SELECT COUNT(*) FROM photos '
      '    WHERE upload_state = ?1 AND deleted_at IS NULL) AS refuses',
      variables: const [
        Variable<String>('failed'),
        Variable<String>('ready'),
      ],
      readsFrom: {outboxEntries, photos},
    ).getSingle();

    return (
      enAttente: row.read<int>('en_attente'),
      refuses: row.read<int>('refuses'),
    );
  }

  Selectable<QueryRow> _pendingQuery() {
    return customSelect(
      'SELECT (SELECT COUNT(*) FROM outbox_entries WHERE status = ?) '
      '     + (SELECT COUNT(*) FROM photos '
      '        WHERE upload_state = ? AND deleted_at IS NULL) AS pending',
      variables: const [
        Variable<String>('pending'),
        Variable<String>('ready'),
      ],
      readsFrom: {outboxEntries, photos},
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Pas `getApplicationDocumentsDirectory()` directement : sur Windows il
    // rend les vrais Documents de l'utilisateur, souvent synchronises par
    // OneDrive — un mode de corruption SQLite connu. Voir `racineDonnees`.
    final dir = await racineDonnees();
    final file = File(p.join(dir.path, 'firestop.sqlite'));

    // Répare le résolveur de tmpdir sur certains Android, faute de quoi les
    // requêtes qui débordent en mémoire échouent sur appareil bas de gamme.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}
