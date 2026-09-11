import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/plateforme.dart';
import '../../database/daos/point_dao.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../database/tables/tables.dart' show floorLabel, floorRange;
import '../../shared/widgets/photo_thumbnail.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';
import '../capture/camera_screen.dart';

/// Fiche d'une traversée — la saisie de terrain, et l'exact reflet du
/// formulaire « Resserrage RF — Fiche AS BUILT » qui sortira au rapport.
///
/// L'ordre des sections suit celui du formulaire imprimé, volontairement : un
/// technicien qui a la fiche papier sous les yeux doit retrouver ses champs
/// dans le même ordre, sans traduire.
///
/// Les champs de texte s'enregistrent après une temporisation ; les listes
/// déroulantes et la date, immédiatement — un choix dans une liste est un geste
/// achevé, il n'y a rien à attendre.
class PointEditorScreen extends ConsumerStatefulWidget {
  const PointEditorScreen({required this.pointId, super.key});

  final String pointId;

  @override
  ConsumerState<PointEditorScreen> createState() => _PointEditorScreenState();
}

class _PointEditorScreenState extends ConsumerState<PointEditorScreen> {
  final _purchaseOrder = TextEditingController();
  final _building = TextEditingController();
  final _room = TextEditingController();
  final _description = TextEditingController();

  Timer? _debounce;

  /// Les champs ont-ils reçu la valeur enregistrée ?
  bool _loaded = false;

  /// L'opérateur a-t-il réellement modifié quelque chose ?
  bool _dirty = false;

  @override
  void dispose() {
    _debounce?.cancel();
    // Sauvegarde finale, sans attendre : un retour en arrière pendant la
    // temporisation perdrait sinon les derniers caractères saisis. L'écriture
    // est purement locale, elle aboutira même si l'écran a disparu.
    unawaited(_persist());

    for (final c in [_purchaseOrder, _building, _room, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Enregistrement différé des champs libres.
  ///
  /// Bien plus agréable qu'un bouton « Enregistrer » sur un chantier, et sans
  /// coût réseau : le fusionnement de l'outbox réduit toutes ces retouches
  /// successives à un seul envoi.
  void _scheduleSave() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _persist);
  }

  Future<void> _persist() async {
    // Deux gardes, et la première évite une perte de données.
    //
    // `_loaded` : tant que la fiche n'a pas reçu ses valeurs, les champs sont
    // vides. Fermer l'écran avant que la base n'ait répondu — un aller-retour
    // rapide, ou une tablette poussive — écrasait alors la saisie par des
    // chaînes vides, sans rien afficher d'anormal.
    //
    // `_dirty` : simplement consulter une traversée ne doit pas produire
    // d'écriture, ni une entrée de synchronisation.
    if (!_loaded || !_dirty) return;

    await ref.read(pointDaoProvider).updatePoint(
          widget.pointId,
          purchaseOrder: Value(_texteOuNull(_purchaseOrder)),
          building: Value(_texteOuNull(_building)),
          room: Value(_texteOuNull(_room)),
          description: Value(_texteOuNull(_description)),
        );
    _dirty = false;
  }

  static String? _texteOuNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Écriture immédiate d'un champ choisi, sans passer par la temporisation.
  ///
  /// Les saisies libres en attente partent avec : sans cela, choisir un produit
  /// juste après avoir tapé un bâtiment écrirait la fiche sans ce bâtiment,
  /// puis la temporisation le réécrirait — deux entrées d'outbox pour un seul
  /// geste, et une fenêtre où la donnée affichée n'est pas celle enregistrée.
  Future<void> _ecrire(Future<void> Function(PointDao dao) action) async {
    _debounce?.cancel();
    await _persist();
    await action(ref.read(pointDaoProvider));
  }

  /// Range une option choisie dans **sa** colonne.
  ///
  /// La correspondance liste → colonne vit ici et nulle part ailleurs. La
  /// disperser dans les sous-widgets — un rappel par champ, chacun sachant
  /// quel paramètre nommé viser — reviendrait à recopier la signature du DAO
  /// dans l'écran : neuf occasions de se tromper de colonne, pour une erreur
  /// qui ne se verrait qu'à la relecture du rapport.
  Future<void> _choisirOption({
    required SettingKind kind,
    required String? optionId,
    int rangProduit = 0,
  }) {
    final valeur = Value(optionId);

    return _ecrire(
      (dao) => switch ((kind, rangProduit)) {
        (SettingKind.configuration, _) =>
          dao.updatePoint(widget.pointId, configurationId: valeur),
        (SettingKind.configurationDetail, _) =>
          dao.updatePoint(widget.pointId, configurationDetailId: valeur),
        (SettingKind.eiLevel, _) =>
          dao.updatePoint(widget.pointId, eiLevelId: valeur),
        (SettingKind.supplier, _) =>
          dao.updatePoint(widget.pointId, supplierId: valeur),
        (SettingKind.productType, _) =>
          dao.updatePoint(widget.pointId, productTypeId: valeur),
        (SettingKind.product, 0) =>
          dao.updatePoint(widget.pointId, product1Id: valeur),
        (SettingKind.product, 1) =>
          dao.updatePoint(widget.pointId, product2Id: valeur),
        (SettingKind.product, 2) =>
          dao.updatePoint(widget.pointId, product3Id: valeur),
        (SettingKind.product, 3) =>
          dao.updatePoint(widget.pointId, product4Id: valeur),
        (SettingKind.product, _) =>
          dao.updatePoint(widget.pointId, product5Id: valeur),
      },
    );
  }

  Future<void> _choisirDate(DateTime actuelle) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: actuelle,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Date de la traversée',
    );
    if (choisie == null) return;

