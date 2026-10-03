import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/ids.dart';
import 'photo_storage.dart';
import 'reduction_jpeg.dart';

/// Résultat d'une compression, prêt à être enregistré par `PointDao`.
typedef CompressedPhoto = ({
  String path,
  int bytes,
  int width,
  int height,
  String sha256,
});

/// Réduction d'un cliché brut avant tout stockage.
///
/// Interface distincte de l'implémentation : la compression réelle passe par un
/// plugin natif, indisponible dans un test unitaire. `PhotoCaptureService` peut
/// ainsi être exercé avec un double.
abstract interface class PhotoProcessor {
  Future<CompressedPhoto> compress(File source);
}

/// **Principal levier de coût du projet.**
///
/// Un JPEG 12 MP sorti du capteur pèse 3 à 5 Mo ; réduit ici, il tombe autour
/// de 400 Ko — sans perte utile, une fiche imprimée à 150 DPI ne restituant pas
/// davantage. Sur un chantier de 2 000 points à trois photos, cela fait 24 Go
/// contre 2,4 Go : le facteur dix qui rend la facture de stockage négligeable,
/// quel que soit le fournisseur.
///
/// La compression est faite **avant** l'écriture en base : rien de non
/// compressé n'atteint jamais le disque durablement ni le réseau.
class ImageCompressor implements PhotoProcessor {
  ImageCompressor([
    this._storage = const PhotoStorage(),
    ReductionJpeg? reduction,
  ]) : _reduction = reduction ?? ReductionJpeg.pourLaPlateforme();

  final PhotoStorage _storage;

  /// Passe par l'abstraction plutot que d'appeler le greffon : celui-ci n'a pas
  /// d'implementation Windows. La capture y est certes masquee — pas de
  /// `camera` non plus — mais brancher un jour l'import d'un cliche depuis le
  /// disque ne doit pas retomber dans le meme piege silencieux.
  final ReductionJpeg _reduction;

  /// Borne inférieure appliquée à chaque axe.
  ///
  /// Attention à la sémantique de `flutter_image_compress` : ce sont des
  /// **minimums par axe**, pas une boîte englobante. Un 4000×3000 devient donc
  /// ~2667×2000 et non 2000×1500. On l'accepte volontairement plutôt que de
  /// décoder l'image en amont pour calculer la cible exacte : ce décodage
  /// coûterait ~24 Mo de mémoire par cliché sur des tablettes de chantier
  /// souvent modestes, pour quelques dizaines de kilo-octets gagnés.
  static const int minEdge = 2000;

  /// 80 est le point d'inflexion du JPEG : au-delà le poids grimpe vite sans
  /// gain visible, en deçà les artefacts deviennent perceptibles sur les
  /// textures fines — joint, mousse, laine de roche.
  static const int quality = 80;

  @override
  Future<CompressedPhoto> compress(File source) async {
    final dir = await _storage.directory();
    final target = p.join(dir.path, '${newId()}.jpg');

    final bytes = await _reduction.reduire(
      source,
      coteMin: minEdge,
      qualite: quality,
      // L'EXIF porte l'orientation du capteur et l'horodatage. Le perdre ferait
      // pivoter des photos dans le rapport final.
      garderExif: true,
    );

    if (bytes == null) {
      throw const FileSystemException('Échec de la compression du cliché.');
    }

    final result = await File(target).writeAsBytes(bytes, flush: true);
    final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
    final width = descriptor.width;
    final height = descriptor.height;
    descriptor.dispose();

    return (
      path: result.path,
      bytes: bytes.length,
      width: width,
      height: height,
      sha256: sha256.convert(bytes).toString(),
    );
  }
}
