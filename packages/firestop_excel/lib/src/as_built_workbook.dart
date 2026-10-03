import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'report_data.dart';

/// Le modèle fourni n'a pas la forme attendue.
///
/// Levée plutôt que de produire un classeur approximatif : les emplacements
/// sont relevés sur **ce** modèle, et un classeur rempli de travers est pire
/// qu'un refus — il s'ouvre, et il est faux.
class ModeleInattendu implements Exception {
  const ModeleInattendu(this.message);

  final String message;

  @override
  String toString() => 'Modèle Excel inattendu : $message';
}

/// Remplit le classeur « AS BUILT Resserrages RF » : **une feuille par
/// traversée**, dans le modèle du bureau.
///
/// Une fonction pure `(modèle, données) → octets`. Le modèle arrive en octets :
/// ce package ne lit aucun fichier.
///
/// ## Le classeur est retouché, pas reconstruit
///
/// Un `.xlsm` est une archive ZIP de fichiers XML. On n'en réécrit que ce qui
/// change — les feuilles de fiche — et tout le reste traverse **octet pour
/// octet** : les macros (`vbaProject.bin`), les styles, la feuille « Menus
/// déroulants », l'image d'en-tête. C'est la raison de ne pas passer par une
/// bibliothèque de tableur : toutes celles qui existent en Dart relisent le
/// classeur dans leur propre modèle et le réécrivent, en perdant au passage
/// les macros, les boutons et les listes déroulantes.
///
/// ## Ce qu'une feuille garde du modèle
///
/// Chaque feuille est une copie de la première feuille du modèle, donc :
///
///  * ses trois boutons, toujours reliés à leurs macros — « Nouveau point »
///    reste utilisable pour ajouter une fiche à la main ;
///  * ses listes déroulantes, alimentées par « Menus déroulants » ;
///  * ses formules : le numéro de fiche (G5), le numéro de projet (E10) et le
///    numéro du point (E15) se calculent depuis K5 et M5 ; la case « Client »
///    montre ce qui se trouve en K7 — voir [_remplir].
///
/// ## Les emplacements
///
/// Relevés dans le XML du modèle, et regroupés ci-dessous. **Toute retouche
/// du modèle impose de les revérifier** — `as_built_workbook_test.dart` échoue
/// si une cellule attendue a disparu.
class AsBuiltWorkbook {
  const AsBuiltWorkbook();

  /// Texte de L5, que la formule du numéro de fiche intercale entre le numéro
  /// de projet et celui du point. Recopié ici pour écrire la valeur calculée
  /// de G5 : sans elle, un lecteur qui ne recalcule pas — aperçu de courriel,
  /// visionneuse de tablette — afficherait le numéro de la fiche d'exemple.
  static const _separateurNumero = '-As Built-';

  static const _feuilleModele = 'xl/worksheets/sheet1.xml';
  static const _dessinModele = 'xl/drawings/drawing1.xml';
  static const _boutonsModele = 'xl/drawings/vmlDrawing1.vml';
  static const _enteteModele = 'xl/drawings/vmlDrawing2.vml';
  static const _enteteRelsModele = 'xl/drawings/_rels/vmlDrawing2.vml.rels';
  static const _controleModele = 'xl/ctrlProps/ctrlProp1.xml';

  /// Les deux feuilles d'exemple du modèle et tout ce qui leur appartient.
  /// Retirées du classeur produit : elles sont remplacées par les fiches.
  static final _aRetirer = RegExp(
    r'^xl/(worksheets/(_rels/)?sheet[12]\.xml(\.rels)?'
    r'|drawings/drawing[12]\.xml'
    r'|drawings/(_rels/)?vmlDrawing[1-4]\.vml(\.rels)?'
    r'|ctrlProps/ctrlProp[1-6]\.xml'
    // Réglages propres à l'imprimante du poste qui a enregistré le modèle.
    r'|printerSettings/printerSettings[12]\.bin'
    // Ordre de calcul : il désigne les feuilles d'exemple. Excel le
    // reconstruit à l'ouverture.
    r'|calcChain\.xml)$',
  );

  // Les cases qui reçoivent une image : des cellules fusionnées, que l'image
  // remplit. Colonnes et lignes comptées à partir de zéro. Leurs dimensions
  // ne sont **pas** écrites ici : elles sont lues dans la feuille du modèle,
  // voir [_Case.lire].

  /// C18:E18 et F18:H18, les deux cases photo.
  static const _casesPhoto = [
    (colonne: 2, colonnes: 3, ligne: 17, lignes: 1),
    (colonne: 5, colonnes: 3, ligne: 17, lignes: 1),
  ];

  /// D7:E8, la case « Client » de la fiche.
  static const _caseClient = (colonne: 3, colonnes: 2, ligne: 6, lignes: 2);

  /// K7:L8, hors de la zone imprimée : là où le modèle attend le client.
  static const _caseSaisieClient =
      (colonne: 10, colonnes: 2, ligne: 6, lignes: 2);

