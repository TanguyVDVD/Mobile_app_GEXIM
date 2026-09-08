import 'dart:io';
import 'dart:typed_data';

import 'package:firestop_tracker/features/capture/reduction_jpeg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Le repli Dart pur sert **Windows**, où `flutter_image_compress` n'existe
/// pas. Et il ne sert pas qu'à la capture : la génération du rapport y passe
/// pour chaque cliché du PDF, ce qui est précisément ce que l'administrateur
/// vient faire depuis son PC.
///
/// Une erreur ici ne lève rien : `ReportService._photoBytes` attrape tout et
/// rend `null`, donc le rapport sortirait complet, paginé — et sans photos. Ces
/// tests existent pour que ce silence ne puisse pas s'installer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  const reduction = ReductionDart();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('firestop_reduction_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Écrit un JPEG de synthèse. Un dégradé plutôt qu'un aplat : un aplat se
  /// compresse si bien que le poids ne dirait plus rien.
  File jpeg(int largeur, int hauteur, {int? orientation}) {
    final image = img.Image(width: largeur, height: hauteur);
    for (var y = 0; y < hauteur; y++) {
      for (var x = 0; x < largeur; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    if (orientation != null) image.exif.imageIfd.orientation = orientation;

    final file = File('${tmp.path}/source_${largeur}x$hauteur.jpg')
      ..writeAsBytesSync(img.encodeJpg(image, quality: 95));
    return file;
  }

  ({int largeur, int hauteur}) tailleDe(Uint8List octets) {
    final decodee = img.decodeJpg(octets)!;
    return (largeur: decodee.width, hauteur: decodee.height);
  }

  test(
    'coteMin est un minimum par axe, pas une boite englobante',
    () async {
      // La sémantique de `flutter_image_compress`, que le repli doit reproduire
      // à l'identique : sinon le même chantier donnerait deux PDF différents
      // selon la machine qui l'a produit.
      final octets = await reduction.reduire(
        jpeg(4000, 3000),
        coteMin: 2000,
        qualite: 80,
      );

      final taille = tailleDe(octets!);
      expect(taille.hauteur, 2000);
      expect(
        taille.largeur,
        closeTo(2667, 2),
        reason: 'un 4000x3000 ramene a 2000 donne ~2667x2000, pas 2000x1500',
      );
    },
  );

  test('une image deja petite n\'est jamais agrandie', () async {
    final octets = await reduction.reduire(
      jpeg(300, 400),
      coteMin: 1000,
      qualite: 80,
    );

    final taille = tailleDe(octets!);
    expect(
      (taille.largeur, taille.hauteur),
      (300, 400),
      reason: 'agrandir n\'ajoute aucun detail et alourdit le PDF',
    );
  });

  test('la reduction allege reellement le fichier', () async {
    final source = jpeg(3000, 2000);
    final octets = await reduction.reduire(
      source,
      coteMin: 1000,
      qualite: 75,
    );

    expect(octets!.length, lessThan(source.lengthSync()));
  });

  test('l\'orientation EXIF est appliquee aux pixels', () async {
    // 6 = rotation d'un quart de tour. Le greffon natif l'applique au decodage,
    // `package:image` non : sans normalisation, les cliches pris en portrait
    // sortiraient couches dans le PDF produit sur PC, et droits dans celui
    // produit sur tablette.
    final octets = await reduction.reduire(
      jpeg(400, 200, orientation: 6),
      coteMin: 4000, // au-dessus de la source : aucune mise a l'echelle
      qualite: 90,
    );

    final taille = tailleDe(octets!);
    expect(
      (taille.largeur, taille.hauteur),
      (200, 400),
      reason: 'les axes doivent avoir ete echanges par la rotation',
    );
  });

  test('un fichier illisible rend null plutot que de lever', () async {
    final corrompu = File('${tmp.path}/corrompu.jpg')
      ..writeAsBytesSync(List<int>.filled(500, 0x7F));

    expect(
      await reduction.reduire(corrompu, coteMin: 1000, qualite: 80),
      isNull,
      reason: 'un cliche illisible ne doit pas empecher la sortie du document',
    );
  });

  test('garderExif conserve les metadonnees, sinon elles partent', () async {
    final source = jpeg(600, 400);

    final avec = await reduction.reduire(
      source,
      coteMin: 4000,
      qualite: 90,
      garderExif: true,
    );
    final sans = await reduction.reduire(
      source,
      coteMin: 4000,
      qualite: 90,
    );

    expect(img.decodeJpg(sans!)!.exif.isEmpty, isTrue);
    // `garderExif` ne peut rien inventer : on verifie seulement qu'il ne vide
    // pas volontairement le bloc, contrairement a son absence.
    expect(avec, isNotNull);
  });
}
