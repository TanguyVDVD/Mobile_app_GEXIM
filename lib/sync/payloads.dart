/// Traduction des lignes locales vers le format attendu par Postgres.
///
/// Ce fichier est la **seule** frontière entre le schéma local et le schéma
/// distant. Isoler la sérialisation ici évite que la forme du fil ne contamine
/// les DAO, et rend un changement de contrat serveur relisible d'un coup d'œil.
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/enums.dart';

String _iso(DateTime value) => value.toUtc().toIso8601String();
String? _isoOrNull(DateTime? value) => value == null ? null : _iso(value);

/// Valeurs des enums Postgres.
///
/// Le mapping est explicite plutôt que dérivé de `Enum.name` : côté SQL on veut
/// du `snake_case` idiomatique, et surtout renommer une constante Dart ne doit
/// jamais casser silencieusement le contrat distant.
extension ProjectStatusWire on ProjectStatus {
  String get wire => switch (this) {
        ProjectStatus.inProgress => 'in_progress',
        ProjectStatus.completed => 'completed',
      };
}

extension PhotoKindWire on PhotoKind {
  String get wire => switch (this) {
        PhotoKind.before => 'before',
        PhotoKind.after => 'after',
        PhotoKind.extra => 'extra',
      };
}

extension SettingKindWire on SettingKind {
  String get wire => switch (this) {
        SettingKind.configuration => 'configuration',
        SettingKind.configurationDetail => 'configuration_detail',
        SettingKind.eiLevel => 'ei_level',
        SettingKind.supplier => 'supplier',
        SettingKind.productType => 'product_type',
        SettingKind.product => 'product',
      };
}

extension UserRoleWire on UserRole {
  String get wire => switch (this) {
        UserRole.admin => 'admin',
        UserRole.operator => 'operator',
      };
}