  /// Marge haute de la mise en page de chaque fiche, en centimètres — l'unité
  /// dans laquelle Excel l'affiche. Le fichier, lui, la compte en pouces.
  ///
  /// Imposée ici plutôt que laissée au modèle (1,9 cm) : l'image d'en-tête du
  /// bureau fait près de 3 cm de haut et débordait sur le titre de la fiche à
  /// l'impression. À 4,5 cm, la fiche commence sous l'en-tête. La macro
  /// « Nouveau point » copie la feuille, donc la marge avec.
  static const _margeHautCm = 4.5;

  /// Rang, dans la plage d'identifiants de sa feuille, de l'image liée de la
  /// case « Client ». Les boutons occupent 1 à 3.
  static const _rangImageLiee = 5;

  /// Produit le classeur. Rend les octets du `.xlsm`.
  Uint8List build({required Uint8List modele, required ReportData data}) {
    if (data.points.isEmpty) {
      // Un classeur sans feuille de fiche n'aurait plus de quoi faire tourner
      // « Nouveau point », qui copie la feuille active.
      throw ArgumentError.value(
        data.points,
        'data.points',
        'Au moins une traversée est nécessaire',
      );
    }

    final parts = <String, Uint8List>{
      for (final file in ZipDecoder().decodeBytes(modele))
        if (file.isFile) file.name: file.readBytes()!,
    };

    String lire(String nom) {
      final octets = parts[nom];
      if (octets == null) throw ModeleInattendu('« $nom » est absent');
      return utf8.decode(octets);
    }

    final feuille = lire(_feuilleModele);
    final dessin = lire(_dessinModele);
    final boutons = lire(_boutonsModele);
    final entete = lire(_enteteModele);
    final enteteRels = parts[_enteteRelsModele];
    final controle = parts[_controleModele];
    if (enteteRels == null || controle == null) {
      throw const ModeleInattendu('boutons ou en-tête incomplets');
    }

    // Les dimensions des cases à image, telles que **ce** modèle les donne.
    final casesPhoto = [
      for (final c in _casesPhoto) _Case.lire(feuille, c),
    ];
    final caseClient = _Case.lire(feuille, _caseClient);
    final caseSaisieClient = _Case.lire(feuille, _caseSaisieClient);

    var types = lire('[Content_Types].xml');
    var classeur = lire('xl/workbook.xml');
    var classeurRels = lire('xl/_rels/workbook.xml.rels');

    // --- Les feuilles d'exemple sortent ------------------------------------

    final idsRetires = <String>{};
    classeurRels = classeurRels.replaceAllMapped(
      RegExp(r'<Relationship [^>]*/>'),
      (m) {
        final rel = m[0]!;
        final cible = RegExp(r'Target="([^"]*)"').firstMatch(rel)?[1] ?? '';
        if (!_aRetirer.hasMatch('xl/$cible')) return rel;
        idsRetires.add(RegExp(r'Id="([^"]*)"').firstMatch(rel)![1]!);
        return '';
      },
    );
    types = types.replaceAllMapped(
      RegExp(r'<Override PartName="/([^"]*)"[^>]*/>'),
      (m) => _aRetirer.hasMatch(m[1]!) ? '' : m[0]!,
    );
    parts.removeWhere((nom, _) => _aRetirer.hasMatch(nom));

    // Les feuilles qui restent — « Menus déroulants ».
    final feuillesGardees = [
      for (final m in RegExp(r'<sheet [^>]*/>').allMatches(classeur))
        if (!idsRetires
            .contains(RegExp(r'r:id="([^"]*)"').firstMatch(m[0]!)?[1]))
          m[0]!,
    ];

    // --- Le logo -------------------------------------------------------------

    final logo = data.clientLogo;
    final extensionLogo = logo == null ? null : _extension(logo);
    final avecLogo = logo != null && extensionLogo != null;
    // Un seul exemplaire dans le classeur, que chaque feuille désigne.
    if (avecLogo) parts['xl/media/logoClient.$extensionLogo'] = logo;

    // --- Une feuille par traversée ------------------------------------------

    final noms = _NomsDeFeuille({
      for (final f in feuillesGardees)
        _desechapper(RegExp(r'name="([^"]*)"').firstMatch(f)?[1] ?? ''),
    });
    final extensionsImage = <String>{};
    final balisesFeuille = StringBuffer();
    final zonesImpression = StringBuffer();
    final relsFeuilles = StringBuffer();
    final typesFeuilles = StringBuffer();

    for (final (index, point) in data.points.indexed) {
      final n = index + 1;
      final nom = noms.pour(point.number);

      // Chaque feuille reçoit sa propre plage d'identifiants de formes : deux
      // feuilles qui partageraient les leurs feraient « réparer » le classeur
      // à l'ouverture, boutons perdus.
      String formes(String xml) {
        var sortie = xml;
        for (var k = 1; k <= 3; k++) {
          final avant = 1024 + k;
          final apres = n * 1024 + k;
          sortie = sortie
              .replaceAll('_x0000_s$avant', '_x0000_s$apres')
              .replaceAll('shapeId="$avant"', 'shapeId="$apres"')
              .replaceAll('<xdr:cNvPr id="$avant"', '<xdr:cNvPr id="$apres"');
        }
        // Le numéro de plage du fichier VML. Selon qu'Excel en ligne ou
        // Excel de bureau a enregistré le modèle en dernier, la balise est
        // écrite `…></o:idmap>` ou `…/>` : les deux sont prises.
        return sortie.replaceAllMapped(
          RegExp(r'(<o:idmap v:ext="edit" data=")1(")'),
          (m) => '${m[1]}$n${m[2]}',
        );
      }

      // Clichés : les deux premiers, dans les deux cases.
      final ancres = StringBuffer();
      final relsDessin = StringBuffer();
      for (final (rang, photo) in point.photos.take(2).indexed) {
        final extension = _extension(photo.bytes);
        if (extension == null) continue;
        extensionsImage.add(extension);

        final media = 'photo${n}_${rang + 1}.$extension';
        parts['xl/media/$media'] = photo.bytes;
        relsDessin.write(
          '<Relationship Id="rIdPhoto${rang + 1}" Type="$_relImage" '
          'Target="../media/$media"/>',
        );
        ancres.write(
          _ancre(
            casesPhoto[rang],
            id: rang + 2,
            nom: 'Photo ${rang + 1}',
            rel: 'rIdPhoto${rang + 1}',
          ),
        );
      }

      // Le logo : posé sur K7, et **montré** dans la case « Client » par une
      // image liée à K7 — voir [_imageLiee].
      final idLiee = n * 1024 + _rangImageLiee;
      if (avecLogo) {
        relsDessin.write(
          '<Relationship Id="rIdLogo" Type="$_relImage" '
          'Target="../media/logoClient.$extensionLogo"/>',
        );
        ancres
          ..write(
            _ancre(
              caseSaisieClient,
              id: 4,
              nom: 'Logo client',
              rel: 'rIdLogo',
            ),
          )
          ..write(_imageLiee(caseClient, id: idLiee, rel: 'rIdLogo'));
      }

      parts['xl/worksheets/fiche$n.xml'] = _octets(
        _remplir(
          formes(feuille),
          data: data,
          point: point,
          premiere: index == 0,
          // Les deux modules de feuille du projet VBA retrouvent chacun une
          // feuille ; les suivantes n'en ont pas, et Excel leur en crée un.
          nomDeCode: switch (index) {
            0 => 'Feuil1',
            1 => 'Feuil36',
            _ => null
          },
          avecLogo: avecLogo,
        ),
      );
      parts['xl/worksheets/_rels/fiche$n.xml.rels'] = _octets(
        '$_enteteXml<Relationships xmlns="$_nsRels">'
        '<Relationship Id="rId2" Type="$_relOffice/drawing" '
        'Target="../drawings/fiche$n.xml"/>'
        '<Relationship Id="rId3" Type="$_relOffice/vmlDrawing" '
        'Target="../drawings/ficheBoutons$n.vml"/>'
        '<Relationship Id="rId4" Type="$_relOffice/vmlDrawing" '
        'Target="../drawings/ficheEntete$n.vml"/>'
        '${[
          for (var k = 1; k <= 3; k++)
            '<Relationship Id="rId${k + 4}" Type="$_relOffice/ctrlProp" '
                'Target="../ctrlProps/fiche${n}_$k.xml"/>',
        ].join()}'
        '</Relationships>',
      );

