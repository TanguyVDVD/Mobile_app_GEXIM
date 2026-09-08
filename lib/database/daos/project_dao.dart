import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../sync/payloads.dart';
import '../database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'project_dao.g.dart';

/// Écritures et lectures des chantiers et de leurs donneurs d'ordre.
///
/// Même invariant que [PointDao] : table métier et outbox dans une seule
/// transaction.
@DriftAccessor(tables: [Clients, Projects, ProjectMembers, Profiles])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(super.attachedDatabase);

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  Stream<List<Client>> watchClients() {
    return (select(clients)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Stream<List<Project>> watchAllProjects() {
    return (select(projects)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Project> projectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingle();

  Stream<Project?> watchProject(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<Client?> watchClient(String id) =>
      (select(clients)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Comptes pouvant être affectés à un chantier.
  Stream<List<Profile>> watchOperators() {
    return (select(profiles)
          ..where((t) => t.role.equalsValue(UserRole.operator))
          ..orderBy([(t) => OrderingTerm.asc(t.fullName)]))
        .watch();
  }

  /// Tous les comptes connus, pour l'écran de gestion des utilisateurs.
  Stream<List<Profile>> watchAllProfiles() {
    return (select(profiles)
          ..orderBy([
            (t) => OrderingTerm.asc(t.role),
            (t) => OrderingTerm.asc(t.fullName),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // La relation utilisateur ↔ chantier, vue des deux côtés
  // ---------------------------------------------------------------------------
  //
  // Une seule table, `project_members`, et deux lectures. Stocker en plus un
  // tableau d'identifiants sur chaque entité donnerait deux sources de vérité
  // pour la même relation : la première affectation faite hors ligne avec une
  // écriture qui échoue les ferait diverger, sans que rien ne dise laquelle
  // fait foi.

  /// Chantiers auxquels un utilisateur est affecté.
  Stream<List<Project>> watchAssignedProjects(String userId) {
    final query = select(projects).join([
      innerJoin(
        projectMembers,
        projectMembers.projectId.equalsExp(projects.id) &
            projectMembers.userId.equals(userId) &
            projectMembers.deletedAt.isNull(),
      ),
    ])
      ..where(projects.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(projects.startedOn)]);

    return query.watch().map(
          (rows) => [for (final row in rows) row.readTable(projects)],
        );
  }

  /// Utilisateurs autorisés sur un chantier.
  Stream<List<ProjectMember>> watchMembers(String projectId) {
    return (select(projectMembers)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull()))
        .watch();
  }

  /// Nombre de chantiers d'un utilisateur, pour la liste de gestion.
  Stream<Map<String, int>> watchAssignmentCounts() {
    return customSelect(
      '''
      SELECT user_id, COUNT(*) AS total
        FROM project_members
       WHERE deleted_at IS NULL
       GROUP BY user_id
      ''',
      readsFrom: {projectMembers},
    ).watch().map(
          (rows) => {
            for (final row in rows)
              row.read<String>('user_id'): row.read<int>('total'),
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Écriture
  // ---------------------------------------------------------------------------

  Future<String> createClient({
    required String name,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? templateId,
  }) async {
    final now = DateTime.now();
    final row = Client(
      id: newId(),
      name: name,
      contactName: contactName,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      address: address,
      logoPath: null,
      templateId: templateId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _persistClient(row);
    return row.id;
  }

  Future<String> createProject({
    required String clientId,
    required String name,
    String? description,
    DateTime? startedOn,
  }) async {
    final now = DateTime.now();
    final row = Project(
      id: newId(),
      clientId: clientId,
      name: name,
      description: description,
      startedOn: startedOn ?? now,
      endedOn: null,
      status: ProjectStatus.inProgress,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _persistProject(row);
    return row.id;
  }

  Future<void> updateClient(
    String clientId, {
    required String name,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? address,
  }) async {
    final current =
        await (select(clients)..where((t) => t.id.equals(clientId))).getSingle();

    await _persistClient(
      current.copyWith(
        name: name,
        contactName: Value(contactName),
        contactEmail: Value(contactEmail),
        contactPhone: Value(contactPhone),
        address: Value(address),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateProject(
    String projectId, {
    required String name,
    required String clientId,
    String? description,
    DateTime? startedOn,
  }) async {
    final current = await projectById(projectId);

    await _persistProject(
      current.copyWith(
        name: name,
        clientId: clientId,
        description: Value(description),
        startedOn: Value(startedOn),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Remplace la liste des opérateurs affectés à un chantier.
  ///
  /// Les retraits sont **logiques**, comme partout ailleurs. C'est aussi ce qui
  /// a imposé de filtrer sur `deleted_at` dans la fonction RLS
  /// `is_project_member` : sans ce filtre, une affectation retirée continuait
  /// d'ouvrir l'accès au chantier — la révocation ne révoquait rien.
  Future<void> setMembers(String projectId, Set<String> userIds) async {
    final now = DateTime.now();

    await transaction(() async {
      final existing = await (select(projectMembers)
            ..where((t) => t.projectId.equals(projectId)))
          .get();

      for (final row in existing) {
        if (userIds.contains(row.userId) || row.deletedAt != null) continue;
        await _persistMember(
          row.copyWith(deletedAt: Value(now), updatedAt: now),
        );
      }

      final known = {for (final row in existing) row.userId: row};
      for (final userId in userIds) {
        final previous = known[userId];
        // Une réaffectation réutilise la ligne existante : la clé primaire est
        // la paire, un insert échouerait.
        await _persistMember(
          previous == null
              ? ProjectMember(
                  projectId: projectId,
                  userId: userId,
                  addedAt: now,
                  updatedAt: now,
                )
              : previous.copyWith(
                  deletedAt: const Value(null),
                  updatedAt: now,
                ),
        );
      }
    });
  }

  /// Clôture un chantier : gèle la saisie et rend le rapport PDF générable.
  ///
  /// L'app masque les chantiers clôturés aux opérateurs, mais ce n'est qu'un
  /// confort d'interface. Le verrou qui compte est la policy RLS côté Postgres,
  /// qui refuse toute écriture d'opérateur sur un projet `completed` — une
  /// tablette dont l'horloge ou le cache est décalé ne peut pas la contourner.
  ///
  /// Réservé à l'admin : le contrôle du rôle appartient à la couche appelante,
  /// et est de toute façon rejoué par RLS.
  Future<void> closeProject(String projectId) async {
    final current = await projectById(projectId);
    final now = DateTime.now();

    await _persistProject(
      current.copyWith(
        status: ProjectStatus.completed,
        endedOn: Value(now),
        updatedAt: now,
      ),
    );
  }

  /// Supprime un chantier — **logiquement**, comme partout ailleurs.
  ///
  /// Les traversées et leurs clichés ne sont pas touchés : ils restent
  /// rattachés au chantier, invisibles avec lui. Un dossier de conformité
  /// incendie ne s'efface pas d'un geste dans une interface, et une suppression
  /// faite par erreur doit rester réparable — il suffit de remettre
  /// `deleted_at` à `null` en base.
  Future<void> deleteProject(String projectId) async {
    final current = await projectById(projectId);
    final now = DateTime.now();

    await _persistProject(
      current.copyWith(deletedAt: Value(now), updatedAt: now),
    );
  }

  /// Rouvre un chantier clôturé par erreur.
  Future<void> reopenProject(String projectId) async {
    final current = await projectById(projectId);
    await _persistProject(
      current.copyWith(
        status: ProjectStatus.inProgress,
        endedOn: const Value(null),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Persistance atomique : table métier + outbox
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  //
  // `toCompanion(false)` sur chaque écriture, et ce n'est pas décoratif.
  //
  // `insertOnConflictUpdate` appliqué à une classe de données sérialise avec
  // `nullToAbsent: true` : une colonne à `null` est purement **omise** du SET.
  // Sur conflit, l'ancienne valeur survit donc. Concrètement, rouvrir un
  // chantier ne pouvait pas effacer sa date de fin, et réaffecter un opérateur
  // écarté ne pouvait pas effacer son `deleted_at` — la ligne restait un
  // tombstone en local alors que la charge utile envoyée au serveur, elle,
  // était correcte. Les deux extrémités divergeaient en silence.
  //
  // Le companion, lui, sérialise sur `present` et non sur la nullité : un
  // `Value(null)` explicite est bien écrit.
  // ---------------------------------------------------------------------------

  Future<void> _persistClient(Client row) {
    return transaction(() async {
      await into(clients).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.client,
        entityId: row.id,
        payload: clientPayload(row),
      );
    });
  }

  Future<void> _persistProject(Project row) {
    return transaction(() async {
      await into(projects).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.project,
        entityId: row.id,
        payload: projectPayload(row),
      );
    });
  }

  Future<void> _persistMember(ProjectMember row) {
    return transaction(() async {
      await into(projectMembers).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.projectMember,
        // Clé composite : l'identité d'une affectation est la paire.
        entityId: '${row.projectId}:${row.userId}',
        payload: projectMemberPayload(row),
      );
    });
  }
}
