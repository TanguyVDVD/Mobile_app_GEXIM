import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/daos/point_dao.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le chantier donne à ses traversées, et le numéro que le technicien
/// leur donne.
///
/// Le numéro de point était attribué par le serveur ; il est désormais saisi.
/// Tout ce qui est vérifié ici découle de ce changement : il doit **partir**
/// au serveur, être proposé sans être imposé, et un doublon doit se voir.
void main() {
  late AppDatabase db;
  late String projectId;

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
      purchaseOrder: 'PO-4471',
      building: 'Bloc A',
    );
    await db.delete(db.outboxEntries).go();
  });

  tearDown(() => db.close());

  Future<String> creer({int? numero}) => db.pointDao.createPoint(
        projectId: projectId,
        authorId: auteur,
        refNumber: numero,
      );

  Future<Point> lePoint(String id) =>
      (db.select(db.points)..where((t) => t.id.equals(id))).getSingle();

  Future<Map<String, dynamic>> derniereCharge(OutboxEntity type) async {
    final entrees = await (db.select(db.outboxEntries)
          ..where((t) => t.entityType.equalsValue(type)))
        .get();
    return jsonDecode(entrees.last.payload) as Map<String, dynamic>;
  }

  group('le chantier', () {
    test('envoie son bon de commande et son batiment au serveur', () async {
      // Absents de la charge utile, ils n'existeraient que sur le poste de
      // l'administrateur : la fiche du technicien resterait sans bon de
      // commande, et le rapport genere sur tablette aussi.
      final chantier = await db.projectDao.projectById(projectId);
      await db.projectDao.updateProject(
        projectId,
        name: chantier.name,
        clientId: chantier.clientId,
        purchaseOrder: 'PO-9000',
        building: 'Bloc B',
      );

      final charge = await derniereCharge(OutboxEntity.project);
      expect(charge['purchase_order'], 'PO-9000');
      expect(charge['building'], 'Bloc B');
    });

    test('donne son batiment a une nouvelle traversee', () async {
      expect((await lePoint(await creer())).building, 'Bloc A');
    });

    test('ne reecrit pas le batiment des traversees deja relevees', () async {
      // Une valeur de depart, pas une valeur partagee : un chantier couvre
      // parfois plusieurs batiments, et corriger le defaut ne doit pas
      // deplacer des traversees deja localisees.
      final id = await creer();
      await db.pointDao.updatePoint(id, building: const Value('Bloc C'));

      final chantier = await db.projectDao.projectById(projectId);
      await db.projectDao.updateProject(
        projectId,
        name: chantier.name,
        clientId: chantier.clientId,
        building: 'Bloc Z',
      );

      expect((await lePoint(id)).building, 'Bloc C');
      expect((await lePoint(await creer())).building, 'Bloc Z');
    });
  });

  group('les ecarts au chantier', () {
    Future<Identification> surLaFiche(String id) async =>
        PointDao.identification(
          await lePoint(id),
          await db.projectDao.projectById(projectId),
        );

    test('sans ecart, la fiche dit ce que dit le chantier', () async {
      final fiche = await surLaFiche(await creer());

      expect(fiche.name, 'Chantier');
      expect(fiche.code, isNull);
      expect(fiche.purchaseOrder, 'PO-4471');
    });

    test('sans ecart, la fiche suit un chantier corrige apres coup', () async {
      // Tout l'interet d'un ecart plutot que d'une copie : une faute de frappe
      // corrigee sur le chantier atteint les fiches deja relevees.
      final id = await creer();
      final chantier = await db.projectDao.projectById(projectId);
      await db.projectDao.updateProject(
        projectId,
        name: 'Chantier corrige',
        clientId: chantier.clientId,
        code: '2026-118',
        purchaseOrder: 'PO-9000',
      );

      final fiche = await surLaFiche(id);
      expect(fiche.name, 'Chantier corrige');
      expect(fiche.code, '2026-118');
      expect(fiche.purchaseOrder, 'PO-9000');
    });

    test('un ecart tient, quoi que devienne le chantier, et part au serveur',
        () async {
      final id = await creer();
      await db.pointDao.updatePoint(
        id,
        projectCode: const Value('2026-999'),
        projectName: const Value('Zone B'),
        purchaseOrder: const Value('PO-ZONE-B'),
      );

      final charge = await derniereCharge(OutboxEntity.point);
      expect(charge['project_code'], '2026-999');
      expect(charge['project_name'], 'Zone B');
      expect(charge['purchase_order'], 'PO-ZONE-B');

      final chantier = await db.projectDao.projectById(projectId);
      await db.projectDao.updateProject(
        projectId,
        name: 'Autre nom',
        clientId: chantier.clientId,
        purchaseOrder: 'PO-9000',
      );

      final fiche = await surLaFiche(id);
      expect(fiche.code, '2026-999');
      expect(fiche.name, 'Zone B');
      expect(fiche.purchaseOrder, 'PO-ZONE-B');
    });

    test('un ecart efface rend la fiche a son chantier', () async {
      final id = await creer();
      await db.pointDao.updatePoint(id, projectName: const Value('Zone B'));
      await db.pointDao.updatePoint(id, projectName: const Value(null));

      expect((await surLaFiche(id)).name, 'Chantier');
    });
  });

  group('l\'etat d\'une fiche dans le releve', () {
    Future<PointSummary> resume() async =>
        (await db.pointDao.pointSummaries(projectId)).single;

    Future<String> option(SettingKind kind, String label, {String? chez}) =>
        db.settingsDao.create(kind: kind, label: label, supplierId: chez);

    test('une fiche tout juste creee : huit valeurs a remplir', () async {
      // Le numéro est proposé, le bâtiment, l'intitulé et le Purchase Order
      // viennent du chantier ; restent le numéro de projet — ce chantier
      // n'en a pas —, l'étage, les cinq listes et un produit.
      await creer();

      final fiche = await resume();
      expect(fiche.missingValues, 8);
      expect(fiche.photoCount, 0);
      expect(fiche.isComplete, isFalse);
    });

    test('un seul produit suffit, quel que soit son emplacement', () async {
      final id = await creer();
      final promat = await option(SettingKind.supplier, 'Promat');
      await db.pointDao.updatePoint(
        id,
        floorLevel: const Value(0),
        configurationId:
            Value(await option(SettingKind.configuration, 'Percement')),
        configurationDetailId:
            Value(await option(SettingKind.configurationDetail, 'Trou')),
        eiLevelId: Value(await option(SettingKind.eiLevel, 'EI60')),
        supplierId: Value(promat),
        productTypeId: Value(await option(SettingKind.productType, 'Mortier')),
      );
      // Restent le produit, et le numéro de projet que le chantier n'a pas.
      expect((await resume()).missingValues, 2);
      await db.pointDao.updatePoint(id, projectCode: const Value('2026-118'));

      // Posé en troisième emplacement, les autres vides : il compte.
      await db.pointDao.updatePoint(
        id,
        product3Id: Value(
          await option(SettingKind.product, 'Promastop-M', chez: promat),
        ),
      );

      final fiche = await resume();
      expect(fiche.missingValues, 0);
      // Toutes les valeurs, mais aucun cliché : pas encore complète.
      expect(fiche.isComplete, isFalse);
    });

    test('un numero efface ou un batiment vide comptent comme manquants',
        () async {
      final id = await creer();
      final avant = (await resume()).missingValues;

      await db.pointDao.updatePoint(
        id,
        refNumber: const Value(null),
        building: const Value('  '),
      );

      expect((await resume()).missingValues, avant + 2);
    });

    test('ce que la fiche reprend du chantier compte aussi', () async {
      // Un numéro de projet ou un bon de commande effacé par mégarde sur le
      // chantier doit se voir sur chacune de ses fiches.
      await creer();
      final avant = (await resume()).missingValues;

      final chantier = await db.projectDao.projectById(projectId);
      await db.projectDao.updateProject(
        projectId,
        name: chantier.name,
        clientId: chantier.clientId,
        code: '2026-118',
        // Le Purchase Order, renseigné à la création, disparaît.
      );

      // Un de gagné (le numéro de projet), un de perdu (le bon de commande).
      expect((await resume()).missingValues, avant);

      await db.projectDao.updateProject(
        projectId,
        name: chantier.name,
        clientId: chantier.clientId,
        code: '2026-118',
        purchaseOrder: 'PO-4471',
      );
      expect((await resume()).missingValues, avant - 1);
    });

    test('un ecart de la traversee comble ce que le chantier n\'a pas',
        () async {
      final id = await creer();
      final avant = (await resume()).missingValues;

      await db.pointDao.updatePoint(id, projectCode: const Value('2026-999'));

      expect((await resume()).missingValues, avant - 1);
    });
  });

  group('le numero de point', () {
    test('est propose a la suite du plus grand, et part au serveur', () async {
      expect((await lePoint(await creer())).refNumber, 1);
      expect((await lePoint(await creer(numero: 40))).refNumber, 40);
      // A la suite du plus grand, pas du nombre de points : le reperage du
      // chantier peut commencer ailleurs qu'a 1.
      expect((await lePoint(await creer())).refNumber, 41);

      expect((await derniereCharge(OutboxEntity.point))['ref_number'], 41);
    });

    test('se corrige et s\'efface comme tout autre champ', () async {
      final id = await creer();

      await db.pointDao.updatePoint(id, refNumber: const Value(12));
      expect((await lePoint(id)).refNumber, 12);
      expect((await derniereCharge(OutboxEntity.point))['ref_number'], 12);

      await db.pointDao.updatePoint(id, refNumber: const Value(null));
      expect((await lePoint(id)).refNumber, isNull);

      // Un champ non passe n'y touche pas.
      await db.pointDao.updatePoint(id, refNumber: const Value(7));
      await db.pointDao.updatePoint(id, building: const Value('Bloc B'));
      expect((await lePoint(id)).refNumber, 7);
    });

    test('un numero libere par une suppression est repropose', () async {
      await creer();
      final dernier = await creer();
      await db.pointDao.deletePoint(dernier);

      expect((await lePoint(await creer())).refNumber, 2);
    });

    test('un doublon est accepte, et signale des deux cotes', () async {
      // Rien ne l'interdit : une contrainte ferait refuser a la
      // synchronisation le releve du second technicien. Mais il doit se voir.
      final a = await creer(numero: 5);
      final b = await creer(numero: 6);
      expect(await db.pointDao.watchRefNumberTaken(a).first, isFalse);

      await db.pointDao.updatePoint(b, refNumber: const Value(5));

      expect(await db.pointDao.watchRefNumberTaken(a).first, isTrue);
      expect(await db.pointDao.watchRefNumberTaken(b).first, isTrue);
    });

    test('deux fiches sans numero ne sont pas des doublons', () async {
      final a = await creer();
      final b = await creer();
      await db.pointDao.updatePoint(a, refNumber: const Value(null));
      await db.pointDao.updatePoint(b, refNumber: const Value(null));

      expect(await db.pointDao.watchRefNumberTaken(a).first, isFalse);
    });

    test('un point supprime ne fait pas doublon', () async {
      final a = await creer(numero: 5);
      final b = await creer(numero: 5);
      await db.pointDao.deletePoint(b);

      expect(await db.pointDao.watchRefNumberTaken(a).first, isFalse);
    });

    test('ordonne le releve, les fiches sans numero a la fin', () async {
      // Le classeur suit cet ordre : celui du reperage, pas celui de la saisie.
      final sans = await creer();
      await db.pointDao.updatePoint(sans, refNumber: const Value(null));
      await creer(numero: 12);
      await creer(numero: 3);

      final releve = await db.pointDao.pointSummaries(projectId);
      expect([for (final s in releve) s.label], ['3', '12', '—']);
      expect([for (final s in releve) s.isProvisional], [false, false, true]);
    });
  });
}
