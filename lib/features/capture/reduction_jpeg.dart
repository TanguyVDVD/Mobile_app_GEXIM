import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;


/// Réduction d'un JPEG : redimensionnement puis réencodage.
///
/// Sur **tablette**, par le codec natif (`flutter_image_compress`), depuis un
/// fichier : c'est le chemin de la capture, et celui de l'export des fiches.
///
/// Une interface et non une fonction, pour que les tests remplacent le
/// greffon — qui n'existe pas dans la machine virtuelle où ils tournent.
abstract interface class ReductionJpeg {
  /// Rend le JPEG réduit, ou `null` si la source est illisible.
  ///
  /// [coteMin] est un **minimum par axe**, pas une boîte englobante : l'image
  /// est réduite jusqu'à ce que le plus contraignant des deux axes atteigne la
  /// cible, et jamais agrandie.
  Future<Uint8List?> reduire(
    File source, {
    required int coteMin,
    required int qualite,
    bool garderExif = false,
  });
}

/// Le codec de la plateforme.
class ReductionNative implements ReductionJpeg {
  const ReductionNative();

  @override
  Future<Uint8List?> reduire(
    File source, {
    required int coteMin,
    required int qualite,
    bool garderExif = false,
  }) {
    return FlutterImageCompress.compressWithFile(
      source.absolute.path,
      minWidth: coteMin,
      minHeight: coteMin,
      quality: qualite,
      keepExif: garderExif,
    );
  }
}

/// Même réduction, en **Dart pur** et depuis des octets : celle du
/// navigateur, qui n'a ni fichiers ni codec natif.
///
/// Elle sert à l'export des fiches, où chaque cliché arrive du serveur. Elle
/// reproduit la sémantique exacte de [ReductionNative] — minimum par axe,
/// orientation redressée — sans quoi le même chantier donnerait deux
/// classeurs différents selon qu'on l'exporte d'une tablette ou d'un
/// navigateur. `test/reduction_jpeg_test.dart` verrouille ces équivalences.
///
/// Par `compute` : un JPEG 12 Mpx occupe ~48 Mo décompressé. Dans un
/// navigateur il n'y a pas d'isolat et le calcul reste sur le fil de
/// l'interface ; l'écran d'export annonce sa progression cliché par cliché.
Future<Uint8List?> reduireOctets(
  Uint8List octets, {
  required int coteMin,
  required int qualite,
  bool garderExif = false,
}) {
  return compute(
    _reduireHorsInterface,
    (
      octets: octets,
      coteMin: coteMin,
      qualite: qualite,
      garderExif: garderExif,
    ),
  );
}

typedef _Demande = ({
  Uint8List octets,
  int coteMin,
  int qualite,
  bool garderExif,
});

/// Exécuté dans un isolat : ne doit toucher à rien d'autre qu'à ses arguments.
Uint8List? _reduireHorsInterface(_Demande demande) {
  // `decodeJpg` **lève** un `ImageException` sur un fichier tronqué au lieu de
  // rendre `null` — contrairement à ce que sa signature nullable laisse croire.
  // Sans ce filet, un cliché à moitié écrit par un crash ferait échouer la
  // compression au lieu d'être simplement signalé absent du rapport.
  final img.Image? source;
  try {
    source = img.decodeJpg(demande.octets);
  } on Object {
    return null;
  }
  if (source == null) return null;

  // L'EXIF porte l'orientation du capteur. `package:image` ne l'applique pas au
  // décodage, contrairement au greffon natif : sans cette normalisation, les
  // clichés pris en portrait sortiraient couchés dans le classeur exporté d'un
  // navigateur, et droits dans celui exporté d'une tablette — Excel n'applique
  // pas l'EXIF non plus. Le même chantier donnerait deux documents différents.
  final droite = img.bakeOrientation(source);

  // Minimum par axe : on ne réduit que jusqu'à ce que le plus contraignant des
  // deux axes atteigne la cible, et jamais d'agrandissement.
  final facteur = <double>[
    demande.coteMin / droite.width,
    demande.coteMin / droite.height,
  ].reduce((a, b) => a > b ? a : b);

  final aReduire = facteur < 1;
  final image = aReduire
      ? img.copyResize(
          droite,
          width: (droite.width * facteur).round(),
          height: (droite.height * facteur).round(),
          interpolation: img.Interpolation.average,
        )
      : droite;

  // `bakeOrientation` a deja remis l'orientation a neutre ; il ne reste ici
  // qu'a decider du sort du reste des metadonnees.
  if (!demande.garderExif) image.exif = img.ExifData();

  return img.encodeJpg(image, quality: demande.qualite);
}
