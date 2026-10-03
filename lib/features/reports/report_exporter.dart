import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/plateforme.dart';
import 'telechargement/telechargement_absent.dart'
    if (dart.library.js_interop) 'telechargement/telechargement_web.dart';

/// Ce qu'il est advenu d'une demande d'export.
sealed class ResultatExport {
  const ResultatExport();
}

/// Le classeur est sorti. [nom] est le nom du fichier, à montrer tel quel :
/// c'est ce que l'administrateur ira chercher dans ses téléchargements.
class ExportReussi extends ResultatExport {
  const ExportReussi(this.nom);

  final String nom;
}

/// Rien à annoncer : le système a pris la main (feuille de partage), ou
/// l'utilisateur a renoncé. Le distinguer d'un échec évite le message d'alerte
/// absurde après une annulation volontaire.
class ExportAnnule extends ResultatExport {
  const ExportAnnule();
}

class ExportEchoue extends ResultatExport {
  const ExportEchoue(this.raison);

  final String raison;
}

/// Sortie du classeur hors de l'application.
///
/// Deux gestes pour deux postes, et non un réglage :
///
///  * sur **tablette**, il n'y a pas d'arborescence à proposer. Le classeur
///    part par le sélecteur de partage du système — courriel, Drive ;
///  * dans un **navigateur**, il se télécharge, comme tout fichier qu'un site
///    remet. L'administrateur le range ensuite où son classement l'impose.
abstract interface class ReportExporter {
  /// Vrai si [exporter] fait télécharger le fichier.
  ///
  /// L'écran s'en sert pour intituler le bouton — « Télécharger » n'a aucun
  /// sens en face d'une feuille de partage.
  bool get telecharge;

  Future<ResultatExport> exporter({
    required String nomPropose,
    required Uint8List octets,
  });

  factory ReportExporter.pourLaPlateforme() => Plateforme.estNavigateur
      ? const ExportParTelechargement()
      : const ExportParPartage();

  /// Classeur Excel **avec macros** : le modèle du bureau porte du VBA.
  static const extension = 'xlsm';
  static const typeMime = 'application/vnd.ms-excel.sheet.macroEnabled.12';
}

/// Navigateur : le fichier est téléchargé.
class ExportParTelechargement implements ReportExporter {
  const ExportParTelechargement();

  @override
  bool get telecharge => true;

  @override
  Future<ResultatExport> exporter({
    required String nomPropose,
    required Uint8List octets,
  }) async {
    try {
      telecharger(
        nom: nomPropose,
        octets: octets,
        typeMime: ReportExporter.typeMime,
      );
      return ExportReussi(nomPropose);
    } on Object catch (e) {
      return ExportEchoue('$e');
    }
  }
}

/// Tablette : la feuille de partage du système.
class ExportParPartage implements ReportExporter {
  const ExportParPartage();

  @override
  bool get telecharge => false;

  @override
  Future<ResultatExport> exporter({
    required String nomPropose,
    required Uint8List octets,
  }) async {
    try {
      // Le partage système veut un fichier, pas des octets. Le dossier
      // temporaire est le bon endroit : Android le vide de lui-même, et le
      // classeur se régénère à l'identique.
      final dossier = await getTemporaryDirectory();
      final fichier = File(p.join(dossier.path, nomPropose));
      await fichier.writeAsBytes(octets, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(fichier.path, mimeType: ReportExporter.typeMime)],
        ),
      );
      // Le système ne dit pas de façon fiable ce que l'utilisateur a choisi,
      // ni s'il a renoncé. Rien à annoncer : la feuille de partage est sa
      // propre confirmation.
      return const ExportAnnule();
    } on Object catch (e) {
      return ExportEchoue('$e');
    }
  }
}
