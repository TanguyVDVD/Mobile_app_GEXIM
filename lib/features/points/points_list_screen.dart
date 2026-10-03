import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../database/daos/point_dao.dart';
import '../../database/tables/enums.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';

/// Le relevé d'un chantier : un registre de traversées.
///
/// Écran ouvert des centaines de fois par jour, souvent avec des gants, sous un
/// éclairage médiocre ou en plein soleil. Chaque ligne est une plaque
/// d'identification : cartouche numéroté, localisation, état des deux clichés
/// réglementaires. Rien d'autre.
class PointsListScreen extends ConsumerWidget {
  const PointsListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId)).valueOrNull;
    final points = ref.watch(pointsProvider(projectId));
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.role == UserRole.admin;
    final closed = project?.status == ProjectStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? 'Chantier'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Gérer le chantier',
              icon: const Icon(Icons.tune, size: 26),
              onPressed: () => context.push('/projects/$projectId/settings'),
            ),
          const SizedBox(width: Fs.xs),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBar(),
          if (closed) const _FrozenNotice(),
          Expanded(
            child: points.when(
              loading: () => const _Loading(),
              error: (e, _) => EmptyState(
                title: 'Lecture impossible',
                body: '$e',
                icon: Icons.error_outline,
              ),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      title: 'Aucune traversée relevée',
                      body: closed
                          ? 'Ce chantier a été clôturé sans relevé.'
                          : 'Commencez par photographier une traversée : '
                              'le cliché avant intervention, puis le '
                              'calfeutrement réalisé.',
                      icon: Icons.grid_4x4,
                    )
                  : _Register(points: list),
            ),
          ),
        ],
      ),
      floatingActionButton: closed
          // Le serveur refuserait de toute façon l'écriture : proposer le
          // bouton ne produirait qu'un échec de synchronisation inexplicable
          // sur le terrain.
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createPoint(context, ref),
              icon: const Icon(Icons.add, size: 24),
              label: const Text('Relever une traversée'),
            ),
    );
  }

  Future<void> _createPoint(BuildContext context, WidgetRef ref) async {
    final authorId = ref.read(currentUserIdProvider);
    if (authorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expirée. Reconnectez-vous.')),
      );
      return;
    }

    // Aucune attente réseau : le point existe dès cette ligne, l'identifiant
    // étant généré sur l'appareil.
    final pointId = await ref.read(pointDaoProvider).createPoint(
          projectId: projectId,
          authorId: authorId,
        );

    if (context.mounted) unawaited(context.push('/points/$pointId'));
  }
}

/// Le registre, précédé de son décompte.
class _Register extends StatelessWidget {
  const _Register({required this.points});

  final List<PointSummary> points;

  @override
  Widget build(BuildContext context) {
    final incomplete = points.where((s) => !s.isComplete).length;

    return ReadableWidth(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.lg, Fs.lg, 96),
        itemCount: points.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: Fs.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Tally(total: points.length, incomplete: incomplete);
          }
          return _PointPlate(points[i - 1]);
        },
      ),
    );
  }
}

/// Décompte de complétude.
///
/// Le seul chiffre qui décide de quelque chose sur le terrain : peut-on quitter
/// le site ? Y revenir coûte une demi-journée, donc il est en tête, et il
/// bascule au rouge dès qu'une fiche n'est pas complète — même règle que
/// l'état affiché sur chaque ligne, voir `Completude`.
class _Tally extends StatelessWidget {
  const _Tally({required this.total, required this.incomplete});

  final int total;
  final int incomplete;

  @override
  Widget build(BuildContext context) {
    final done = incomplete == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: Fs.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$total',
            style: Fs.reference.copyWith(fontSize: 34, letterSpacing: -1),
          ),
          const SizedBox(width: Fs.sm),
          Expanded(
            child: Text(
              done
                  ? 'traversée${total > 1 ? 's' : ''} — dossier complet'
                  : 'traversée${total > 1 ? 's' : ''} — $incomplete à compléter',
              style: TextStyle(
                fontSize: 15.5,
                color: done ? Fs.inkMuted : Fs.signal,
                fontWeight: done ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointPlate extends ConsumerWidget {
  const _PointPlate(this.summary);

  final PointSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = summary.point;
    final complete = summary.isComplete;
    // L'étage est une option de liste : la traversée n'en porte que
    // l'identifiant. Les libellés incluent les options retirées du
    // catalogue — une fiche relevée l'an dernier garde son étage.
    final libelles = ref.watch(settingOptionLabelsProvider).valueOrNull ??
        const <String, String>{};
    // Bâtiment, étage, local — dans l'ordre où on situe une traversée sur un
    // site, du plus large au plus précis.
    final location = [
      point.building,
      libelles[point.floorId],
      point.room,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Plate(
      accent: !complete,
      padding: const EdgeInsets.all(Fs.md),
      onTap: () => context.push('/points/${point.id}'),
      child: Row(
        children: [
          ReferenceTag(
            label: summary.label,
            isProvisional: summary.isProvisional,
          ),
          const SizedBox(width: Fs.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.isEmpty ? 'Localisation à préciser' : location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: location.isEmpty ? Fs.inkMuted : Fs.ink,
                    fontStyle:
                        location.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: Fs.sm),
                PointStatus(
                  photos: summary.photoCount,
                  missingValues: summary.missingValues,
                ),
              ],
            ),
          ),
          if (summary.isProvisional)
            const Padding(
              padding: EdgeInsets.only(left: Fs.sm),
              child: Tooltip(
                message: 'Numéro du point à saisir',
                child: Icon(Icons.edit_outlined, size: 16, color: Fs.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _FrozenNotice extends StatelessWidget {
  const _FrozenNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Fs.ground,
      padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.md, Fs.lg, Fs.md),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 19, color: Fs.inkMuted),
          const SizedBox(width: Fs.md),
          Expanded(
            child: Text(
              'Chantier clôturé. Le relevé est figé.',
              style: Fs.metaOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
