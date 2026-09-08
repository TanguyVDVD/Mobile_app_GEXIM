import 'dart:typed_data';

/// Nature d'un cliché dans le dossier d'une traversée.
///
/// Volontairement redéfini ici plutôt qu'importé de l'application : ce package
/// ne doit rien connaître d'elle, c'est ce qui lui permet de tourner aussi dans
/// un conteneur serveur.
enum ReportPhotoKind { before, after, extra }

/// Un cliché, déjà décodable par le moteur PDF.
///
/// Les octets sont fournis par l'appelant. Le package ne lit ni fichier ni
/// réseau : c'est ce qui le rend testable sans le moindre échafaudage, et
/// interchangeable entre l'application (fichiers locaux) et le serveur
/// (objets du bucket).
class ReportPhoto {
  const ReportPhoto({
    required this.kind,
    required this.bytes,
    this.caption,
  });

  final ReportPhotoKind kind;
  final Uint8List bytes;
  final String? caption;
}

class ReportClient {
  const ReportClient({
    required this.name,
    this.address,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
  });

  final String name;
  final String? address;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
}

class ReportProject {
  const ReportProject({
    required this.name,
    this.description,
    this.startedOn,
    this.endedOn,
  });

  final String name;
  final String? description;
  final DateTime? startedOn;
  final DateTime? endedOn;
}

/// Une traversée telle qu'elle apparaît dans le rapport.
class ReportPoint {
  const ReportPoint({
    required this.label,
    required this.capturedAt,
    this.floor,
    this.room,
    this.description,
    this.authorName,
    this.materials = const [],
    this.photos = const [],
  });

  /// Numéro définitif, tel qu'il figurera au dossier.
  final String label;

  final DateTime capturedAt;
  final String? floor;
  final String? room;
  final String? description;
  final String? authorName;
  final List<String> materials;
  final List<ReportPhoto> photos;

  String get location {
    final parts = [floor, room].where((s) => s != null && s.isNotEmpty);
    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  ReportPhoto? photoOf(ReportPhotoKind kind) {
    for (final photo in photos) {
      if (photo.kind == kind) return photo;
    }
    return null;
  }

  /// Les deux clichés exigés par la norme sont-ils présents ?
  ///
  /// Reporté tel quel dans le tableau récapitulatif : c'est ce qu'un auditeur
  /// vérifie en premier, et le masquer rendrait le document trompeur.
  bool get isComplete =>
      photoOf(ReportPhotoKind.before) != null &&
      photoOf(ReportPhotoKind.after) != null;
}

/// Tout ce qu'il faut pour produire un rapport, et rien d'autre.
class ReportData {
  const ReportData({
    required this.client,
    required this.project,
    required this.points,
    required this.generatedAt,
    this.clientLogo,
    this.letterheadCover,
    this.letterheadBody,
  });

  final ReportClient client;
  final ReportProject project;
  final List<ReportPoint> points;
  final DateTime generatedAt;

  /// PNG ou JPEG. Absent ⇒ l'en-tête se rabat sur le nom du client.
  final Uint8List? clientLogo;

  /// Papier à en-tête, **déjà rasterisé en image**, appliqué en fond de page.
  ///
  /// Le package ne sait pas lire un PDF : c'est l'appelant qui convertit le
  /// document type en image (`Printing.raster` côté application). Cela garde ce
  /// package sans entrée-sortie ni dépendance native, et lui permet de tourner
  /// dans un conteneur.
  ///
  /// Conséquence à connaître : le texte de l'en-tête n'est plus sélectionnable
  /// dans le rapport final, et sa netteté dépend de la définition choisie à la
  /// conversion.
  final Uint8List? letterheadCover;

  /// Fond des pages suivantes. Absent ⇒ [letterheadCover] est réutilisé.
  ///
  /// La plupart des papiers à en-tête ont une première page chargée et des
  /// pages de suite allégées.
  final Uint8List? letterheadBody;

  int get completeCount => points.where((p) => p.isComplete).length;
}
