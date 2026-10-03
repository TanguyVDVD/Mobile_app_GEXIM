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
/// Le client a encore des chantiers : il ne se supprime pas.
class ClientEncoreUtilise implements Exception {
  const ClientEncoreUtilise(this.chantiers);

  /// Nombre de chantiers vivants qui le désignent.
  final int chantiers;

  @override
  String toString() => 'Client encore désigné par $chantiers chantier(s)';
}

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

  /// Crée un client.
  ///
  /// [id] est paramétrable, et ce n'est pas une commodité de test : le logo est
  /// **obligatoire**, et son objet distant est rangé sous l'identifiant du
  /// client. L'appelant doit donc connaître cet identifiant avant de téléverser
  /// le binaire, c'est-à-dire avant que la ligne n'existe. Voir
  /// `ClientEditorScreen`.
  Future<String> createClient({
    required String name,
    required String address,
    required String logoPath,
    String? id,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
  }) async {
    final now = DateTime.now();
    final row = Client(
      id: id ?? newId(),
      name: name,
      contactName: contactName,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      address: address,
      logoPath: logoPath,
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
    String? code,
    String? purchaseOrder,
    String? building,
    String? description,
    DateTime? startedOn,
  }) async {
    final now = DateTime.now();
    final row = Project(
      id: newId(),
      clientId: clientId,
      code: code,
      purchaseOrder: purchaseOrder,
      building: building,
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
    required String address,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
  }) async {
    final current = await (select(clients)..where((t) => t.id.equals(clientId)))
        .getSingle();

    await _persistClient(
      current.copyWith(
        name: name,
        address: address,
        contactName: Value(contactName),
        contactEmail: Value(contactEmail),
        contactPhone: Value(contactPhone),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Remplace le logo d'un client par un objet déjà déposé dans le bucket.
  ///
  /// Séparé de [updateClient], parce que le geste l'est : le binaire est
  /// téléversé d'abord — cela demande du réseau — et seul son chemin transite
  /// ensuite par la file d'attente. Mélanger les deux exposerait à enregistrer
  /// un chemin pointant vers un objet qui n'existe pas.
  ///
  /// L'ancien objet n'est pas effacé du bucket : il peut encore figurer dans
  /// un rapport déjà remis.
  Future<void> setClientLogo(String clientId, String logoPath) async {
    final current = await (select(clients)..where((t) => t.id.equals(clientId)))
        .getSingle();

    await _persistClient(
      current.copyWith(logoPath: logoPath, updatedAt: DateTime.now()),
    );
  }

  Future<void> updateProject(
    String projectId, {
    required String name,
    required String clientId,
    String? code,
    String? purchaseOrder,
    String? building,
    String? description,
    DateTime? startedOn,
  }) async {
    final current = await projectById(projectId);

    await _persistProject(
      current.copyWith(
        name: name,
        clientId: clientId,
        code: Value(code),
        purchaseOrder: Value(purchaseOrder),
        // Ne réécrit pas les traversées déjà relevées : c'est une valeur de
        // départ, recopiée à la création de chaque point.
        building: Value(building),
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

  /// Clôture un chantier : gèle la saisie et ouvre l'export des fiches.
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

  /// Efface **physiquement** un chantier de cet appareil : ses affectations,
  /// ses traversées, leurs clichés, et tout ce qui attendait d'être envoyé
  /// pour eux. Rend les chemins des fichiers de clichés, que l'appelant
  /// retire du disque.
  ///
  /// La seule exception à « suppression logique partout », et elle ne se
  /// décide jamais ici : cette méthode n'est appelée qu'**après** que le
  /// serveur a effacé le chantier — par `ProjectAdminService` sur l'appareil
  /// de l'administrateur, par `PullEngine` sur les autres. Elle ne met donc
  /// rien en file : il n'y a plus rien à dire au serveur.
  ///
  /// La file d'attente est vidée de ce chantier **dans la même transaction**.
  /// Une entrée laissée derrière repousserait une traversée que le serveur
  /// écarte désormais ; pire, un échec resté là bloquerait la déconnexion
  /// pour un travail qui n'existe plus.
  Future<List<String>> purgeProject(String projectId) {
    final chantier = [Variable<String>(projectId)];

    return transaction(() async {
      final fichiers = await customSelect(
        '''
        SELECT ph.local_path
          FROM photos ph
          JOIN points p ON p.id = ph.point_id
         WHERE p.project_id = ?1 AND ph.local_path IS NOT NULL
        ''',
        variables: chantier,
      ).map((row) => row.read<String>('local_path')).get();

      await customUpdate(
        '''
        DELETE FROM outbox_entries
         WHERE (entity_type = 'project' AND entity_id = ?1)
            OR (entity_type = 'projectMember' AND entity_id LIKE ?1 || ':%')
            OR (entity_type = 'point' AND entity_id IN
                 (SELECT id FROM points WHERE project_id = ?1))
            OR (entity_type = 'photo' AND entity_id IN
                 (SELECT ph.id FROM photos ph
                    JOIN points p ON p.id = ph.point_id
                   WHERE p.project_id = ?1))
        ''',
        variables: chantier,
        updates: {attachedDatabase.outboxEntries},
        updateKind: UpdateKind.delete,
      );
      // Dans l'ordre des clés étrangères : les clichés avant leurs
      // traversées, tout avant le chantier.
      await customUpdate(
        'DELETE FROM photos WHERE point_id IN '
        '(SELECT id FROM points WHERE project_id = ?1)',
        variables: chantier,
        updates: {attachedDatabase.photos},
        updateKind: UpdateKind.delete,
      );
      await customUpdate(
        'DELETE FROM points WHERE project_id = ?1',
        variables: chantier,
        updates: {attachedDatabase.points},
        updateKind: UpdateKind.delete,
      );
      await (delete(projectMembers)
            ..where((t) => t.projectId.equals(projectId)))
          .go();
      await (delete(projects)..where((t) => t.id.equals(projectId))).go();

      return fichiers;
    });
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

  /// Nombre de chantiers vivants d'un client. En une seule lecture : c'est une
  /// boîte de dialogue destructive qui le demande.
  Future<int> liveProjectCount(String clientId) async {
    final total = projects.id.count();
    final row = await (selectOnly(projects)
          ..addColumns([total])
          ..where(
            projects.clientId.equals(clientId) & projects.deletedAt.isNull(),
          ))
        .getSingle();
    return row.read(total) ?? 0;
  }

  /// Supprime un client — **logiquement**, et seulement s'il n'a plus de
  /// chantier.
  ///
  /// Un chantier vivant désigne son client : le supprimer dessous laisserait
  /// des fiches sans logo ni adresse, donc des classeurs exportés avec une
  /// case « Client » vide. Lève [ClientEncoreUtilise] plutôt que de le
  /// permettre ; l'administrateur supprime d'abord les chantiers, ou les
  /// rattache à un autre client.
  ///
  /// La vérification et l'écriture sont dans la même transaction : un
  /// chantier créé entre les deux ne passe pas au travers.
  Future<void> deleteClient(String clientId) {
    return transaction(() async {
      final chantiers = await liveProjectCount(clientId);
      if (chantiers > 0) throw ClientEncoreUtilise(chantiers);

      final current = await (select(clients)
            ..where((t) => t.id.equals(clientId)))
          .getSingle();
      final now = DateTime.now();
      await _persistClient(
        current.copyWith(deletedAt: Value(now), updatedAt: now),
      );
    });
  }

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
