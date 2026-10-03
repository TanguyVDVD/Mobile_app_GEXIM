import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les six listes déroulantes de la fiche, et les emplacements produit du
/// point.
///
/// Ce qui est vérifié ici tient en une phrase : **rien de ce qu'un technicien a
/// relevé ne doit changer de sens dans son dos.** Une option retirée du
/// catalogue, un produit désélectionné au milieu de la liste, une fiche qui
/// désigne une entrée disparue — ces trois-là sont silencieux, et tous trois
/// atterrissent dans un rapport de conformité.
void main() {
  late AppDatabase db;
  late String projectId;
  late String pointId;

  /// Fournisseur des produits créés par [creer] : un produit en exige un.
  late String fournisseur;

  const auteur = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    await db.into(db.profiles).insert(
          Profile(
            id: auteur,
            fullName: 'Technicien',
            email: 'tech@gexim.be',
            role: UserRole.operator,
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    final clientId = await db.projectDao.createClient(
      name: 'Client',
      address: 'Rue du Test 1, 4000 Liège',
      logoPath: 'client/logo.png',
    );
    projectId = await db.projectDao.createProject(
      clientId: clientId,
      name: 'Chantier',
    );
    pointId = await db.pointDao.createPoint(
      projectId: projectId,
      authorId: auteur,
    );
    fournisseur = await db.settingsDao.create(
      kind: SettingKind.supplier,
      label: 'Promat',
    );
    await db.delete(db.outboxEntries).go();
  });

  tearDown(() => db.close());

  Future<String> creer(SettingKind kind, String label, {String? chez}) =>
      db.settingsDao.create(
        kind: kind,
        label: label,
        supplierId: kind == SettingKind.product ? chez ?? fournisseur : null,
      );

  Future<List<String>> libellesDe(SettingKind kind) async =>
      [for (final o in await db.settingsDao.ofKind(kind)) o.label];

  /// Pose des produits dans les emplacements, à partir du premier.
  Future<void> poser(List<String?> ids) => db.pointDao.updatePoint(
        pointId,
        product1Id: Value(ids.elementAtOrNull(0)),
        product2Id: Value(ids.elementAtOrNull(1)),
        product3Id: Value(ids.elementAtOrNull(2)),
        product4Id: Value(ids.elementAtOrNull(3)),
        product5Id: Value(ids.elementAtOrNull(4)),
      );

  Future<Point> lePoint() => (db.select(db.points)
        ..where((t) => t.id.equals(pointId)))
      .getSingle();

  group('les listes administrees', () {
    test('une option creee part aussi vers le serveur', () async {
      // L'invariant du dépôt : table métier et outbox dans la même
      // transaction. Une option visible à l'écran mais jamais synchronisée
      // serait proposée sur une seule tablette — et la fiche qui la désigne
      // partirait vers un serveur qui ne la connaît pas.
      final id = await creer(SettingKind.product, 'Promastop-FC');

      final entrees = await db.select(db.outboxEntries).get();
      expect(entrees, hasLength(1));
      expect(entrees.single.entityId, id);
      expect(entrees.single.entityType, OutboxEntity.settingOption);

      final payload =
          jsonDecode(entrees.single.payload) as Map<String, dynamic>;
      expect(payload['kind'], 'product');
      expect(payload['label'], 'Promastop-FC');
    });

    test('chaque liste est etanche aux autres', () async {
      await creer(SettingKind.product, 'Promastop-FC');
      await creer(SettingKind.supplier, 'Hilti');
      await creer(SettingKind.eiLevel, 'EI120');

      expect(await libellesDe(SettingKind.product), ['Promastop-FC']);
      expect(await libellesDe(SettingKind.supplier), ['Promat', 'Hilti']);
      expect(await libellesDe(SettingKind.eiLevel), ['EI120']);
      expect(await libellesDe(SettingKind.configuration), isEmpty);
    });

    test('l\'ordre est celui de l\'administrateur, pas celui de l\'alphabet',
        () async {
      // Le cas qui a motive la colonne `sort_order` : trie alphabetiquement,
      // EI120 passe avant EI30.
      for (final niveau in ['EI30', 'EI60', 'EI90', 'EI120']) {
        await creer(SettingKind.eiLevel, niveau);
      }

      expect(
        await libellesDe(SettingKind.eiLevel),
        ['EI30', 'EI60', 'EI90', 'EI120'],
      );
    });

    test('reordonner reecrit la liste entiere en une transaction', () async {
      final a = await creer(SettingKind.product, 'A');
      final b = await creer(SettingKind.product, 'B');
      final c = await creer(SettingKind.product, 'C');

      await db.settingsDao.reorder(SettingKind.product, [c, a, b]);

      expect(await libellesDe(SettingKind.product), ['C', 'A', 'B']);
    });

    test('retirer est logique : la ligne reste, et part au serveur', () async {
      final id = await creer(SettingKind.product, 'Promastop-W');
      await db.delete(db.outboxEntries).go();

      await db.settingsDao.retire(id);

      // Plus proposee a la saisie...
      expect(await libellesDe(SettingKind.product), isEmpty);
      // ...mais toujours en base, sans quoi les points qui la referencent
      // violeraient leur cle etrangere.
      expect(
        await (db.select(db.settingOptions)..where((t) => t.id.equals(id)))
            .get(),
        hasLength(1),
      );

      final payload = jsonDecode(
        (await db.select(db.outboxEntries).getSingle()).payload,
      ) as Map<String, dynamic>;
      expect(payload['deleted_at'], isNotNull);
    });

    test('les libelles du rapport incluent les options retirees', () async {
      // Un produit retire du catalogue a bel et bien ete pose. L'ecarter ferait
      // sortir une ligne « Produit utilise (1) » vide sur le document meme qui
      // atteste de la conformite.
      final id = await creer(SettingKind.product, 'Promastop-B');
      await db.settingsDao.retire(id);

      expect(await db.settingsDao.labels(), containsPair(id, 'Promastop-B'));
    });
  });

  group('un produit appartient a un fournisseur', () {
    Future<List<String>> produitsDe(String? supplierId) async => [
          for (final o in await db.settingsDao.watchProducts(supplierId).first) o.label,
        ];

    test('la fiche ne recoit que les produits du fournisseur choisi',
        () async {
      final hilti = await creer(SettingKind.supplier, 'Hilti');
      await creer(SettingKind.product, 'Promastop-FC');
      await creer(SettingKind.product, 'CFS-F FX', chez: hilti);
      await creer(SettingKind.product, 'Promaseal-A');

      expect(await produitsDe(fournisseur), ['Promastop-FC', 'Promaseal-A']);
      expect(await produitsDe(hilti), ['CFS-F FX']);
    });

    test('le fournisseur part au serveur avec le produit', () async {
      // Sans `parent_id` dans la charge utile, le rattachement n'existerait
      // que sur la tablette de l'administrateur : partout ailleurs, la liste
      // des produits resterait vide.
      await creer(SettingKind.product, 'Promastop-FC');

      final payload = jsonDecode(
        (await db.select(db.outboxEntries).getSingle()).payload,
      ) as Map<String, dynamic>;
      expect(payload['parent_id'], fournisseur);
    });

    test('un produit sans fournisseur est refuse, un parent ailleurs aussi',
        () async {
      // Le premier ne serait propose sur aucune fiche ; le second serait
      // rejete par le serveur, mais a la synchronisation seulement.
      expect(
        () => db.settingsDao
            .create(kind: SettingKind.product, label: 'Orphelin'),
        throwsArgumentError,
      );
      expect(
        () => db.settingsDao.create(
          kind: SettingKind.eiLevel,
          label: 'EI30',
          supplierId: fournisseur,
        ),
        throwsArgumentError,
      );
    });

    test('rattacher deplace le produit, et part au serveur', () async {
      // Le cas des produits d'un catalogue anterieur au rattachement : ils
      // descendent sans fournisseur, et l'administrateur les range.
      await db.into(db.settingOptions).insert(
            SettingOption(
              id: 'orphelin',
              kind: SettingKind.product,
              label: 'Alsijoint',
              sortOrder: 0,
              updatedAt: DateTime(2026, 9, 1),
            ),
          );
      expect(await produitsDe(null), ['Alsijoint']);

      await db.settingsDao.attach('orphelin', fournisseur);

      expect(await produitsDe(null), isEmpty);
      expect(await produitsDe(fournisseur), ['Alsijoint']);
      final payload = jsonDecode(
        (await db.select(db.outboxEntries).getSingle()).payload,
      ) as Map<String, dynamic>;
      expect(payload['parent_id'], fournisseur);
    });

    test('changer de fournisseur vide les produits qui ne sont pas les siens',
        () async {
      // Sans cela, le rapport attribuerait a un fabricant les references
      // d'un autre. Les emplacements ne se tassent pas : la position reste
      // celle du rapport.
      final hilti = await creer(SettingKind.supplier, 'Hilti');
      final a = await creer(SettingKind.product, 'Promastop-FC');
      final b = await creer(SettingKind.product, 'Promaseal-A');
      await db.pointDao.setSupplier(pointId, fournisseur);
      await poser([a, null, b]);
      await db.delete(db.outboxEntries).go();

      await db.pointDao.setSupplier(pointId, hilti);

      final point = await lePoint();
      expect(point.supplierId, hilti);
      expect(point.product1Id, isNull);
      expect(point.product3Id, isNull);
      // Une seule ecriture distante : aucun etat intermediaire ne part.
      expect(await db.select(db.outboxEntries).get(), hasLength(1));
    });

    test('rechoisir le meme fournisseur ne touche pas a ses produits',
        () async {
      final a = await creer(SettingKind.product, 'Promastop-FC');
      // Retire du catalogue, mais bel et bien pose : il reste.
      final b = await creer(SettingKind.product, 'Promastop-B');
      await db.settingsDao.retire(b);
      await db.pointDao.setSupplier(pointId, fournisseur);
      await poser([a, b]);

      await db.pointDao.setSupplier(pointId, fournisseur);

      final point = await lePoint();
      expect(point.product1Id, a);
      expect(point.product2Id, b);
    });
  });

  group('les cinq emplacements produit', () {
    test('une caracteristique se deselectionne', () async {
      // L'ancienne signature de `updatePoint` appliquait `valeur ?? valeur
      // actuelle` : effacer un champ etait indiscernable de « ne rien changer »,
      // et une liste deroulante ne pouvait plus etre remise a vide.
      final niveau = await creer(SettingKind.eiLevel, 'EI60');

      await db.pointDao.updatePoint(pointId, eiLevelId: Value(niveau));
      expect((await lePoint()).eiLevelId, niveau);

      await db.pointDao.updatePoint(pointId, eiLevelId: const Value(null));
      expect((await lePoint()).eiLevelId, isNull);
    });

    test('un champ non passe n\'est pas touche', () async {
      final niveau = await creer(SettingKind.eiLevel, 'EI90');
      await db.pointDao.updatePoint(
        pointId,
        eiLevelId: Value(niveau),
        building: const Value('Bloc A'),
      );

      // Une modification du batiment seul ne doit pas emporter le niveau EI.
      await db.pointDao.updatePoint(pointId, building: const Value('Bloc B'));

      final point = await lePoint();
      expect(point.building, 'Bloc B');
      expect(point.eiLevelId, niveau);
    });

    test('un point referencant une option supprimee reste lisible', () async {
      final id = await creer(SettingKind.product, 'Promastop-M');
      await poser([id]);
      await db.settingsDao.retire(id);

      // La cle etrangere tient, la reference survit, et le libelle se retrouve.
      expect((await lePoint()).product1Id, id);
      expect(await db.settingsDao.labels(), containsPair(id, 'Promastop-M'));
    });
  });

  group('la fiche complete', () {
    test('toutes les caracteristiques partent dans une seule charge utile',
        () async {
      final config = await creer(SettingKind.configuration, 'Percement');
      final detail = await creer(SettingKind.configurationDetail, 'Trou');
      final ei = await creer(SettingKind.eiLevel, 'EI120');
      final etage = await creer(SettingKind.floor, 'Niveau -2');
      final fournisseur = await creer(SettingKind.supplier, 'Promat');
      await db.delete(db.outboxEntries).go();

      await db.pointDao.updatePoint(
        pointId,
        refNumber: const Value('47'),
        building: const Value('Bloc A'),
        floorId: Value(etage),
        configurationId: Value(config),
        configurationDetailId: Value(detail),
        eiLevelId: Value(ei),
        supplierId: Value(fournisseur),
      );

      final payload = jsonDecode(
        (await db.select(db.outboxEntries).getSingle()).payload,
      ) as Map<String, dynamic>;

      // Saisi par le technicien, donc transmis : il etait auparavant attribue
      // par le serveur, et absent de la charge utile.
      expect(payload['ref_number'], '47');
      expect(payload['building'], 'Bloc A');
      expect(payload['floor_id'], etage);
      expect(payload['configuration_id'], config);
      expect(payload['configuration_detail_id'], detail);
      expect(payload['ei_level_id'], ei);
      expect(payload['supplier_id'], fournisseur);
    });
  });
}
