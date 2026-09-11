import 'dart:io';

import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/features/auth/auth_backend.dart';
import 'package:firestop_tracker/features/auth/auth_service.dart';
import 'package:firestop_tracker/features/capture/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements AuthBackend {
  String? userId;
  String? email;
  int signOutCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  String? get currentUserEmail => email;

  @override
  Stream<String?> get userIdChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    // L'identité est décidée par le test via `userId`.
    this.email = email;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    this.email = email;
    // `sessionOpened` laisse le test choisir entre les deux comportements
    // possibles du projet Supabase : session immédiate, ou attente d'une
    // confirmation par courriel.
    return sessionOpened;
  }

  bool sessionOpened = true;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    userId = null;
  }
}

void main() {
  late AppDatabase db;
  late _FakeBackend backend;
  late AuthService auth;

  const alice = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
  const bob = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

  late Directory tmp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    backend = _FakeBackend();
    tmp = await Directory.systemTemp.createTemp('firestop_auth_');
    auth = AuthService(db, backend, PhotoStorage(root: tmp));
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> signInAs(String userId) async {
    backend.userId = userId;
    await auth.signIn(email: '$userId@gexim.be', password: 'x');
  }

  /// Un relevé complet appartenant au compte connecté.
  Future<void> seedWork({bool pending = true}) async {
    final now = DateTime(2026, 7, 1);
    await db.into(db.clients).insert(
          Client(
            id: 'c1',
            name: 'Client',
            address: 'Rue du Test 1, 4000 Liège',
            logoPath: 'c1/logo.png',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.projects).insert(
          Project(
            id: 'p1',
            clientId: 'c1',
            name: 'Chantier',
            status: ProjectStatus.inProgress,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.pointDao.createPoint(
      projectId: 'p1',
      authorId: backend.userId!,
    );
    if (!pending) {
      // Tout est parti : la file est vide.
      await db.delete(db.outboxEntries).go();
    }
  }

  /// Une écriture que le serveur a refusée pour de bon — un chantier clôturé
  /// entre-temps, une affectation retirée. Elle attend qu'un administrateur
  /// lève la cause, et n'existe que sur cette tablette.
  Future<void> refuserUnEnvoi() async {
    await db.outboxDao.enqueue(
      entityType: OutboxEntity.point,
      entityId: 'pt-refuse',
      payload: {'id': 'pt-refuse'},
    );
    final entry = await db.outboxDao.claimNext();
    await db.outboxDao.markFailed(entry!, 'RLS : refus');
  }

  group('profil local', () {
    test('est créé à la connexion, avant toute descente', () async {
      await signInAs(alice);

      final profile = await db.select(db.profiles).getSingle();
      expect(profile.id, alice);
      expect(
        profile.email,
        '$alice@gexim.be',
        reason: 'sans ce profil, la premiere traversee violerait la cle '
            'etrangere author_id',
      );
    });

    test('est horodaté à l\'époque zéro pour perdre face au serveur', () async {
      await signInAs(alice);

      final profile = await db.select(db.profiles).getSingle();
      expect(
        profile.updatedAt.millisecondsSinceEpoch,
        0,
        reason: 'horodate a maintenant, le profil provisoire gagnerait le '
            'last-write-wins et l\'operateur resterait sans nom ni role',
      );
    });

    test('n\'écrase pas un vrai profil déjà redescendu', () async {
      await db.into(db.profiles).insert(
            Profile(
              id: alice,
              fullName: 'Alice Martin',
              email: 'alice@gexim.be',
              role: UserRole.admin,
              updatedAt: DateTime(2026, 7, 1),
            ),
          );

      await signInAs(alice);

      final profile = await db.select(db.profiles).getSingle();
      expect(profile.fullName, 'Alice Martin');
      expect(
        profile.role,
        UserRole.admin,
        reason: 'le provisoire retrograderait un admin en operateur',
      );
    });
  });

  group('inscription', () {
    test('un nouveau compte est toujours un simple technicien', () async {
      backend.userId = alice;
      final opened = await auth.signUp(
        email: 'alice@gexim.be',
        password: 'motdepasse',
        fullName: 'Alice Martin',
      );

      expect(opened, isTrue);
      final profile = await db.select(db.profiles).getSingle();
      expect(
        profile.role,
        UserRole.operator,
        reason: 'le role n\'est jamais transmis par le client : un compte qui '
            'naitrait admin viderait tout le modele de securite',
      );
    });

    test('un nouveau compte n\'a acces a aucun chantier', () async {
      backend.userId = alice;
      await auth.signUp(
        email: 'alice@gexim.be',
        password: 'motdepasse',
        fullName: 'Alice Martin',
      );

      expect(
        await db.projectDao.watchAssignedProjects(alice).first,
        isEmpty,
        reason: 'un admin doit affecter explicitement',
      );
    });

    test(
      'confirmation par courriel : compte cree, session non ouverte',
      () async {
        backend
          ..sessionOpened = false
          ..userId = null;

        final opened = await auth.signUp(
          email: 'alice@gexim.be',
          password: 'motdepasse',
          fullName: 'Alice Martin',
        );

        expect(opened, isFalse);
        expect(
          await db.select(db.profiles).get(),
          isEmpty,
          reason: 'sans session, aucun profil local a semer',
        );
      },
    );
  });

  group('deconnexion', () {
    test('refusee tant qu\'un releve n\'est pas parti', () async {
      await signInAs(alice);
      await seedWork();

      await expectLater(
        auth.signOut(),
        throwsA(isA<PendingWorkBlocked>()),
      );
      expect(
        backend.signOutCalls,
        0,
        reason: 'la session doit rester ouverte pour permettre la synchro',
      );
    });

    test('autorisee quand tout est synchronise', () async {
      await signInAs(alice);
      await seedWork(pending: false);

      await auth.signOut();
      expect(backend.signOutCalls, 1);
    });

    test('refusee aussi quand le serveur a refuse un envoi', () async {
      await signInAs(alice);
      await seedWork(pending: false);
      await refuserUnEnvoi();

      await expectLater(
        auth.signOut(),
        throwsA(
          isA<PendingWorkBlocked>()
              .having((e) => e.message, 'message', contains('refusé')),
        ),
      );
      expect(backend.signOutCalls, 0);
    });
  });

  group('changement de compte', () {
    test('purge la base locale', () async {
      await signInAs(alice);
      await seedWork(pending: false);
      expect(await db.select(db.points).get(), isNotEmpty);

      await signInAs(bob);

      expect(await db.select(db.points).get(), isEmpty);
      expect(await db.select(db.projects).get(), isEmpty);
      expect(await db.select(db.syncCursors).get(), isEmpty);
      expect(
        (await db.select(db.profiles).get()).single.id,
        bob,
        reason: 'les releves d\'un operateur ne doivent pas apparaitre sur la '
            'tablette d\'un autre',
      );
    });

    test('refuse et referme la session si du travail reste sur l\'appareil',
        () async {
      await signInAs(alice);
      await seedWork();

      backend.userId = bob;
      await expectLater(
        auth.signIn(email: 'bob@gexim.be', password: 'x'),
        throwsA(isA<PendingWorkBlocked>()),
      );

      expect(
        await db.select(db.points).get(),
        isNotEmpty,
        reason: 'la purge aurait detruit une journee de releves',
      );
      expect(
        backend.signOutCalls,
        1,
        reason: 'la tablette doit revenir au compte capable de faire partir '
            'ces releves',
      );
    });

    test('refuse aussi quand un envoi a ete refuse par le serveur', () async {
      // Le cas qui passait : rien « en attente », tout « refusé ». Le compteur
      // ne voyait que l'attente, laissait l'autre compte se connecter, et la
      // purge emportait un relevé qui n'existait nulle part ailleurs.
      await signInAs(alice);
      await seedWork(pending: false);
      await refuserUnEnvoi();

      backend.userId = bob;
      await expectLater(
        auth.signIn(email: 'bob@gexim.be', password: 'x'),
        throwsA(isA<PendingWorkBlocked>()),
      );
      expect(
        await db.select(db.points).get(),
        isNotEmpty,
        reason: 'le releve refuse attend un administrateur : la purge l\'aurait '
            'detruit',
      );
    });

    test('refuse aussi quand un cliche a ete refuse', () async {
      await signInAs(alice);
      await seedWork(pending: false);
      final point = await db.select(db.points).getSingle();
      await db.into(db.photos).insert(
            Photo(
              id: 'ph-refuse',
              pointId: point.id,
              kind: PhotoKind.before,
              localPath: '${tmp.path}/ph-refuse.jpg',
              sortOrder: 0,
              takenAt: DateTime(2026, 7, 1),
              uploadState: PhotoUploadState.failed,
              uploadAttempts: 5,
              updatedAt: DateTime(2026, 7, 1),
            ),
          );

      backend.userId = bob;
      await expectLater(
        auth.signIn(email: 'bob@gexim.be', password: 'x'),
        throwsA(isA<PendingWorkBlocked>()),
      );
      expect(await db.select(db.photos).get(), isNotEmpty);
    });

    test('se reconnecter avec le meme compte conserve tout', () async {
      await signInAs(alice);
      await seedWork();

      await signInAs(alice);

      expect(
        await db.select(db.points).get(),
        isNotEmpty,
        reason: 'retelecharger le chantier entier a chaque ouverture serait '
            'inutilisable hors ligne',
      );
      expect(await db.select(db.outboxEntries).get(), isNotEmpty);
    });
  });
}
