import 'dart:typed_data';

import 'package:firestop_excel/firestop_excel.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../../database/daos/point_dao.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart' as app;
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
  rendering('Écriture du classeur');

  const ReportPhase(this.label);

  final String label;
}

/// Avancement de la génération.
typedef ReportProgress = void Function(ReportPhase phase, int done, int total);

/// Le classeur produit, et ce qu'il faut en dire à l'écran.
typedef ClasseurProduit = ({
  Uint8List octets,

  /// Nombre de fiches, donc de feuilles.
  int fiches,

  /// Clichés attendus que le classeur ne contient pas : binaire introuvable,
  /// appareil hors ligne devant la photo d'un collègue. À afficher — une fiche
  /// de conformité sans sa photo ne doit pas partir sans que quelqu'un le
  /// sache.
  int clichesManquants,

  /// Le logo du client n'a pas pu être rapatrié : la case « Client » porte
  /// son nom.
  bool sansLogo,
});

/// Assemble les données d'un chantier et produit son classeur Excel.
///
/// Le document est le classeur **« AS BUILT Resserrages RF »** du bureau :
/// une feuille par traversée, remplie dans le modèle embarqué — macros,
/// boutons et listes déroulantes compris, pour qu'il reste exploitable dans
/// Excel. Tout le remplissage vit dans `firestop_excel`, package Dart pur. Ce
/// service ne fait que le nourrir : lire la base locale, résoudre les
/// caractéristiques en libellés, rapatrier les clichés.
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
  /// sur Windows, où la génération du classeur est pourtant l'usage principal.
  /// Voir `ReductionJpeg`.
  final ReductionJpeg _reduction;

  /// Le modèle, tel que déclaré dans `pubspec.yaml`.
  static const modele = 'AS_BUILT_Resserages_RF_model_vierge.xlsm';

  /// La fiche a deux cases photo.
  static const _clichesParFiche = 2;

  /// Définition des clichés embarqués dans le classeur.
  ///
  /// Bien en deçà des ~2000 px stockés. Une case photo fait une dizaine de
  /// centimètres à l'impression : mille pixels y dépassent déjà 250 DPI. Et
  /// le classeur les porte **tous** — à 400 Ko pièce, un chantier de 200
  /// traversées pèserait 160 Mo, impossible à joindre à un courriel.
  static const int _coteClasseur = 1000;
  static const int _qualiteClasseur = 75;

  /// Délai de garde par fichier rapatrié.
  ///
  /// Le client Supabase n'en impose aucun : sur un réseau qui accepte la
  /// connexion sans jamais répondre — portail captif, émulateur mal routé — un
  /// seul téléchargement suspend la génération entière, sans fin et sans
  /// message.
  static const Duration _downloadTimeout = Duration(seconds: 20);

  /// Produit le classeur du chantier.
  Future<ClasseurProduit> build(
    String projectId, {
    ReportProgress? onProgress,
  }) async {
    onProgress?.call(ReportPhase.reading, 0, 0);

    final project = await _db.projectDao.projectById(projectId);
    final client = await (_db.select(_db.clients)
          ..where((t) => t.id.equals(project.clientId)))
        .getSingle();

    // Lectures **ponctuelles**, jamais des `.first` sur des flux : un export
    // est un instantané, et s'abonner à des requêtes vivantes pendant qu'un
    // cycle de synchronisation écrit dans les mêmes tables expose à attendre
    // sans fin un événement déjà passé.
    final summaries = await _db.pointDao.pointSummaries(projectId);
    if (summaries.isEmpty) {
      throw StateError(
        'Ce chantier ne compte aucune traversée : il n\'y a pas de fiche à '
        'produire.',
      );
    }

    // Les caractéristiques sont stockées par identifiant ; la fiche les veut
    // en clair. `labels()` inclut délibérément les options retirées du
    // catalogue : les écarter ferait sortir une ligne « Produit utilisé (1) »
    // vide pour une traversée pourtant renseignée.
    final options = await _db.settingsDao.labels();

    // Les clichés de chaque fiche, choisis avant tout rapatriement : le total
    // affiché est ainsi celui du travail réellement à faire.
    final retenus = [
      for (final summary in summaries)
        _ordonner(await _db.pointDao.photosOf(summary.point.id))
            .take(_clichesParFiche)
            .toList(),
    ];
    final total = retenus.fold(0, (somme, liste) => somme + liste.length);
    var done = 0;
    var manquants = 0;
    onProgress?.call(ReportPhase.photos, 0, total);

    final points = <ReportPoint>[];
    for (final (index, summary) in summaries.indexed) {
      final photos = <ReportPhoto>[];
      for (final photo in retenus[index]) {
        final bytes = await _photoBytes(photo);
        if (bytes == null) {
          manquants++;
        } else {
          photos.add(ReportPhoto(bytes: bytes));
        }
        onProgress?.call(ReportPhase.photos, ++done, total);
      }

      final point = summary.point;
      final etage = point.floorLevel;
      final id = PointDao.identification(point, project);
      points.add(
        ReportPoint(
          number: point.refNumber?.toString(),
          capturedAt: point.capturedAt,
          // Ce que dit le chantier, sauf si la traversée s'en écarte.
          projectCode: id.code,
          projectName: id.name,
          purchaseOrder: id.purchaseOrder,
          building: point.building,
          // « Niveau 2 », et non le « Étage 2 » de l'écran de saisie : c'est
          // l'intitulé exact de la liste « Étages » du classeur. Une fiche
          // retouchée à la main dans Excel doit retrouver sa valeur dans le
          // menu déroulant.
          floor: etage == null ? null : 'Niveau $etage',
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
              // sinon remonter le troisième à sa place.
              options[id] ?? '',
          ],
          photos: photos,
        ),
      );
    }

    onProgress?.call(ReportPhase.rendering, 0, 0);

    final logo = await _logoDuClient(client);
    // Sans le modèle il n'y a rien à remplir : cette lecture-là n'échoue pas
    // en silence.
    final octetsModele =
        (await rootBundle.load(modele)).buffer.asUint8List();

    // Dans un isolat : compresser plusieurs centaines de clichés dans une
    // archive fige sinon l'interface plusieurs secondes, bandeau de
    // progression compris — de quoi faire croire à un plantage.
    final octets = await compute(
      _construire,
      (
        octetsModele,
        ReportData(
          client: ReportClient(name: client.name, address: client.address),
          project: ReportProject(name: project.name, code: project.code),
          points: points,
          clientLogo: logo,
        ),
      ),
    );

    return (
      octets: octets,
      fiches: points.length,
      clichesManquants: manquants,
      sansLogo: logo == null,
    );
  }

  /// Fonction de premier niveau : un isolat ne peut pas recevoir de méthode
  /// liée à ce service, qui tient la base de données.
  static Uint8List _construire((Uint8List, ReportData) entree) =>
      const AsBuiltWorkbook().build(modele: entree.$1, data: entree.$2);

  /// Logo du client, rapatrié du bucket.
  ///
  /// Échoue en silence : un classeur sans logo vaut infiniment mieux qu'aucun
  /// classeur, et ce fichier vit sur le réseau. La case « Client » porte alors
  /// le nom du client, et l'écran le signale.
  Future<Uint8List?> _logoDuClient(Client client) async {
    try {
      return await _gateway
          .downloadAsset(client.logoPath, bucket: 'client-logos')
          .timeout(_downloadTimeout);
    } on Object {
      return null;
    }
  }

  /// Rapatrie le cliché si nécessaire, puis le réduit pour le classeur.
  ///
  /// Rend `null` quand le binaire est introuvable — appareil hors ligne devant
  /// une photo prise par un collègue. Le classeur sort quand même, et
  /// l'appelant compte l'absence.
  Future<Uint8List?> _photoBytes(Photo photo) async {
    try {
      final file = await _photos.fileFor(photo).timeout(_downloadTimeout);
      if (file == null) return null;

      return await _reduction.reduire(
        file,
        coteMin: _coteClasseur,
        qualite: _qualiteClasseur,
      );
    } on Object {
      // Réseau muet, fichier illisible, décodage en échec : un cliché de moins
      // ne doit jamais empêcher la sortie du document.
      return null;
    }
  }

  /// Range les clichés : l'avant, l'après, puis les compléments.
  ///
  /// La fiche offre deux cases. La paire réglementaire est la preuve du
  /// dossier, et c'est elle qui doit les occuper : un cliché complémentaire
  /// qui s'intercalerait devant elle en chasserait l'« après ».
  static List<Photo> _ordonner(List<Photo> photos) {
    int rang(app.PhotoKind kind) => switch (kind) {
          app.PhotoKind.before => 0,
          app.PhotoKind.after => 1,
          app.PhotoKind.extra => 2,
        };

    return [...photos]..sort((a, b) => rang(a.kind).compareTo(rang(b.kind)));
  }
}
