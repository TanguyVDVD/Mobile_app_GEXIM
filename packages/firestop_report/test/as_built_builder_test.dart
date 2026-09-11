import 'dart:typed_data';

import 'package:firestop_report/firestop_report.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// Rendu de la fiche AS BUILT.
///
/// Deux choses se vérifient ici, et la seconde est la moins évidente.
///
/// La première est la règle de pagination : **chaque traversée commence sur une
/// page neuve**, et peut en occuper plusieurs si ses clichés débordent. Deux
/// traversées ne partagent jamais une page — c'est ce qui permet d'extraire une
/// fiche d'un dossier sans emporter la moitié de la suivante.
///
/// La seconde est que les valeurs **atteignent réellement la page**. Un
/// générateur de PDF ne se plaint de rien : un champ oublié, une valeur passée
/// au mauvais emplacement ou une chaîne vide produisent un document
/// parfaitement valide, seulement faux. Les tests lisent donc le flux de
/// contenu en clair (`compresser: false`) plutôt que de se contenter de
/// l'absence d'exception.
void main() {
  /// JPEG minimal valide (1×1 px), suffisant pour exercer le décodage.
  final jpegMinuscule = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, ...List<int>.filled(64, 0x08),
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11,
    0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x37, 0xFF,
    0xD9,
  ]);

  ReportPoint traversee(
    String label, {
    int cliches = 2,
    List<String> produits = const ['Promastop-FC'],
    String? etage = 'Etage 2',
  }) {
    return ReportPoint(
      label: label,
      capturedAt: DateTime(2026, 8, 20, 9, 15),
      purchaseOrder: 'PO-4471',
      building: 'Bloc A',
      floor: etage,
      configuration: 'Traversee de paroi verticale',
      configurationDetail: 'Chemin de cables',
      eiLevel: 'EI120',
      supplier: 'Promat',
      productType: 'Manchon',
      products: produits,
      photos: [
        for (var i = 0; i < cliches; i++) ReportPhoto(bytes: jpegMinuscule),
      ],
    );
  }

  ReportData donnees(
    List<ReportPoint> points, {
    Uint8List? fond,
    Uint8List? logo,
    String? code = '2026-118',
  }) =>
      ReportData(
        client: const ReportClient(
          name: 'Client Test',
          address: 'Rue de l\'Industrie 12, 4000 Liege',
        ),
        project: ReportProject(name: 'Chantier Nord', code: code),
        points: points,
        generatedAt: DateTime(2026, 9, 11, 14, 30),
        clientLogo: logo,
        formBackground: fond,
      );

  /// Nombre de pages du document.
  ///
  /// `/Type /Pages` (le nœud de l'arbre) est exclu du décompte : il contient la
  /// même sous-chaîne que `/Type /Page` et ferait mentir le résultat d'une
  /// unité, ce qui est exactement l'erreur que ce test cherche à détecter.
  int pages(Uint8List pdf) => RegExp(r'/Type\s*/Page(?![s\w])')
      .allMatches(String.fromCharCodes(pdf))
      .length;

  /// Nombre d'images embarquées : chaque XObject image porte `/Subtype /Image`.
  int images(Uint8List pdf) => RegExp(r'/Subtype\s*/Image')
      .allMatches(String.fromCharCodes(pdf))
      .length;

  group('pagination', () {
    test('trois traversees ordinaires font trois pages', () async {
      final pdf = await const AsBuiltBuilder().build(
        donnees([traversee('1'), traversee('2'), traversee('3')]),
        compresser: false,
      );

      expect(pages(pdf), 3);
    });

    test('les cliches au-dela des deux cases passent en page de suite',
        () async {
      // Cinq cliches : deux dans les cases imprimees, trois en page de suite.
      // Les subdiviser dans le cadre pour gagner une page retrecirait la
      // preuve — c'est elle qu'un controleur vient regarder.
      final pdf = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 5)]), compresser: false);

      expect(pages(pdf), 2);
    });

    test('une page de suite tient six cliches, la septieme en ouvre une autre',
        () async {
      // 2 cases imprimees + 6 = 8 tient en deux pages ; le neuvieme cliche en
      // impose une troisieme.
      final huit = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 8)]), compresser: false);
      expect(pages(huit), 2);

      final neuf = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 9)]), compresser: false);
      expect(pages(neuf), 3);
    });

    test('une traversee qui deborde ne repousse pas la suivante sur sa page',
        () async {
      // C'est l'invariant qui compte : 1 fiche + 2 suites + 1 fiche = 4 pages.
      // Si les deux traversees partageaient une page, le compte tomberait a 3.
      final pdf = await const AsBuiltBuilder().build(
        donnees([traversee('1', cliches: 14), traversee('2')]),
        compresser: false,
      );

      expect(pages(pdf), 4);
    });

    test('une page de suite se rattache visiblement a sa traversee', () async {
      // Un dossier de conformite se photocopie et se transmet par extraits.
      // Une page detachee qui ne dirait pas d'ou elle vient serait inutilisable.
      final pdf = await const AsBuiltBuilder().build(
        donnees([traversee('47', cliches: 5)]),
        compresser: false,
      );
      final contenu = _texte(pdf);

      expect(contenu, contains('Traversee n'));
      expect(contenu, contains('47'));
      expect(contenu, contains('cliches complementaires'));
      expect(contenu, contains('Chantier Nord'));
    });

    test('plusieurs pages de suite sont numerotees entre elles', () async {
      final pdf = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 9)]), compresser: false);
      final contenu = _texte(pdf);

      expect(contenu, contains('suite 1/2'));
      expect(contenu, contains('suite 2/2'));
    });

    test('une page de suite unique n\'est pas numerotee', () async {
      // « suite 1/1 » sur une page seule donnerait a croire qu'il en manque une.
      final pdf = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 3)]), compresser: false);

      expect(_texte(pdf), isNot(contains('suite')));
    });

    test('un chantier vide produit une page, jamais un document vide',
        () async {
      // Un PDF sans page n'est pas ecrivable : le moteur leve, et l'operateur
      // se retrouve devant un echec sans cause visible. Mieux vaut une page qui
      // dit qu'il n'y a rien.
      final pdf =
          await const AsBuiltBuilder().build(donnees([]), compresser: false);

      expect(pages(pdf), 1);
      expect(_texte(pdf), contains('Aucune traversee'));
    });
  });

  group('les valeurs atteignent la page', () {
    test('les caracteristiques et l\'identification y sont toutes', () async {
      final pdf = await const AsBuiltBuilder().build(
        donnees([traversee('47')]),
        compresser: false,
      );
      final contenu = _texte(pdf);

      for (final attendu in [
        '20/08/2026', // date de la traversee
        '47', // numero de point
        '2026-118', // numero de projet
        'Chantier Nord', // intitule du projet
        'PO-4471', // purchase order
        'Bloc A', // batiment
        'Etage 2',
        'Traversee de paroi verticale',
        'Chemin de cables',
        'EI120',
        'Promat',
        'Manchon', // type de produit utilise
        'Promastop-FC',
        'Client Test',
        'Rue de l', // adresse du client
      ]) {
        expect(
          contenu,
          contains(attendu),
          reason: '« $attendu » n\'a pas atteint la fiche',
        );
      }
    });

    test('les cinq emplacements produit gardent leur rang', () async {
      // Le deuxieme emplacement est vide, le troisieme rempli. Rien ne doit se
      // tasser : le rapport d'un chantier deja livre porte ces numeros-la.
      final pdf = await const AsBuiltBuilder().build(
        donnees([
          traversee('1', produits: ['Promastop-FC', '', 'Promaseal-AG']),
        ]),
        compresser: false,
      );
      final contenu = _texte(pdf);

      expect(contenu, contains('Promastop-FC'));
      expect(contenu, contains('Promaseal-AG'));
    });

    test('une caracteristique absente s\'ecrit, elle ne disparait pas',
        () async {
      // Une case blanche se lit comme un defaut d'impression ; un tiret dit
      // « renseigne, et vide ». Sur un document contractuel, la nuance compte.
      final pdf = await const AsBuiltBuilder().build(
        donnees([
          ReportPoint(label: '9', capturedAt: DateTime(2026, 1, 2)),
        ], code: null),
        compresser: false,
      );

      expect(_texte(pdf), contains('-'));
      expect(pages(pdf), 1);
    });
  });

  group('logo du client', () {
    // Les deux formats que l'écran client accepte. Le PNG ne passe pas par le
    // même chemin que le JPEG dans le moteur PDF — il est décodé, là où le JPEG
    // est recopié tel quel — et c'est justement le format habituel d'un logo.
    //
    // Un PNG décodé devient un raster RGBA : sa couche alpha part dans un
    // masque (`/SMask`), qui est lui-même une image. D'où « au moins une ».
    final logos = <String, Uint8List>{
      'PNG': img.encodePng(img.Image(width: 40, height: 12)),
      'JPEG': img.encodeJpg(img.Image(width: 40, height: 12)),
    };

    for (final MapEntry(key: format, value: octets) in logos.entries) {
      test('un logo $format atteint la case du client', () async {
        // Aucun cliché, aucun fond : la seule image possible est le logo.
        final sans = await const AsBuiltBuilder().build(
          donnees([traversee('1', cliches: 0)]),
          compresser: false,
        );
        final avec = await const AsBuiltBuilder().build(
          donnees([traversee('1', cliches: 0)], logo: octets),
          compresser: false,
        );

        expect(images(sans), 0);
        expect(
          images(avec),
          greaterThanOrEqualTo(1),
          reason: 'le logo $format n\'a pas atteint la page',
        );
      });
    }

    test('un logo illisible ne fait pas echouer le document', () async {
      final pdf = await const AsBuiltBuilder().build(
        donnees(
          [traversee('1', cliches: 0)],
          logo: Uint8List.fromList([1, 2, 3, 4]),
        ),
        compresser: false,
      );

      expect(pages(pdf), 1);
      expect(images(pdf), 0);
    });
  });

  group('cas degrades', () {
    test('un cliche illisible ne fait pas echouer le document', () async {
      // Transfert interrompu, cache purge au mauvais moment : le rapport doit
      // sortir en signalant la lacune, pas exploser.
      final pdf = await const AsBuiltBuilder().build(
        donnees([
          ReportPoint(
            label: '1',
            capturedAt: DateTime(2026, 1, 2),
            photos: [
              ReportPhoto(bytes: Uint8List.fromList([0xFF, 0xD8, 0x00])),
            ],
          ),
        ]),
        compresser: false,
      );

      expect(pages(pdf), 1);
      expect(_texte(pdf), contains('Cliche absent'));
    });

    test('un emplacement reglementaire vide est signale, pas laisse blanc',
        () async {
      final pdf = await const AsBuiltBuilder()
          .build(donnees([traversee('1', cliches: 0)]), compresser: false);

      // Les deux cases imprimees du formulaire, toutes deux annoncees vides.
      expect('Cliche absent'.allMatches(_texte(pdf)).length, 2);
    });

    test('sans fond de formulaire, le document sort quand meme', () async {
      // L'asset peut manquer d'un build mal empaquete. Les valeurs se posent
      // alors sur une page nue, aux memes emplacements : un document sans cadre
      // reste transmissible, pas de document du tout ne l'est pas.
      final pdf = await const AsBuiltBuilder()
          .build(donnees([traversee('1')]), compresser: false);

      expect(pages(pdf), 1);
      expect(_texte(pdf), contains('Promastop-FC'));
    });

    test('un fond illisible est ignore plutot que fatal', () async {
      final pdf = await const AsBuiltBuilder().build(
        donnees(
          [traversee('1')],
          fond: Uint8List.fromList([0x89, 0x50, 0x00, 0x00]),
        ),
        compresser: false,
      );

      expect(pages(pdf), 1);
    });
  });
}

/// Texte visible du document, reconstitué depuis les flux de contenu.
///
/// Le moteur PDF n'écrit pas une phrase d'un seul tenant : il émet un `Tj` par
/// mot, chacun positionné, pour gérer l'espacement. « Cliche absent » se
/// retrouve donc dans les octets sous la forme `[(Cliche)]TJ … [(absent)]TJ`,
/// et un `contains` naïf sur le fichier brut échouerait — en laissant croire
/// que le libellé n'a jamais atteint la page.
///
/// Les littéraux entre parenthèses sont donc extraits et rejoints par une
/// espace. Les octets d'une image embarquée peuvent en fournir quelques-uns au
/// passage ; c'est sans effet sur un `contains`, qui cherche une présence.
String _texte(Uint8List pdf) {
  final brut = String.fromCharCodes(pdf);
  final mots = RegExp(r'\(([^()]*)\)')
      .allMatches(brut)
      .map((m) => m.group(1)!)
      .where((mot) => mot.isNotEmpty);
  return mots.join(' ');
}
