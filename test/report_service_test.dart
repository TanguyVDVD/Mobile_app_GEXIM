import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/features/capture/photo_repository.dart';
import 'package:firestop_tracker/features/capture/reduction_jpeg.dart';
import 'package:firestop_tracker/features/reports/report_service.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Passerelle réduite à ce que l'export interroge : le logo du client.
class _Passerelle implements RemoteGateway {
  _Passerelle({this.logo});

  final Uint8List? logo;

  @override
  Future<Uint8List> downloadAsset(
    String remotePath, {
    required String bucket,
  }) async =>
      logo ?? (throw const SocketException('hors ligne'));

  @override
  Future<Uint8List> downloadPhoto(String remotePath) =>
      throw const SocketException('hors ligne');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Rend le fichier tel quel : la réduction a ses propres tests.
class _SansReduction implements ReductionJpeg {
  const _SansReduction();

  @override
  Future<Uint8List?> reduire(
    File source, {
    required int coteMin,
    required int qualite,
    bool garderExif = false,
  }) =>
      source.readAsBytes();
}

/// De la base locale au classeur Excel.
///
/// Le remplissage du modèle a ses tests dans `packages/firestop_excel`. Ici
/// c'est le **trajet** qui est vérifié : que chaque donnée du chantier arrive
/// bien dans la fiche — et que ce qui manque soit compté, pas tu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory dossier;
  late String projectId;

  const auteur = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';

