/// Traduction des lignes locales vers le format attendu par Postgres.
///
/// Ce fichier est la **seule** frontière entre le schéma local et le schéma
/// distant. Isoler la sérialisation ici évite que la forme du fil ne contamine
/// les DAO, et rend un changement de contrat serveur relisible d'un coup d'œil.
library;

import 'dart:convert';

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
        ProjectStatus.draft => 'draft',
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
      'template_id': row.templateId,
      'created_at': _iso(row.createdAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
    };

Map<String, Object?> projectPayload(Project row) => {
      'id': row.id,
      'client_id': row.clientId,
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

Map<String, Object?> pointPayload(Point row) => {
      'id': row.id,
      'project_id': row.projectId,
      'floor': row.floor,
      'room': row.room,
      'description': row.description,
      'author_id': row.authorId,
      'captured_at': _iso(row.capturedAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
      // `ref_number` est délibérément absent : le numéro définitif est attribué
      // par une séquence Postgres au moment de la synchro. L'envoyer laisserait
      // deux appareils hors-ligne écraser mutuellement leur « point 47 ».
    };

Map<String, Object?> pointMaterialPayload(PointMaterial row) => {
      'point_id': row.pointId,
      'material_id': row.materialId,
      'quantity': row.quantity,
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _isoOrNull(row.deletedAt),
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
      'draft' => ProjectStatus.draft,
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

UserRole userRoleFromWire(String value) => switch (value) {
      'admin' => UserRole.admin,
      'operator' => UserRole.operator,
      // Un rôle ajouté côté serveur ne doit surtout pas être interprété comme
      // `admin` par défaut. On échoue, la ligne part en erreur de synchro.
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

ReportTemplatesCompanion reportTemplateFromRemote(Map<String, dynamic> row) =>
    ReportTemplatesCompanion(
      id: Value(row['id'] as String),
      name: Value(row['name'] as String),
      // Postgrest désérialise déjà le `jsonb`. On le ré-encode : la base locale
      // ne stocke qu'une chaîne, le package de rendu se charge de la relire.
      config: Value(jsonEncode(row['config'] ?? const <String, Object?>{})),
      isDefault: Value(row['is_default'] as bool? ?? false),
      letterheadCoverPath: Value(row['letterhead_cover_path'] as String?),
      letterheadBodyPath: Value(row['letterhead_body_path'] as String?),
      updatedAt: Value(_parseTs(row['updated_at'])),
    );

ClientsCompanion clientFromRemote(Map<String, dynamic> row) => ClientsCompanion(
      id: Value(row['id'] as String),
      name: Value(row['name'] as String),
      contactName: Value(row['contact_name'] as String?),
      contactEmail: Value(row['contact_email'] as String?),
      contactPhone: Value(row['contact_phone'] as String?),
      address: Value(row['address'] as String?),
      logoPath: Value(row['logo_path'] as String?),
      templateId: Value(row['template_id'] as String?),
      createdAt: Value(_parseTs(row['created_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

ProjectsCompanion projectFromRemote(Map<String, dynamic> row) =>
    ProjectsCompanion(
      id: Value(row['id'] as String),
      clientId: Value(row['client_id'] as String),
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

PointsCompanion pointFromRemote(Map<String, dynamic> row) => PointsCompanion(
      id: Value(row['id'] as String),
      projectId: Value(row['project_id'] as String),
      // Le numéro définitif redescend ici, et remplace le provisoire affiché.
      refNumber: Value(row['ref_number'] as int?),
      floor: Value(row['floor'] as String?),
      room: Value(row['room'] as String?),
      description: Value(row['description'] as String?),
      authorId: Value(row['author_id'] as String),
      capturedAt: Value(_parseTs(row['captured_at'])),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

MaterialsCompanion materialFromRemote(Map<String, dynamic> row) =>
    MaterialsCompanion(
      id: Value(row['id'] as String),
      label: Value(row['label'] as String),
      manufacturer: Value(row['manufacturer'] as String?),
      reference: Value(row['reference'] as String?),
      clientId: Value(row['client_id'] as String?),
      updatedAt: Value(_parseTs(row['updated_at'])),
      deletedAt: Value(_parseTsOrNull(row['deleted_at'])),
    );

PointMaterialsCompanion pointMaterialFromRemote(Map<String, dynamic> row) =>
    PointMaterialsCompanion(
      pointId: Value(row['point_id'] as String),
      materialId: Value(row['material_id'] as String),
      quantity: Value((row['quantity'] as num?)?.toDouble()),
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
