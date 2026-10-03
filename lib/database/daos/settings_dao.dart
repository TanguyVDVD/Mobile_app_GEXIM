import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../sync/payloads.dart';
import '../database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'settings_dao.g.dart';

/// Les listes déroulantes de la fiche de traversée.
///
/// Même invariant que [PointDao] et [ProjectDao] : table métier et outbox dans
/// une seule transaction.
///
/// **Pourquoi la file d'attente et non le réseau direct**, contrairement au
/// logo d'un client et aux changements de rôle. Ces deux-là sont en ligne pour
/// des raisons qui ne valent pas ici : un logo est un fichier qui doit exister
/// avant qu'on le référence, une élévation de privilèges ne doit jamais
/// s'appliquer en différé. Une option de liste n'est qu'une donnée métier
/// ordinaire, au même titre qu'un client ou qu'un chantier — et la console
/// d'administration est explicitement conçue pour fonctionner sans réseau.
@DriftAccessor(tables: [SettingOptions])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  /// Options vivantes d'une liste, dans l'ordre voulu par l'administrateur.
  Stream<List<SettingOption>> watchKind(SettingKind kind) =>
      _kindQuery(kind).watch();

  /// Même liste, en **une seule lecture**.
  ///
  /// Pour le rapport et les boîtes de dialogue : un instantané n'a rien à faire
  /// abonné à un flux vivant, qu'un cycle de synchronisation peut relancer sous
  /// les pieds de l'appelant. Voir `PointDao.pointSummaries`.
  Future<List<SettingOption>> ofKind(SettingKind kind) => _kindQuery(kind).get();

  MultiSelectable<SettingOption> _kindQuery(SettingKind kind) {
    return select(settingOptions)
      ..where((t) => t.kind.equalsValue(kind) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.label),
      ]);
  }

  /// Produits vivants d'un fournisseur, dans l'ordre voulu par
  /// l'administrateur.
  ///
  /// [supplierId] à `null` rend les produits **sans fournisseur** : ceux d'un
  /// catalogue antérieur au rattachement, que la fiche ne propose plus nulle
  /// part et que l'écran Paramètres donne à rattacher.
  Stream<List<SettingOption>> watchProducts(String? supplierId) =>
      _productsQuery(supplierId).watch();

  MultiSelectable<SettingOption> _productsQuery(String? supplierId) {
    return select(settingOptions)
      ..where(
        (t) =>
            t.kind.equalsValue(SettingKind.product) &
            t.deletedAt.isNull() &
            (supplierId == null
                ? t.parentId.isNull()
                : t.parentId.equals(supplierId)),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.label),
      ]);
  }

  /// Libellé de **toutes** les options, y compris supprimées.
  ///
  /// Le rapport passe par ici, et c'est la raison d'être du « y compris
  /// supprimées » : une option retirée du catalogue reste désignée par les
  /// fiches déjà relevées. L'écarter ferait sortir un rapport de conformité
  /// avec une ligne « Produit utilisé (1) » vide, sans le moindre message —
  /// alors que le produit a bel et bien été posé.
  Future<Map<String, String>> labels() async =>
      _toLabels(await select(settingOptions).get());

  /// Même table de correspondance, en flux.
  ///
  /// L'écran de saisie en a besoin pour la même raison que le rapport : une
  /// fiche peut désigner une option retirée du catalogue. Sans son libellé, la
  /// liste déroulante afficherait une case vide — et le premier enregistrement
  /// effacerait pour de bon une caractéristique que personne n'avait voulu
  /// changer.
  Stream<Map<String, String>> watchLabels() =>
      select(settingOptions).watch().map(_toLabels);

  Map<String, String> _toLabels(List<SettingOption> rows) =>
      {for (final row in rows) row.id: row.label};

  // ---------------------------------------------------------------------------
  // Écriture
  // ---------------------------------------------------------------------------

  /// Ajoute une option en fin de liste.
  ///
  /// [supplierId] est exigé pour un produit et refusé ailleurs : un produit
  /// sans fournisseur ne serait proposé sur aucune fiche, et le serveur
  /// rejette un parent sur toute autre liste — mais à la synchronisation
  /// seulement, bien après le geste.
  Future<String> create({
    required SettingKind kind,
    required String label,
    String? supplierId,
  }) async {
    if ((kind == SettingKind.product) != (supplierId != null)) {
      throw ArgumentError.value(
        supplierId,
        'supplierId',
        'Un produit, et lui seul, désigne un fournisseur',
      );
    }

    final row = SettingOption(
      id: newId(),
      kind: kind,
      label: label,
      // Le rang est pris sur toute la liste des produits, tous fournisseurs
      // confondus : seul l'ordre relatif compte, et il reste juste si le
      // produit change un jour de fournisseur.
      sortOrder: await _nextSortOrder(kind),
      parentId: supplierId,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );
    await _persist(row);
    return row.id;
  }

  Future<void> rename(String id, String label) async {
    final current = await _byId(id);
    await _persist(current.copyWith(label: label, updatedAt: DateTime.now()));
  }

  /// Rattache un produit à un fournisseur.
  ///
  /// Sert aux produits restés sans fournisseur, et à corriger une erreur de
  /// rattachement. Les fiches qui désignent ce produit ne sont pas touchées :
  /// elles gardent leur fournisseur et leur produit, tels que relevés.
  Future<void> attach(String productId, String supplierId) async {
    final current = await _byId(productId);
    if (current.kind != SettingKind.product) {
      throw ArgumentError.value(productId, 'productId', 'Pas un produit');
    }
    await _persist(
      current.copyWith(parentId: Value(supplierId), updatedAt: DateTime.now()),
    );
  }

  /// Réordonne une liste entière : l'ordre du tableau devient le `sortOrder`.
  ///
  /// Pour les produits, [idsInOrder] est la liste d'**un** fournisseur : les
  /// rangs se recouvrent d'un fournisseur à l'autre, sans conséquence
  /// puisqu'ils ne sont jamais affichés ensemble.
  ///
  /// La liste complète plutôt qu'un échange de deux voisins : un « monter d'un
  /// cran » écrit deux lignes et laisse la liste incohérente si l'appareil
  /// s'éteint entre les deux. Ici, une transaction, un état final.
  Future<void> reorder(SettingKind kind, List<String> idsInOrder) async {
    final now = DateTime.now();

    await transaction(() async {
      final known = {for (final row in await ofKind(kind)) row.id: row};

      for (final (int index, String id) in idsInOrder.indexed) {
        final row = known[id];
        if (row == null || row.sortOrder == index) continue;
        await _persist(row.copyWith(sortOrder: index, updatedAt: now));
      }
    });
  }

  /// Retire une option — **logiquement**, comme partout ailleurs.
  ///
  /// Les points qui la désignent gardent leur référence : la ligne existe
  /// toujours, elle ne s'offre simplement plus au choix. Un DELETE physique
  /// violerait les clés étrangères de `points` sur les tablettes, et
  /// détruirait la caractérisation de traversées déjà livrées au client.
  Future<void> retire(String id) async {
    final now = DateTime.now();
    await _persist((await _byId(id)).copyWith(deletedAt: Value(now), updatedAt: now));
  }

  Future<SettingOption> _byId(String id) =>
      (select(settingOptions)..where((t) => t.id.equals(id))).getSingle();

  Future<int> _nextSortOrder(SettingKind kind) async {
    final row = await (selectOnly(settingOptions)
          ..addColumns([settingOptions.sortOrder.max()])
          ..where(settingOptions.kind.equalsValue(kind)))
        .getSingle();
    return (row.read(settingOptions.sortOrder.max()) ?? -1) + 1;
  }

  // ---------------------------------------------------------------------------
  // Persistance atomique : table métier + outbox
  // ---------------------------------------------------------------------------

  Future<void> _persist(SettingOption row) {
    return transaction(() async {
      // `toCompanion(false)` : sans lui, une colonne remise à `null` serait
      // omise du SET, et l'ancienne valeur survivrait en local alors que la
      // charge utile envoyée au serveur serait correcte. Voir la note
      // détaillée dans `ProjectDao`.
      await into(settingOptions).insertOnConflictUpdate(row.toCompanion(false));
      await attachedDatabase.outboxDao.enqueue(
        entityType: OutboxEntity.settingOption,
        entityId: row.id,
        payload: settingOptionPayload(row),
      );
    });
  }
}
