import 'package:drift/native.dart';
import 'package:firestop_tracker/database/daos/project_dao.dart';
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

    final clientId = await db.projectDao.createClient(
      name: 'Client',
      address: 'Rue du Test 1, 4000 Liège',
      logoPath: 'client/logo.png',
    );
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
      expect(
          await db.projectDao.watchAssignedProjects(alice).first, hasLength(1));

      await db.projectDao.purgeProject(projectId);

      expect(await db.projectDao.watchAssignedProjects(alice).first, isEmpty);
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

  group('suppression d\'un chantier', () {
    // La seule suppression physique de l'application. `purgeProject` n'est
    // appelée qu'une fois le serveur d'accord : elle efface, et ne dit plus
    // rien à personne.

    Future<String> photo(String pointId, String id, {String? fichier}) async {
      await db.into(db.photos).insert(
            Photo(
              id: id,
              pointId: pointId,
              kind: PhotoKind.before,
              localPath: fichier,
              sortOrder: 0,
              takenAt: DateTime(2026, 10, 3),
              uploadState: PhotoUploadState.ready,
              uploadAttempts: 0,
              updatedAt: DateTime(2026, 10, 3),
            ),
          );
      return id;
    }

    test('efface le chantier, ses affectations, ses traversees, leurs cliches',
        () async {
      await db.projectDao.setMembers(projectId, {alice, bob});
      final point =
          await db.pointDao.createPoint(projectId: projectId, authorId: alice);
      await photo(point, 'ph1', fichier: '/photos/ph1.jpg');
      await photo(point, 'ph2');

      final fichiers = await db.projectDao.purgeProject(projectId);

      expect(await db.select(db.projects).get(), isEmpty);
      expect(await db.select(db.projectMembers).get(), isEmpty);
      expect(await db.select(db.points).get(), isEmpty);
      expect(await db.select(db.photos).get(), isEmpty);
      // Les fichiers à retirer du disque : ceux qui en avaient un.
      expect(fichiers, ['/photos/ph1.jpg']);
    });

    test('vide la file d\'attente de ce chantier, et rien n\'y ajoute',
        () async {
      // Une entrée laissée derrière repousserait une traversée que le
      // serveur écarte désormais ; en échec, elle bloquerait la déconnexion
      // pour un travail qui n'existe plus.
      await db.projectDao.setMembers(projectId, {alice});
      await db.pointDao.createPoint(projectId: projectId, authorId: alice);
      expect(await db.select(db.outboxEntries).get(), isNotEmpty);

      await db.projectDao.purgeProject(projectId);

      expect(await db.select(db.outboxEntries).get(), isEmpty);
    });

    test('ne touche a rien d\'autre', () async {
      final clientId = (await db.projectDao.projectById(projectId)).clientId;
      final voisin = await db.projectDao.createProject(
        clientId: clientId,
        name: 'Voisin',
      );
      await db.projectDao.setMembers(voisin, {alice});
      final point =
          await db.pointDao.createPoint(projectId: voisin, authorId: alice);
      await photo(point, 'ph-voisin', fichier: '/photos/voisin.jpg');
      final enFile = (await db.select(db.outboxEntries).get()).length;

      final fichiers = await db.projectDao.purgeProject(projectId);

      expect(fichiers, isEmpty);
      expect(
        (await db.select(db.projects).get()).map((p) => p.id),
        [voisin],
      );
      expect(await db.select(db.projectMembers).get(), hasLength(1));
      expect(await db.select(db.points).get(), hasLength(1));
      expect(await db.select(db.photos).get(), hasLength(1));
      // Le client reste : il n'appartient pas au chantier.
      expect(await db.select(db.clients).get(), hasLength(1));
      // La file du voisin est intacte ; seule l'entrée du chantier purgé,
      // s'il en avait une, a disparu.
      expect(
        (await db.select(db.outboxEntries).get()).length,
        inInclusiveRange(enFile - 1, enFile),
      );
      expect(await outboxEntityIds(), contains(point));
    });

    test('un chantier deja absent : sans effet, sans erreur', () async {
      // Le cas de tout appareil qui reçoit la trace d'un chantier qu'il n'a
      // jamais eu.
      expect(await db.projectDao.purgeProject('inconnu'), isEmpty);
      expect(await db.select(db.projects).get(), hasLength(1));
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

  group('suppression d\'un client', () {
    Future<String> clientDuChantier() async =>
        (await db.projectDao.projectById(projectId)).clientId;

    test('refusee tant qu\'un chantier le designe', () async {
      // Un chantier sans client sortirait des fiches sans logo ni adresse.
      final clientId = await clientDuChantier();

      expect(await db.projectDao.liveProjectCount(clientId), 1);
      await expectLater(
        db.projectDao.deleteClient(clientId),
        throwsA(
          isA<ClientEncoreUtilise>().having((e) => e.chantiers, 'chantiers', 1),
        ),
      );
      expect(await db.projectDao.watchClients().first, hasLength(1));
    });

    test('est logique : la ligne reste, sort des listes, et part au serveur',
        () async {
      final clientId = await clientDuChantier();
      // Un chantier supprime ne retient plus son client.
      await db.projectDao.purgeProject(projectId);
      await db.delete(db.outboxEntries).go();

      await db.projectDao.deleteClient(clientId);

      expect(await db.projectDao.watchClients().first, isEmpty);
      // La ligne reste : un client, lui, se supprime logiquement.
      final ligne = await db.select(db.clients).getSingle();
      expect(ligne.deletedAt, isNotNull);

      final entree = await db.select(db.outboxEntries).getSingle();
      expect(entree.entityType, OutboxEntity.client);
      expect(entree.entityId, clientId);
      expect(entree.payload, contains('"deleted_at":"'));
    });
  });
}
