import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../sync/backoff.dart';
import '../database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'outbox_dao.g.dart';

/// Accès à la file d'attente durable des écritures.
///
/// Toute la politique de rejeu vit ici : fusionnement, réservation d'un lot,
/// temporisation exponentielle et abandon définitif.
@DriftAccessor(tables: [OutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// Met une écriture en file, en **fusionnant** avec l'entrée en attente qui
  /// vise déjà la même entité.
  ///
  /// Sans ce fusionnement, un opérateur qui retouche la description d'un point
  /// dix fois hors-ligne produirait dix requêtes à la reconnexion — pour un
  /// résultat identique. On ne pousse que le dernier état connu.
  ///
  /// Deux subtilités volontaires :
  ///
  ///  - On ne fusionne **que** les entrées `pending`. Si une entrée est
  ///    `inflight`, sa charge utile est déjà partie sur le réseau : l'écraser
  ///    perdrait silencieusement la modification que l'opérateur vient de
  ///    saisir. On insère alors une seconde entrée, poussée au cycle suivant.
  ///
  ///  - `createdAt` n'est **jamais** rafraîchi lors d'un fusionnement. Cette
  ///    date porte l'ordre des dépendances : un projet est nécessairement créé
  ///    avant ses points, donc inséré avant eux dans l'outbox. Le rajeunir
  ///    ferait remonter un point devant son projet et provoquerait une
  ///    violation de clé étrangère à l'arrivée.
  Future<void> enqueue({
    required OutboxEntity entityType,
    required String entityId,
    required Map<String, Object?> payload,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final encoded = jsonEncode(payload);

    await transaction(() async {
      final pending = await (select(outboxEntries)
            ..where(
              (t) =>
                  t.entityType.equalsValue(entityType) &
                  t.entityId.equals(entityId) &
                  t.status.equalsValue(OutboxStatus.pending),
            )
            ..limit(1))
          .getSingleOrNull();

      if (pending != null) {
        await (update(outboxEntries)..where((t) => t.id.equals(pending.id)))
            .write(
          OutboxEntriesCompanion(
            payload: Value(encoded),
            // L'état a changé : les échecs passés ne présument plus de rien.
            attempts: const Value(0),
            nextAttemptAt: Value(at),
            lastError: const Value(null),
          ),
        );
        return;
      }

      await into(outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          id: newId(),
          entityType: entityType,
          entityId: entityId,
          payload: encoded,
          createdAt: at,
          nextAttemptAt: at,
        ),
      );
    });
  }

  /// Réserve la prochaine entrée à pousser et la bascule en `inflight`.
  ///
  /// La réservation est transactionnelle : deux déclenchements concurrents
  /// (retour du réseau *et* reprise au premier plan, par exemple) ne peuvent pas
  /// envoyer deux fois la même entrée.
  ///
  /// Le tri par `createdAt` garantit que les entités parentes précèdent leurs
  /// enfants — c'est tout le mécanisme de gestion des dépendances, sans graphe
  /// ni tri topologique.
  ///
  /// Une entrée à la fois, et non un lot : la latence d'une transaction SQLite
  /// est négligeable face à un aller-retour réseau, et cela supprime tout un
  /// pan de complexité. Avec un lot, l'échec de la troisième entrée laisserait
  /// les suivantes bloquées en `inflight` sans que personne ne les envoie, et
  /// il faudrait une logique de libération pour les récupérer.
  Future<OutboxEntry?> claimNext({DateTime? now}) {
    final at = now ?? DateTime.now();

    return transaction(() async {
      final row = await (select(outboxEntries)
            ..where(
              (t) =>
                  t.status.equalsValue(OutboxStatus.pending) &
                  t.nextAttemptAt.isSmallerOrEqualValue(at),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

      if (row == null) return null;

      await (update(outboxEntries)..where((t) => t.id.equals(row.id))).write(
        const OutboxEntriesCompanion(status: Value(OutboxStatus.inflight)),
      );
      return row;
    });
  }

  /// L'entrée a été acceptée par le serveur : elle disparaît.
  ///
  /// La sécurité du rejeu ne repose pas sur cette suppression mais sur
  /// l'idempotence : la clé primaire étant générée côté client, un upsert rejoué
  /// après un accusé de réception perdu réécrit simplement la même ligne.
  Future<void> markSent(String id) =>
      (delete(outboxEntries)..where((t) => t.id.equals(id))).go();

  /// Échec temporaire : on repasse en attente, plus tard.
  Future<void> markRetry(
    OutboxEntry entry,
    Object error, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return (update(outboxEntries)..where((t) => t.id.equals(entry.id))).write(
      OutboxEntriesCompanion(
        status: const Value(OutboxStatus.pending),
        attempts: Value(entry.attempts + 1),
        nextAttemptAt: Value(at.add(backoffDelay(entry.attempts))),
        lastError: Value(error.toString()),
      ),
    );
  }

  /// Échec définitif : plus aucune tentative automatique.
  ///
  /// L'entrée est conservée, jamais supprimée : elle représente du travail réel
  /// d'un opérateur sur le terrain. `watchFailed` la remonte à l'écran de
  /// synchronisation pour arbitrage humain.
  Future<void> markFailed(OutboxEntry entry, Object error) {
    return (update(outboxEntries)..where((t) => t.id.equals(entry.id))).write(
      OutboxEntriesCompanion(
        status: const Value(OutboxStatus.failed),
        attempts: Value(entry.attempts + 1),
        lastError: Value(error.toString()),
      ),
    );
  }

  /// Libère les entrées restées `inflight`, à appeler au démarrage.
  ///
  /// Une entrée `inflight` sans envoi en cours signifie que le processus est
  /// mort au milieu d'une requête (kill Android, batterie vide). Sans cette
  /// reprise, elle resterait bloquée à jamais et le travail serait perdu.
  Future<int> recoverInflight() {
    return (update(outboxEntries)
          ..where((t) => t.status.equalsValue(OutboxStatus.inflight)))
        .write(
      const OutboxEntriesCompanion(status: Value(OutboxStatus.pending)),
    );
  }

  /// Réarme **toutes** les entrées abandonnées, en une seule écriture.
  ///
  /// Une variante en lot plutôt qu'une boucle sur `watchFailed()` : un flux
  /// vivant n'est pas une lecture ponctuelle. Les écritures d'un cycle de
  /// synchronisation invalident la requête sous les pieds de l'appelant, et la
  /// souscription peut attendre indéfiniment un événement déjà passé — c'est
  /// exactement le blocage qui figeait autrefois la génération du rapport.
  ///
  /// Rend le nombre d'entrées réarmées.
  Future<int> retryAllFailed({DateTime? now}) {
    return (update(outboxEntries)
          ..where((t) => t.status.equalsValue(OutboxStatus.failed)))
        .write(
      OutboxEntriesCompanion(
        status: const Value(OutboxStatus.pending),
        attempts: const Value(0),
        nextAttemptAt: Value(now ?? DateTime.now()),
        lastError: const Value(null),
      ),
    );
  }

  /// Réarme manuellement une entrée abandonnée (bouton « Réessayer »).
  Future<void> retryFailed(String id) {
    return (update(outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: const Value(OutboxStatus.pending),
        attempts: const Value(0),
        nextAttemptAt: Value(DateTime.now()),
        lastError: const Value(null),
      ),
    );
  }

  /// Entrées nécessitant une intervention, pour l'écran de synchronisation.
  Stream<List<OutboxEntry>> watchFailed() {
    return (select(outboxEntries)
          ..where((t) => t.status.equalsValue(OutboxStatus.failed))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }
}
