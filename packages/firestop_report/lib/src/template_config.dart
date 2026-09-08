/// Disposition des clichés sur la fiche d'une traversée.
enum PhotoLayout {
  /// Avant et après côte à côte. Lecture par comparaison, la plus parlante.
  twoUp,

  /// L'un sous l'autre, en pleine largeur. Pour les traversées où le détail
  /// compte plus que la comparaison.
  stacked,

  /// Grille 2×2 : les deux obligatoires plus deux complémentaires.
  grid,

  /// Aucun cliché — récapitulatif textuel seul.
  none;

  static PhotoLayout parse(Object? value) => switch (value) {
        'twoUp' => PhotoLayout.twoUp,
        'stacked' => PhotoLayout.stacked,
        'grid' || 'grid2x2' => PhotoLayout.grid,
        'none' => PhotoLayout.none,
        _ => PhotoLayout.twoUp,
      };
}

/// Champs affichables sur une fiche.
enum PointField {
  ref,
  location,
  materials,
  description,
  author,
  date;

  static PointField? parse(Object? value) => switch (value) {
        'ref' => PointField.ref,
        'location' => PointField.location,
        'materials' => PointField.materials,
        'description' => PointField.description,
        'author' => PointField.author,
        'date' => PointField.date,
        _ => null,
      };
}

class BrandConfig {
  const BrandConfig({this.accentColor = 0xFFC8102E, this.showLogo = true});

  /// ARGB. Un rapport porte les couleurs du donneur d'ordre.
  final int accentColor;
  final bool showLogo;
}

class CoverConfig {
  const CoverConfig({
    this.enabled = true,
    this.subtitle = 'Rapport de conformité - calfeutrement de traversées',
    this.showSummary = true,
  });

  final bool enabled;
  final String subtitle;

  /// Tableau récapitulatif de toutes les traversées.
  final bool showSummary;
}

class PointCardConfig {
  const PointCardConfig({
    this.layout = PhotoLayout.twoUp,
    this.fields = const [
      PointField.ref,
      PointField.location,
      PointField.materials,
      PointField.description,
      PointField.author,
      PointField.date,
    ],
    this.pageBreakPerPoint = true,
  });

  final PhotoLayout layout;
  final List<PointField> fields;

  /// Une traversée par page. Exigé par la plupart des cahiers des charges :
  /// une fiche doit pouvoir être extraite et transmise seule.
  final bool pageBreakPerPoint;

  bool shows(PointField field) => fields.contains(field);
}

/// Marges de page, en millimètres.
///
/// Réglables uniquement à cause du papier à en-tête : chaque en-tête imprime
/// dans des zones qui lui sont propres, et le contenu doit s'en écarter. Sans
/// ce réglage, le texte se poserait par-dessus le logo ou les mentions légales
/// du document type.
class MarginConfig {
  const MarginConfig({
    this.top = 17,
    this.right = 11,
    this.bottom = 17,
    this.left = 11,
  });

  final double top;
  final double right;
  final double bottom;
  final double left;

  static const _mmParPoint = 72 / 25.4;

  double get topPt => top * _mmParPoint;
  double get rightPt => right * _mmParPoint;
  double get bottomPt => bottom * _mmParPoint;
  double get leftPt => left * _mmParPoint;
}

class BandConfig {
  const BandConfig({this.left = '', this.right = '', this.center = ''});

  final String left;
  final String right;
  final String center;

  bool get isEmpty => left.isEmpty && right.isEmpty && center.isEmpty;
}

/// Gabarit de rapport, propre à un client.
///
/// **Toute lecture est tolérante, et c'est un choix de conception.** Un rapport
/// de conformité est un document contractuel : refuser de le produire parce
/// qu'un administrateur a saisi `#GG0000` dans un champ de couleur serait bien
/// pire que de le produire en rouge par défaut. Chaque clé absente, mal typée
/// ou inconnue retombe sur une valeur sûre.
class TemplateConfig {
  const TemplateConfig({
    this.version = 1,
    this.brand = const BrandConfig(),
    this.cover = const CoverConfig(),
    this.pointCard = const PointCardConfig(),
    this.margins = const MarginConfig(),
    this.header = const BandConfig(
      left: '{{client.name}}',
      right: '{{project.name}}',
    ),
    this.footer = const BandConfig(
      center: 'Page {{page}}/{{pages}} - généré le {{date}}',
    ),
  });

