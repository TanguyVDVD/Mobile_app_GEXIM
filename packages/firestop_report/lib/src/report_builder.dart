import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_data.dart';
import 'template_config.dart';

/// Produit le rapport PDF d'un chantier clôturé.
///
/// **Fonction pure de (données, gabarit) vers des octets.** Aucune lecture de
/// fichier, aucun accès réseau, aucune dépendance Flutter : le même appel sert
/// l'aperçu dans l'application et la génération définitive côté serveur, sans
/// que la mise en page ne soit écrite deux fois.
class ReportBuilder {
  const ReportBuilder({this.regularFont, this.boldFont});

  /// Polices en TTF, **fortement recommandées en production**.
  ///
  /// Optionnelles parce qu'un package Dart pur ne peut pas charger d'asset
  /// Flutter : c'est à l'appelant de les fournir — depuis `rootBundle` côté
  /// application, depuis le disque de l'image côté conteneur.
  ///
  /// Sans elles, le rendu retombe sur les polices standard du format PDF.
  /// Helvetica couvre les accents français, mais **pas** l'ensemble d'Unicode :
  /// le tiret cadratin, l'apostrophe typographique, l'œ ligaturé et les points
  /// de suspension en sont absents, et sont alors **silencieusement omis** du
  /// document — un simple avertissement en console, aucune exception.
  ///
  /// Les libellés produits par ce package s'en tiennent donc au sous-ensemble
  /// sûr. Mais le nom d'un client, l'observation saisie sur le terrain ou le
  /// sous-titre d'un gabarit sont du texte libre : sur un document contractuel,
  /// perdre des caractères sans le dire n'est pas acceptable. Fournissez une
  /// police Unicode.
  final Uint8List? regularFont;
  final Uint8List? boldFont;

  Future<Uint8List> build(
    ReportData data, [
    TemplateConfig config = TemplateConfig.fallback,
  ]) async {
    final accent = PdfColor.fromInt(config.brand.accentColor);
    final theme = _theme();

    final doc = pw.Document(
      title: 'Rapport de conformité — ${data.project.name}',
      author: data.client.name,
      subject: config.cover.subtitle,
      theme: theme,
    );

    if (config.cover.enabled) {
      doc.addPage(_coverPage(data, config, accent, theme));
    }
    if (config.cover.showSummary && data.points.isNotEmpty) {
      doc.addPage(_summaryPage(data, config, accent, theme));
    }
    if (data.points.isNotEmpty) {
      doc.addPage(_pointPages(data, config, accent, theme));
    }

    return doc.save();
  }