    // L'heure de la saisie initiale est conservée : elle n'est pas affichée,
    // mais elle ordonne les clichés et les relevés d'une même journée.
    await _ecrire(
      (dao) => dao.updatePoint(
        widget.pointId,
        capturedAt: Value(
          DateTime(
            choisie.year,
            choisie.month,
            choisie.day,
            actuelle.hour,
            actuelle.minute,
          ),
        ),
      ),
    );
  }

  /// Supprime la traversée, après confirmation.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette traversée ?'),
        content: const Text(
          'Ses clichés et ses caractéristiques disparaîtront avec elle, et elle '
          'ne figurera pas au rapport de conformité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    // Avant la suppression : la sauvegarde différée réécrirait la ligne juste
    // après, en annulant le `deleted_at`.
    _debounce?.cancel();
    _dirty = false;

    await ref.read(pointDaoProvider).deletePoint(widget.pointId);
    if (mounted) context.pop();
  }

  Future<void> _shoot(PhotoKind kind, String title) async {
    final File? original = await CameraScreen.push(context, title);
    if (original == null) return;

    try {
      await ref.read(photoCaptureServiceProvider).capture(
            pointId: widget.pointId,
            kind: kind,
            original: original,
          );
    } on Object catch (e) {
      // Compression ou enregistrement en échec. Sans ce message, l'écran de
      // prise de vue se refermait comme après un succès : le technicien
      // quittait le chantier persuadé d'avoir sa photo, et l'emplacement vide
      // ne se découvrait qu'au rapport.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le cliché n\'a pas été enregistré : $e. '
              'Reprenez la photo.'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = ref.watch(pointProvider(widget.pointId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traversée'),
        actions: [
          IconButton(
            tooltip: 'Supprimer la traversée',
            icon: const Icon(Icons.delete_outline),
            onPressed: _loaded ? _delete : null,
          ),
        ],
      ),
      body: point.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (row) {
          if (row == null) {
            return const Center(child: Text('Traversée introuvable.'));
          }
          if (!_loaded) {
            _purchaseOrder.text = row.purchaseOrder ?? '';
            _building.text = row.building ?? '';
            _room.text = row.room ?? '';
            _description.text = row.description ?? '';
            _loaded = true;
          }

          return Column(
            children: [
              const SyncStatusBar(),
              Expanded(
                child: ReadableWidth(
                  child: ListView(
                    padding: const EdgeInsets.all(Fs.lg),
                    children: [
                      const SectionHeading('Identification'),
                      _Identification(
                        point: row,
                        purchaseOrder: _purchaseOrder,
                        building: _building,
                        onEdit: _scheduleSave,
                        onDate: () => _choisirDate(row.capturedAt),
                        onFloor: (niveau) => _ecrire(
                          (dao) => dao.updatePoint(
                            widget.pointId,
                            floorLevel: Value(niveau),
                          ),
                        ),
                      ),

                      const SizedBox(height: Fs.xl),
                      const SectionHeading('Photographies'),
                      _Photographies(
                        pointId: widget.pointId,
                        onShoot: _shoot,
                      ),

                      const SizedBox(height: Fs.xl),
                      const SectionHeading('Caractéristiques'),
                      _Caracteristiques(
                        point: row,
                        onChoisir: _choisirOption,
                      ),

                      const SizedBox(height: Fs.xl),
                      // Hors formulaire imprimé, et annoncé comme tel : un
                      // technicien doit savoir ce qui atterrira sous les yeux
                      // du client et ce qui reste un repère interne.
                      const SectionHeading('Repères internes'),
                      Text(
                        'Ces deux champs ne figurent pas sur la fiche du '
                        'rapport.',
                        style: Fs.metaOf(context),
                      ),
                      const SizedBox(height: Fs.md),
                      TextField(
                        controller: _room,
                        decoration: const InputDecoration(
                          labelText: 'Local',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSave(),
                      ),
                      const SizedBox(height: Fs.md),
                      TextField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Observations',
                          hintText: 'Remarques, réserves, particularités…',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSave(),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Enregistre le choix fait dans une liste déroulante.
///
/// [rangProduit] n'a de sens que pour [SettingKind.product] : il désigne l'un
/// des cinq emplacements « Produit utilisé », à partir de zéro.
typedef ChoixOption = Future<void> Function({
  required SettingKind kind,
  required String? optionId,
  int rangProduit,
});

// =============================================================================
// Identification
// =============================================================================

class _Identification extends ConsumerWidget {
  const _Identification({
    required this.point,
    required this.purchaseOrder,
    required this.building,
    required this.onEdit,
    required this.onDate,
    required this.onFloor,
  });

  final Point point;
  final TextEditingController purchaseOrder;
  final TextEditingController building;
  final VoidCallback onEdit;
  final VoidCallback onDate;
  final ValueChanged<int?> onFloor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(point.projectId)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChampDate(valeur: point.capturedAt, onTap: onDate),
        const SizedBox(height: Fs.md),

        // Le numéro de la traversée, et son caractère provisoire.
        //
        // Affiché et non saisissable : il est attribué par une séquence
        // Postgres à la synchronisation. Tant qu'il est nul, le dire plutôt que
        // d'inventer — il figurera dans un rapport de conformité.
        _ChampLu(
          libelle: 'Numéro du point',
          valeur: point.refNumber?.toString() ??
              'attribué à la prochaine synchronisation',
          attenue: point.refNumber == null,
        ),
        const SizedBox(height: Fs.md),

        // Repris du chantier, pas ressaisis : deux endroits où corriger un
        // numéro de projet, c'est un rapport sur deux qui porte l'ancien.
        _ChampLu(
          libelle: 'Numéro projet',
          valeur: project?.code ?? '—',
          attenue: project?.code == null,
        ),
        const SizedBox(height: Fs.md),
        _ChampLu(libelle: 'Intitulé projet', valeur: project?.name ?? '…'),
        const SizedBox(height: Fs.md),

        TextField(
          controller: purchaseOrder,
          decoration: const InputDecoration(
            labelText: 'Purchase Order',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => onEdit(),
        ),
        const SizedBox(height: Fs.md),
        TextField(
          controller: building,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Bâtiment(s) concerné(s)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => onEdit(),
        ),
        const SizedBox(height: Fs.md),
        DropdownButtonFormField<int?>(
          initialValue: point.floorLevel,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Étage',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(child: Text('—')),
            for (final niveau in floorRange)
              DropdownMenuItem<int?>(
                value: niveau,
                child: Text(floorLabel(niveau)),
              ),
          ],
          onChanged: onFloor,
        ),
      ],
    );
  }
}

/// Une valeur que l'écran affiche sans permettre de la modifier.
///
/// Présentée comme un champ et non comme une ligne de texte : elle occupe la
/// même place dans le formulaire que sur la fiche imprimée, et un technicien
/// qui la cherche la trouve là où il l'attend.
class _ChampLu extends StatelessWidget {
  const _ChampLu({
    required this.libelle,
    required this.valeur,
    this.attenue = false,
  });

  final String libelle;
  final String valeur;
  final bool attenue;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: libelle,
        border: const OutlineInputBorder(),
        // Fond neutre plutôt que blanc : ce qui ne se touche pas ne doit pas
        // ressembler à ce qui se touche.
        fillColor: Fs.ground,
      ),
      child: Text(
        valeur,
        style: TextStyle(
          fontSize: 16.5,
          color: attenue ? Fs.inkMuted : Fs.ink,
          fontStyle: attenue ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _ChampDate extends StatelessWidget {
  const _ChampDate({required this.valeur, required this.onTap});

  final DateTime valeur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Fs.radius,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          '${valeur.day.toString().padLeft(2, '0')}/'
          '${valeur.month.toString().padLeft(2, '0')}/${valeur.year}',
          style: const TextStyle(fontSize: 16.5),
        ),
      ),
    );
  }
}

// =============================================================================
// Caractéristiques
// =============================================================================

class _Caracteristiques extends StatelessWidget {
  const _Caracteristiques({required this.point, required this.onChoisir});

  final Point point;
  final ChoixOption onChoisir;

  @override
  Widget build(BuildContext context) {
    final produits = [
      point.product1Id,
      point.product2Id,
      point.product3Id,
      point.product4Id,
      point.product5Id,
    ];

    return Column(
      children: [
        _ListeOptions(
          kind: SettingKind.configuration,
          libelle: 'Configuration',
          selection: point.configurationId,
          onChanged: (id) =>
              onChoisir(kind: SettingKind.configuration, optionId: id),
        ),
        const SizedBox(height: Fs.md),
        _ListeOptions(
          kind: SettingKind.configurationDetail,
          libelle: 'Configuration détaillée',
          selection: point.configurationDetailId,
          onChanged: (id) =>
              onChoisir(kind: SettingKind.configurationDetail, optionId: id),
        ),
        const SizedBox(height: Fs.md),
        _ListeOptions(
          kind: SettingKind.eiLevel,
          libelle: 'Niveau EI',
          selection: point.eiLevelId,
          onChanged: (id) =>
              onChoisir(kind: SettingKind.eiLevel, optionId: id),
        ),
        const SizedBox(height: Fs.md),
        _ListeOptions(
          kind: SettingKind.supplier,
          libelle: 'Fournisseur de produit utilisé',
          selection: point.supplierId,
          onChanged: (id) =>
              onChoisir(kind: SettingKind.supplier, optionId: id),
        ),
        const SizedBox(height: Fs.md),
        _ListeOptions(
          kind: SettingKind.productType,
          libelle: 'Type de produit utilisé',
          selection: point.productTypeId,
          onChanged: (id) =>
              onChoisir(kind: SettingKind.productType, optionId: id),
        ),

        const SizedBox(height: Fs.lg),
        // Les cinq emplacements sont tous affichés, même vides : leur numéro
        // est celui du rapport, et un « Produit utilisé (3) » qui apparaîtrait
        // seulement une fois le (2) rempli laisserait croire que l'ordre se
        // tasse tout seul. Il ne se tasse pas — voir `PointDao.setProducts`.
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: Fs.md),
          _ListeOptions(
            kind: SettingKind.product,
            libelle: 'Produit utilisé (${i + 1})',
            selection: produits[i],
            onChanged: (id) => onChoisir(
              kind: SettingKind.product,
              optionId: id,
              rangProduit: i,
            ),
          ),
        ],
      ],
    );
  }
}

/// Liste déroulante alimentée par une table de paramètres.
///
/// Trois cas à traiter, et les deux derniers sont ceux qui font mal si on les
/// oublie :
///
///  * la liste est vide — l'administrateur ne l'a pas encore remplie. On le dit,
///    plutôt que d'offrir un champ qui ne s'ouvre sur rien ;
///  * l'option choisie a été **retirée** du catalogue depuis. Elle ne figure
///    plus dans les entrées, et `DropdownButtonFormField` exige que sa valeur
///    corresponde à exactement une entrée : sans traitement, l'écran plante.
///    Elle est donc réinjectée, signalée comme retirée ;
///  * l'option choisie n'est **pas encore descendue** du serveur. Même symptôme,
///    autre cause : la traversée vient d'un collègue et le catalogue local est
///    en retard. Même traitement, libellé différent — dire « retiré » là où
///    c'est « pas encore reçu » enverrait chercher au mauvais endroit.
class _ListeOptions extends ConsumerWidget {
  const _ListeOptions({
    required this.kind,
    required this.libelle,
    required this.selection,
    required this.onChanged,
  });

  final SettingKind kind;
  final String libelle;
  final String? selection;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(settingOptionsProvider(kind)).valueOrNull;
    final libelles =
        ref.watch(settingOptionLabelsProvider).valueOrNull ??
            const <String, String>{};

    if (options == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: libelle,
          border: const OutlineInputBorder(),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    final courant = selection;
    final orpheline = courant != null && !options.any((o) => o.id == courant);

    return DropdownButtonFormField<String?>(
      initialValue: courant,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: libelle,
        border: const OutlineInputBorder(),
        helperText: options.isEmpty
            ? 'Liste vide — à remplir dans Paramètres.'
            : null,
      ),
      items: [
        const DropdownMenuItem<String?>(child: Text('—')),
        for (final option in options)
          DropdownMenuItem<String?>(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
        if (orpheline)
          DropdownMenuItem<String?>(
            value: courant,
            child: Text(
              libelles.containsKey(courant)
                  ? '${libelles[courant]} (retiré)'
                  : 'Entrée pas encore synchronisée',
              style: const TextStyle(color: Fs.signal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// =============================================================================
// Clichés
// =============================================================================

/// Les deux emplacements de la fiche, puis les clichés complémentaires.
///
/// Les deux premiers sont stockés sous `PhotoKind.before` et `PhotoKind.after`.
/// Les noms de l'enum n'ont pas changé — c'est le contrat de synchronisation,
/// et les valeurs `'before'` / `'after'` circulent jusque dans Postgres — mais
/// la fiche AS BUILT ne distingue plus l'avant de l'après : elle offre deux
/// cases, d'où « Photo 1 » et « Photo 2 » à l'écran.
class _Photographies extends ConsumerWidget {
  const _Photographies({required this.pointId, required this.onShoot});

  final String pointId;
  final Future<void> Function(PhotoKind kind, String title) onShoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(pointPhotosProvider(pointId));

    return photos.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur : $e'),
      data: (list) => _PhotoSlots(
        photos: list,
        captureDisponible: Plateforme.captureDisponible,
        onShoot: onShoot,
        onRetire: (id) => ref.read(photoCaptureServiceProvider).retire(id),
      ),
    );
  }
}

class _PhotoSlots extends StatelessWidget {
  const _PhotoSlots({
    required this.photos,
    required this.onShoot,
    required this.onRetire,
    required this.captureDisponible,
  });

  final List<Photo> photos;
  final Future<void> Function(PhotoKind kind, String title) onShoot;
  final Future<void> Function(String photoId) onRetire;

  /// Faux sur PC : `camera` n'a pas d'implémentation Windows. Mieux vaut ne
  /// rien proposer que d'afficher un bouton dont l'appui remonterait un
  /// `MissingPluginException` — et de toute façon, photographier une traversée
  /// est le travail du technicien sur place.
  final bool captureDisponible;

  Photo? _of(PhotoKind kind) {
    for (final photo in photos) {
      if (photo.kind == kind) return photo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final extras =
        photos.where((p) => p.kind == PhotoKind.extra).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Slot(
                label: 'Photo 1',
                hint: 'Premier cliché de la traversée',
                photo: _of(PhotoKind.before),
                onShoot: captureDisponible
                    ? () => onShoot(PhotoKind.before, 'Photo 1')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Slot(
                label: 'Photo 2',
                hint: 'Second cliché de la traversée',
                photo: _of(PhotoKind.after),
                onShoot: captureDisponible
                    ? () => onShoot(PhotoKind.after, 'Photo 2')
                    : null,
              ),
            ),
          ],
        ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: Fs.lg),
          Wrap(
            spacing: Fs.sm,
            runSpacing: Fs.sm,
            children: [
              for (final photo in extras)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PhotoThumbnail(photo: photo, size: 84),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: IconButton(
                        tooltip: 'Retirer ce cliché',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.cancel, size: 20),
                        color: Fs.inkMuted,
                        onPressed: () => onRetire(photo.id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: Fs.md),
        if (captureDisponible)
          // Bouton discret et nommé plutôt qu'un grand carré vide : celui-ci se
          // lisait comme un troisième emplacement obligatoire manquant, alors
          // qu'un cliché complémentaire est facultatif.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  onShoot(PhotoKind.extra, 'Cliché complémentaire'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un cliché'),
              style: TextButton.styleFrom(
                foregroundColor: Fs.inkMuted,
                padding: const EdgeInsets.symmetric(horizontal: Fs.sm),
              ),
            ),
          )
        else
          // Dire pourquoi, plutôt que de laisser un écran amputé sans raison :
          // un administrateur qui ne trouve pas le bouton conclurait à une
          // panne, et appellerait.
          const Text(
            'Les clichés se prennent depuis la tablette, sur le chantier.',
            style: TextStyle(fontSize: 13, height: 1.3, color: Fs.inkMuted),
          ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.hint,
    required this.photo,
    required this.onShoot,
  });

  final String label;
  final String hint;
  final Photo? photo;

  /// `null` là où la plateforme n'a pas de capteur exploitable : l'emplacement
  /// reste visible — il fait partie du dossier, et son absence doit continuer à
  /// se voir — mais il n'est plus tactile.
  final VoidCallback? onShoot;

  /// Emplacement de la fiche, vide ou rempli.
  ///
  /// Les deux occupent toute la largeur, à parts égales, et un emplacement vide
  /// s'annonce en rouge : il manque quelque chose au dossier, ce n'est pas un
  /// espace décoratif.
  @override
  Widget build(BuildContext context) {
    final current = photo;
    final missing = current == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              color: missing ? Fs.signal : Fs.ink,
            ),
            const SizedBox(width: Fs.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Fs.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: Fs.sm),
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: missing ? Fs.plate : Colors.transparent,
            borderRadius: Fs.radius,
            child: InkWell(
              onTap: onShoot,
              borderRadius: Fs.radius,
              child: missing
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: Fs.radius,
                        border: Border.all(color: Fs.hairline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 26,
                            color: Fs.inkMuted,
                          ),
                          const SizedBox(height: Fs.sm),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: Fs.sm),
                            child: Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: Fs.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : PhotoThumbnail(photo: current, size: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}
