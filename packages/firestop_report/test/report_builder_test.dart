import 'dart:typed_data';

import 'package:firestop_report/firestop_report.dart';
import 'package:test/test.dart';

/// Un rapport de conformité est un livrable contractuel : il doit sortir même
/// quand le dossier est imparfait. Ces tests couvrent surtout les cas dégradés.
void main() {
  _papierEnTete();

  final generatedAt = DateTime(2026, 9, 4, 14, 30);

  /// JPEG minimal valide (1×1 px), suffisant pour exercer le décodage.
  final tinyJpeg = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, ...List<int>.filled(64, 0x08),
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11,
    0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x37, 0xFF,
    0xD9,
  ]);

  ReportPoint point(
    String label, {
    bool before = true,
    bool after = true,
    List<String> materials = const ['Mousse coupe-feu PU'],
    String? description = 'Traversée de câbles courants faibles.',
  }) {
    return ReportPoint(
      label: label,
      capturedAt: DateTime(2026, 8, 20, 9, 15),
      floor: 'R+2',
      room: 'Local technique',
      description: description,
      authorName: 'Opérateur Test',
      materials: materials,
      photos: [
        if (before)
          ReportPhoto(kind: ReportPhotoKind.before, bytes: tinyJpeg),
        if (after) ReportPhoto(kind: ReportPhotoKind.after, bytes: tinyJpeg),
      ],
    );
  }

  ReportData data(List<ReportPoint> points) => ReportData(
        client: const ReportClient(
          name: 'Client Test',
          address: 'Rue de l\'Industrie 12, 4000 Liège',
        ),
        project: ReportProject(
          name: 'Chantier Nord',
          description: 'Réfection des traversées techniques.',
          startedOn: DateTime(2026, 5, 1),
          endedOn: DateTime(2026, 8, 30),
        ),
        points: points,
        generatedAt: generatedAt,
      );

  Future<Uint8List> render(
    ReportData input, [
    TemplateConfig config = TemplateConfig.fallback,
  ]) =>
      const ReportBuilder().build(input, config);

  test('produit un PDF valide', () async {
    final bytes = await render(data([point('1'), point('2')]));

    expect(bytes.length, greaterThan(1000));
    expect(
      String.fromCharCodes(bytes.take(5)),
      '%PDF-',
      reason: 'l\'en-tete doit identifier un PDF pour tout lecteur',
    );
  });

  group('cas degrades', () {
    test('un chantier sans aucune traversee sort quand meme', () async {
      final bytes = await render(data(const []));
      expect(bytes.length, greaterThan(500));
    });

    test('une traversee sans le moindre cliche sort quand meme', () async {
      final bytes = await render(
        data([point('1', before: false, after: false)]),
      );
      expect(bytes.length, greaterThan(500));
    });

    test('un cliche corrompu ne fait pas echouer la generation', () async {
      // Transfert interrompu, cache purge au mauvais moment : les octets sont
      // la mais indecodables. Un document signalant « cliche absent » vaut
      // infiniment mieux qu'aucun document.
      final corrompu = ReportPoint(
        label: '1',
        capturedAt: DateTime(2026, 8, 20),
        photos: [
          ReportPhoto(
            kind: ReportPhotoKind.before,
            bytes: Uint8List.fromList([0xFF, 0xD8, 0x00, 0x00, 0x00]),
          ),
        ],
      );

      final bytes = await render(data([corrompu]));
      expect(bytes.length, greaterThan(500));
    });

    test('des champs vides ou absents ne cassent rien', () async {
      final nu = ReportPoint(
        label: '1',
        capturedAt: DateTime(2026, 8, 20),
      );
      final bytes = await render(data([nu]));
      expect(bytes.length, greaterThan(500));
    });

    test('un texte tres long se repartit sans deborder', () async {
      final bavard = point('1', description: 'Traversée. ' * 500);
      final bytes = await render(data([bavard]));
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('gabarits', () {
    test('chaque disposition de cliches produit un document', () async {
      for (final layout in PhotoLayout.values) {
        final config = TemplateConfig(
          pointCard: PointCardConfig(layout: layout),
        );
        final bytes = await render(data([point('1')]), config);
        expect(
          bytes.length,
          greaterThan(500),
          reason: 'la disposition $layout a echoue',
        );
      }
    });

    test('une fiche par page pese plus qu\'un flux continu', () async {
      final points = [for (var i = 1; i <= 6; i++) point('$i')];

      final paginated = await render(
        data(points),
        const TemplateConfig(
          pointCard: PointCardConfig(pageBreakPerPoint: true),
        ),
      );
      final flowing = await render(
        data(points),
        const TemplateConfig(
          pointCard: PointCardConfig(pageBreakPerPoint: false),
        ),
      );

      expect(
        paginated.length,
        greaterThan(flowing.length),
        reason: 'six pages doivent couter plus que deux ou trois',
      );
    });

    test('sans page de garde ni recapitulatif, le document est plus court',
        () async {
      final points = [point('1')];

      final complet = await render(data(points));
      final minimal = await render(
        data(points),
        const TemplateConfig(cover: CoverConfig(enabled: false, showSummary: false)),
      );

      expect(minimal.length, lessThan(complet.length));
    });
  });

  test('un dossier incomplet reste generable et signale', () async {
    final input = data([point('1'), point('2', after: false)]);

    expect(input.completeCount, 1);
    expect(input.points[1].isComplete, isFalse);

    final bytes = await render(input);
    expect(bytes.length, greaterThan(1000));
  });
}

/// Papier à en-tête et marges.
void _papierEnTete() {
  final tinyPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
    0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
    0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
    0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  ReportData avec({Uint8List? couverture, Uint8List? suite}) => ReportData(
        client: const ReportClient(name: 'Client'),
        project: const ReportProject(name: 'Chantier'),
        points: [
          ReportPoint(label: '1', capturedAt: DateTime(2026, 8, 1)),
        ],
        generatedAt: DateTime(2026, 9, 1),
        letterheadCover: couverture,
        letterheadBody: suite,
      );

  group('papier a en-tete', () {
    test('un fond de page est accepte et alourdit le document', () async {
      final sans = await const ReportBuilder().build(avec());
      final avecFond =
          await const ReportBuilder().build(avec(couverture: tinyPng));

      expect(avecFond.length, greaterThan(sans.length));
    });

    test('une page de suite distincte est acceptee', () async {
      final bytes = await const ReportBuilder()
          .build(avec(couverture: tinyPng, suite: tinyPng));
      expect(bytes.length, greaterThan(1000));
    });

    test('un fond illisible ne fait pas echouer la generation', () async {
      // Rasterisation ratee, fichier tronque : le document doit sortir nu
      // plutot que pas du tout.
      final bytes = await const ReportBuilder()
          .build(avec(couverture: Uint8List.fromList([0x89, 0x50, 0x00])));
      expect(bytes.length, greaterThan(500));
    });
  });

  group('marges', () {
    test('les marges du gabarit sont appliquees', () async {
      const large = TemplateConfig(
        margins: MarginConfig(top: 50, right: 40, bottom: 50, left: 40),
      );
      final serre = await const ReportBuilder().build(avec());
      final ample = await const ReportBuilder().build(avec(), large);

      // Meme contenu, zone utile reduite : la pagination change, donc le poids.
      expect(serre.length, isNot(equals(ample.length)));
    });

    test('une marge aberrante est bornee au lieu de casser la mise en page',
        () async {
      final c = TemplateConfig.fromJson(const {
        'margins': {'top': 5000, 'left': -80, 'right': 'beaucoup'},
      });

      expect(c.margins.top, 60, reason: 'plafonnee');
      expect(c.margins.left, 0, reason: 'plancher a zero');
      expect(c.margins.right, 11, reason: 'valeur illisible : defaut');

      final bytes = await const ReportBuilder().build(avec(), c);
      expect(bytes.length, greaterThan(500));
    });

    test('les millimetres sont convertis en points PDF', () {
      const m = MarginConfig(top: 25.4);
      expect(m.topPt, closeTo(72, 0.01));
    });
  });
}
