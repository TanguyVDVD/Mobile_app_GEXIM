import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_data.dart';

/// Rendu du rapport sur le formulaire « Resserrage RF — Fiche AS BUILT ».
///
/// **Chaque traversée commence sur une page neuve**, et toujours sur le même
/// fond : `template_rapport.png`. Deux traversées ne partagent jamais une page.
///
/// Une traversée peut en revanche en occuper plusieurs : au-delà des deux
/// emplacements imprimés, les clichés complémentaires passent sur des pages de
/// suite. Celles-ci ne reprennent pas le formulaire — ce serait afficher une
/// vingtaine de cases vides — mais elles portent le numéro de la traversée et
/// le chantier, pour qu'une page détachée du dossier reste identifiable.
///
/// Le formulaire est figé : il n'y a **rien** à configurer — ni marges, ni
/// couleur, ni papier à en-tête. Ce moteur ne fait qu'une chose : poser les
/// valeurs dans les cases d'un document qui existe déjà.
///
/// Comme tout ce package, c'est une fonction pure : aucune lecture de fichier,
/// aucun accès réseau, aucune dépendance Flutter. Le fond arrive en octets par
/// [ReportData.formBackground] — l'application le lit dans ses assets, un
/// conteneur serveur le lirait sur son disque, et le rendu est identique.
class AsBuiltBuilder {
  const AsBuiltBuilder({this.regularFont, this.boldFont});

  /// Polices TTF, **fortement recommandées en production**.
  ///
  /// Sans elles le rendu retombe sur Helvetica, qui omet **silencieusement**
  /// `—`, `’`, `œ` et `…`. Les libellés de ce fichier s'en tiennent au
  /// sous-ensemble sûr, mais un nom de client ou un nom de produit est du texte
  /// libre. Voir `assets/fonts/README.md`.
  final Uint8List? regularFont;
  final Uint8List? boldFont;

  /// Produit le document.
  ///
  /// [compresser] à `false` écrit les flux de contenu en clair. Le fichier est
  /// nettement plus lourd et n'a pas vocation à être livré — mais il devient
  /// lisible, donc **vérifiable** : c'est ainsi que les tests s'assurent qu'un
  /// libellé atteint bien la page, plutôt que de faire confiance au fait que la
  /// génération n'a pas levé d'exception. Le même réglage sert à inspecter un
  /// document dont la mise en page surprend.
  Future<Uint8List> build(ReportData data, {bool compresser = true}) async {
    final theme = _theme();
    final fond = _image(data.formBackground);

    final doc = pw.Document(
      title: 'Fiche AS BUILT — ${data.project.name}',
      author: data.client.name,
      subject: 'Resserrage RF',
      theme: theme,
      compress: compresser,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      // Marge nulle : le formulaire porte son propre cadre, et tout est
      // positionné au point près par rapport à lui. Une marge de page
      // décalerait le repère sans rien apporter.
      margin: pw.EdgeInsets.zero,
    );

    // Même format, sans le formulaire : les pages de suite n'ont pas de cases à
    // remplir, seulement des clichés.
    final pageNue = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: pw.EdgeInsets.zero,
    );

    if (data.points.isEmpty) {
      // Un document d'une page qui dit qu'il n'y a rien, plutôt qu'un PDF vide
      // — que le moteur refuserait d'écrire, et qui laisserait l'opérateur
      // devant un échec sans cause visible.
      doc.addPage(_page(pageTheme, fond, [_vide()]));
      return doc.save();
    }

    for (final point in data.points) {
      // `addPage` ouvre toujours une page neuve : c'est ce qui garantit qu'une
      // traversée ne commence jamais au milieu de la précédente.
      doc.addPage(_page(pageTheme, fond, _fiche(data, point)));

      final suites = _lotsDeSuite(point);
      for (final (int index, List<ReportPhoto> lot) in suites.indexed) {
        doc.addPage(
          _page(
            pageNue,
            null,
            _pageDeSuite(data, point, lot, index + 1, suites.length),
          ),
        );
      }
    }