      parts['xl/drawings/fiche$n.xml'] = _octets(
        formes(dessin)
            // Identifiant de création, propre à chaque forme : le recopier
            // sur toutes les feuilles en ferait des doublons. Facultatif.
            .replaceAll(
              RegExp(
                r'<a:ext uri="\{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236\}">'
                r'.*?</a:ext>',
              ),
              '',
            )
            .replaceFirst('</xdr:wsDr>', '$ancres</xdr:wsDr>'),
      );
      if (relsDessin.isNotEmpty) {
        parts['xl/drawings/_rels/fiche$n.xml.rels'] = _octets(
          '$_enteteXml<Relationships xmlns="$_nsRels">$relsDessin'
          '</Relationships>',
        );
      }
      parts['xl/drawings/ficheBoutons$n.vml'] = _octets(
        avecLogo
            ? formes(boutons).replaceFirst(
                '</xml>',
                '${_imageLieeVml(caseClient, id: idLiee)}</xml>',
              )
            : formes(boutons),
      );
      if (avecLogo) {
        parts['xl/drawings/_rels/ficheBoutons$n.vml.rels'] = _octets(
          '$_enteteXml<Relationships xmlns="$_nsRels">'
          '<Relationship Id="rId1" Type="$_relImage" '
          'Target="../media/logoClient.$extensionLogo"/></Relationships>',
        );
      }
      parts['xl/drawings/ficheEntete$n.vml'] = _octets(formes(entete));
      parts['xl/drawings/_rels/ficheEntete$n.vml.rels'] = enteteRels;
      for (var k = 1; k <= 3; k++) {
        parts['xl/ctrlProps/fiche${n}_$k.xml'] = controle;
        typesFeuilles.write(
          '<Override PartName="/xl/ctrlProps/fiche${n}_$k.xml" '
          'ContentType="application/vnd.ms-excel.controlproperties+xml"/>',
        );
      }
      typesFeuilles
        ..write(
          '<Override PartName="/xl/worksheets/fiche$n.xml" ContentType="'
          'application/vnd.openxmlformats-officedocument.spreadsheetml.'
          'worksheet+xml"/>',
        )
        ..write(
          '<Override PartName="/xl/drawings/fiche$n.xml" ContentType="'
          'application/vnd.openxmlformats-officedocument.drawing+xml"/>',
        );

