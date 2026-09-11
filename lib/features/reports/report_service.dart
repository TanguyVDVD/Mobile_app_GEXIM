import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:firestop_report/firestop_report.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../database/database.dart';
import '../../database/tables/enums.dart' as app;
import '../../database/tables/tables.dart' show floorLabel;
import '../../sync/remote_gateway.dart';
import '../capture/photo_repository.dart';
import '../capture/reduction_jpeg.dart';

/// Étape en cours de la génération.
///
/// Affichée à l'écran, et pas seulement décorative : une génération qui
/// s'éternise doit dire **où** elle est bloquée. Un « Préparation… » muet ne
/// distingue pas une lecture locale d'un téléchargement suspendu.
enum ReportPhase {
  reading('Lecture du relevé'),
  photos('Préparation des clichés'),
  rendering('Mise en page du document');

  const ReportPhase(this.label);

  final String label;
}

/// Avancement de la génération.
typedef ReportProgress = void Function(ReportPhase phase, int done, int total);

/// Assemble les données d'un chantier et produit son rapport PDF.
///
/// Toute la mise en page vit dans `firestop_report`, package Dart pur. Ce
/// service ne fait que le nourrir : lire la base locale, résoudre les
/// caractéristiques en libellés, rapatrier les clichés.
///
/// Le document produit est la **fiche AS BUILT**, composée par-dessus un
/// formulaire fixe et commun à tous les clients. Il n'y a rien à configurer :
/// ni gabarit, ni marges, ni papier à en-tête.
class ReportService {
  const ReportService({
    required AppDatabase db,
    required PhotoRepository photos,
    required RemoteGateway gateway,
    required ReductionJpeg reduction,
  })  : _db = db,
        _photos = photos,
        _gateway = gateway,
        _reduction = reduction;

  final AppDatabase _db;
  final PhotoRepository _photos;
  final RemoteGateway _gateway;

  /// Injectée plutôt qu'appelée en dur : le greffon de compression n'existe pas
  /// sur Windows, où la génération du rapport est pourtant l'usage principal.
  /// Voir `ReductionJpeg`.
  final ReductionJpeg _reduction;

  /// Définition des clichés embarqués dans le PDF.
  ///
  /// Bien en deçà des ~2000 px stockés, et c'est délibéré : le moteur PDF
  /// conserve **toutes** les images décodées en mémoire jusqu'à l'écriture du
  /// document. Un chantier de 200 traversées à trois clichés de 400 Ko ferait
  /// 240 Mo de pointe — de quoi faire tuer l'application par Android au milieu
  /// de la génération.
  ///
  /// La perte est nulle à l'œil : une photo occupe environ 250 points de large
  /// sur une page A4, soit ~520 px à 150 DPI. Mille pixels laissent déjà de la
  /// marge pour un agrandissement à l'écran.
  static const int _pdfMaxEdge = 1000;
  static const int _pdfQuality = 75;

  /// Délai de garde par cliché rapatrié.
  ///
  /// Le client Supabase n'en impose aucun : sur un réseau qui accepte la
  /// connexion sans jamais répondre — portail captif, émulateur mal routé — un
  /// seul téléchargement suspend la génération entière, sans fin et sans
  /// message. Mieux vaut un rapport signalant « cliché absent ».
  static const Duration _downloadTimeout = Duration(seconds: 20);

  /// Produit le rapport. Rend les octets du PDF.
  ///
  /// Le document est la **fiche AS BUILT** : une page neuve par traversée,
  /// composée par-dessus le formulaire `template_rapport.png`.
  ///
  /// Le seul habillage est le logo du client : le fond de page *est* le
  /// formulaire.
  Future<Uint8List> build(
    String projectId, {
    ReportProgress? onProgress,
  }) async {
    final data = await _collect(projectId, onProgress);

    onProgress?.call(ReportPhase.rendering, 0, 0);

    // Chargés en dernier, une fois les clichés prêts : ce sont des accessoires,
    // et leur absence ne doit jamais empêcher la sortie du document.
    final logo = await _logoDuClient(data.$2);
    final formulaire = await _formulaire();
    final fonts = await _loadFonts();

    final collecte = data.$1;
    return AsBuiltBuilder(
      regularFont: fonts?.$1,
      boldFont: fonts?.$2,
    ).build(
      ReportData(
        client: collecte.client,
        project: collecte.project,
        points: collecte.points,
        generatedAt: collecte.generatedAt,
        clientLogo: logo,
        formBackground: formulaire,
      ),
    );
  }