    return doc.save();
  }

  /// Clichés qui ne tiennent pas dans les deux emplacements imprimés, par
  /// pages de [_parPageDeSuite].
  List<List<ReportPhoto>> _lotsDeSuite(ReportPoint point) {
    final reste = point.photos.skip(_Zones.emplacements).toList();

    return [
      for (var i = 0; i < reste.length; i += _parPageDeSuite)
        reste.sublist(
          i,
          math.min(i + _parPageDeSuite, reste.length),
        ),
    ];
  }

  /// Six clichés par page de suite : deux colonnes — celles du formulaire, pour
  /// que l'œil retrouve le même rythme — sur trois rangées. Une case fait alors
  /// à peu près le format d'une photo, là où deux rangées donneraient des cases
  /// hautes et étroites où tout cliché paysage flotterait au milieu du blanc.
  static const int _parPageDeSuite = 6;

  pw.Page _page(
    pw.PageTheme pageTheme,
    pw.ImageProvider? fond,
    List<pw.Widget> contenu,
  ) {
    return pw.Page(
      pageTheme: pageTheme,
      build: (context) => pw.Stack(
        children: [
          // Enfant non positionné : c'est lui qui donne sa taille au Stack, et
          // donc le repère des coordonnées. Sans lui, un Stack ne contenant que
          // des `Positioned` se réduirait à rien et tout serait rogné.
          pw.SizedBox(
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
          ),
          if (fond != null)
            pw.Positioned(
              left: _Grille.origineX,
              top: _Grille.origineY,
              child: pw.Image(
                fond,
                width: _Grille.largeur,
                height: _Grille.hauteur,
                fit: pw.BoxFit.fill,
              ),
            ),
          ...contenu,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Une fiche
  // ---------------------------------------------------------------------------

  List<pw.Widget> _fiche(ReportData data, ReportPoint point) {
    return [
      // En-tête. Le « Numéro » du haut et le « Numéro du point » du bas portent
      // la même valeur : une page valant une traversée, le numéro de fiche
      // *est* le numéro de point. Les remplir tous deux évite qu'un lecteur ne
      // cherche une numérotation de document qui n'existe pas.
      _valeur(_Zones.date, _date(point.capturedAt)),
      _valeur(_Zones.numeroFiche, point.label),

      // Les deux cases du client sont vierges dans le gabarit : les textes
      // d'exemple « logo client » et « adresse client » en ont été retirés, le
      // logo et l'adresse étant exigés à la création d'un client. Rien à
      // couvrir, donc — et une case qui resterait vide se verrait, ce qui est
      // le bon comportement pour une donnée obligatoire manquante.
      _logoOuNom(data),
      _valeurMultiligne(_Zones.adresseClient, data.client.address),

      _valeur(_Zones.numeroProjet, data.project.code ?? '-'),
      _valeur(_Zones.intituleProjet, data.project.name),
      _valeur(_Zones.purchaseOrder, point.purchaseOrder ?? '-'),
      _valeur(_Zones.batiments, point.building ?? '-'),
      _valeur(_Zones.etage, point.floor ?? '-'),
      _valeur(_Zones.numeroPoint, point.label),

      ..._photos(point),

      _valeur(_Zones.configuration, point.configuration ?? '-'),
      _valeur(_Zones.configurationDetaillee, point.configurationDetail ?? '-'),
      _valeur(_Zones.niveauEi, point.eiLevel ?? '-'),
      _valeur(_Zones.fournisseur, point.supplier ?? '-'),
      _valeur(_Zones.typeDeProduit, point.productType ?? '-'),

      // Les cinq emplacements sont parcourus en entier, et non seulement ceux
      // qui portent un produit : la position est signifiante, « Produit utilisé
      // (3) » doit rester le troisième même si le deuxième est vide.
      for (var i = 0; i < _Zones.produits.length; i++)
        _valeur(
          _Zones.produits[i],
          i < point.products.length ? point.products[i] : '',
        ),
    ];
  }

  pw.Widget _vide() {
    return _texte(
      _Zones.intituleProjet,
      'Aucune traversee relevee sur ce chantier.',
      taille: 9,
    );
  }

  // ---------------------------------------------------------------------------
  // Clichés
  // ---------------------------------------------------------------------------

  /// Remplit les deux cases imprimées du cadre « Photographies ».
  ///
  /// Exactement deux, jamais plus : ce sont celles que le formulaire dessine, et
  /// les subdiviser pour caser un troisième cliché rétrécirait la preuve pour
  /// gagner une page. Les clichés suivants vont sur une page de suite — voir
  /// [_pageDeSuite].
  ///
  /// Une case vide est **signalée**, pas laissée blanche : une case blanche se
  /// lirait comme un défaut de mise en page, là où c'est une lacune du dossier.
  List<pw.Widget> _photos(ReportPoint point) {
    return [
      for (var i = 0; i < _Zones.emplacements; i++)
        _cliche(
          _Zones.emplacementPhoto(i),
          i < point.photos.length ? point.photos[i] : null,
          signalerSiVide: true,
        ),
    ];
  }

  /// Un cliché dans sa case.
  pw.Widget _cliche(
    _Zone zone,
    ReportPhoto? photo, {
    bool signalerSiVide = false,
    bool encadrer = false,
  }) {
    final image = _image(photo?.bytes);

    if (image == null && !signalerSiVide) return _rien();

    return _place(
      zone.retrecie(2),
      image == null
          ? pw.Center(
              child: pw.Text(
                'Cliche absent',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            )
          : pw.Container(
              // Le formulaire dessine déjà ses deux cadres ; une page de suite,
              // non — d'où le trait, pour que le cliché ne flotte pas.
              decoration: encadrer
                  ? pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey600,
                        width: 0.5,
                      ),
                    )
                  : null,
              // `contain` et non `cover` : un calfeutrement se documente en
              // entier. Recadrer pour remplir la case pourrait couper le bord
              // même de la traversée — c'est-à-dire la preuve.
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pages de suite
  // ---------------------------------------------------------------------------

  /// Clichés complémentaires d'une traversée, six par page.
  ///
  /// Pas de formulaire en fond : il n'y a rien à y renseigner, et une vingtaine
  /// de cases vides derrière six photos se lirait comme une fiche bâclée.
  ///
  /// L'en-tête n'est pas décoratif. Un dossier de conformité se feuillette, se
  /// photocopie et se transmet par extraits : une page qui ne dirait pas de
  /// quelle traversée elle vient serait inexploitable dès qu'elle se détache.
  List<pw.Widget> _pageDeSuite(
    ReportData data,
    ReportPoint point,
    List<ReportPhoto> lot,
    int rang,
    int total,
  ) {
    // Sans parenthèses : le moteur PDF les échappe dans les flux de contenu,
    // ce qui rend le libellé pénible à retrouver quand on inspecte un document.
    // « suite 1/2 » dit la même chose et se lit aussi bien.
    final suite = total > 1 ? ' - suite $rang/$total' : '';

    return [
      _texte(
        _Zones.suiteEntete,
        'Traversee n° ${point.label} - ${data.project.name} - '
        'cliches complementaires$suite',
        taille: 9,
      ),
      for (final (int index, ReportPhoto photo) in lot.indexed)
        _cliche(_Zones.suiteCase(index), photo, encadrer: true),
    ];
  }

  // ---------------------------------------------------------------------------
  // Logo du client
  // ---------------------------------------------------------------------------

  pw.Widget _logoOuNom(ReportData data) {
    final logo = _image(data.clientLogo);
    final zone = _Zones.logoClient.retrecie(3);

    return _place(
      zone,
      logo == null
          ? pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                data.client.name,
                maxLines: 1,
                softWrap: false,
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            )
          : pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  // ---------------------------------------------------------------------------
  // Primitives de placement
  // ---------------------------------------------------------------------------

  /// Une valeur sur une ligne, dans sa case.
  ///
  /// `FittedBox(scaleDown)` plutôt qu'une troncature : un nom de produit un peu
  /// long rétrécit au lieu de se faire couper. Sur un document contractuel,
  /// perdre la fin d'une référence sans le dire serait la même faute que celle
  /// des caractères avalés par Helvetica.
  pw.Widget _valeur(_Zone zone, String valeur) =>
      _texte(zone, valeur, taille: 8);

  pw.Widget _texte(_Zone zone, String valeur, {required double taille}) {
    if (valeur.isEmpty) return _rien();

    return _place(
      zone.retrecie(2).decalee(gauche: 3),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            valeur,
            maxLines: 1,
            softWrap: false,
            style: pw.TextStyle(fontSize: taille),
          ),
        ),
      ),
    );
  }

  /// Une valeur qui peut occuper deux lignes — l'adresse du client.
  pw.Widget _valeurMultiligne(_Zone zone, String valeur) {
    if (valeur.isEmpty) return _rien();

    return _place(
      zone.retrecie(2).decalee(gauche: 3),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          valeur,
          maxLines: 3,
          overflow: pw.TextOverflow.clip,
          style: const pw.TextStyle(fontSize: 7.5, lineSpacing: 0.5),
        ),
      ),
    );
  }

  pw.Widget _place(_Zone zone, pw.Widget enfant) {
    return pw.Positioned(
      left: _Grille.x(zone.gauchePx),
      top: _Grille.y(zone.hautPx),
      child: pw.SizedBox(
        width: _Grille.taille(zone.largeurPx),
        height: _Grille.taille(zone.hauteurPx),
        child: enfant,
      ),
    );
  }

  pw.Widget _rien() => pw.Positioned(left: 0, top: 0, child: pw.SizedBox());

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  pw.ThemeData _theme() {
    final regular = regularFont;
    final bold = boldFont;
    if (regular == null) return pw.ThemeData.base();

    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regular.buffer.asByteData()),
      bold: bold == null ? null : pw.Font.ttf(bold.buffer.asByteData()),
    );
  }

  /// Décode des octets en refusant d'échouer.
  ///
  /// Un JPEG tronqué — transfert interrompu, cache purgé au mauvais moment —
  /// ferait autrement exploser la génération entière. Le rapport est un
  /// livrable contractuel : mieux vaut un document signalant « cliche absent »
  /// qu'aucun document du tout.
  pw.ImageProvider? _image(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return pw.MemoryImage(bytes);
    } on Object {
      return null;
    }
  }

  static String _date(DateTime d) =>
      '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