      relsFeuilles.write(
        '<Relationship Id="rIdFiche$n" Type="$_relOffice/worksheet" '
        'Target="worksheets/fiche$n.xml"/>',
      );
      // Les identifiants 1 et 2 sont ceux des feuilles du modèle ; « Menus
      // déroulants » garde le sien, les fiches prennent la suite de 1000 pour
      // ne jamais le croiser.
      balisesFeuille.write(
        '<sheet name="${_echapper(nom)}" sheetId="${1000 + n}" '
        'r:id="rIdFiche$n"/>',
      );
      zonesImpression.write(
        '<definedName name="_xlnm.Print_Area" localSheetId="$index">'
        "${_echapper("'${nom.replaceAll("'", "''")}'")}"
        r'!$B$2:$I$32</definedName>',
      );
    }

    // --- Le classeur recousu ------------------------------------------------

    classeur = classeur
        .replaceFirst(
          RegExp(r'<sheets>.*?</sheets>'),
          '<sheets>$balisesFeuille${feuillesGardees.join()}</sheets>',
        )
        .replaceFirst(
          RegExp(r'<definedNames>.*?</definedNames>'),
          '<definedNames>$zonesImpression</definedNames>',
        )
        // Le modèle s'ouvrait sur sa seconde feuille.
        .replaceFirst(RegExp(r' firstSheet="\d+"'), '')
        .replaceFirst(RegExp(r' activeTab="\d+"'), '');
    if (!classeur.contains(balisesFeuille.toString())) {
      throw const ModeleInattendu('liste des feuilles introuvable');
    }

    classeurRels = classeurRels.replaceFirst(
      '</Relationships>',
      '$relsFeuilles</Relationships>',
    );
    for (final extension in {...extensionsImage, if (avecLogo) extensionLogo}) {
      if (!types.contains('Extension="$extension"')) {
        types = types.replaceFirst(
          '<Override',
          '<Default Extension="$extension" '
              'ContentType="image/${extension == 'jpg' ? 'jpeg' : extension}"/>'
              '<Override',
        );
      }
    }
    types = types.replaceFirst('</Types>', '$typesFeuilles</Types>');

    parts['[Content_Types].xml'] = _octets(types);
    parts['xl/workbook.xml'] = _octets(classeur);
    parts['xl/_rels/workbook.xml.rels'] = _octets(classeurRels);

    return _archiver(parts);
  }

  // ---------------------------------------------------------------------------
  // Une fiche
  // ---------------------------------------------------------------------------

  String _remplir(
    String xml, {
    required ReportData data,
    required ReportPoint point,
    required bool premiere,
    required String? nomDeCode,
    required bool avecLogo,
  }) {
    final code = (point.projectCode ?? data.project.code)?.trim() ?? '';
    final numero = point.number?.trim() ?? '';

    final f = _Feuille(
      xml
          // Marques de révision d'Excel : recopiées, elles seraient en double
          // d'une feuille à l'autre. Facultatives.
          .replaceAll(RegExp(r' xr:uid="\{[^"]*\}"'), '')
          .replaceFirst(
            'codeName="Feuil1"',
            nomDeCode == null ? '' : 'codeName="$nomDeCode"',
          )
          .replaceFirst(
            RegExp(r'<sheetViews>.*?</sheetViews>'),
            '<sheetViews><sheetView${premiere ? ' tabSelected="1"' : ''} '
            'zoomScale="115" zoomScaleNormal="115" workbookViewId="0">'
            '<selection activeCell="E15" sqref="E15:H15"/></sheetView>'
            '</sheetViews>',
          )
          // La référence aux réglages d'imprimante, retirés du classeur.
          .replaceFirst(RegExp(r'(<pageSetup [^>]*?) r:id="rId1"'), r'$1')
          // La marge haute, voir [_margeHautCm].
          .replaceFirstMapped(
            RegExp(r'(<pageMargins [^>]*?top=")[^"]*(")'),
            (m) => '${m[1]}${(_margeHautCm / 2.54).toStringAsFixed(4)}${m[2]}',
          ),
    )
      // En-tête
      ..nombre('D5', _jourExcel(point.capturedAt))
      ..texte('K5', code)
      // Le numéro du point, tel que saisi : c'est de M5 que la fiche le tire,
      // pour son numéro (G5) comme pour la ligne « Numéro du point » (E15).
      ..texte('M5', numero)
      // Le modèle écrit `CONCAT(K5,L5,M5)`. Cette fonction n'existe que dans
      // les Excel récents et sous licence : ailleurs, le numéro de fiche
      // vire à « #NOM? » au premier recalcul — donc à chaque « Nouveau
      // point ». L'opérateur `&` dit la même chose dans toutes les versions.
      ..formule('G5', 'K5&L5&M5', '$code$_separateurNumero$numero')
      ..texte('F7', data.client.address)
      // Identification
      ..formule('E10', 'K5', code)
      ..texte('E11', point.projectName ?? data.project.name)
      ..texte('E12', point.purchaseOrder)
      ..texte('E13', point.building)
      ..texte('E14', point.floor)
      // Caractéristiques
      ..texte('F20', point.configuration)
      ..texte('F21', point.configurationDetail)
      ..texte('F22', point.eiLevel)
      ..texte('F23', point.supplier)
      ..texte('F24', point.productType);

    // « Numéro du point » reprend M5 par formule. Le style du modèle sur
    // cette case est un format de date (« mmm-aa ») ; on prend celui de la
    // ligne « Intitulé Projet », **lu dans le modèle** — son numéro change à
    // chaque fois qu'Excel réenregistre le classeur. Sans numéro, pas de
    // formule : `=M5` sur une cellule
    // vide afficherait « 0 », un numéro que personne n'a donné.
    final styleVoisin = f.styleDe('E11');
    if (numero.isEmpty) {
      f.texte('E15', '', style: styleVoisin);
    } else {
      f.formule('E15', 'M5', numero, style: styleVoisin);
    }

    for (var i = 0; i < 5; i++) {
      f.texte('F${25 + i}', i < point.products.length ? point.products[i] : '');
    }

    // La case « Client » (D7) vaut `=K7` : écrire en K7 suffit à remplir la
    // fiche. Mais une formule ne reporte pas une image. Avec un logo, les deux
    // cellules sont vidées — sinon la fiche afficherait le « 0 » d'une
    // référence vide sous le logo — et le lien de D7 vers K7 est tenu par une
    // image liée, voir [_imageLiee].
    if (avecLogo) {
      f
        ..texte('K7', '')
        ..texte('D7', '');
    } else {
      f
        ..texte('K7', data.client.name)
        ..formule('D7', 'K7', data.client.name);
    }

    return f.xml;
  }

  /// Numéro de série d'un jour, tel qu'Excel le compte.
  static int _jourExcel(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(1899, 12, 30))
          .inDays;

  // ---------------------------------------------------------------------------
  // Clichés
  // ---------------------------------------------------------------------------

  /// Ancre une image sur une case, qu'elle **remplit entièrement**.
  ///
  /// C'est le geste de la macro « Insérer Photo » du modèle : l'image prend
  /// les dimensions de la cellule, et les suit si on la redimensionne. Elle
  /// est donc étirée quand ses proportions ne sont pas celles de la case — un
  /// cliché pris en hauteur, un logo carré. Voulu par le bureau : une case
  /// pleine, plutôt qu'une image centrée entre deux marges.
  static String _ancre(
    _Case c, {
    required int id,
    required String nom,
    required String rel,
  }) {
    return '<xdr:twoCellAnchor editAs="twoCell">${c.ancre}'
        '<xdr:pic><xdr:nvPicPr>'
        // Petits identifiants : hors des plages réservées aux boutons.
        '<xdr:cNvPr id="$id" name="${_echapper(nom)}"/>'
        '<xdr:cNvPicPr><a:picLocks/></xdr:cNvPicPr>'
        '</xdr:nvPicPr><xdr:blipFill>'
        '<a:blip xmlns:r="$_relOffice" r:embed="$rel"/>'
        '<a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
        '<xdr:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="${c.largeurEmu}" cy="${c.hauteurEmu}"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>'
        '</xdr:pic><xdr:clientData/></xdr:twoCellAnchor>';
  }

  // ---------------------------------------------------------------------------
  // L'image liée de la case « Client »
  // ---------------------------------------------------------------------------
  //
  // Le modèle fait dire à la case « Client » ce que contient K7 (`=K7`). Une
  // formule ne sait pas reporter une image ; l'outil d'Excel qui le fait est
  // l'**image liée** (« appareil photo ») : une image dont le contenu est, en
  // permanence, ce qui s'affiche dans une plage — ici K7, logo compris. Changer
  // le logo posé sur K7 change la fiche, comme le modèle le veut.
  //
  // Structure relevée sur un classeur où Excel a collé une telle image, pas
  // déduite d'une documentation. Elle tient en deux morceaux qui se désignent
  // par le même identifiant : une image du dessin, et une forme de l'ancien
  // format VML qui porte la plage visée.
  //
  // L'autre voie — l'image placée *dans* la cellule, que `=K7` reporte — a été
  // essayée et écartée : le classeur se rouvre sur « #INCONNU! » dès que le
  // poste n'a pas d'Excel sous licence active.

  static String _imageLiee(_Case c, {required int id, required String rel}) {
    const a14 = 'http://schemas.microsoft.com/office/drawing/2010/main';
    return '<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/'
        'markup-compatibility/2006"><mc:Choice xmlns:a14="$a14" '
        'Requires="a14"><xdr:twoCellAnchor editAs="twoCell">${c.ancre}'
        '<xdr:pic><xdr:nvPicPr>'
        '<xdr:cNvPr id="$id" name="Client"/>'
        '<xdr:cNvPicPr><a:picLocks noChangeArrowheads="1"/><a:extLst>'
        '<a:ext uri="{84589F7E-364E-4C9E-8A38-B11213B215E9}">'
        '<a14:cameraTool cellRange="\$K\$7" spid="_x0000_s$id"/>'
        '</a:ext></a:extLst></xdr:cNvPicPr></xdr:nvPicPr>'
        // L'image de repli, montrée tant qu'Excel n'a pas redessiné la plage :
        // le logo lui-même.
        '<xdr:blipFill><a:blip xmlns:r="$_relOffice" r:embed="$rel"/>'
        '<a:srcRect/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
        '<xdr:spPr bwMode="auto"><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="${c.largeurEmu}" cy="${c.hauteurEmu}"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></xdr:spPr>'
        '</xdr:pic><xdr:clientData/></xdr:twoCellAnchor></mc:Choice>'
        '<mc:Fallback/></mc:AlternateContent>';
  }

  /// Le pendant VML de [_imageLiee], ajouté au fichier des boutons.
  static String _imageLieeVml(_Case c, {required int id}) {
    return '<v:shapetype id="_x0000_t75" coordsize="21600,21600" o:spt="75" '
        'o:preferrelative="t" path="m@4@5l@4@11@9@11@9@5xe" filled="f" '
        'stroked="f"><v:stroke joinstyle="miter"></v:stroke><v:formulas>'
        '<v:f eqn="if lineDrawn pixelLineWidth 0"></v:f>'
        '<v:f eqn="sum @0 1 0"></v:f><v:f eqn="sum 0 0 @1"></v:f>'
        '<v:f eqn="prod @2 1 2"></v:f>'
        '<v:f eqn="prod @3 21600 pixelWidth"></v:f>'
        '<v:f eqn="prod @3 21600 pixelHeight"></v:f>'
        '<v:f eqn="sum @0 0 1"></v:f><v:f eqn="prod @6 1 2"></v:f>'
        '<v:f eqn="prod @7 21600 pixelWidth"></v:f>'
        '<v:f eqn="sum @8 21600 0"></v:f>'
        '<v:f eqn="prod @7 21600 pixelHeight"></v:f>'
        '<v:f eqn="sum @10 21600 0"></v:f></v:formulas>'
        '<v:path o:extrusionok="f" gradientshapeok="t" o:connecttype="rect">'
        '</v:path><o:lock v:ext="edit" aspectratio="t"></o:lock></v:shapetype>'
        '<v:shape id="Client" o:spid="_x0000_s$id" type="#_x0000_t75" '
        'style="position:absolute;margin-left:147pt;margin-top:99pt;'
        'width:${c.largeurEmu / 12700}pt;height:${c.hauteurEmu / 12700}pt;'
        'z-index:9;visibility:visible">'
        '<v:imagedata o:relid="rId1" o:title=""></v:imagedata>'
        '<x:ClientData ObjectType="Pict"><x:SizeWithCells></x:SizeWithCells>'
        '<x:Anchor>${c.ancreVml}</x:Anchor>'
        '<x:FmlaPict>\$K\$7</x:FmlaPict><x:CF>Pict</x:CF>'
        '<x:Camera></x:Camera></x:ClientData></v:shape>';
  }

  /// `jpeg` ou `png` d'après la signature, `null` pour tout autre contenu.
  static String? _extension(Uint8List o) {
    if (o.length > 3 && o[0] == 0xFF && o[1] == 0xD8 && o[2] == 0xFF) {
      return 'jpeg';
    }
    if (o.length > 8 &&
        o[0] == 0x89 &&
        o[1] == 0x50 &&
        o[2] == 0x4E &&
        o[3] == 0x47) {
      return 'png';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Archive
  // ---------------------------------------------------------------------------

  static Uint8List _archiver(Map<String, Uint8List> parts) {
    final archive = Archive();

    // La table des types en tête, comme l'écrit Excel : certains lecteurs
    // s'attendent à la trouver là.
    const premier = '[Content_Types].xml';
    for (final nom in [premier, ...parts.keys.where((n) => n != premier)]) {
      final fichier = ArchiveFile.bytes(nom, parts[nom]!);
      // Un JPEG ou un PNG est déjà compressé : le repasser dans Deflate
      // coûterait du temps sur chaque cliché pour ne rien gagner.
      if (nom.startsWith('xl/media/')) {
        fichier.compression = CompressionType.none;
      }
      archive.add(fichier);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  // ---------------------------------------------------------------------------
  // XML
  // ---------------------------------------------------------------------------

  static const _enteteXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const _nsRels =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _relOffice =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _relImage = '$_relOffice/image';

  static Uint8List _octets(String xml) => utf8.encode(xml);
}

/// Une case du modèle qui reçoit une image : cellules fusionnées, repérées par
/// leur première colonne et leur première ligne (à partir de zéro).
class _Case {
  const _Case({
    required this.colonne,
    required this.largeurs,
    required this.ligne,
    required this.hauteurs,
  });

  /// Lit dans la feuille du modèle les dimensions d'une plage de cellules.
  ///
  /// Lues et non recopiées : Excel retouche largeurs et hauteurs à chaque
  /// réenregistrement du modèle (une ligne perd sa hauteur explicite, une
  /// colonne gagne un centième). Des constantes auraient décalé les images
  /// sans que rien ne le signale.
  factory _Case.lire(
    String feuille,
    ({int colonne, int colonnes, int ligne, int lignes}) plage,
  ) {
    double attribut(String nom, double defaut) =>
        double.tryParse(
          RegExp('$nom="([\\d.]+)"').firstMatch(feuille)?[1] ?? '',
        ) ??
        defaut;

    final largeurParDefaut = attribut('defaultColWidth', 8.43);
    final hauteurParDefaut = attribut('defaultRowHeight', 15);
    final colonnes = [
      for (final m in RegExp(
        r'<col min="(\d+)" max="(\d+)" width="([\d.]+)"',
      ).allMatches(feuille))
        (int.parse(m[1]!), int.parse(m[2]!), double.parse(m[3]!)),
    ];

    // Une largeur Excel se compte en caractères de la police par défaut,
    // qui fait 7 px de chasse dans ce modèle.
    int largeur(int index) {
      final numero = index + 1; // les colonnes d'Excel partent de 1
      for (final (min, max, valeur) in colonnes) {
        if (numero >= min && numero <= max) return (valeur * 7 + 0.5).floor();
      }
      return (largeurParDefaut * 7 + 0.5).floor();
    }

    double hauteur(int index) =>
        double.tryParse(
          RegExp('<row r="${index + 1}"[^>]*? ht="([\\d.]+)"')
                  .firstMatch(feuille)?[1] ??
              '',
        ) ??
        hauteurParDefaut;

    return _Case(
      colonne: plage.colonne,
      largeurs: [
        for (var i = 0; i < plage.colonnes; i++) largeur(plage.colonne + i),
      ],
      ligne: plage.ligne,
      hauteurs: [
        for (var i = 0; i < plage.lignes; i++) hauteur(plage.ligne + i),
      ],
    );
  }

  final int colonne;

  /// Largeur de chaque colonne couverte, en pixels.
  final List<int> largeurs;

  final int ligne;

  /// Hauteur de chaque ligne couverte, en points.
  final List<double> hauteurs;

  static const _emuParPixel = 9525;
  static const _emuParPoint = 12700;

  /// Retrait laissé de chaque côté, en pixels : l'image remplit la case
  /// **sans recouvrir ses traits**. Posée bord à bord, elle masquait le cadre
  /// des cases photo, tracé en trait moyen.
  static const _retrait = 2;

  int get _derniereLargeur => largeurs.last * _emuParPixel;
  int get _derniereHauteur => (hauteurs.last * _emuParPoint).round();

  int get largeurEmu =>
      (largeurs.fold(0, (somme, px) => somme + px) - 2 * _retrait) *
      _emuParPixel;

  int get hauteurEmu =>
      (hauteurs.fold(0.0, (somme, pt) => somme + pt) * _emuParPoint).round() -
      2 * _retrait * _emuParPixel;

  /// Du coin de la première cellule à celui de la dernière, retrait déduit.
  /// L'image suit donc la case si on la redimensionne.
  String get ancre {
    const r = _retrait * _emuParPixel;
    return '<xdr:from><xdr:col>$colonne</xdr:col><xdr:colOff>$r</xdr:colOff>'
        '<xdr:row>$ligne</xdr:row><xdr:rowOff>$r</xdr:rowOff></xdr:from>'
        '<xdr:to><xdr:col>${colonne + largeurs.length - 1}</xdr:col>'
        '<xdr:colOff>${_derniereLargeur - r}</xdr:colOff>'
        '<xdr:row>${ligne + hauteurs.length - 1}</xdr:row>'
        '<xdr:rowOff>${_derniereHauteur - r}</xdr:rowOff></xdr:to>';
  }

  /// La même ancre, dans l'écriture de l'ancien format VML : colonne, décalage
  /// en pixels, ligne, décalage en pixels — pour chacun des deux coins.
  String get ancreVml {
    final bas = (hauteurs.last * 96 / 72).round() - _retrait;
    return '$colonne, $_retrait, $ligne, $_retrait, '
        '${colonne + largeurs.length - 1}, ${largeurs.last - _retrait}, '
        '${ligne + hauteurs.length - 1}, $bas';
  }
}

/// Échappe un texte pour un contenu ou un attribut XML.
///
/// Retire aussi les caractères de contrôle, interdits en XML 1.0 : un seul,
/// collé depuis un courriel dans un nom de chantier, rendrait le classeur
/// entier illisible.
String _echapper(String texte) => texte
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]'), '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _desechapper(String texte) => texte
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Le XML d'une feuille, et de quoi y poser des valeurs.
///
/// Chaque cellule est retrouvée par sa référence et réécrite **en gardant son
/// style** — bordure, police, alignement : c'est le modèle qui met en forme.
class _Feuille {
  _Feuille(this.xml);

  String xml;

  /// Texte, écrit dans la cellule même plutôt que dans la table partagée du
  /// classeur : celle-ci n'a ainsi jamais à être touchée. Vide ou `null` ⇒
  /// cellule vidée, sans quoi la valeur d'exemple du modèle resterait.
  void texte(String ref, String? valeur, {String? style}) {
    final propre = valeur?.trim() ?? '';
    if (propre.isEmpty) {
      brut(ref, '', '', style: style);
    } else {
      brut(
        ref,
        't="inlineStr"',
        '<is><t xml:space="preserve">${_echapper(propre)}</t></is>',
        style: style,
      );
    }
  }

  /// Numéro de style de la cellule [ref], tel que le modèle le porte.
  String? styleDe(String ref) {
    final trouve = RegExp('<c r="$ref"([^>]*?)(?:/>|>)').firstMatch(xml);
    if (trouve == null) throw ModeleInattendu('cellule $ref introuvable');
    return RegExp(r' s="(\d+)"').firstMatch(trouve[1]!)?[1];
  }

  void nombre(String ref, num valeur) => brut(ref, '', '<v>$valeur</v>');

  /// Formule du modèle, avec sa valeur calculée.
  void formule(
    String ref,
    String expression,
    String valeur, {
    String? style,
  }) =>
      brut(
        ref,
        't="str"',
        '<f>${_echapper(expression)}</f><v>${_echapper(valeur)}</v>',
        style: style,
      );

  void brut(String ref, String attributs, String contenu, {String? style}) {
    final cellule = RegExp('<c r="$ref"([^>]*?)(/>|>.*?</c>)', dotAll: true);
    final trouve = cellule.firstMatch(xml);
    if (trouve == null) throw ModeleInattendu('cellule $ref introuvable');

    final s = style ?? RegExp(r' s="(\d+)"').firstMatch(trouve[1]!)?[1];
    final debut = '<c r="$ref"'
        '${s == null ? '' : ' s="$s"'}'
        '${attributs.isEmpty ? '' : ' $attributs'}';

    xml = xml.replaceRange(
      trouve.start,
      trouve.end,
      contenu.isEmpty ? '$debut/>' : '$debut>$contenu</c>',
    );
  }
}

/// Noms de feuille : le numéro du point, rendu acceptable par Excel.
class _NomsDeFeuille {
  _NomsDeFeuille(Set<String> dejaPris)
      : _pris = {for (final nom in dejaPris) nom.toLowerCase()};

  /// Excel compare les noms sans tenir compte de la casse.
  final Set<String> _pris;

  static const _longueurMax = 31;

  String pour(String? numero) {
    var base = (numero ?? '')
        // Caractères qu'Excel refuse dans un nom de feuille.
        .replaceAll(RegExp(r'[\[\]:*?/\\]'), '-')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    // Ni en tête ni en queue : l'apostrophe y délimite les références.
    while (base.startsWith("'")) {
      base = base.substring(1);
    }
    while (base.endsWith("'")) {
      base = base.substring(0, base.length - 1);
    }
    if (base.isEmpty) base = 'Sans numéro';
    if (base.length > _longueurMax) base = base.substring(0, _longueurMax);

    // Deux points de même numéro — l'application le signale mais ne
    // l'interdit pas — donnent « 12 » et « 12 (2) ».
    var nom = base;
    for (var n = 2; !_pris.add(nom.toLowerCase()); n++) {
      final suffixe = ' ($n)';
      final place = _longueurMax - suffixe.length;
      nom = '${base.length > place ? base.substring(0, place) : base}$suffixe';
    }
    return nom;
  }
}
