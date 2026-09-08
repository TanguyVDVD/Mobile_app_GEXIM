import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../../core/plateforme.dart';

/// Ce qu'il est advenu d'une demande d'enregistrement.
sealed class ResultatExport {
  const ResultatExport();
}

/// Le fichier est écrit. [chemin] est absolu, et destiné à être montré tel quel
/// à l'administrateur : c'est ce qu'il ira chercher dans son explorateur.
class ExportReussi extends ResultatExport {
  const ExportReussi(this.chemin);

  final String chemin;
}

/// L'administrateur a fermé le sélecteur. Ce n'est pas une erreur, et rien ne
/// doit s'afficher : le distinguer d'un échec évite le message d'alerte absurde
/// après une annulation volontaire.
class ExportAnnule extends ResultatExport {
  const ExportAnnule();
}

/// Le dossier est en lecture seule, le disque plein, le fichier ouvert dans un
/// lecteur PDF qui le verrouille — cas courant quand on régénère un rapport.
class ExportEchoue extends ResultatExport {
  const ExportEchoue(this.raison);

  final String raison;
}

/// Sortie du rapport hors de l'application.
///
/// Deux gestes différents pour deux postes de travail, et non un réglage :
///
///  * sur **tablette**, il n'y a pas d'arborescence à proposer. Le rapport part
///    par le sélecteur de partage du système — courriel, Drive, l'imprimante du
///    bureau — c'est le seul geste qui ait un sens là-bas.
///  * sur **PC**, l'administrateur clôture un chantier et range le document
///    dans le dossier client, celui que son classement impose. Lui imposer un
///    emplacement, puis lui demander de retrouver le fichier pour le déplacer,
///    serait un détour pour rien.
///
/// Le dépôt sur le serveur (`ReportService.publish`) reste indépendant des
/// deux : il vise l'archive, pas le poste de travail.
abstract interface class ReportExporter {
  /// Vrai si [enregistrer] ouvre un sélecteur d'emplacement.
  ///
  /// L'écran s'en sert pour intituler le bouton — « Enregistrer sous… » n'a
  /// aucun sens en face d'une feuille de partage.
  bool get proposeUnEmplacement;

  Future<ResultatExport> enregistrer({
    required String nomPropose,
    required Uint8List octets,
  });

  factory ReportExporter.pourLaPlateforme() =>
      Plateforme.enregistrementLocalDisponible
          ? const ExportVersLeDisque()
          : const ExportParPartage();
}

/// Bureau : sélecteur d'emplacement natif, puis écriture.
class ExportVersLeDisque implements ReportExporter {
  const ExportVersLeDisque();

  @override
  bool get proposeUnEmplacement => true;

  @override
  Future<ResultatExport> enregistrer({
    required String nomPropose,
    required Uint8List octets,
  }) async {
    String? chemin;
    try {
      // `bytes` n'est volontairement pas passé : sur les plateformes de bureau
      // `saveFile` écrirait le fichier lui-même et ne rendrait qu'un chemin,
      // sans distinguer un disque plein d'une annulation. On écrit donc nous
      // mêmes, pour pouvoir dire ce qui a échoué.
      chemin = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport',
        fileName: nomPropose,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        // Le sélecteur doit rester modal au-dessus de la fenêtre : sans cela il
        // peut s'ouvrir derrière, et l'application paraît figée.
        lockParentWindow: true,
      );
    } on Object catch (e) {
      return ExportEchoue('Sélecteur d\'emplacement indisponible : $e');
    }

    if (chemin == null) return const ExportAnnule();

    // Certains sélecteurs rendent le nom sans suffixe quand l'utilisateur l'a
    // effacé. Un rapport de conformité qui n'a pas d'extension ne s'ouvre pas
    // d'un double-clic, et se retrouve mal à la recherche.
    if (!chemin.toLowerCase().endsWith('.pdf')) chemin = '$chemin.pdf';

    try {
      await File(chemin).writeAsBytes(octets, flush: true);
      return ExportReussi(chemin);
    } on FileSystemException catch (e) {
      // Cas le plus fréquent en pratique : le rapport précédent est encore
      // ouvert dans un lecteur PDF, qui verrouille le fichier.
      return ExportEchoue(e.osError?.message ?? e.message);
    }
  }
}

/// Tablette : la feuille de partage du système.
class ExportParPartage implements ReportExporter {
  const ExportParPartage();

  @override
  bool get proposeUnEmplacement => false;

  @override
  Future<ResultatExport> enregistrer({
    required String nomPropose,
    required Uint8List octets,
  }) async {
    try {
      await Printing.sharePdf(bytes: octets, filename: nomPropose);
      // Le système ne dit pas ce que l'utilisateur a choisi, ni s'il a
      // renoncé. Rien à annoncer : la feuille de partage est sa propre
      // confirmation.
      return const ExportAnnule();
    } on Object catch (e) {
      return ExportEchoue('$e');
    }
  }
}