  final jpeg = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 40, height: 30)),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dossier = await Directory.systemTemp.createTemp('export_test');

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
      name: 'Client Exemple SA',
      address: 'Rue du Test 1, 4000 Liège',
      logoPath: 'client/logo.png',
    );
    projectId = await db.projectDao.createProject(
      clientId: clientId,
      name: 'Hall logistique',
      code: '2026-118',
      purchaseOrder: 'PO-4471',
      building: 'Bloc A',
    );
  });

  tearDown(() async {
    await db.close();
    await dossier.delete(recursive: true);
  });

  ReportService service({Uint8List? logo}) {
    final passerelle = _Passerelle(logo: logo);
    return ReportService(
      db: db,
      photos: PhotoRepository(db, passerelle),
      gateway: passerelle,
      reduction: const _SansReduction(),
    );
  }

  Future<String> creerPoint(int numero) => db.pointDao.createPoint(
        projectId: projectId,
        authorId: auteur,
        refNumber: '$numero',
        capturedAt: DateTime(2026, 10, 3),
      );

  Future<void> ajouterPhoto(
    String pointId,
    PhotoKind kind, {
    bool fichierPresent = true,
  }) async {
    final id = '$pointId-${kind.name}';
    final fichier = File('${dossier.path}/$id.jpg');
    if (fichierPresent) await fichier.writeAsBytes(jpeg);

    await db.into(db.photos).insert(
          Photo(
            id: id,
            pointId: pointId,
            kind: kind,
            localPath: fichier.path,
            sortOrder: 0,
            takenAt: DateTime(2026, 10, 3),
            uploadState: PhotoUploadState.ready,
            uploadAttempts: 0,
            updatedAt: DateTime(2026, 10, 3),
          ),
        );
  }

  Map<String, String> xml(Uint8List classeur) => {
        for (final f in ZipDecoder().decodeBytes(classeur))
          if (f.isFile && f.name.endsWith('.xml'))
            f.name: utf8.decode(f.readBytes()!),
      };

  /// Texte de la cellule [ref], ou sa valeur calculée si c'est une formule.
  String valeur(String feuille, String ref) {
    final cellule = RegExp('<c r="$ref"[^>]*?(?:/>|>(.*?)</c>)', dotAll: true)
            .firstMatch(feuille)?[1] ??
        '';
    return RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).firstMatch(cellule)?[1] ??
        RegExp(r'<v>(.*?)</v>').firstMatch(cellule)?[1] ??
        '';
  }

  test('une feuille par traversee, remplie depuis le chantier et le point',
      () async {
    final ei = await db.settingsDao.create(
      kind: SettingKind.eiLevel,
      label: 'EI60',
    );
    final etage = await db.settingsDao.create(
      kind: SettingKind.floor,
      label: 'Niveau 2',
    );
    final promat = await db.settingsDao.create(
      kind: SettingKind.supplier,
      label: 'Promat',
    );
    final produit = await db.settingsDao.create(
      kind: SettingKind.product,
      label: 'Promastop-M',
      supplierId: promat,
    );
    // Retiré du catalogue, mais bel et bien posé : il doit rester sur la
    // fiche.
    await db.settingsDao.retire(produit);

    final point = await creerPoint(12);
    await db.pointDao.updatePoint(
      point,
      floorId: Value(etage),
      eiLevelId: Value(ei),
      supplierId: Value(promat),
      product3Id: Value(produit),
    );
    await creerPoint(3);

    final classeur = await service().build(projectId);
    final parts = xml(classeur.octets);

    expect(classeur.fiches, 2);
    // Dans l'ordre des numéros, pas de la saisie.
    expect(
      RegExp('<sheet name="([^"]*)"')
          .allMatches(parts['xl/workbook.xml']!)
          .map((m) => m[1]),
      ['3', '12', 'Menus déroulants'],
    );

    final fiche = parts['xl/worksheets/fiche2.xml']!;
    expect(valeur(fiche, 'K5'), '2026-118');
    expect(valeur(fiche, 'E11'), 'Hall logistique');
    expect(valeur(fiche, 'E12'), 'PO-4471');
    expect(valeur(fiche, 'E13'), 'Bloc A');
    // Le libellé de l'étage, tel que la liste administrée le donne.
    expect(valeur(fiche, 'E14'), 'Niveau 2');
    // Le numéro du point : en M5, que « Numéro du point » reprend par formule.
    expect(valeur(fiche, 'M5'), '12');
    expect(valeur(fiche, 'E15'), '12');
    expect(valeur(fiche, 'F22'), 'EI60');
    expect(valeur(fiche, 'F23'), 'Promat');
    expect(valeur(fiche, 'F27'), 'Promastop-M');
  });

  test('une traversee qui s\'ecarte du chantier garde son ecart a l\'export',
      () async {
    final ecartee = await creerPoint(1);
    await db.pointDao.updatePoint(
      ecartee,
      projectCode: const Value('2026-999'),
      projectName: const Value('Zone B'),
      purchaseOrder: const Value('PO-ZONE-B'),
    );
    await creerPoint(2);

    final parts = xml((await service().build(projectId)).octets);

    final fiche1 = parts['xl/worksheets/fiche1.xml']!;
    expect(valeur(fiche1, 'K5'), '2026-999');
    expect(valeur(fiche1, 'E11'), 'Zone B');
    expect(valeur(fiche1, 'E12'), 'PO-ZONE-B');
    // Sa voisine, elle, dit toujours ce que dit le chantier.
    final fiche2 = parts['xl/worksheets/fiche2.xml']!;
    expect(valeur(fiche2, 'K5'), '2026-118');
    expect(valeur(fiche2, 'E11'), 'Hall logistique');
    expect(valeur(fiche2, 'E12'), 'PO-4471');
  });

  test('les deux cases recoivent l\'avant et l\'apres, pas un complement',
      () async {
    final point = await creerPoint(1);
    // Insérés dans le désordre : le complément d'abord.
    await ajouterPhoto(point, PhotoKind.extra);
    await ajouterPhoto(point, PhotoKind.after);
    await ajouterPhoto(point, PhotoKind.before);

    final classeur = await service().build(projectId);
    final medias = [
      for (final f in ZipDecoder().decodeBytes(classeur.octets))
        if (f.name.startsWith('xl/media/photo')) f.name,
    ];

    expect(medias, hasLength(2));
    expect(classeur.clichesManquants, 0);
  });

  test('un cliche introuvable est compte, et le classeur sort quand meme',
      () async {
    // Photo prise sur une autre tablette, appareil hors ligne : la fiche sort
    // avec une case vide. Le dire est la seule chose qui évite qu'elle parte
    // ainsi chez le client.
    final point = await creerPoint(1);
    await ajouterPhoto(point, PhotoKind.before);
    await ajouterPhoto(point, PhotoKind.after, fichierPresent: false);

    final classeur = await service().build(projectId);

    expect(classeur.fiches, 1);
    expect(classeur.clichesManquants, 1);
  });

  test('sans reseau le logo manque : signale, et le nom du client le remplace',
      () async {
    await creerPoint(1);

    final sans = await service().build(projectId);
    expect(sans.sansLogo, isTrue);
    expect(
      valeur(xml(sans.octets)['xl/worksheets/fiche1.xml']!, 'K7'),
      'Client Exemple SA',
    );

    final avec = await service(logo: jpeg).build(projectId);
    expect(avec.sansLogo, isFalse);
    expect(
      ZipDecoder().decodeBytes(avec.octets).map((f) => f.name),
      contains('xl/media/logoClient.jpeg'),
    );
  });

  test('un chantier sans traversee est refuse en clair', () async {
    await expectLater(
      service().build(projectId),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('aucune traversée'),
        ),
      ),
    );
  });
}