// =============================================================================
// Géométrie du formulaire
// =============================================================================
//
// Toutes les coordonnées ci-dessous sont en **pixels de `template_rapport.png`**
// (562 × 709), et non en points PDF. C'est délibéré : elles ont été relevées
// sur l'image elle-même, en détectant ses traits de tableau, et se revérifient
// donc directement dessus. Les convertir à la main en points aurait rendu tout
// contrôle ultérieur impossible.
//
// `_Grille` fait la conversion, une fois, en fonction de la place que l'image
// occupe sur la feuille A4.

/// Placement du formulaire sur la page, et conversion pixel → point.
abstract final class _Grille {
  static const double imageLargeurPx = 562;
  static const double imageHauteurPx = 709;

  /// Marge minimale autour du formulaire.
  static const double marge = 18;

  /// Facteur d'echelle, choisi pour que le formulaire tienne **entier** dans la
  /// feuille sans déformation.
  ///
  /// Le rapport de forme du PNG (0,793) n'est pas celui de l'A4 (0,707) :
  /// l'étirer pour remplir la page écraserait le formulaire en hauteur et
  /// désaccorderait toutes les cases de leurs libellés imprimés.
  static final double echelle = math.min(
    (PdfPageFormat.a4.width - 2 * marge) / imageLargeurPx,
    (PdfPageFormat.a4.height - 2 * marge) / imageHauteurPx,
  );

