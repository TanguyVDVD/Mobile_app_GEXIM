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

/// Mise en page du rapport PDF, propre à un client.
///
/// Descendu du serveur, jamais modifié depuis une tablette. Stocké localement
/// pour que l'aperçu du rapport reste disponible hors-ligne.
class ReportTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// JSON brut, désérialisé par le package `firestop_report`.
  ///
  /// Volontairement non typé ici : la base locale n'a pas à connaître la forme
  /// d'un template. Elle le transporte, le moteur de rendu l'interprète.
  TextColumn get config => text()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Papier à en-tête, dans le bucket `letterheads`. PDF ou image.
  TextColumn get letterheadCoverPath => text().nullable()();

  /// Fond des pages suivantes. `null` ⇒ la page de garde est réutilisée.
  TextColumn get letterheadBodyPath => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Client donneur d'ordre. Porte l'identité visuelle des rapports PDF.
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get contactName => text().nullable()();
  TextColumn get contactEmail => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  TextColumn get address => text().nullable()();

  /// Chemin du logo dans le bucket distant. Injecté dans l'en-tête du rapport.
  TextColumn get logoPath => text().nullable()();

  /// Template PDF appliqué à ce client. `null` ⇒ template par défaut.
  TextColumn get templateId =>
      text().nullable().customConstraint('REFERENCES report_templates(id)')();

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
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startedOn => dateTime().nullable()();
  DateTimeColumn get endedOn => dateTime().nullable()();
  TextColumn get status =>
      textEnum<ProjectStatus>().withDefault(const Constant('draft'))();
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

  TextColumn get floor => text().nullable()();
  TextColumn get room => text().nullable()();
  TextColumn get description => text().nullable()();

  TextColumn get authorId =>
      text().customConstraint('NOT NULL REFERENCES profiles(id)')();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Catalogue des matériaux de calfeutrement.
///
/// `clientId` nul ⇒ entrée du catalogue global. Renseigné ⇒ référence propre à
/// un client (produits imposés par son cahier des charges).
///
/// Renommée en `MaterialItem` : `Material` entrerait en collision avec le widget
/// du même nom dans tout fichier important `package:flutter/material.dart`.
@DataClassName('MaterialItem')
class Materials extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get clientId =>
      text().nullable().customConstraint('REFERENCES clients(id)')();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Association N-N point ↔ matériau, avec la quantité mise en œuvre.
class PointMaterials extends Table {
  TextColumn get pointId =>
      text().customConstraint('NOT NULL REFERENCES points(id)')();
  TextColumn get materialId =>
      text().customConstraint('NOT NULL REFERENCES materials(id)')();
  RealColumn get quantity => real().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {pointId, materialId};
}

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
/// descente des données. Voir la migration `20260904090300_sync_cursor.sql`.
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
