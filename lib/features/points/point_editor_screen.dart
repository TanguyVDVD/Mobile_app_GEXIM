import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../shared/widgets/photo_thumbnail.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';
import '../../core/plateforme.dart';
import '../capture/camera_screen.dart';

/// Fiche d'une traversée : localisation, matériaux, clichés.
class PointEditorScreen extends ConsumerStatefulWidget {
  const PointEditorScreen({required this.pointId, super.key});

  final String pointId;

  @override
  ConsumerState<PointEditorScreen> createState() => _PointEditorScreenState();
}

class _PointEditorScreenState extends ConsumerState<PointEditorScreen> {
  final _floor = TextEditingController();
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

    _floor.dispose();
    _room.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Enregistrement différé.
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
    // rapide, ou une tablette poussive — écrasait alors l'étage, le local et
    // les observations par des chaînes vides, sans rien afficher d'anormal.
    //
    // `_dirty` : simplement consulter une traversée ne doit pas produire
    // d'écriture, ni une entrée de synchronisation.
    if (!_loaded || !_dirty) return;

    await ref.read(pointDaoProvider).updatePoint(
          widget.pointId,
          floor: _floor.text,
          room: _room.text,
          description: _description.text,
        );
    _dirty = false;
  }

  /// Supprime la traversée, après confirmation.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette traversée ?'),
        content: const Text(
          'Ses clichés et ses matériaux disparaîtront avec elle, et elle ne '
          'figurera pas au rapport de conformité.',
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

    await ref.read(photoCaptureServiceProvider).capture(
          pointId: widget.pointId,
          kind: kind,
          original: original,
        );
  }

  @override
  Widget build(BuildContext context) {
    final point = ref.watch(pointProvider(widget.pointId));
    final photos = ref.watch(pointPhotosProvider(widget.pointId));

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
            _floor.text = row.floor ?? '';
            _room.text = row.room ?? '';
            _description.text = row.description ?? '';
            _loaded = true;
          }

          return Column(
            children: [
              const SyncStatusBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SectionHeading('Localisation'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _floor,
                            decoration: const InputDecoration(
                              labelText: 'Étage',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _scheduleSave(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _room,
                            decoration: const InputDecoration(
                              labelText: 'Local',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _scheduleSave(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeading('Clichés'),
                    photos.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur : $e'),
                      data: (list) => _PhotoSlots(
                        photos: list,
                        captureDisponible: Plateforme.captureDisponible,
                        onShoot: _shoot,
                        onRetire: (id) =>
                            ref.read(photoCaptureServiceProvider).retire(id),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeading('Matériaux mis en œuvre'),
                    _MaterialPicker(pointId: widget.pointId),
                    const SizedBox(height: 20),
                    const SectionHeading('Observations'),
                    TextField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Nature de la traversée, remarques…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Les deux clichés obligatoires, puis les complémentaires.
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
                label: 'Avant',
                hint: 'La traversée nue',
                photo: _of(PhotoKind.before),
                onShoot: captureDisponible
                    ? () => onShoot(PhotoKind.before, 'Avant calfeutrement')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Slot(
                label: 'Après',
                hint: 'Le calfeutrement réalisé',
                photo: _of(PhotoKind.after),
                onShoot: captureDisponible
                    ? () => onShoot(PhotoKind.after, 'Après calfeutrement')
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
          // lisait comme un troisième emplacement réglementaire manquant, alors
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
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Fs.inkMuted,
            ),
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
  /// reste visible — il fait partie du dossier réglementaire, et son absence
  /// doit continuer à se voir — mais il n'est plus tactile.
  final VoidCallback? onShoot;

  /// Emplacement réglementaire, vide ou rempli.
  ///
  /// C'est le moment le plus caractéristique du métier : la paire avant/après
  /// **est** la preuve. Les deux emplacements occupent donc toute la largeur,
  /// à parts égales, et un emplacement vide s'annonce en rouge — il manque
  /// quelque chose au dossier, ce n'est pas un espace décoratif.
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

/// Sélection dans le catalogue, sans saisie libre.
///
/// Une référence tapée à la main sur le terrain ne serait pas exploitable en
/// audit de conformité : c'est le catalogue serveur qui fait foi.
class _MaterialPicker extends ConsumerWidget {
  const _MaterialPicker({required this.pointId});

  final String pointId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(materialsProvider);
    final selected = ref.watch(pointMaterialsProvider(pointId));

    return catalogue.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur : $e'),
      data: (materials) {
        if (materials.isEmpty) {
          return const Text(
            'Catalogue vide — il descendra à la prochaine synchronisation.',
          );
        }

        final chosen = {
          for (final link in selected.valueOrNull ?? const <PointMaterial>[])
            link.materialId,
        };

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final material in materials)
              FilterChip(
                label: Text(material.label),
                selected: chosen.contains(material.id),
                onSelected: (on) {
                  final next = {...chosen};
                  if (on) {
                    next.add(material.id);
                  } else {
                    next.remove(material.id);
                  }
                  ref.read(pointDaoProvider).setMaterials(
                        pointId,
                        {for (final id in next) id: null},
                      );
                },
              ),
          ],
        );
      },
    );
  }
}

