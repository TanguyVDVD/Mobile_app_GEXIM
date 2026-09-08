import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les écritures d'administration décident de qui accède à quoi : ce sont elles
/// que lisent les policies RLS côté serveur.
void main() {
  late AppDatabase db;
  late String projectId;

  const alice = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
  const bob = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026, 8, 1);

    for (final id in [alice, bob]) {
      await db.into(db.profiles).insert(
            Profile(
              id: id,
              fullName: 'Op $id',
              email: '$id@gexim.be',
              role: UserRole.operator,
              updatedAt: now,
            ),
          );
    }

    final clientId = await db.projectDao.createClient(name: 'Client');
    projectId = await db.projectDao.createProject(
      clientId: clientId,
      name: 'Chantier',
    );
    await db.delete(db.outboxEntries).go();
  });

  tearDown(() => db.close());

  Future<List<ProjectMember>> allMembers() =>
      db.select(db.projectMembers).get();

  Future<Set<String>> outboxEntityIds() async {
    final rows = await db.select(db.outboxEntries).get();
    return {for (final row in rows) row.entityId};
  }

  group('affectations', () {
    test('affecter met la modification en file pour le serveur', () async {
      await db.projectDao.setMembers(projectId, {alice});

      expect(await allMembers(), hasLength(1));
      expect(await outboxEntityIds(), {'$projectId:$alice'});
    });

    test(
      'retirer un operateur laisse un tombstone, jamais un effacement',
      () async {
        await db.projectDao.setMembers(projectId, {alice, bob});
        await db.delete(db.outboxEntries).go();

        await db.projectDao.setMembers(projectId, {alice});

        final rows = await allMembers();
        expect(
          rows,
          hasLength(2),
          reason: 'un effacement local ne serait jamais annonce au serveur, et '
              'l\'operateur garderait ses droits',
        );

        final retire = rows.firstWhere((m) => m.userId == bob);
        expect(retire.deletedAt, isNotNull);
        expect(
          await outboxEntityIds(),
          contains('$projectId:$bob'),
          reason: 'c\'est cet envoi qui coupe reellement l\'acces cote RLS',
        );
      },
    );

    test('reaffecter quelqu\'un de retire reutilise sa ligne', () async {
      await db.projectDao.setMembers(projectId, {alice});
      await db.projectDao.setMembers(projectId, <String>{});
      await db.projectDao.setMembers(projectId, {alice});

      final rows = await allMembers();
      expect(
        rows,
        hasLength(1),
        reason: 'la cle primaire est la paire : un insert aurait echoue',
      );
      expect(rows.single.deletedAt, isNull);
    });

    test('watchMembers ignore les affectations retirees', () async {
      await db.projectDao.setMembers(projectId, {alice, bob});
      await db.projectDao.setMembers(projectId, {alice});

      final visible = await db.projectDao.watchMembers(projectId).first;
      expect(visible.map((m) => m.userId), [alice]);
    });
  });

  group('relation utilisateur / chantier, vue des deux cotes', () {
    test('les deux lectures decoulent de la meme table', () async {
      final autre = await db.projectDao.createProject(
        clientId: (await db.select(db.clients).getSingle()).id,
        name: 'Second chantier',
      );

      await db.projectDao.setMembers(projectId, {alice, bob});
      await db.projectDao.setMembers(autre, {alice});

      // allowedUserIds(projet)
      final surLePremier = await db.projectDao.watchMembers(projectId).first;
      expect(surLePremier.map((m) => m.userId).toSet(), {alice, bob});

      // assignedProjectIds(utilisateur)
      final chantiersAlice =
          await db.projectDao.watchAssignedProjects(alice).first;
      final chantiersBob = await db.projectDao.watchAssignedProjects(bob).first;

      expect(chantiersAlice.map((p) => p.id).toSet(), {projectId, autre});
      expect(
        chantiersBob.map((p) => p.id).toSet(),
        {projectId},
        reason: 'aucune des deux vues ne peut contredire l\'autre : elles '
            'lisent la meme ligne',
      );
    });

    test('un retrait disparait des deux cotes a la fois', () async {
      await db.projectDao.setMembers(projectId, {alice, bob});
      await db.projectDao.setMembers(projectId, {alice});

      expect(
        (await db.projectDao.watchMembers(projectId).first)
            .map((m) => m.userId),
        [alice],
      );
      expect(await db.projectDao.watchAssignedProjects(bob).first, isEmpty);
    });

    test('un chantier supprime sort des affectations', () async {
      await db.projectDao.setMembers(projectId, {alice});
      expect(await db.projectDao.watchAssignedProjects(alice).first, hasLength(1));

      await db.projectDao.deleteProject(projectId);

      expect(await db.projectDao.watchAssignedProjects(alice).first, isEmpty);
      expect(
        await db.select(db.points).get(),
        isEmpty,
        reason: 'aucun point sur ce chantier de test',
      );
    });

    test('le compteur d\'affectations repere un technicien oublie', () async {
      await db.projectDao.setMembers(projectId, {alice});

      final counts = await db.projectDao.watchAssignmentCounts().first;
      expect(counts[alice], 1);
      expect(
        counts[bob],
        isNull,
        reason: 'bob s\'est inscrit et attend qu\'on l\'affecte',
      );
    });
  });

  group('suppression', () {
    test('est logique : la ligne reste, et part au serveur', () async {
      await db.projectDao.deleteProject(projectId);

      final row = await db.projectDao.projectById(projectId);
      expect(row.deletedAt, isNotNull);
      expect(await db.projectDao.watchAllProjects().first, isEmpty);
      expect(await outboxEntityIds(), contains(projectId));
    });
  });

  group('cloture', () {
    test('fige le chantier et date la fin', () async {
      await db.projectDao.closeProject(projectId);

      final project = await db.projectDao.projectById(projectId);
      expect(project.status, ProjectStatus.completed);
      expect(project.endedOn, isNotNull);
      expect(await outboxEntityIds(), contains(projectId));
    });

    test('le chantier cloture reste affecte, mais change de statut', () async {
      await db.projectDao.setMembers(projectId, {alice});

      await db.projectDao.closeProject(projectId);

      // L'affectation ne bouge pas : c'est le statut qui ecarte le chantier de
      // la liste du technicien, filtre porte par `assignedProjectsProvider`.
      final vus = await db.projectDao.watchAssignedProjects(alice).first;
      expect(vus, hasLength(1));
      expect(vus.single.status, ProjectStatus.completed);

      expect(
        await db.projectDao.watchAllProjects().first,
        hasLength(1),
        reason: 'l\'admin doit continuer a le voir : il porte le rapport',
      );
    });

    test('rouvrir efface la date de fin', () async {
      await db.projectDao.closeProject(projectId);
      await db.projectDao.reopenProject(projectId);

      final project = await db.projectDao.projectById(projectId);
      expect(project.status, ProjectStatus.inProgress);
      expect(project.endedOn, isNull);
    });
  });
}