  static final double largeur = imageLargeurPx * echelle;
  static final double hauteur = imageHauteurPx * echelle;

  /// Centré sur la feuille : le formulaire est plus « carré » que l'A4, la
  /// place restante se répartit donc en haut et en bas.
  static final double origineX = (PdfPageFormat.a4.width - largeur) / 2;
  static final double origineY = (PdfPageFormat.a4.height - hauteur) / 2;

  static double x(double px) => origineX + px * echelle;
  static double y(double px) => origineY + px * echelle;
  static double taille(double px) => px * echelle;
}

/// Une case du formulaire, en pixels de l'image source.
class _Zone {
  const _Zone({
    required this.gauchePx,
    required this.hautPx,
    required this.droitePx,
    required this.basPx,
  });

  final double gauchePx;
  final double hautPx;
  final double droitePx;
  final double basPx;

  double get largeurPx => droitePx - gauchePx;
  double get hauteurPx => basPx - hautPx;

  /// Rentre de [marge] pixels de chaque côté, pour ne pas peindre par-dessus
  /// les traits imprimés du tableau.
  _Zone retrecie(double marge) => _Zone(
        gauchePx: gauchePx + marge,
        hautPx: hautPx + marge,
        droitePx: droitePx - marge,
        basPx: basPx - marge,
      );

  _Zone decalee({double gauche = 0}) => _Zone(
        gauchePx: gauchePx + gauche,
        hautPx: hautPx,
        droitePx: droitePx,
        basPx: basPx,
      );
}

/// Les cases du formulaire, relevées sur `template_rapport.png`.
///
/// Les valeurs viennent d'une détection des traits du tableau sur l'image :
/// lignes horizontales à y = 66, 82, 99, 133, 149, 166, 182, 199, 215, 232,
/// 248, 281, 467, 483 … 649 ; séparateurs verticaux à x = 37, 117, 195, 275,
/// 360, 525. Toute retouche du PNG impose de les relever à nouveau — et c'est
/// exactement pour cela qu'elles sont rassemblées ici, et nulle part ailleurs.
abstract final class _Zones {
  // Ligne « Date : … Numéro … »
  static const date = _Zone(gauchePx: 117, hautPx: 66, droitePx: 195, basPx: 82);
  static const numeroFiche =
      _Zone(gauchePx: 360, hautPx: 66, droitePx: 525, basPx: 82);

