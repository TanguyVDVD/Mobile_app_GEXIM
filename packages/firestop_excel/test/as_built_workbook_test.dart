import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:firestop_excel/firestop_excel.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Le classeur produit, relu partie par partie.
///
/// Ce que ces tests ne peuvent pas dire : si Excel ouvre le classeur sans le
/// « réparer ». Un XML bien formé et des liens cohérents en sont la condition
/// nécessaire, vérifiée ici ; la preuve, elle, se fait dans Excel — voir
/// `tool/exemple.dart`.
void main() {
  final modele = File(
    '../../AS_BUILT_Resserages_RF_model_vierge.xlsm',
  ).readAsBytesSync();

  Map<String, Uint8List> ouvrir(Uint8List classeur) => {
        for (final f in ZipDecoder().decodeBytes(classeur))
          if (f.isFile) f.name: f.readBytes()!,
      };

  final partsModele = ouvrir(modele);

  /// L'image d'en-tête du modèle : un vrai JPEG, large. Cherchée par son
  /// extension et non par son nom — Excel la renomme quand il réenregistre le
  /// classeur.
  final jpeg = partsModele.entries
      .firstWhere(
          (e) => e.key.startsWith('xl/media/') && e.key.endsWith('.jpeg'))
      .value;

  final feuilleModele = utf8.decode(partsModele['xl/worksheets/sheet1.xml']!);

  /// En-tête d'un PNG de 300 × 600 : assez pour être reconnu et mesuré.
  final png = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, //
    0, 0, 0x01, 0x2C, 0, 0, 0x02, 0x58, //
    8, 2, 0, 0, 0,
  ]);

  ReportPoint point({
    String? numero = '12',
    List<ReportPhoto> photos = const [],
    List<String> produits = const ['Promastop-M', '', 'Promaseal-A'],
  }) =>
      ReportPoint(
        number: numero,
        capturedAt: DateTime(2026, 10, 3, 15, 42),
        purchaseOrder: 'PO-4471',
        building: 'Bloc A',
        floor: 'Niveau 2',
        configuration: 'Traversée de paroi verticale',
        configurationDetail: 'Chemin de câbles',
        eiLevel: 'EI60',
        supplier: 'Promat',
        productType: 'Mortier',
        products: produits,
        photos: photos,
      );

  Map<String, Uint8List> construire(
    List<ReportPoint> points, {
    Uint8List? logo,
    String? code = '2026-118',
    String nomProjet = 'Hall logistique',
  }) =>
      ouvrir(
        const AsBuiltWorkbook().build(
          modele: modele,
          data: ReportData(
            client: const ReportClient(
              name: 'Client Exemple SA',
              address: 'Rue du Test 1\n4000 Liège',
            ),
            project: ReportProject(name: nomProjet, code: code),
            points: points,
            clientLogo: logo,
          ),
        ),
      );

  String texte(Map<String, Uint8List> parts, String nom) =>
      utf8.decode(parts[nom]!);

  /// Contenu de la cellule [ref] : `(attributs, intérieur)`.
  (String, String) cellule(String feuille, String ref) {
    final m = RegExp('<c r="$ref"([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
        .firstMatch(feuille);
    expect(m, isNotNull, reason: 'cellule $ref absente');
    return (m![1]!, m[2] ?? '');
  }

  String valeur(String feuille, String ref) {
    final (_, interieur) = cellule(feuille, ref);
    final t = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).firstMatch(interieur);
    final v = RegExp(r'<v>(.*?)</v>').firstMatch(interieur);
    return t?[1] ?? v?[1] ?? '';
  }

  /// Coins de l'image nommée [nom] : colonne et ligne de départ, puis
  /// d'arrivée (à partir de zéro).
  (int, int, int, int) coins(String dessin, String nom) {
    final ancre = dessin
        .split('<xdr:twoCellAnchor')
        .firstWhere((a) => a.contains('name="$nom"'));
    final m = RegExp(
      r'<xdr:from><xdr:col>(\d+)</xdr:col>.*?<xdr:row>(\d+)</xdr:row>.*?'
      r'<xdr:to><xdr:col>(\d+)</xdr:col>.*?<xdr:row>(\d+)</xdr:row>',
    ).firstMatch(ancre)!;
    return (
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      int.parse(m[4]!),
    );
  }

  List<String> nomsDeFeuille(Map<String, Uint8List> parts) => [
        for (final m in RegExp(r'<sheet name="([^"]*)"')
            .allMatches(texte(parts, 'xl/workbook.xml')))
          m[1]!,
      ];

  group('ce qui vient du modele traverse intact', () {
    final parts = construire([point(), point(numero: '13')]);

    test('les macros, octet pour octet', () {
      // Le classeur est rouvert dans Excel pour l'export : sans son projet
      // VBA, les trois boutons de chaque fiche ne mèneraient nulle part.
      expect(parts['xl/vbaProject.bin'], partsModele['xl/vbaProject.bin']);
      expect(
        texte(parts, '[Content_Types].xml'),
        contains('application/vnd.ms-excel.sheet.macroEnabled.main+xml'),
      );
    });

    test('les styles et la feuille des menus deroulants', () {
      expect(parts['xl/styles.xml'], partsModele['xl/styles.xml']);
      expect(
        parts['xl/worksheets/sheet3.xml'],
        partsModele['xl/worksheets/sheet3.xml'],
      );
      expect(nomsDeFeuille(parts).last, 'Menus déroulants');
    });

    test('chaque fiche garde ses boutons, relies a leurs macros', () {
      for (final n in [1, 2]) {
        final feuille = texte(parts, 'xl/worksheets/fiche$n.xml');
        final boutons = texte(parts, 'xl/drawings/ficheBoutons$n.vml');
        for (final macro in ['choisir_chemin_photos', 'nvx_pt', 'ins_photo2']) {
          expect(feuille, contains('macro="[0]!$macro"'));
          expect(boutons, contains('<x:FmlaMacro>[0]!$macro</x:FmlaMacro>'));
        }
      }
    });

    test('chaque fiche garde ses listes deroulantes', () {
      // « Garder la ligne menu déroulant » : une fiche ajoutée ou corrigée à
      // la main doit toujours proposer les listes du bureau.
      final feuille = texte(parts, 'xl/worksheets/fiche2.xml');
      expect(RegExp('<x14:dataValidation ').allMatches(feuille), hasLength(7));
      expect(feuille, contains(r"'Menus déroulants'!$A$4:$A$34"));
    });

    test('les feuilles d\'exemple du modele ont disparu', () {
      expect(nomsDeFeuille(parts), ['12', '13', 'Menus déroulants']);
      expect(parts.keys, isNot(contains('xl/worksheets/sheet1.xml')));
      expect(parts.keys, isNot(contains('xl/calcChain.xml')));
    });
  });

  group('une fiche', () {
    final parts = construire([
      point(photos: [ReportPhoto(bytes: jpeg), ReportPhoto(bytes: png)]),
    ]);
    final feuille = texte(parts, 'xl/worksheets/fiche1.xml');

    test('porte la date du releve, comme une vraie date Excel', () {
      // Un nombre, pas un texte : la cellule garde son format de date, et se
      // trie. 3 octobre 2026 = jour 46298 d'Excel, quelle que soit l'heure.
      final (attributs, _) = cellule(feuille, 'D5');
      expect(attributs, isNot(contains('t=')));
      expect(valeur(feuille, 'D5'), '46298');
    });

    test('recoit le numero de projet en K5, que les formules reprennent', () {
      expect(valeur(feuille, 'K5'), '2026-118');
      expect(cellule(feuille, 'E10').$2, contains('<f>K5</f>'));
      expect(cellule(feuille, 'E10').$2, contains('<v>2026-118</v>'));
    });

    test('recoit le numero du point en M5, d\'ou la fiche le tire', () {
      // Tel que saisi : c'est aussi le nom de la feuille.
      expect(valeur(feuille, 'M5'), '12');
      // « Numéro du point » le reprend par formule, comme le numéro de fiche.
      expect(cellule(feuille, 'E15').$2, contains('<f>M5</f>'));
      expect(cellule(feuille, 'E15').$2, contains('<v>12</v>'));
      expect(
          cellule(feuille, 'G5').$2, contains('<v>2026-118-As Built-12</v>'));
    });

    test('ecrit le numero de fiche sans CONCAT', () {
      // La fonction du modèle n'existe que dans les Excel récents sous
      // licence ; ailleurs le numéro vire à « #NOM? » au premier recalcul.
      expect(cellule(feuille, 'G5').$2, contains('<f>K5&amp;L5&amp;M5</f>'));
      expect(feuille, isNot(contains('CONCAT')));
    });

    test('porte chaque valeur du point a son emplacement', () {
      expect(valeur(feuille, 'F7'), 'Rue du Test 1\n4000 Liège');
      expect(valeur(feuille, 'E11'), 'Hall logistique');
      expect(valeur(feuille, 'E12'), 'PO-4471');
      expect(valeur(feuille, 'E13'), 'Bloc A');
      expect(valeur(feuille, 'E14'), 'Niveau 2');
      expect(valeur(feuille, 'E15'), '12');
      expect(valeur(feuille, 'F20'), 'Traversée de paroi verticale');
      expect(valeur(feuille, 'F21'), 'Chemin de câbles');
      expect(valeur(feuille, 'F22'), 'EI60');
      expect(valeur(feuille, 'F23'), 'Promat');
      expect(valeur(feuille, 'F24'), 'Mortier');
    });

    test('garde les cinq emplacements produit a leur rang', () {
      // Le deuxième, vide, ne fait pas remonter le troisième.
      expect(valeur(feuille, 'F25'), 'Promastop-M');
      expect(valeur(feuille, 'F26'), '');
      expect(valeur(feuille, 'F27'), 'Promaseal-A');
      expect(valeur(feuille, 'F28'), '');
      expect(valeur(feuille, 'F29'), '');
    });

    test('ne garde aucune valeur d\'exemple du modele', () {
      // Le modèle arrive prérempli (« Percement de paroi Verticale »,
      // « Promastop-CC liquide »…), en renvois vers sa table de textes. Un
      // renvoi resté en place mettrait le produit d'un autre chantier sur la
      // fiche.
      for (final ref in ['F20', 'F21', 'F22', 'F23', 'F24', 'F25', 'F26']) {
        expect(cellule(feuille, ref).$1, isNot(contains('t="s"')), reason: ref);
      }
    });

    test('a une marge haute de 4,5 cm, les autres marges du modele', () {
      // Excel affiche les marges en centimètres et les enregistre en pouces.
      String? marge(String xml, String cote) =>
          RegExp('<pageMargins [^>]*?$cote="([^"]*)"').firstMatch(xml)?[1];

      expect(double.parse(marge(feuille, 'top')!) * 2.54, closeTo(4.5, 0.001));
      for (final cote in ['left', 'right', 'bottom', 'header', 'footer']) {
        expect(marge(feuille, cote), marge(feuilleModele, cote), reason: cote);
      }
    });

    test('garde la mise en forme du modele', () {
      // Chaque cellule remplie garde le style que **le modèle** lui donne.
      // Comparé au modèle et non à un numéro : Excel renumérote ses styles à
      // chaque réenregistrement.
      String? style(String xml, String ref) =>
          RegExp(' s="(\\d+)"').firstMatch(cellule(xml, ref).$1)?[1];

      for (final ref in ['D5', 'K5', 'F7', 'E11', 'E13', 'F20', 'F29']) {
        expect(style(feuille, ref), style(feuilleModele, ref), reason: ref);
        expect(style(feuille, ref), isNotNull, reason: ref);
      }
      // « Numéro du point » : le modèle y porte un format de date ; la fiche
      // prend le style de la ligne « Intitulé Projet ».
      expect(style(feuille, 'E15'), style(feuilleModele, 'E11'));
    });
  });

  group('les cliches', () {
    List<Match> images(Map<String, Uint8List> parts, String nom) =>
        RegExp(r'<xdr:cNvPr id="\d+" name="' '$nom' r' \d"/>')
            .allMatches(texte(parts, 'xl/drawings/fiche1.xml'))
            .toList();

    test('les deux premiers, et eux seuls', () {
      final parts = construire([
        point(
          photos: [
            ReportPhoto(bytes: jpeg),
            ReportPhoto(bytes: png),
            ReportPhoto(bytes: jpeg),
          ],
        ),
      ]);

      expect(images(parts, 'Photo'), hasLength(2));
      expect(parts['xl/media/photo1_1.jpeg'], jpeg);
      expect(parts['xl/media/photo1_2.png'], png);
      expect(parts.keys, isNot(contains('xl/media/photo1_3.jpeg')));
    });

    test('un seul cliche : une seule image, dans la premiere case', () {
      final parts = construire([
        point(photos: [ReportPhoto(bytes: jpeg)]),
      ]);

      expect(images(parts, 'Photo'), hasLength(1));
      // C18:E18 — colonnes 2 à 4, ligne 17, à partir de zéro.
      expect(
        coins(texte(parts, 'xl/drawings/fiche1.xml'), 'Photo 1'),
        (2, 17, 4, 17),
      );
    });

    test('aucun cliche : aucune image, et la fiche sort quand meme', () {
      final parts = construire([point()]);
      expect(images(parts, 'Photo'), isEmpty);
      expect(parts.keys, isNot(contains('xl/drawings/_rels/fiche1.xml.rels')));
    });

    test('prennent les dimensions de la case, lues dans le modele', () {
      // 2 px de retrait de chaque côté, pour laisser voir les traits. La
      // ligne 18 du modèle fait 160,15 pt ; ses colonnes C à E, 93 + 89 + 92 px.
      final parts = construire([
        point(photos: [ReportPhoto(bytes: jpeg)]),
      ]);
      final taille =
          RegExp(r'<a:ext cx="(\d+)" cy="(\d+)"/></a:xfrm>').firstMatch(
        texte(parts, 'xl/drawings/fiche1.xml')
            .split('<xdr:twoCellAnchor')
            .firstWhere((a) => a.contains('name="Photo 1"')),
      )!;

      expect(int.parse(taille[1]!), (93 + 89 + 92 - 4) * 9525);
      expect(int.parse(taille[2]!), (160.15 * 12700).round() - 4 * 9525);
    });

    test('remplissent chacun toute sa case', () {
      // Demande du bureau : la case pleine, comme le fait la macro « Insérer
      // Photo » — quitte à étirer un cliché pris en hauteur. L'ancre va donc
      // du premier au dernier coin de la case, quelles que soient les
      // proportions de l'image (ici un paysage et un portrait).
      final parts = construire([
        point(photos: [ReportPhoto(bytes: jpeg), ReportPhoto(bytes: png)]),
      ]);
      final dessin = texte(parts, 'xl/drawings/fiche1.xml');

      expect(coins(dessin, 'Photo 1'), (2, 17, 4, 17)); // C18:E18
      expect(coins(dessin, 'Photo 2'), (5, 17, 7, 17)); // F18:H18
      // Et elle suit la case si on la redimensionne.
      expect(
        RegExp('<xdr:twoCellAnchor editAs="twoCell">').allMatches(dessin),
        hasLength(2),
      );
    });

    test('un contenu qui n\'est pas une image est ecarte', () {
      final parts = construire([
        point(photos: [
          ReportPhoto(bytes: Uint8List.fromList([1, 2, 3, 4]))
        ]),
      ]);
      expect(images(parts, 'Photo'), isEmpty);
    });
  });

  group('le client', () {
    test('avec logo : pose sur K7, et montre dans la case Client', () {
      final parts = construire([point(), point(numero: '13')], logo: jpeg);

      for (final n in [1, 2]) {
        final dessin = texte(parts, 'xl/drawings/fiche$n.xml');
        final feuille = texte(parts, 'xl/worksheets/fiche$n.xml');

        // Le logo lui-même, sur K7:L8.
        expect(coins(dessin, 'Logo client'), (10, 6, 11, 7));
        // La case « Client », D7:E8.
        expect(coins(dessin, 'Client'), (3, 6, 4, 7));

        // Pas de « 0 » sous le logo : la formule `=K7` ne reporte pas une
        // image, la cellule est vidée.
        expect(cellule(feuille, 'D7').$2, isEmpty);
        expect(cellule(feuille, 'K7').$2, isEmpty);
      }
      // Un seul exemplaire du logo, quel que soit le nombre de fiches.
      expect(
        parts.keys.where((n) => n.startsWith('xl/media/logoClient')),
        hasLength(1),
      );
    });

    test('la case Client est liee a K7, pas une seconde copie du logo', () {
      // Le modèle veut que la fiche dise ce que contient K7. L'image liée
      // tient en deux morceaux qui doivent se désigner par le même
      // identifiant, propre à chaque feuille — sinon Excel « répare » le
      // classeur, ou l'image ne suit plus K7.
      final parts = construire([point(), point(numero: '13')], logo: jpeg);

      for (final n in [1, 2]) {
        final id = '_x0000_s${n * 1024 + 5}';
        final dessin = texte(parts, 'xl/drawings/fiche$n.xml');
        final vml = texte(parts, 'xl/drawings/ficheBoutons$n.vml');

        expect(
          dessin,
          contains('<a14:cameraTool cellRange="\$K\$7" spid="$id"/>'),
        );
        expect(vml, contains('o:spid="$id"'));
        expect(vml, contains('<x:FmlaPict>\$K\$7</x:FmlaPict>'));
        expect(vml, contains('<x:Camera>'));
        // L'image de repli des deux morceaux est le logo.
        expect(
          texte(parts, 'xl/drawings/_rels/ficheBoutons$n.vml.rels'),
          contains('../media/logoClient.jpeg'),
        );
      }
    });

    test('sans logo : aucune image liee', () {
      final parts = construire([point()]);
      expect(
        texte(parts, 'xl/drawings/fiche1.xml'),
        isNot(contains('cameraTool')),
      );
      expect(
        texte(parts, 'xl/drawings/ficheBoutons1.vml'),
        isNot(contains('Camera')),
      );
      expect(
        parts.keys,
        isNot(contains('xl/drawings/_rels/ficheBoutons1.vml.rels')),
      );
    });

    test('sans logo : son nom, par la formule du modele', () {
      final parts = construire([point()]);
      final feuille = texte(parts, 'xl/worksheets/fiche1.xml');

      expect(valeur(feuille, 'K7'), 'Client Exemple SA');
      expect(cellule(feuille, 'D7').$2, contains('<f>K7</f>'));
      expect(cellule(feuille, 'D7').$2, contains('<v>Client Exemple SA</v>'));
    });
  });

  group('une feuille par traversee', () {
    test('nommee d\'apres le numero du point, dans l\'ordre fourni', () {
      final parts = construire([
        for (final n in ['3', '12', '40']) point(numero: n),
      ]);
      expect(nomsDeFeuille(parts), ['3', '12', '40', 'Menus déroulants']);
    });

    test('deux points de meme numero donnent deux feuilles distinctes', () {
      // L'application signale le doublon sans l'interdire. Excel, lui,
      // refuse deux feuilles de même nom — le classeur ne s'ouvrirait pas.
      final parts = construire([
        point(numero: '12'),
        point(numero: '12'),
        point(numero: null),
        point(numero: '  '),
      ]);
      expect(
        nomsDeFeuille(parts),
        ['12', '12 (2)', 'Sans numéro', 'Sans numéro (2)', 'Menus déroulants'],
      );
    });

    test('sans numero, la fiche ne s\'invente pas un « 0 »', () {
      // `=M5` sur une cellule vide vaut zéro : un numéro que personne n'a
      // donné, sur une fiche de conformité.
      final feuille = texte(
        construire([point(numero: null)]),
        'xl/worksheets/fiche1.xml',
      );
      expect(cellule(feuille, 'M5').$2, isEmpty);
      expect(cellule(feuille, 'E15').$2, isEmpty);
    });

    test('un numero qu\'Excel refuserait comme nom est assaini', () {
      final parts = construire([
        point(numero: 'A/12:[b]*?'),
        point(numero: 'x' * 40),
        point(numero: 'Menus déroulants'),
      ]);
      final noms = nomsDeFeuille(parts);

      expect(noms[0], 'A-12--b---');
      expect(noms[1], hasLength(31));
      expect(noms[2], 'Menus déroulants (2)');
      // La fiche, elle, garde le numéro tel que saisi.
      expect(
        valeur(texte(parts, 'xl/worksheets/fiche1.xml'), 'E15'),
        'A/12:[b]*?',
      );
    });

    test('chacune a sa zone d\'impression', () {
      final parts = construire([point(), point(numero: "l'aile")]);
      final classeur = texte(parts, 'xl/workbook.xml');

      expect(classeur, contains(r'''localSheetId="0">'12'!$B$2:$I$32'''));
      // L'apostrophe d'un nom de feuille se double dans une référence.
      expect(classeur, contains(r'''localSheetId="1">'l''aile'!$B$2:$I$32'''));
    });

    test('aucun identifiant de forme n\'est partage entre deux feuilles', () {
      // Deux feuilles aux mêmes identifiants font « réparer » le classeur à
      // l'ouverture, et les boutons y passent.
      final parts =
          construire([for (var i = 1; i <= 4; i++) point(numero: '$i')]);
      final vus = <String>{};
      for (var n = 1; n <= 4; n++) {
        final ids = RegExp(r'id="(_x0000_s\d+)"')
            .allMatches(texte(parts, 'xl/drawings/ficheBoutons$n.vml'))
            .map((m) => m[1]!)
            .toList();
        expect(ids, hasLength(3));
        for (final id in ids) {
          expect(vus.add(id), isTrue, reason: '$id en double');
          expect(
            texte(parts, 'xl/worksheets/fiche$n.xml'),
            contains('shapeId="${id.substring(8)}"'),
          );
        }
      }
    });

    test('chaque feuille a son propre numero de plage de formes', () {
      // Le pendant du test précédent, côté ancien format : deux fichiers VML
      // de même numéro, et Excel « répare ». La balise s'écrit de deux façons
      // selon l'Excel qui a enregistré le modèle en dernier.
      final parts =
          construire([for (var i = 1; i <= 3; i++) point(numero: '$i')]);
      for (var n = 1; n <= 3; n++) {
        for (final fichier in ['ficheBoutons$n.vml', 'ficheEntete$n.vml']) {
          expect(
            RegExp(r'<o:idmap v:ext="edit" data="(\d+)"')
                .firstMatch(texte(parts, 'xl/drawings/$fichier'))?[1],
            '$n',
            reason: fichier,
          );
        }
      }
    });

    test('les modules VBA de feuille retrouvent une feuille', () {
      final parts =
          construire([for (var i = 1; i <= 3; i++) point(numero: '$i')]);
      expect(texte(parts, 'xl/worksheets/fiche1.xml'),
          contains('codeName="Feuil1"'));
      expect(texte(parts, 'xl/worksheets/fiche2.xml'),
          contains('codeName="Feuil36"'));
      expect(texte(parts, 'xl/worksheets/fiche3.xml'),
          isNot(contains('codeName=')));
    });
  });

  group('le classeur reste coherent', () {
    final parts = construire(
      [
        point(photos: [ReportPhoto(bytes: jpeg), ReportPhoto(bytes: png)]),
        point(numero: '13', photos: [ReportPhoto(bytes: png)]),
        point(numero: '14'),
      ],
      logo: png,
      // Tout ce qu'un nom de chantier peut contenir de gênant pour du XML,
      // caractère de contrôle compris.
      nomProjet: 'Hall <A> & "B" \u0007 d\'essai',
    );

    test('chaque partie XML est bien formee', () {
      for (final entree in parts.entries) {
        if (!RegExp(r'\.(xml|rels|vml)$').hasMatch(entree.key)) continue;
        expect(
          () => XmlDocument.parse(utf8.decode(entree.value)),
          returnsNormally,
          reason: entree.key,
        );
      }
    });

    test('le texte saisi est rendu tel quel, echappe', () {
      final feuille = XmlDocument.parse(
        texte(parts, 'xl/worksheets/fiche1.xml'),
      );
      final e11 = feuille.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.getAttribute('r') == 'E11');
      expect(e11.innerText, 'Hall <A> & "B"  d\'essai');
    });

    test('chaque lien designe une partie presente', () {
      for (final entree in parts.entries) {
        if (!entree.key.endsWith('.rels')) continue;
        // `a/_rels/b.xml.rels` décrit les liens de `a/b.xml`.
        final dossier = entree.key.replaceFirst(RegExp(r'_rels/[^/]*$'), '');
        for (final rel in XmlDocument.parse(utf8.decode(entree.value))
            .rootElement
            .childElements) {
          if (rel.getAttribute('TargetMode') == 'External') continue;
          final cible = Uri.parse(dossier).resolve(rel.getAttribute('Target')!);
          expect(
            parts.keys,
            contains(cible.path),
            reason: '${entree.key} → ${rel.getAttribute('Target')}',
          );
        }
      }
    });

    test('chaque partie a un type declare', () {
      final types = XmlDocument.parse(texte(parts, '[Content_Types].xml'));
      final extensions = {
        for (final e in types.findAllElements('Default'))
          e.getAttribute('Extension')!.toLowerCase(),
      };
      final declarees = {
        for (final e in types.findAllElements('Override'))
          e.getAttribute('PartName')!.substring(1),
      };

      for (final nom in parts.keys) {
        if (nom == '[Content_Types].xml') continue;
        expect(
          declarees.contains(nom) ||
              extensions.contains(nom.split('.').last.toLowerCase()),
          isTrue,
          reason: nom,
        );
      }
      // Et rien n'est déclaré qui n'existe pas.
      expect(declarees.difference(parts.keys.toSet()), isEmpty);
    });
  });

  group('refus', () {
    test('sans traversee, pas de classeur', () {
      expect(() => construire([]), throwsArgumentError);
    });

    test('un autre classeur que le modele est refuse en clair', () {
      // Un classeur quelconque — ici le modèle amputé de sa première feuille.
      final archive = Archive();
      for (final entree in partsModele.entries) {
        if (entree.key == 'xl/worksheets/sheet1.xml') continue;
        archive.add(ArchiveFile.bytes(entree.key, entree.value));
      }

      expect(
        () => const AsBuiltWorkbook().build(
          modele: ZipEncoder().encodeBytes(archive),
          data: ReportData(
            client: const ReportClient(name: 'C', address: 'A'),
            project: const ReportProject(name: 'P'),
            points: [point()],
          ),
        ),
        throwsA(isA<ModeleInattendu>()),
      );
    });
  });
}
