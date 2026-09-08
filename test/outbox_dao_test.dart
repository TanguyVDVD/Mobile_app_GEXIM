import 'dart:convert';

import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'outbox est le point de défaillance unique de l'offline-first : une entrée
/// perdue ici, et le relevé d'un opérateur disparaît sans le moindre signal.
/// C'est donc la partie du socle qui mérite le plus de tests.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<OutboxEntry>> allEntries() =>
      db.select(db.outboxEntries).get();

  Future<void> enqueuePoint(
    String id,
    String description, {
    required DateTime at,
  }) {
    return db.outboxDao.enqueue(
      entityType: OutboxEntity.point,
      entityId: id,
      payload: {'id': id, 'description': description},
      now: at,
    );
  }

  group('fusionnement', () {
    test(
      'dix retouches hors-ligne ne produisent qu\'un seul envoi',
      () async {
        final t0 = DateTime(2026, 3, 2, 8);
        for (var i = 0; i < 10; i++) {
          await enqueuePoint(
            'point-a',
            'version $i',
            at: t0.add(Duration(minutes: i)),
          );
        }

        final entries = await allEntries();
        expect(entries, hasLength(1));
        expect(
          jsonDecode(entries.single.payload),
          containsPair('description', 'version 9'),
        );
      },
    );

    test(
      'le fusionnement preserve createdAt, donc l\'ordre des dependances',
      () async {
        final t0 = DateTime(2026, 3, 2, 8);

        // Un projet est créé, puis un point dedans.
        await db.outboxDao.enqueue(
          entityType: OutboxEntity.project,
          entityId: 'projet-1',
          payload: const {'id': 'projet-1'},
          now: t0,
        );
        await enqueuePoint('point-a', 'initial', at: t0.add(const Duration(minutes: 1)));

        // Puis le projet est renommé — bien après.
        await db.outboxDao.enqueue(
          entityType: OutboxEntity.project,
          entityId: 'projet-1',
          payload: const {'id': 'projet-1', 'name': 'Renommé'},
          now: t0.add(const Duration(hours: 3)),
        );

        // Si le fusionnement avait rafraîchi createdAt, le projet passerait
        // derrière son point et le serveur rejetterait celui-ci en violation de
        // clé étrangère.
        final first = await db.outboxDao.claimNext(
          now: t0.add(const Duration(hours: 4)),
        );
        expect(first!.entityType, OutboxEntity.project);
      },
    );

    test(
      'une entree inflight n\'est jamais ecrasee : la retouche part ensuite',
      () async {
        final t0 = DateTime(2026, 3, 2, 8);
        await enqueuePoint('point-a', 'partie sur le reseau', at: t0);

        // L'envoi commence.
        final claimed = await db.outboxDao.claimNext(now: t0);
        expect(claimed, isNotNull);

        // L'opérateur retouche pendant que la requête est en vol.
        await enqueuePoint(
          'point-a',
          'saisie pendant l\'envoi',
          at: t0.add(const Duration(seconds: 2)),
        );

        final entries = await allEntries();
        expect(
          entries,
          hasLength(2),
          reason: 'ecraser la charge utile en vol perdrait la nouvelle saisie',
        );
      },
    );
  });

  group('drain', () {
    test('claimNext respecte l\'ordre de creation', () async {
      final t0 = DateTime(2026, 3, 2, 8);
      await db.outboxDao.enqueue(
        entityType: OutboxEntity.client,
        entityId: 'client-1',
        payload: const {'id': 'client-1'},
        now: t0,
      );
      await db.outboxDao.enqueue(
        entityType: OutboxEntity.project,
        entityId: 'projet-1',
        payload: const {'id': 'projet-1'},
        now: t0.add(const Duration(seconds: 1)),
      );
      await enqueuePoint('point-a', 'x', at: t0.add(const Duration(seconds: 2)));

      final order = <OutboxEntity>[];
      for (var i = 0; i < 3; i++) {
        final entry = await db.outboxDao.claimNext(now: t0.add(const Duration(minutes: 1)));
        order.add(entry!.entityType);
        await db.outboxDao.markSent(entry.id);
      }

      expect(order, [
        OutboxEntity.client,
        OutboxEntity.project,
        OutboxEntity.point,
      ]);
    });

    test('un echec transitoire repousse l\'entree dans le futur', () async {
      final t0 = DateTime(2026, 3, 2, 8);
      await enqueuePoint('point-a', 'x', at: t0);

      final entry = await db.outboxDao.claimNext(now: t0);
      await db.outboxDao.markRetry(entry!, 'reseau coupe', now: t0);

      // Immédiatement après, rien n'est dû.
      expect(await db.outboxDao.claimNext(now: t0), isNull);

      // Une heure plus tard, la temporisation est écoulée (plafond : 30 min).
      final retried =
          await db.outboxDao.claimNext(now: t0.add(const Duration(hours: 1)));
      expect(retried, isNotNull);
      expect(retried!.attempts, 1);
    });

    test(
      'recoverInflight libere les entrees orphelines apres un crash',
      () async {
        final t0 = DateTime(2026, 3, 2, 8);
        await enqueuePoint('point-a', 'x', at: t0);
        await db.outboxDao.claimNext(now: t0);

        // Le processus meurt ici. Au redémarrage :
        await db.outboxDao.recoverInflight();

        final recovered = await db.outboxDao.claimNext(now: t0);
        expect(
          recovered,
          isNotNull,
          reason: 'sans reprise, l\'entree resterait bloquee a jamais',
        );
      },
    );

    test('un echec definitif sort l\'entree du drain sans la detruire', () async {
      final t0 = DateTime(2026, 3, 2, 8);
      await enqueuePoint('point-a', 'x', at: t0);

      final entry = await db.outboxDao.claimNext(now: t0);
      await db.outboxDao.markFailed(entry!, 'RLS: refus');

      expect(await db.outboxDao.claimNext(now: t0.add(const Duration(days: 1))), isNull);
      expect(
        await allEntries(),
        hasLength(1),
        reason: 'le travail de l\'operateur ne doit jamais etre supprime',
      );
    });
  });
}