  // Ligne « Client | logo client | adresse client »
  static const logoClient =
      _Zone(gauchePx: 117, hautPx: 99, droitePx: 275, basPx: 133);
  static const adresseClient =
      _Zone(gauchePx: 275, hautPx: 99, droitePx: 525, basPx: 133);

  // Bloc d'identification : libellés à gauche, valeurs de x = 195 à 525.
  static const _identGauche = 195.0;
  static const _identDroite = 525.0;

  static const numeroProjet = _Zone(
    gauchePx: _identGauche,
    hautPx: 149,
    droitePx: _identDroite,
    basPx: 166,
  );
  static const intituleProjet = _Zone(
    gauchePx: _identGauche,
    hautPx: 166,
    droitePx: _identDroite,
    basPx: 182,
  );
  static const purchaseOrder = _Zone(
    gauchePx: _identGauche,
    hautPx: 182,
    droitePx: _identDroite,
    basPx: 199,
  );
  static const batiments = _Zone(
    gauchePx: _identGauche,
    hautPx: 199,
    droitePx: _identDroite,
    basPx: 215,
  );
  static const etage = _Zone(
    gauchePx: _identGauche,
    hautPx: 215,
    droitePx: _identDroite,
    basPx: 232,
  );
  static const numeroPoint = _Zone(
    gauchePx: _identGauche,
    hautPx: 232,
    droitePx: _identDroite,
    basPx: 248,
  );

  // Cadre « Photographies » : deux cases côte à côte, séparées par le trait
  // vertical imprimé à x = 275.
  static const photos =
      _Zone(gauchePx: 37, hautPx: 281, droitePx: 525, basPx: 467);
  static const double photoSeparateur = 275;

  /// Nombre de cases imprimées dans le cadre « Photographies ».
  static const int emplacements = 2;

  static _Zone emplacementPhoto(int index) => _Zone(
        gauchePx: index == 0 ? photos.gauchePx : photoSeparateur,
        hautPx: photos.hautPx,
        droitePx: index == 0 ? photoSeparateur : photos.droitePx,
        basPx: photos.basPx,
      );

  // ---------------------------------------------------------------------------
  // Pages de suite
  // ---------------------------------------------------------------------------
  //
  // Même repère que le formulaire, pour que les deux types de page s'alignent :
  // mêmes marges latérales, et la même colonne médiane à x = 275.

  static const suiteEntete =
      _Zone(gauchePx: 37, hautPx: 22, droitePx: 525, basPx: 46);

  static const _suiteHaut = 60.0;
  static const _suiteBas = 690.0;
  static const _suiteRangees = 3;

  /// Case d'un cliché complémentaire, de 0 à 5 : deux colonnes, trois rangées.
  static _Zone suiteCase(int index) {
    const hauteur = (_suiteBas - _suiteHaut) / _suiteRangees;
    final rangee = index ~/ 2;

    return _Zone(
      gauchePx: index.isEven ? photos.gauchePx : photoSeparateur,
      hautPx: _suiteHaut + rangee * hauteur,
      droitePx: index.isEven ? photoSeparateur : photos.droitePx,
      basPx: _suiteHaut + (rangee + 1) * hauteur,
    );
  }

  // Bloc des caractéristiques : libellés à gauche, valeurs de x = 275 à 525.
  static const _caracGauche = 275.0;
  static const _caracDroite = 525.0;

  static _Zone _carac(double haut, double bas) => _Zone(
        gauchePx: _caracGauche,
        hautPx: haut,
        droitePx: _caracDroite,
        basPx: bas,
      );

  static final configuration = _carac(483, 500);
  static final configurationDetaillee = _carac(500, 516);
  static final niveauEi = _carac(516, 533);
  static final fournisseur = _carac(533, 549);

  /// Ligne « Type de produit utilisé » : manchon, mortier, mousse 1 comp…
  static final typeDeProduit = _carac(549, 566);

  /// Les cinq emplacements « Produit utilisé (1) » à « (5) », dans l'ordre.
  static final produits = <_Zone>[
    _carac(566, 582),
    _carac(582, 599),
    _carac(599, 615),
    _carac(615, 632),
    _carac(632, 649),
  ];
}
