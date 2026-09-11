import 'package:drift/drift.dart';

import 'enums.dart';

// -----------------------------------------------------------------------------
// Conventions communes à toutes les tables métier
// -----------------------------------------------------------------------------
//
// 1. `id` est un UUID v7 généré **côté client** (voir `core/ids.dart`). Aucune
//    création d'entité ne dépend du réseau.
//
// 2. `updatedAt` porte la résolution de conflit : last-write-wins. Les points
//    sont quasi append-only et chaque opérateur travaille sur sa zone, donc les
//    conflits réels sont rares — un CRDT serait de la sur-ingénierie ici.
//
// 3. `deletedAt` : **suppression logique uniquement**. Un DELETE physique est
//    incompatible avec l'offline-first (un appareil hors-ligne depuis trois
//    jours ressusciterait la ligne à la synchro).
//
//    Conséquence directe et volontaire : l'outbox n'a **pas** d'opération
//    « delete ». Supprimer, c'est renseigner `deletedAt` — donc un upsert
//    ordinaire. Un seul chemin de code au lieu de deux.
//
// 4. Les clés étrangères sont déclarées en `customConstraint` et non via
//    `.references(Table, #id)`.
//
//    Ce n'est pas un choix de style. Avec drift_dev 2.31 sur analyzer 10.x,
//    `.references()` n'est plus reconnu : le générateur émet un simple
//    avertissement (« This parameter should be a simple class name »), le build
//    se termine en succès, et le schéma produit **ne contient aucune clause
//    REFERENCES**. L'intégrité référentielle disparaît sans que rien n'échoue.
//
//    `customConstraint` écrit le SQL tel quel : il est vérifiable dans
//    `database.g.dart` et insensible aux versions de l'analyseur. Contrepartie
//    à connaître : il remplace *toutes* les contraintes générées, d'où le
//    `NOT NULL` explicite.
// -----------------------------------------------------------------------------

/// Profil utilisateur, miroir local de `auth.users` + rôle applicatif.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get email => text()();
  TextColumn get role => textEnum<UserRole>()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Client donneur d'ordre.
