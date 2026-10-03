import 'package:drift/drift.dart';

// La base s'ouvre différemment sur tablette (un fichier SQLite) et dans un
// navigateur (SQLite en WebAssembly). Le choix se fait **à la compilation** :
// la connexion native importe `dart:ffi`, qui n'existe pas côté web — un
// simple test à l'exécution ne suffirait pas, le fichier ne compilerait pas.
import 'connexion/connexion_native.dart'
    if (dart.library.js_interop) 'connexion/connexion_web.dart';
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
  AppDatabase() : super(ouvrirConnexion());

  /// Constructeur de test : base en mémoire, sans I/O disque.
  ///
  // Pas de paramètre `super` : le constructeur généré nomme le sien `e`, et
  // `AppDatabase.forTesting(super.e)` se lirait nettement moins bien.
  // ignore: use_super_parameters
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  /// Version 2 : `setting_options.parent_id`, le fournisseur d'un produit.
  /// Version 3 : `projects.purchase_order` et `projects.building`.
  /// Version 4 : `points.project_code` et `points.project_name`.
  /// Version 5 : `points.ref_number` passe d'entier à texte.
  /// Version 6 : l'étage devient une option de liste (`points.floor_id`).
  ///
  /// Toute modification de table doit s'accompagner d'une migration, et d'un
  /// test qui la rejoue (`test/migration_test.dart`) : les pièges rencontrés
  /// avant la remise à plat du schéma sont décrits dans `CLAUDE.md` (« Une
  /// migration est écrite hier mais s'exécute avec le code d'aujourd'hui »).
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
          await _createParentIndex();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Une base qui porte une autre version vient d'une build de
          // développement antérieure à la remise à plat : le dire en clair,
          // plutôt que le message générique de drift, qui parle de « strategy »
          // à un technicien. L'écran de démarrage affiche ce texte tel quel.
          if (from < 1 || from > to) {
            throw StateError(
              'La base locale de cet appareil est en version $from, que cette '
              'version de l\'application (schéma $to) ne sait pas lire.',
            );
          }

          // 1 → 2. SQL littéral et non `m.addColumn` : une migration doit
          // rester ce qu'elle était le jour où elle a été écrite, quelle que
          // soit la définition Dart qui aura cours quand elle s'exécutera.
          //
          // Les produits déjà présents restent sans fournisseur jusqu'à ce que
          // le serveur les renvoie rattachés (voir la migration SQL
          // `product_supplier`, qui les réestampille).
          if (from < 2) {
            await customStatement(
              'ALTER TABLE setting_options ADD COLUMN parent_id TEXT',
            );
            await _createParentIndex();
          }

          // 2 → 3. Le bon de commande et le bâtiment par défaut du chantier.
          // `points.ref_number` existait déjà : seul son sens change, il est
          // saisi au lieu d'être attribué par le serveur.
          if (from < 3) {
            await customStatement(
              'ALTER TABLE projects ADD COLUMN purchase_order TEXT',
            );
            await customStatement(
              'ALTER TABLE projects ADD COLUMN building TEXT',
            );
          }

          // 3 → 4. Les écarts d'une traversée à son chantier. Le troisième,
          // `purchase_order`, existait déjà.
          if (from < 4) {
            await customStatement(
              'ALTER TABLE points ADD COLUMN project_code TEXT',
            );
            await customStatement(
              'ALTER TABLE points ADD COLUMN project_name TEXT',
            );
          }

          // 4 → 5. Le numéro de point devient un texte (« 1.40 »).
          //
          // SQLite ne sait pas changer le type d'une colonne, et il ne suffit
          // pas de la *déclarer* texte côté Dart : une colonne créée INTEGER
          // garde son **affinité** numérique, et « 1.40 » y serait rangé comme
          // le nombre 1,4 — relu « 1.4 ». D'où une vraie colonne neuve : on
          // écarte l'ancienne, on crée la nouvelle, on recopie, on retire.
          if (from < 5) {
            await customStatement(
              'ALTER TABLE points RENAME COLUMN ref_number TO ref_number_entier',
            );
            await customStatement(
              'ALTER TABLE points ADD COLUMN ref_number TEXT',
            );
            await customStatement(
              'UPDATE points SET ref_number = CAST(ref_number_entier AS TEXT) '
              'WHERE ref_number_entier IS NOT NULL',
            );
            await customStatement(
              'ALTER TABLE points DROP COLUMN ref_number_entier',
            );
          }

          // 5 → 6. L'étage n'est plus un entier mais une option de liste.
          //
          // L'ancienne colonne est retirée sans être convertie ici : les
          // options « Niveau N » sont créées par le serveur, avec des
          // identifiants que cet appareil ne connaît pas encore. C'est la
          // migration SQL qui rattache chaque traversée à son étage et la
          // réestampille ; elle redescend alors avec son `floor_id`.
          if (from < 6) {
            await customStatement(
              'ALTER TABLE points ADD COLUMN floor_id TEXT '
              'REFERENCES setting_options(id)',
            );
            await customStatement('ALTER TABLE points DROP COLUMN floor_level');
          }
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

  /// Les produits d'un fournisseur — la liste que la fiche ouvre cinq fois.
  ///
  /// À part de [_createIndexes] : la montée de version 1 → 2 le crée aussi, et
  /// rejouer les autres échouerait sur des index déjà présents.
  Future<void> _createParentIndex() => customStatement(
        'CREATE INDEX idx_setting_options_parent '
        'ON setting_options (parent_id, deleted_at, sort_order)',
      );

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
