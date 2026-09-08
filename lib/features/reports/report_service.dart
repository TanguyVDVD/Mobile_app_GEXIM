import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:firestop_report/firestop_report.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../database/database.dart';
import '../../database/tables/enums.dart' as app;
import '../../sync/remote_gateway.dart';
import '../capture/photo_repository.dart';
import '../capture/reduction_jpeg.dart';
import 'letterhead_service.dart';

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
/// service ne fait que le nourrir : lire la base locale, rapatrier les clichés,
/// choisir le gabarit du client.
class ReportService {
  const ReportService({
    required AppDatabase db,
    required PhotoRepository photos,
    required RemoteGateway gateway,
    required LetterheadService letterheads,
    required ReductionJpeg reduction,
  })  : _db = db,
        _photos = photos,
        _gateway = gateway,
        _letterheads = letterheads,
        _reduction = reduction;

  final AppDatabase _db;
  final PhotoRepository _photos;
  final RemoteGateway _gateway;
  final LetterheadService _letterheads;

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
  Future<Uint8List> build(
    String projectId, {
    ReportProgress? onProgress,
  }) async {
    final data = await _collect(projectId, onProgress);
    final template = await _templateRowFor(data.$2);
    final config = _configOf(template);

    onProgress?.call(ReportPhase.rendering, 0, 0);

    // Habillage : logo du client et papier à en-tête. Chargés en dernier, une
    // fois les clichés prêts — ce sont des accessoires, et leur absence ne doit
    // jamais empêcher la sortie du document.
    final habillage = await _habillage(data.$2, template);
    final fonts = await _loadFonts();
    final builder = ReportBuilder(
      regularFont: fonts?.$1,
      boldFont: fonts?.$2,
    );

    final collecte = data.$1;
    return builder.build(
      ReportData(
        client: collecte.client,
        project: collecte.project,
        points: collecte.points,
        generatedAt: collecte.generatedAt,
        clientLogo: habillage.logo,
        letterheadCover: habillage.couverture,
        letterheadBody: habillage.suite,
      ),
      config,
    );
  }

  /// Logo du client et fonds de page, tous facultatifs.
  ///
  /// Chaque chargement échoue en silence : un rapport sans habillage vaut
  /// infiniment mieux qu'aucun rapport, et ces fichiers vivent sur le réseau.
  Future<({Uint8List? logo, Uint8List? couverture, Uint8List? suite})>
      _habillage(Client client, ReportTemplate? template) async {
    Uint8List? logo;
    final chemin = client.logoPath;
    if (chemin != null && chemin.isNotEmpty) {
      try {
        logo = await _gateway
            .downloadLetterhead(chemin, bucket: 'client-logos')
            .timeout(_downloadTimeout);
      } on Object {
        logo = null;
      }
    }

    final couverture = await _letterheads.rasterise(
      await _letterheads.download(template?.letterheadCoverPath),
    );
    final suite = await _letterheads.rasterise(
      await _letterheads.download(template?.letterheadBodyPath),
    );

    return (logo: logo, couverture: couverture, suite: suite);
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
    final authors = await _authorNames();
    final materials = await _materialsByPoint(projectId);

    final total = await _photoCount(projectId);
    var done = 0;
    onProgress?.call(ReportPhase.photos, 0, total);

    final points = <ReportPoint>[];
    for (final summary in summaries) {
      final photos = <ReportPhoto>[];

      for (final photo in await _db.pointDao.photosOf(summary.point.id)) {
        final bytes = await _photoBytes(photo);
        if (bytes != null) {
          photos.add(ReportPhoto(kind: _kind(photo.kind), bytes: bytes));
        }
        onProgress?.call(ReportPhase.photos, ++done, total);
      }

      points.add(
        ReportPoint(
          label: summary.label,
          capturedAt: summary.point.capturedAt,
          floor: summary.point.floor,
          room: summary.point.room,
          description: summary.point.description,
          authorName: authors[summary.point.authorId],
          materials: materials[summary.point.id] ?? const [],
          photos: photos,
        ),
      );
    }

    return (
      ReportData(
        client: ReportClient(
          name: client.name,
          address: client.address,
          contactName: client.contactName,
          contactEmail: client.contactEmail,
          contactPhone: client.contactPhone,
        ),
        project: ReportProject(
          name: project.name,
          description: project.description,
          startedOn: project.startedOn,
          endedOn: project.endedOn,
        ),
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

  Future<Map<String, String>> _authorNames() async {
    final rows = await _db.select(_db.profiles).get();
    return {
      for (final row in rows)
        row.id: row.fullName.isEmpty ? row.email : row.fullName,
    };
  }

  Future<Map<String, List<String>>> _materialsByPoint(String projectId) async {
    final rows = await _db.customSelect(
      '''
      SELECT pm.point_id AS point_id, m.label AS label
        FROM point_materials pm
        JOIN materials m ON m.id = pm.material_id
        JOIN points p    ON p.id = pm.point_id
       WHERE p.project_id = ?1
         AND pm.deleted_at IS NULL
         AND m.deleted_at IS NULL
       ORDER BY m.label ASC
      ''',
      variables: [Variable<String>(projectId)],
      readsFrom: {_db.pointMaterials, _db.materials, _db.points},
    ).get();

    final result = <String, List<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.read<String>('point_id'), () => [])
          .add(row.read<String>('label'));
    }
    return result;
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

  static ReportPhotoKind _kind(app.PhotoKind kind) => switch (kind) {
        app.PhotoKind.before => ReportPhotoKind.before,
        app.PhotoKind.after => ReportPhotoKind.after,
        app.PhotoKind.extra => ReportPhotoKind.extra,
      };

  // ---------------------------------------------------------------------------
  // Gabarit et polices
  // ---------------------------------------------------------------------------

  /// Gabarit du client, ou celui par défaut.
  ///
  /// Un JSON illisible ne bloque pas la génération : `TemplateConfig` lit avec
  /// tolérance, et une erreur de saisie retombe sur les valeurs par défaut.
  /// Refuser de produire un document contractuel pour une virgule mal placée
  /// serait un mauvais arbitrage.
  Future<ReportTemplate?> _templateRowFor(Client client) {
    final templateId = client.templateId;

    return (_db.select(_db.reportTemplates)
          ..where(
            (t) => templateId == null
                ? t.isDefault.equals(true)
                : t.id.equals(templateId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  TemplateConfig _configOf(ReportTemplate? row) {
    if (row == null) return TemplateConfig.fallback;
    try {
      final json = jsonDecode(row.config);
      return json is Map<String, dynamic>
          ? TemplateConfig.fromJson(json)
          : TemplateConfig.fallback;
    } on FormatException {
      return TemplateConfig.fallback;
    }
  }

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
