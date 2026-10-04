import 'dart:io';

import 'package:flutter/services.dart';

import '../../database/tables/enums.dart';

/// La galerie de la tablette : l'album « FireStop », visible depuis
/// l'application Photos ou Galerie de l'appareil.
///
/// Demande du bureau, 4 octobre 2026 : chaque cliché ajouté à une traversée y
/// est aussi **copié**. La copie n'entre dans aucun mécanisme de
/// l'application — ni synchronisée, ni relue, ni retirée quand le cliché ou la
/// traversée le sont. Elle appartient au technicien.
///
/// Une interface, pour que les tests remplacent le canal de plateforme, qui
/// n'existe pas dans la machine virtuelle où ils tournent.
abstract interface class Galerie {
  /// Copie [cliche] dans la galerie sous le nom [nom] (sans chemin, avec son
  /// extension). Lève [GalerieEchec] si la copie n'a pas pu se faire.
  Future<void> ajouter(File cliche, {required String nom});
}

/// La copie vers la galerie a échoué. Le cliché, lui, est bien sur la fiche.
class GalerieEchec implements Exception {
  const GalerieEchec(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Android, par un canal vers `MainActivity` plutôt que par un greffon : ceux
/// qui écrivent dans la galerie n'ont pas d'implémentation pour le navigateur
/// (voir « Un greffon absent ne casse pas la compilation », dans CLAUDE.md),
/// et le travail tient en un appel à `MediaStore`.
class GalerieAndroid implements Galerie {
  const GalerieAndroid();

  static const _canal = MethodChannel('be.gexim.firestop_tracker/galerie');

  @override
  Future<void> ajouter(File cliche, {required String nom}) async {
    try {
      await _canal.invokeMethod<void>('ajouter', {
        'chemin': cliche.absolute.path,
        'nom': nom,
      });
    } on PlatformException catch (e) {
      throw GalerieEchec(e.message ?? e.code);
    } on MissingPluginException {
      throw const GalerieEchec('galerie indisponible sur cet appareil');
    }
  }
}

/// Nom du fichier dans la galerie : chantier, numéro du point, emplacement
/// du cliché, horodatage — de quoi retrouver une photo sans ouvrir la fiche.
///
/// L'emplacement porte les noms de l'écran, « Photo 1 » et « Photo 2 » : la
/// fiche ne distingue plus l'avant de l'après.
///
/// L'horodatage, à la seconde, distingue une photo reprise de la précédente :
/// sur la fiche la reprise remplace, dans la galerie les deux restent.
String nomDeCliche({
  required String chantier,
  required String? numero,
  required PhotoKind nature,
  required DateTime prisLe,
}) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final quand = '${prisLe.year}${deux(prisLe.month)}${deux(prisLe.day)}'
      '_${deux(prisLe.hour)}${deux(prisLe.minute)}${deux(prisLe.second)}';

  final parties = [
    _assaini(chantier),
    if (numero != null && _assaini(numero).isNotEmpty) 'pt${_assaini(numero)}',
    switch (nature) {
      PhotoKind.before => 'photo1',
      PhotoKind.after => 'photo2',
      PhotoKind.extra => 'complement',
    },
    quand,
  ].where((partie) => partie.isNotEmpty);

  return '${parties.join('_')}.jpg';
}

/// Retire ce qu'un système de fichiers refuse, et borne la longueur : un
/// intitulé de chantier est un texte libre.
String _assaini(String texte) {
  final propre = texte
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  return propre.length > 40 ? propre.substring(0, 40).trim() : propre;
}