  final int version;
  final BrandConfig brand;
  final CoverConfig cover;
  final PointCardConfig pointCard;
  final MarginConfig margins;
  final BandConfig header;
  final BandConfig footer;

  /// Gabarit appliqué à un client qui n'en a pas.
  static const TemplateConfig fallback = TemplateConfig();

  factory TemplateConfig.fromJson(Map<String, dynamic> json) {
    final brand = _map(json['brand']);
    final cover = _map(json['cover']);
    final card = _map(json['pointCard']);

    return TemplateConfig(
      version: _int(json['version'], 1),
      brand: BrandConfig(
        accentColor: _color(brand['accentColor'], 0xFFC8102E),
        showLogo: _bool(brand['showLogo'], true),
      ),
      cover: CoverConfig(
        enabled: _bool(cover['enabled'], true),
        subtitle: _string(
          cover['subtitle'],
          'Rapport de conformité - calfeutrement de traversées',
        ),
        showSummary: _bool(cover['showSummary'], true),
      ),
      pointCard: PointCardConfig(
        layout: PhotoLayout.parse(card['layout']),
        fields: _fields(card['fields']),
        pageBreakPerPoint: _string(card['pageBreak'], 'perPoint') == 'perPoint',
      ),
      margins: _margins(json['margins']),
      header: _band(json['header'], const BandConfig(
        left: '{{client.name}}',
        right: '{{project.name}}',
      )),
      footer: _band(json['footer'], const BandConfig(
        center: 'Page {{page}}/{{pages}} - généré le {{date}}',
      )),
    );
  }

  // ---------------------------------------------------------------------------
  // Lectures tolérantes
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static int _int(Object? value, int fallback) =>
      value is int ? value : (value is num ? value.toInt() : fallback);

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static String _string(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;

  /// `#RRGGBB` ou `#AARRGGBB`. Tout le reste retombe sur la valeur par défaut.
  static int _color(Object? value, int fallback) {
    if (value is! String) return fallback;

    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6 && hex.length != 8) return fallback;

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;

    return hex.length == 6 ? 0xFF000000 | parsed : parsed;
  }

  /// Une liste vide donnerait une fiche muette : on retombe sur tous les
  /// champs plutôt que sur rien.
  static List<PointField> _fields(Object? value) {
    if (value is! List) return const PointCardConfig().fields;

    final parsed = [
      for (final entry in value)
        if (PointField.parse(entry) case final PointField field) field,
    ];
    return parsed.isEmpty ? const PointCardConfig().fields : parsed;
  }

  /// Marges en millimètres, bornées.
  ///
  /// Le plafond n'est pas cosmétique : au-delà, la zone de contenu devient trop
  /// étroite pour deux clichés côte à côte, et la mise en page échoue à la
  /// génération — sur un document contractuel, au pire moment.
  static MarginConfig _margins(Object? value) {
    if (value is! Map<String, dynamic>) return const MarginConfig();

    double lire(String cle, double defaut) {
      final v = value[cle];
      final n = v is num ? v.toDouble() : defaut;
      return n.clamp(0, 60).toDouble();
    }

    return MarginConfig(
      top: lire('top', 17),
      right: lire('right', 11),
      bottom: lire('bottom', 17),
      left: lire('left', 11),
    );
  }

  static BandConfig _band(Object? value, BandConfig fallback) {
    if (value is! Map<String, dynamic>) return fallback;
    return BandConfig(
      left: _string(value['left'], ''),
      right: _string(value['right'], ''),
      center: _string(value['center'] ?? value['text'], ''),
    );
  }
}
