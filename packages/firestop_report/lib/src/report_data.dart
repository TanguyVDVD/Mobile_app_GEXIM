import 'dart:typed_data';

/// Un cliché, déjà décodable par le moteur PDF.
///
/// Les octets sont fournis par l'appelant. Le package ne lit ni fichier ni
/// réseau : c'est ce qui le rend testable sans le moindre échafaudage, et
/// interchangeable entre l'application (fichiers locaux) et le serveur
/// (objets du bucket).
///
/// **L'ordre de la liste fait foi**, et il n'y a pas de nature de cliché ici :
/// la fiche AS BUILT offre deux cases puis autant de pages de suite qu'il en
/// faut, sans distinguer l'avant de l'après. C'est à l'appelant de ranger ses
/// clichés dans l'ordre où ils doivent paraître.
class ReportPhoto {
  const ReportPhoto({required this.bytes});

  final Uint8List bytes;
}

/// Le donneur d'ordre, tel qu'il figure en tête de chaque fiche.
class ReportClient {
  const ReportClient({required this.name, required this.address});

  final String name;

  /// Case « adresse client » du formulaire. Exigée à la création d'un client :
  /// une fiche qui n'identifie pas son destinataire n'a pas de valeur
  /// contractuelle.
  final String address;
}

/// Le chantier : les deux premières lignes du bloc d'identification.
class ReportProject {
  const ReportProject({required this.name, this.code});

  /// Ligne « Intitulé Projet ».
  final String name;

  /// Ligne « Numéro Projet », telle que le donneur d'ordre la numérote.
  final String? code;
}

/// Une traversée telle qu'elle apparaît sur sa fiche.
///
/// Les caractéristiques issues des listes administrées arrivent ici **résolues
/// en libellés**, jamais en identifiants : ce package ne connaît aucune base de
/// données, et c'est ce qui lui permet de tourner aussi bien dans
/// l'application que dans un conteneur serveur.
///
/// Rien de plus que ce que le formulaire porte. Les champs que l'application
/// stocke sans les imprimer — local, observations, auteur du relevé — ne
/// remontent volontairement pas jusqu'ici : les transporter obligerait le
/// service à les lire en base à chaque rapport, pour une donnée que personne ne
/// verrait.
class ReportPoint {
  const ReportPoint({
    required this.label,
    required this.capturedAt,
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

  /// Numéro définitif, tel qu'il figurera au dossier.
  final String label;

  /// Ligne « Date » de la fiche.
  final DateTime capturedAt;

  /// Bon de commande du client. Terme anglais conservé : c'est celui de la
  /// fiche et des pièces contractuelles.
  final String? purchaseOrder;

  final String? building;

  /// Étage, **déjà mis en forme** par l'appelant (« Rez-de-chaussée »,
  /// « Étage 2 »). Le package ne rejoue pas la règle de nommage : elle vivrait
  /// alors à deux endroits, et l'écran de saisie finirait par ne plus dire la
  /// même chose que le document remis au client.
  final String? floor;

  final String? configuration;
  final String? configurationDetail;
  final String? eiLevel;
  final String? supplier;

  /// Ligne « Type de produit utilisé » : manchon, mortier, mousse 1 comp…
  final String? productType;

  /// Produits mis en œuvre, **dans l'ordre des cinq emplacements** de la fiche.
  /// Le premier élément est « Produit utilisé (1) ».
  final List<String> products;

  /// Clichés, dans l'ordre d'apparition. Les deux premiers vont dans les cases
  /// imprimées, les suivants sur des pages de suite.
  final List<ReportPhoto> photos;
}

/// Tout ce qu'il faut pour produire un rapport, et rien d'autre.
class ReportData {
  const ReportData({
    required this.client,
    required this.project,
    required this.points,
    required this.generatedAt,
    this.clientLogo,
    this.formBackground,
  });

  final ReportClient client;
  final ReportProject project;
  final List<ReportPoint> points;
  final DateTime generatedAt;

  /// PNG ou JPEG. Absent ⇒ la case se rabat sur le nom du client.
  final Uint8List? clientLogo;

  /// Fond de la fiche AS BUILT : `template_rapport.png`, le formulaire vierge
  /// par-dessus lequel [AsBuiltBuilder] pose les valeurs.
  ///
  /// Fourni en octets par l'appelant, comme tout le reste : le package ne lit
  /// aucun fichier. Absent ⇒ les valeurs sont posées sur une page nue, aux
  /// mêmes emplacements — un document sans cadre plutôt qu'aucun document.
  final Uint8List? formBackground;
}