  /// Le formulaire vierge, depuis les assets de l'application.
  ///
  /// Échoue en silence, comme tout le reste de l'habillage : sans lui les
  /// valeurs se posent sur une page nue, aux mêmes emplacements. Un document
  /// sans cadre reste lisible et transmissible ; pas de document du tout, non.
  Future<Uint8List?> _formulaire() async {
    try {
      final data = await rootBundle.load('template_rapport.png');
      return data.buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  /// Logo du client, rapatrié du bucket.
  ///
  /// Échoue en silence : un rapport sans logo vaut infiniment mieux qu'aucun
  /// rapport, et ce fichier vit sur le réseau. Le moteur PDF pose alors le nom
  /// du client dans la case. Le délai de garde est le même que pour les
  /// clichés — un serveur qui accepte la connexion sans jamais répondre
  /// suspendrait sinon la génération entière pour un accessoire.
  Future<Uint8List?> _logoDuClient(Client client) async {
    try {
      return await _gateway
          .downloadAsset(client.logoPath, bucket: 'client-logos')
          .timeout(_downloadTimeout);
    } on Object {
      return null;
    }
  }

  /// Dépose le rapport sur le serveur. Nécessite du réseau.
  ///
  /// Volontairement séparé de [build] : le PDF est une donnée dérivée, toujours
  /// reconstructible. Un dépôt échoué se retente en régénérant, sans qu'il ait
  /// fallu faire transiter des dizaines de mégaoctets par la file d'attente.
  Future<void> publish(String projectId, Uint8List bytes) {
    return _gateway.publishReport(
      projectId: projectId,
      remotePath: '$projectId/rapport.pdf',
      bytes: bytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Collecte
  // ---------------------------------------------------------------------------

  Future<(ReportData, Client)> _collect(
    String projectId,
    ReportProgress? onProgress,
  ) async {
    onProgress?.call(ReportPhase.reading, 0, 0);

    final project = await _db.projectDao.projectById(projectId);
    final client = await (_db.select(_db.clients)
          ..where((t) => t.id.equals(project.clientId)))
        .getSingle();

    // Lectures **ponctuelles**, jamais des `.first` sur des flux : un rapport
    // est un instantané, et s'abonner à des requêtes vivantes pendant qu'un
    // cycle de synchronisation écrit dans les mêmes tables expose à attendre
    // sans fin un événement déjà passé.
    final summaries = await _db.pointDao.pointSummaries(projectId);

    // Les caractéristiques sont stockées par identifiant ; le rapport les veut
    // en clair. Une seule lecture de toute la table plutôt qu'une jointure par
    // point : il y a quelques dizaines d'options, et le rapport en relit les
    // mêmes à chaque fiche.
    //
    // `labels()` inclut délibérément les options retirées du catalogue. Les
    // écarter ferait sortir une ligne « Produit utilisé (1) » vide pour une
    // traversée pourtant renseignée — une lacune fabriquée par l'outil, sur le
    // document même qui atteste de la conformité.
    final options = await _db.settingsDao.labels();

    final total = await _photoCount(projectId);
    var done = 0;
    onProgress?.call(ReportPhase.photos, 0, total);

    final points = <ReportPoint>[];
    for (final summary in summaries) {
      final photos = <ReportPhoto>[];

      for (final photo in _ordonner(await _db.pointDao.photosOf(summary.point.id))) {
        final bytes = await _photoBytes(photo);
        if (bytes != null) photos.add(ReportPhoto(bytes: bytes));
        onProgress?.call(ReportPhase.photos, ++done, total);
      }

      final point = summary.point;
      points.add(
        ReportPoint(
          label: summary.label,
          capturedAt: point.capturedAt,
          purchaseOrder: point.purchaseOrder,
          building: point.building,
          // Mis en forme ici et non dans le package : la règle de nommage des
          // étages appartient à l'application, et la dupliquer ferait que
          // l'écran de saisie et le document remis au client finiraient par ne
          // plus dire la même chose.
          floor: point.floorLevel == null ? null : floorLabel(point.floorLevel!),
          configuration: options[point.configurationId],
          configurationDetail: options[point.configurationDetailId],
          eiLevel: options[point.eiLevelId],
          supplier: options[point.supplierId],
          productType: options[point.productTypeId],
          products: [
            for (final id in [
              point.product1Id,
              point.product2Id,
              point.product3Id,
              point.product4Id,
              point.product5Id,
            ])
              // La chaîne vide, et non un saut : les cinq emplacements de la
              // fiche sont positionnels. Retirer le deuxième produit ferait
              // sinon remonter le troisième à sa place, sur un document déjà
              // remis au client sous l'autre numérotation.
              options[id] ?? '',
          ],
          photos: photos,
        ),
      );
    }

    return (
      ReportData(
        client: ReportClient(name: client.name, address: client.address),
        project: ReportProject(name: project.name, code: project.code),
        points: points,
        generatedAt: DateTime.now(),
      ),
      client,
    );
  }

  /// Rapatrie le cliché si nécessaire, puis le réduit pour le document.
  ///
  /// Rend `null` quand le binaire est introuvable — appareil hors ligne devant
  /// une photo prise par un collègue. Le rapport sort quand même, en signalant
  /// « cliché absent » : mieux vaut un document lacunaire mais honnête
  /// qu'aucun document.
  Future<Uint8List?> _photoBytes(Photo photo) async {
    try {
      final file = await _photos.fileFor(photo).timeout(_downloadTimeout);
      if (file == null) return null;

      return await _reduction.reduire(
        file,
        coteMin: _pdfMaxEdge,
        qualite: _pdfQuality,
      );
    } on Object {
      // Réseau muet, fichier illisible, décodage en échec : un cliché de moins
      // ne doit jamais empêcher la sortie du document.
      return null;
    }
  }

  Future<int> _photoCount(String projectId) async {
    final row = await _db.customSelect(
      '''
      SELECT COUNT(*) AS total
        FROM photos ph
        JOIN points p ON p.id = ph.point_id
       WHERE p.project_id = ?1
         AND ph.deleted_at IS NULL
         AND p.deleted_at IS NULL
      ''',
      variables: [Variable<String>(projectId)],
      readsFrom: {_db.photos, _db.points},
    ).getSingle();
    return row.read<int>('total');
  }

  /// Range les clichés : l'avant, l'après, puis les compléments.
  ///
  /// La fiche ne distingue plus « avant » et « après » — elle offre deux cases,
  /// puis autant qu'il en faut. Mais la paire réglementaire reste la preuve du
  /// dossier, et c'est elle qui doit occuper les deux cases imprimées : c'est
  /// là que le regard d'un contrôleur se pose. Un cliché complémentaire qui
  /// s'intercalerait devant elle repousserait l'« après » en seconde rangée.
  static List<Photo> _ordonner(List<Photo> photos) {
    int rang(app.PhotoKind kind) => switch (kind) {
          app.PhotoKind.before => 0,
          app.PhotoKind.after => 1,
          app.PhotoKind.extra => 2,
        };

    return [...photos]..sort((a, b) => rang(a.kind).compareTo(rang(b.kind)));
  }

  // ---------------------------------------------------------------------------
  // Polices
  // ---------------------------------------------------------------------------

  /// Polices Unicode, si elles ont été déposées dans `assets/fonts/`.
  ///
  /// Sans elles, le rendu retombe sur Helvetica, qui **omet silencieusement**
  /// le tiret cadratin, l'apostrophe typographique et l'œ ligaturé. Ces
  /// caractères sortent des claviers de téléphone sans qu'on y pense : sur un
  /// document contractuel, les perdre sans le dire n'est pas acceptable.
  /// Voir `assets/fonts/README.md`.
  Future<(Uint8List, Uint8List?)?> _loadFonts() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Report-Regular.ttf');
      Uint8List? bold;
      try {
        bold = (await rootBundle.load('assets/fonts/Report-Bold.ttf'))
            .buffer
            .asUint8List();
      } on Object {
        bold = null;
      }
      return (regular.buffer.asUint8List(), bold);
    } on Object {
      return null;
    }
  }
}