  /// Thème de page : marges du gabarit, et papier à en-tête en fond.
  ///
  /// `FullPage(ignoreMargins: true)` fait couvrir toute la feuille au fond, y
  /// compris sous les marges — c'est bien là que se trouve l'en-tête imprimé.
  /// Le contenu, lui, reste à l'intérieur des marges.
  pw.PageTheme _pageTheme(
    TemplateConfig config,
    pw.ThemeData theme,
    Uint8List? fond,
  ) {
    final image = _image(fond);
    final m = config.margins;

    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: pw.EdgeInsets.fromLTRB(m.leftPt, m.topPt, m.rightPt, m.bottomPt),
      buildBackground: image == null
          ? null
          : (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.fill),
              ),
    );
  }

  pw.ThemeData _theme() {
    final regular = regularFont;
    final bold = boldFont;
    if (regular == null) return pw.ThemeData.base();

    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regular.buffer.asByteData()),
      bold: bold == null ? null : pw.Font.ttf(bold.buffer.asByteData()),
    );
  }

  // ---------------------------------------------------------------------------
  // Page de garde
  // ---------------------------------------------------------------------------

  pw.Page _coverPage(
    ReportData data,
    TemplateConfig config,
    PdfColor accent,
    pw.ThemeData theme,
  ) {
    final logo = config.brand.showLogo ? _image(data.clientLogo) : null;

    return pw.Page(
      pageTheme: _pageTheme(config, theme, data.letterheadCover),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.SizedBox(height: 70, child: pw.Image(logo, alignment: pw.Alignment.centerLeft))
          else
            pw.Text(
              data.client.name,
              style: const pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(height: 60),
          pw.Container(width: 90, height: 4, color: accent),
          pw.SizedBox(height: 24),
          pw.Text(
            config.cover.subtitle,
            style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            data.project.name,
            style: const pw.TextStyle(
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (data.project.description case final String description
              when description.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(description, style: const pw.TextStyle(fontSize: 11)),
          ],
          pw.Spacer(),
          _coverFacts(data, accent),
        ],
      ),
    );
  }

  pw.Widget _coverFacts(ReportData data, PdfColor accent) {
    final incomplete = data.points.length - data.completeCount;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
        _fact('Client', data.client.name),
        if (data.client.address case final String address
            when address.isNotEmpty)
          _fact('Adresse', address),
        if (data.project.startedOn case final DateTime started)
          _fact('Début des travaux', _date(started)),
        if (data.project.endedOn case final DateTime ended)
          _fact('Fin des travaux', _date(ended)),
        _fact('Traversées recensées', '${data.points.length}'),
        // Un dossier incomplet est signalé sur la page de garde, pas enterré
        // en annexe : c'est la première chose qu'un auditeur doit voir, et le
        // taire rendrait le document trompeur.
        if (incomplete > 0)
          _fact(
            'Dossiers incomplets',
            '$incomplete traversée${incomplete > 1 ? 's' : ''} sans les deux '
                'clichés réglementaires',
            color: accent,
          ),
        _fact('Document généré le', _dateTime(data.generatedAt)),
      ],
    );
  }

  pw.Widget _fact(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Récapitulatif
  // ---------------------------------------------------------------------------

  pw.MultiPage _summaryPage(
    ReportData data,
    TemplateConfig config,
    PdfColor accent,
    pw.ThemeData theme,
  ) {
    return pw.MultiPage(
      pageTheme: _pageTheme(config, theme, _bodyLetterhead(data)),
      header: (context) => _band(config.header, data, context, accent),
      footer: (context) => _band(config.footer, data, context, accent),
      build: (context) => [
        pw.Text(
          'Récapitulatif',
          style: const pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const ['N°', 'Localisation', 'Matériaux', 'Dossier'],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: accent),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
          },
          columnWidths: const {
            0: pw.FixedColumnWidth(36),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(72),
          },
          data: [
            for (final point in data.points)
              [
                point.label,
                point.location,
                point.materials.join(', '),
                point.isComplete ? 'Complet' : 'Incomplet',
              ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fiches
  // ---------------------------------------------------------------------------

  pw.MultiPage _pointPages(
    ReportData data,
    TemplateConfig config,
    PdfColor accent,
    pw.ThemeData theme,
  ) {
    final card = config.pointCard;

    return pw.MultiPage(
      pageTheme: _pageTheme(config, theme, _bodyLetterhead(data)),
      header: (context) => _band(config.header, data, context, accent),
      footer: (context) => _band(config.footer, data, context, accent),
      build: (context) => [
        for (final (index, point) in data.points.indexed) ...[
          // Une fiche par page : la plupart des cahiers des charges l'exigent,
          // pour qu'une traversée puisse être extraite et transmise seule.
          if (card.pageBreakPerPoint && index > 0) pw.NewPage(),
          ..._pointCard(point, config, accent),
          if (!card.pageBreakPerPoint) pw.SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Une fiche, **éclatée en widgets de premier niveau** et non repliée dans une
  /// seule colonne.
  ///
  /// `MultiPage` ne sait couper qu'entre les éléments que lui rend `build`, ou à
  /// l'intérieur d'un widget capable de s'étaler. Enfermer la fiche entière dans
  /// une `Column` la rendait indivisible : une observation un peu longue
  /// dépassait la hauteur de page et faisait **échouer la génération du
  /// rapport**. Sur un chantier, c'est le commentaire détaillé d'une traversée
  /// litigieuse — précisément celle qui compte — qui aurait tout bloqué.
  List<pw.Widget> _pointCard(
    ReportPoint point,
    TemplateConfig config,
    PdfColor accent,
  ) {
    final card = config.pointCard;

    return [
      pw.Container(
        width: double.infinity,
        color: accent,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (card.shows(PointField.ref))
              pw.Text(
                'Traversée n° ${point.label}',
                style: const pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            if (card.shows(PointField.location))
              pw.Text(
                point.location,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      if (card.layout != PhotoLayout.none) ...[
        _photos(point, card.layout),
        pw.SizedBox(height: 12),
      ],
      ..._details(point, card),
    ];
  }

  List<pw.Widget> _details(ReportPoint point, PointCardConfig card) {
    final description = point.description;

    return [
      if (card.shows(PointField.materials))
        _fact(
          'Matériaux utilisés',
          point.materials.isEmpty ? '-' : point.materials.join(', '),
        ),
      if (card.shows(PointField.author))
        _fact('Relevé par', point.authorName ?? '-'),
      if (card.shows(PointField.date))
        _fact('Date du relevé', _dateTime(point.capturedAt)),

      // L'observation est rendue en bloc de premier niveau, séparée de son
      // intitulé : c'est le seul champ de longueur libre, et `Text` sait
      // s'étaler sur plusieurs pages là où une `Row` ne le peut pas.
      if (card.shows(PointField.description)) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          'Observations',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          (description?.isNotEmpty ?? false) ? description! : '-',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Clichés
  // ---------------------------------------------------------------------------

  pw.Widget _photos(ReportPoint point, PhotoLayout layout) {
    if (layout == PhotoLayout.none) return pw.SizedBox();

    final before = point.photoOf(ReportPhotoKind.before);
    final after = point.photoOf(ReportPhotoKind.after);
    final extras =
        point.photos.where((p) => p.kind == ReportPhotoKind.extra).toList();

    return switch (layout) {
      PhotoLayout.twoUp => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _framed('Avant', before, 190)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _framed('Après', after, 190)),
          ],
        ),
      PhotoLayout.stacked => pw.Column(
          children: [
            _framed('Avant', before, 240),
            pw.SizedBox(height: 12),
            _framed('Après', after, 240),
          ],
        ),
      PhotoLayout.grid => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _framed('Avant', before, 150)),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _framed('Après', after, 150)),
              ],
            ),
            if (extras.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _framed('Complément', extras.first, 150),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: extras.length > 1
                        ? _framed('Complément', extras[1], 150)
                        : pw.SizedBox(),
                  ),
                ],
              ),
            ],
          ],
        ),
      PhotoLayout.none => pw.SizedBox(),
    };
  }

  pw.Widget _framed(String label, ReportPhoto? photo, double height) {
    final image = _image(photo?.bytes);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: height,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: image == null
              // Un cliché manquant ou illisible est signalé, jamais masqué :
              // une case vide laisserait croire à une erreur de mise en page,
              // là où c'est une lacune du dossier.
              ? pw.Center(
                  child: pw.Text(
                    'Cliché absent',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                )
              : pw.Image(image, fit: pw.BoxFit.cover),
        ),
      ],
    );
  }

  /// Fond des pages de contenu.
  ///
  /// Beaucoup de papiers à en-tête n'ont qu'une planche : à défaut de page de
  /// suite, on réutilise la première plutôt que de laisser les pages nues, ce
  /// qui donnerait un document visiblement bancal.
  Uint8List? _bodyLetterhead(ReportData data) =>
      data.letterheadBody ?? data.letterheadCover;

  /// Décode des octets, en refusant d'échouer.
  ///
  /// Un JPEG tronqué — transfert interrompu, cache purgé au mauvais moment —
  /// ferait autrement exploser la génération entière. Or le rapport est un
  /// livrable contractuel : mieux vaut un document signalant « cliché absent »
  /// qu'aucun document du tout.
  pw.ImageProvider? _image(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return pw.MemoryImage(bytes);
    } on Object {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Bandeaux
  // ---------------------------------------------------------------------------

  pw.Widget _band(
    BandConfig band,
    ReportData data,
    pw.Context context,
    PdfColor accent,
  ) {
    if (band.isEmpty) return pw.SizedBox();

    String fill(String template) => _interpolate(template, data, context);

    const style = pw.TextStyle(fontSize: 8, color: PdfColors.grey600);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(fill(band.left), style: style),
          pw.Text(fill(band.center), style: style),
          pw.Text(fill(band.right), style: style),
        ],
      ),
    );
  }

  String _interpolate(String template, ReportData data, pw.Context context) {
    if (template.isEmpty) return '';

    return template
        .replaceAll('{{client.name}}', data.client.name)
        .replaceAll('{{project.name}}', data.project.name)
        .replaceAll('{{page}}', '${context.pageNumber}')
        .replaceAll('{{pages}}', '${context.pagesCount}')
        .replaceAll('{{date}}', _date(data.generatedAt));
  }

  // ---------------------------------------------------------------------------
  // Dates
  // ---------------------------------------------------------------------------
  //
  // Formatage à la main plutôt que via `intl` : une seule locale est nécessaire,
  // et le package reste sans dépendance superflue pour tourner en conteneur.

  static String _date(DateTime d) =>
      '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  static String _dateTime(DateTime d) =>
      '${_date(d)} à ${_pad(d.hour)}:${_pad(d.minute)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