///
/// Son nom, son adresse et son logo figurent en tête de chaque fiche du
/// rapport, sur le formulaire AS BUILT commun à tous. L'adresse et le logo sont
/// donc **obligatoires**, ici comme en base distante : un rapport sans eux
/// serait amputé de l'identification de son destinataire.
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get contactName => text().nullable()();
  TextColumn get contactEmail => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  TextColumn get address => text().withLength(min: 1)();

  /// Chemin du logo dans le bucket `client-logos`, posé dans la case « logo
  /// client » de chaque fiche.
  TextColumn get logoPath => text().withLength(min: 1)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Chantier. Unité de travail de l'opérateur et périmètre d'un rapport.
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get clientId =>
      text().customConstraint('NOT NULL REFERENCES clients(id)')();

  /// Numéro de chantier du donneur d'ordre, reporté sur chaque fiche du
  /// rapport (ligne « Numéro Projet » du gabarit).
  ///
  /// Texte et non entier : les numéros de chantier portent presque toujours un
  /// préfixe ou un millésime (« 2026-118 », « BE/447 »). Nullable, parce qu'un
  /// chantier se crée sur le terrain avant que l'administratif ne suive.
  TextColumn get code => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startedOn => dateTime().nullable()();
  DateTimeColumn get endedOn => dateTime().nullable()();
  TextColumn get status =>
      textEnum<ProjectStatus>().withDefault(const Constant('inProgress'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Affectation d'un opérateur à un chantier.
///
/// Décide de tout côté serveur : c'est cette table que consultent les policies
/// RLS pour savoir ce qu'un opérateur a le droit de lire et d'écrire. Elle est
/// synchronisée comme les autres depuis que la console d'administration permet
/// d'affecter quelqu'un hors ligne.
class ProjectMembers extends Table {
  TextColumn get projectId =>
      text().customConstraint('NOT NULL REFERENCES projects(id)')();
  TextColumn get userId =>
      text().customConstraint('NOT NULL REFERENCES profiles(id)')();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, userId};
}

/// Valeur d'une des listes déroulantes de la fiche de traversée.
///
/// Une seule table pour toutes les listes — configurations, configurations
/// détaillées, niveaux EI, fournisseurs, types de produit, produits —
/// discriminées par [kind]. Voir [SettingKind] pour le raisonnement.
///
/// **Administrée, jamais saisie librement.** Une référence tapée à la main sur
/// le terrain ne serait pas exploitable en audit de conformité : deux
/// orthographes du même produit deviennent deux produits. Les points s'y
/// rattachent par cle etrangere, ce qui rend la faute impossible.
///
/// D'où aussi la suppression **logique** : une option retirée du catalogue
/// reste référencée par les fiches déjà produites, et un rapport régénéré deux
/// ans plus tard doit rendre le même document.
@DataClassName('SettingOption')
class SettingOptions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<SettingKind>()();
  TextColumn get label => text().withLength(min: 1, max: 120)();

  /// Rang d'affichage dans la liste déroulante.
  ///
  /// Explicite plutôt qu'alphabétique : « EI30, EI60, EI90, EI120 » est un
  /// ordre croissant que l'alphabet casserait — EI120 passerait avant EI30 —
  /// et les configurations ont un ordre métier que l'administrateur connaît.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Point / traversée : le cœur métier. Un trou dans une paroi, son calfeutrement
/// et les preuves photographiques associées.
class Points extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().customConstraint('NOT NULL REFERENCES projects(id)')();

  /// Numéro **définitif**, attribué par une séquence Postgres à la synchro.
  ///
  /// Volontairement nullable. Deux opérateurs hors-ligne créeraient tous deux
  /// le « point 47 » : impossible de trancher localement. Tant que ce champ est
  /// `null`, l'UI affiche un numéro provisoire déduit du rang de création dans
  /// le projet — l'ordre par `id` suffit, les UUID v7 étant chronologiques.
  /// Aucune colonne supplémentaire n'est donc nécessaire.
  IntColumn get refNumber => integer().nullable()();

  /// Bon de commande du client. Terme anglais conservé : c'est celui qui figure
  /// sur les pièces contractuelles comme sur le gabarit du rapport.
  TextColumn get purchaseOrder => text().nullable()();

  /// Bâtiment(s) concerné(s). Champ libre : aucune nomenclature ne s'impose
  /// d'un site à l'autre.
  TextColumn get building => text().nullable()();

  /// Étage, de -3 à 5 (voir [floorRange]).
  ///
  /// Entier et non texte : l'étage est un axe ordonné, et c'est ce qui permet
  /// de lire un relevé du sous-sol au dernier niveau.
  IntColumn get floorLevel => integer().nullable()();

  /// Local. Hors gabarit du rapport, conservé comme repère de terrain.
  TextColumn get room => text().nullable()();

  /// Observations libres. Hors gabarit du rapport, lui aussi.
  TextColumn get description => text().nullable()();

  // ---------------------------------------------------------------------------
  // Caractéristiques choisies dans les listes administrées
  // ---------------------------------------------------------------------------
  //
  // Toutes nullable : une traversée se photographie d'abord et se qualifie
  // ensuite, souvent de retour au bureau. Exiger les six listes à la création
  // reviendrait à faire remplir un formulaire devant un trou dans un mur.

  TextColumn get configurationId =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get configurationDetailId =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get eiLevelId =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get supplierId =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get productTypeId =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();

  // Cinq colonnes plutôt qu'une table d'association, et c'est délibéré.
  //
  // Le gabarit du rapport porte cinq lignes numérotées, « Produit utilisé (1) »
  // à « (5) » : l'arité est fixe et la position est signifiante. Une table N-N
  // aurait exigé une colonne de rang pour dire exactement la même chose.
  TextColumn get product1Id =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get product2Id =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get product3Id =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get product4Id =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();
  TextColumn get product5Id =>
      text().nullable().customConstraint('REFERENCES setting_options(id)')();

  TextColumn get authorId =>
      text().customConstraint('NOT NULL REFERENCES profiles(id)')();

  /// Date de la traversée — la « Date » du gabarit.
  DateTimeColumn get capturedAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Étages proposés, du troisième sous-sol au cinquième niveau.
///
/// Borné plutôt que libre : au-delà c'est une tour, et le relevé s'y ferait de
/// toute façon bâtiment par bâtiment. La liste vit ici et non dans l'écran de
/// saisie, pour que la contrainte SQL du schéma (`points_floor_level_range`)
/// et la liste déroulante restent démontrablement la même chose.
const List<int> floorRange = [-3, -2, -1, 0, 1, 2, 3, 4, 5];

/// Libellé d'un étage. Le rez-de-chaussée se nomme, il ne se numérote pas.
String floorLabel(int level) => switch (level) {
      0 => 'Rez-de-chaussée',
      < 0 => '$level (sous-sol)',
      _ => 'Étage $level',
    };

/// Photo rattachée à un point.
///
/// Cette table porte à la fois la **métadonnée** (synchronisée via l'outbox) et
/// l'**état du binaire** (piloté par `PhotoUploader`). Les deux sont séparés :
/// le fichier part en premier, la ligne distante n'est écrite qu'ensuite, pour
/// que la base ne référence jamais un objet absent du bucket.
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get pointId =>
      text().customConstraint('NOT NULL REFERENCES points(id)')();
  TextColumn get kind => textEnum<PhotoKind>()();

  /// Chemin absolu du fichier compressé dans le répertoire de l'app.
  /// Reste renseigné après l'upload : il sert de cache d'affichage.
  TextColumn get localPath => text().nullable()();

  /// Chemin dans le bucket distant. `null` ⇒ binaire pas encore transféré.
  TextColumn get remotePath => text().nullable()();

  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get bytes => integer().nullable()();

  /// Empreinte du fichier compressé : déduplication et détection de corruption.
  TextColumn get sha256 => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get takenAt => dateTime()();

  TextColumn get uploadState => textEnum<PhotoUploadState>()();
  IntColumn get uploadAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextUploadAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Réglages locaux, hors synchronisation.
///
/// Sert notamment à mémoriser le dernier compte connecté sur cette tablette :
/// c'est ce qui permet de détecter un changement d'utilisateur et de purger les
/// données du précédent, plutôt que de mélanger les relevés de deux personnes
/// dans une même base.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Curseur de réplication descendante, une ligne par entité.
///
/// Contient le `synced_at` **serveur** le plus récent appliqué localement. Pas
/// l'`updated_at` : celui-ci vient des tablettes et une horloge déréglée
/// suffirait à propulser le curseur dans le futur, coupant définitivement la
/// descente des données. Voir `touch_synced_at` dans
/// `supabase/migrations/20260913100000_schema.sql`.
class SyncCursors extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entity};
}

/// File d'attente durable des écritures à pousser vers Supabase.
///
/// Firestore sait synchroniser des documents hors-ligne, mais Firebase Storage
/// n'a **aucune** file d'upload offline — et les photos sont 95 % du volume.
/// Cette table devait donc exister quel que soit le backend ; y faire transiter
/// aussi les métadonnées ne coûte presque rien.
///
/// Pas de colonne `operation` : voir la note sur la suppression logique en tête
/// de fichier. Tout est un upsert.
class OutboxEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => textEnum<OutboxEntity>()();
  TextColumn get entityId => text()();

  /// Instantané JSON de la ligne, au format attendu par la table distante.
  TextColumn get payload => text()();

  /// Ordonne le drain, et **porte l'ordre des dépendances** : un projet est
  /// forcément créé avant ses points, donc inséré avant dans l'outbox. Le
  /// fusionnement d'entrées (coalescing) préserve délibérément cette date.
  DateTimeColumn get createdAt => dateTime()();

  TextColumn get status =>
      textEnum<OutboxStatus>().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
