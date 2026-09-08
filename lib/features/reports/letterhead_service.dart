import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../sync/remote_gateway.dart';

/// Papier à en-tête : envoi, récupération, et conversion en fond de page.
///
/// Le moteur de rendu vit dans un package Dart pur : il ne sait pas lire un
/// PDF. C'est ici, côté application, que le document type est **rasterisé** —
/// `Printing.raster` s'appuie sur le moteur PDF du système.
///
/// Le compromis est assumé : le texte de l'en-tête n'est plus sélectionnable
/// dans le rapport final, et sa netteté dépend de la définition choisie. En
/// échange, le package reste utilisable dans un conteneur, et n'importe quel
/// PDF fourni par un client fonctionne — y compris ceux aux polices exotiques
/// qu'un analyseur maison rendrait de travers.
class LetterheadService {
  const LetterheadService(this._gateway);

  final RemoteGateway _gateway;

  /// 150 points par pouce : la définition d'impression courante.
  ///
  /// Au-delà, chaque page du rapport embarquerait une image de plusieurs
  /// mégaoctets — un chantier de cent traversées produirait un fichier
  /// impossible à envoyer par courriel.
  static const double _dpi = 150;

  /// Convertit un document type en image de fond.
  ///
  /// Rend `null` si la conversion échoue : un rapport sans papier à en-tête
  /// vaut mieux qu'aucun rapport.
  Future<Uint8List?> rasterise(Uint8List? document, {int page = 0}) async {
    if (document == null || document.isEmpty) return null;

    // Une image fournie directement n'a rien à convertir.
    if (_estUneImage(document)) return document;

    try {
      await for (final raster in Printing.raster(
        document,
        pages: [page],
        dpi: _dpi,
      )) {
        return await raster.toPng();
      }
    } on Object {
      // PDF chiffré, corrompu, ou moteur système indisponible.
      return null;
    }
    return null;
  }

  /// Dépose un fichier d'habillage : papier à en-tête, ou logo client.
  ///
  /// Le bucket est un paramètre parce que les deux suivent exactement le même
  /// chemin — choix d'un fichier, envoi, chemin distant enregistré — et que
  /// dupliquer la méthode pour changer une constante n'apporterait rien.
  Future<void> upload({
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
    String bucket = 'letterheads',
  }) {
    return _gateway.uploadLetterhead(
      remotePath: remotePath,
      bytes: bytes,
      contentType: contentType,
      bucket: bucket,
    );
  }

  /// Délai de garde du rapatriement.
  ///
  /// Le client Supabase n'en impose aucun. Sur un réseau qui accepte la
  /// connexion sans jamais répondre — portail captif, VPN à moitié monté — le
  /// téléchargement du papier à en-tête suspendrait la génération entière, sans
  /// fin et sans message : l'écran resterait sur « Mise en page du document »
  /// pour un simple accessoire. Mieux vaut un rapport sans son fond de page.
  static const Duration _delaiDeGarde = Duration(seconds: 20);

  Future<Uint8List?> download(String? remotePath) async {
    if (remotePath == null || remotePath.isEmpty) return null;
    try {
      return await _gateway
          .downloadLetterhead(remotePath)
          .timeout(_delaiDeGarde);
    } on Object {
      return null;
    }
  }

  /// PNG et JPEG se reconnaissent à leurs premiers octets.
  static bool _estUneImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final png = bytes[0] == 0x89 && bytes[1] == 0x50;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    return png || jpeg;
  }
}