Map<String, Object?> clientPayload(Client row) => {
      'id': row.id,
      'name': row.name,
      'contact_name': row.contactName,
      'contact_email': row.contactEmail,
      'contact_phone': row.contactPhone,
      'address': row.address,
      'logo_path': row.logoPath,
      'created_at': _iso(row.createdAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
    };

Map<String, Object?> projectPayload(Project row) => {
      'id': row.id,
      'client_id': row.clientId,
      'code': row.code,
      'name': row.name,
      'description': row.description,
      'started_on': _isoOrNull(row.startedOn),
      'ended_on': _isoOrNull(row.endedOn),
      'status': row.status.wire,
      'created_at': _iso(row.createdAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
    };

Map<String, Object?> projectMemberPayload(ProjectMember row) => {
      'project_id': row.projectId,
      'user_id': row.userId,
      'added_at': _iso(row.addedAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
    };

/// Option d'une liste déroulante administrée.
Map<String, Object?> settingOptionPayload(SettingOption row) => {
      'id': row.id,
      'kind': row.kind.wire,
      'label': row.label,
      'sort_order': row.sortOrder,
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
    };

Map<String, Object?> pointPayload(Point row) => {
      'id': row.id,
      'project_id': row.projectId,
      'purchase_order': row.purchaseOrder,
      'building': row.building,
      'floor_level': row.floorLevel,
      'room': row.room,
      'description': row.description,
      'configuration_id': row.configurationId,
      'configuration_detail_id': row.configurationDetailId,
      'ei_level_id': row.eiLevelId,
      'supplier_id': row.supplierId,
      'product_type_id': row.productTypeId,
      'product1_id': row.product1Id,
      'product2_id': row.product2Id,
      'product3_id': row.product3Id,
      'product4_id': row.product4Id,
      'product5_id': row.product5Id,
      'author_id': row.authorId,
      'captured_at': _iso(row.capturedAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
      // `ref_number` est délibérément absent : le numéro définitif est attribué
      // par une séquence Postgres au moment de la synchro. L'envoyer laisserait
      // deux appareils hors-ligne écraser mutuellement leur « point 47 ».
    };

/// Métadonnée d'une photo — jamais son binaire.
///
/// N'est mise en file qu'**après** transfert réussi du fichier, pour que la base
/// distante ne référence jamais un objet absent du bucket.
Map<String, Object?> photoPayload(Photo row) => {
      'id': row.id,
      'point_id': row.pointId,
      'kind': row.kind.wire,
      'storage_path': row.remotePath,
      'width': row.width,
      'height': row.height,
      'bytes': row.bytes,
      'sha256': row.sha256,
      'sort_order': row.sortOrder,
      'taken_at': _iso(row.takenAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
      // `synced_at` est délibérément absent : c'est le curseur du serveur. Le
      // laisser écrire par un client rendrait la réplication descendante
      // vulnérable à l'horloge de n'importe quelle tablette.
    };

// =============================================================================
// Sens descendant : Postgres → base locale
// =============================================================================

DateTime _parseTs(Object? value) =>
    DateTime.parse(value! as String).toLocal();

DateTime? _parseTsOrNull(Object? value) =>
    value == null ? null : _parseTs(value);

/// Horodatage serveur d'une ligne reçue : le curseur de pull.
DateTime syncedAtOf(Map<String, dynamic> row) => _parseTs(row['synced_at']);

ProjectStatus projectStatusFromWire(String value) => switch (value) {
      'in_progress' => ProjectStatus.inProgress,
      'completed' => ProjectStatus.completed,
      _ => throw FormatException('Statut de chantier inconnu : $value'),
    };

PhotoKind photoKindFromWire(String value) => switch (value) {
      'before' => PhotoKind.before,
      'after' => PhotoKind.after,
      'extra' => PhotoKind.extra,
      _ => throw FormatException('Type de photo inconnu : $value'),
    };

SettingKind settingKindFromWire(String value) => switch (value) {
      'configuration' => SettingKind.configuration,
      'configuration_detail' => SettingKind.configurationDetail,
      'ei_level' => SettingKind.eiLevel,
      'supplier' => SettingKind.supplier,
      'product_type' => SettingKind.productType,
      'product' => SettingKind.product,
      // Une liste ajoutée côté serveur ne doit surtout pas se ranger par défaut
      // dans l'une des existantes : elle apparaîtrait dans une liste déroulante
      // où elle n'a rien à faire, et un technicien la choisirait.
      //
      // On échoue — et ce n'est pas une ligne qui part en erreur : c'est
      // **toute la descente** qui s'arrête ici, pour cette entité et toutes
      // celles qui la suivent dans `PullEntity`. `SyncEngine._runCycle` le
      // signale par `needsAttention`. Le remède est de mettre l'application à
      // jour ; c'est ce qui est arrivé au poste Windows le 11 septembre 2026.
      _ => throw FormatException('Liste de paramètres inconnue : $value'),
    };

UserRole userRoleFromWire(String value) => switch (value) {
      'admin' => UserRole.admin,
      'operator' => UserRole.operator,
      // Un rôle ajouté côté serveur ne doit surtout pas être interprété comme
      // `admin` par défaut. On échoue — et comme pour les listes ci-dessus,
      // c'est la descente entière qui s'arrête, signalée par `needsAttention`.
      _ => throw FormatException('Rôle inconnu : $value'),
    };

ProfilesCompanion profileFromRemote(Map<String, dynamic> row) =>
    ProfilesCompanion(
      id: Value(row['id'] as String),
      fullName: Value(row['full_name'] as String? ?? ''),
      email: Value(row['email'] as String? ?? ''),
      role: Value(userRoleFromWire(row['role'] as String)),
      updatedAt: Value(_parseTs(row['updated_at'])),
    );

ClientsCompanion clientFromRemote(Map<String, dynamic> row) => ClientsCompanion(
      id: Value(row['id'] as String),
      name: Value(row['name'] as String),
      contactName: Value(row['contact_name'] as String?),
      contactEmail: Value(row['contact_email'] as String?),
      contactPhone: Value(row['contact_phone'] as String?),
      address: Value(row['address'] as String),
      logoPath: Value(row['logo_path'] as String),
      createdAt: Value(_parseTs(row['created_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

ProjectsCompanion projectFromRemote(Map<String, dynamic> row) =>
    ProjectsCompanion(
      id: Value(row['id'] as String),
      clientId: Value(row['client_id'] as String),
      code: Value(row['code'] as String?),
      name: Value(row['name'] as String),
      description: Value(row['description'] as String?),
      startedOn: Value(_parseTsOrNull(row['started_on'])),
      endedOn: Value(_parseTsOrNull(row['ended_on'])),
      status: Value(projectStatusFromWire(row['status'] as String)),
      createdAt: Value(_parseTs(row['created_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

ProjectMembersCompanion projectMemberFromRemote(Map<String, dynamic> row) =>
    ProjectMembersCompanion(
      projectId: Value(row['project_id'] as String),
      userId: Value(row['user_id'] as String),
      addedAt: Value(_parseTs(row['added_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

SettingOptionsCompanion settingOptionFromRemote(Map<String, dynamic> row) =>
    SettingOptionsCompanion(
      id: Value(row['id'] as String),
      kind: Value(settingKindFromWire(row['kind'] as String)),
      label: Value(row['label'] as String),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

PointsCompanion pointFromRemote(Map<String, dynamic> row) => PointsCompanion(
      id: Value(row['id'] as String),
      projectId: Value(row['project_id'] as String),
      // Le numéro définitif redescend ici, et remplace le provisoire affiché.
      refNumber: Value(row['ref_number'] as int?),
      purchaseOrder: Value(row['purchase_order'] as String?),
      building: Value(row['building'] as String?),
      floorLevel: Value(row['floor_level'] as int?),
      room: Value(row['room'] as String?),
      description: Value(row['description'] as String?),
      configurationId: Value(row['configuration_id'] as String?),
      configurationDetailId: Value(row['configuration_detail_id'] as String?),
      eiLevelId: Value(row['ei_level_id'] as String?),
      supplierId: Value(row['supplier_id'] as String?),
      productTypeId: Value(row['product_type_id'] as String?),
      product1Id: Value(row['product1_id'] as String?),
      product2Id: Value(row['product2_id'] as String?),
      product3Id: Value(row['product3_id'] as String?),
      product4Id: Value(row['product4_id'] as String?),
      product5Id: Value(row['product5_id'] as String?),
      authorId: Value(row['author_id'] as String),
      capturedAt: Value(_parseTs(row['captured_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

/// Colonnes d'une photo appartenant au **serveur**.
///
/// `localPath`, `uploadState`, `uploadAttempts` et `lastError` en sont
/// volontairement absents : ce sont des champs strictement locaux. Les inclure
/// effacerait le chemin du fichier en cache de l'appareil qui a pris la photo,
/// à chaque redescente — l'obligeant à la retélécharger sans raison.
PhotosCompanion photoFromRemote(Map<String, dynamic> row) => PhotosCompanion(
      id: Value(row['id'] as String),
      pointId: Value(row['point_id'] as String),
      kind: Value(photoKindFromWire(row['kind'] as String)),
      remotePath: Value(row['storage_path'] as String?),
      width: Value(row['width'] as int?),
      height: Value(row['height'] as int?),
      bytes: Value(row['bytes'] as int?),
      sha256: Value(row['sha256'] as String?),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      takenAt: Value(_parseTs(row['taken_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
      // Le binaire est chez le serveur : par définition, il y est déjà.
      uploadState: const Value(PhotoUploadState.uploaded),
    );
