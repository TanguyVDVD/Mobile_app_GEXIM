import 'dart:typed_data';

/// Un cliché, en JPEG ou en PNG.
///
/// Les octets sont fournis par l'appelant. Le package ne lit ni fichier ni
/// réseau : c'est ce qui le rend testable sans échafaudage.
class ReportPhoto {
  const ReportPhoto({required this.bytes});

  final Uint8List bytes;
}

/// Le donneur d'ordre, tel qu'il figure en tête de chaque fiche.
class ReportClient {
  const ReportClient({required this.name, required this.address});

  /// Posé dans la case « Client » quand le logo manque.
  final String name;

  /// Case « l'adresse » du modèle.
  final String address;
}

/// Le chantier : ce que toutes ses fiches ont en commun.
class ReportProject {
  const ReportProject({required this.name, this.code});

  /// Ligne « Intitulé Projet ».
  final String name;

  /// Ligne « Numéro Projet », telle que le donneur d'ordre la numérote. Écrite
  /// en K5 : la fiche la reprend par formule, ainsi que le numéro de fiche.
  final String? code;
}

/// Une traversée telle qu'elle apparaît sur sa fiche.
///
/// Les caractéristiques issues des listes administrées arrivent ici **résolues
/// en libellés**, jamais en identifiants : ce package ne connaît aucune base de
/// données.
class ReportPoint {
  const ReportPoint({
    required this.capturedAt,
    this.number,
    this.projectCode,
    this.projectName,
    this.purchaseOrder,
    this.building,
    this.floor,
    this.configuration,
    this.configurationDetail,
    this.eiLevel,
    this.supplier,
    this.productType,
    this.products = const [],
    this.photos = const [],
  });

  /// Numéro du point, tel que saisi. Donne aussi son nom à la feuille. `null`
  /// si la fiche n'en a pas encore.
  final String? number;

  /// Ligne « Date » de la fiche. Seul le jour compte.
  final DateTime capturedAt;

  /// Numéro et intitulé de projet **propres à cette fiche**, quand elle
  /// s'écarte de son chantier. `null` : ceux de [ReportData.project].
  final String? projectCode;
  final String? projectName;

  final String? purchaseOrder;
  final String? building;

  /// Étage, **déjà mis en forme** par l'appelant.
  final String? floor;

  final String? configuration;
  final String? configurationDetail;
  final String? eiLevel;
  final String? supplier;
  final String? productType;

  /// Produits mis en œuvre, **dans l'ordre des cinq emplacements** de la fiche.
  /// Une chaîne vide laisse l'emplacement vide sans décaler les suivants.
  final List<String> products;

  /// Clichés, dans l'ordre d'apparition. La fiche a deux cases : seuls les
  /// deux premiers y figurent.
  final List<ReportPhoto> photos;
}

/// Tout ce qu'il faut pour produire le classeur, et rien d'autre.
class ReportData {
  const ReportData({
    required this.client,
    required this.project,
    required this.points,
    this.clientLogo,
  });

  final ReportClient client;
  final ReportProject project;

  /// Une feuille par élément, dans cet ordre.
  final List<ReportPoint> points;

  /// PNG ou JPEG. Absent ⇒ la case « Client » porte le nom du client.
  final Uint8List? clientLogo;
}
