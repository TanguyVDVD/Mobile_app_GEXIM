import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../../core/plateforme.dart';

/// Réduction d'un JPEG : redimensionnement puis réencodage.
///
/// Deux implémentations, parce que `flutter_image_compress` **n'existe pas sur
/// Windows** (android, ios, macos, web uniquement). Or la réduction ne sert pas
/// qu'à la capture : l'export y passe pour chaque cliché embarqué dans le
/// classeur Excel, et exporter est justement ce que l'administrateur vient
/// faire depuis son PC.
///
/// Sans ce repli, l'appel remonterait un `MissingPluginException` attrapé par
/// le `try` de `ReportService._photoBytes`, qui rend `null` sur erreur. Le
/// document serait produit sans la moindre alerte : complet, paginé, et **vide
/// de toute photo**. C'est la panne silencieuse type de ce dépôt — celle qu'on
/// ne découvre qu'en ouvrant le rapport livré au client.
abstract interface class ReductionJpeg {
  /// Réduit [source] et rend les octets du JPEG produit.
  ///
  /// [coteMin] est un **minimum par axe**, pas une boîte englobante : un
  /// 4000×3000 réduit à 2000 donne ~2667×2000. C'est la sémantique de
  /// `flutter_image_compress`, reprise à l'identique par le repli pour que les
  /// deux plateformes produisent le même document.
  ///
  /// [garderExif] conserve les métadonnées du capteur — horodatage, appareil.
  /// L'orientation, elle, est **toujours** appliquée aux pixels puis remise à
  /// neutre : c'est la seule façon d'obtenir le même rendu des deux côtés.
  ///
  /// Rend `null` si l'image est illisible.
  Future<Uint8List?> reduire(
    File source, {
    required int coteMin,
    required int qualite,
    bool garderExif = false,
  });

  /// L'implémentation qui convient à la plateforme courante.
  factory ReductionJpeg.pourLaPlateforme() => Plateforme
          .compressionNativeDisponible
      ? const ReductionNative()
      : const ReductionDart();
}

/// Repli natif : le codec du système, rapide et économe en mémoire.
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

/// Repli Dart pur, pour Windows et Linux.
///
/// Plus lent que le codec système, et c'est assumé : il tourne sur un PC de
/// bureau, pas sur une tablette de 2018. Le décodage a lieu dans un **isolat**
/// (`compute`) — un JPEG 12 Mpx décompressé occupe ~48 Mo et son traitement
/// bloquerait l'interface plusieurs centaines de millisecondes par cliché, soit
/// une fenêtre figée pendant toute la génération d'un rapport de 200 photos.
class ReductionDart implements ReductionJpeg {
  const ReductionDart();

  @override
  Future<Uint8List?> reduire(
    File source, {
    required int coteMin,
    required int qualite,
    bool garderExif = false,
  }) async {
    final octets = await source.readAsBytes();
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
  // clichés pris en portrait sortiraient couchés dans le classeur produit sur
  // PC, et droits dans celui produit sur tablette — Excel n'applique pas
  // l'EXIF non plus. Le même chantier donnerait deux documents différents.
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
