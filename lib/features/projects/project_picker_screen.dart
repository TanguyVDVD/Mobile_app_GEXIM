import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../database/database.dart';
import '../../shared/widgets/account_menu.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';

/// Accueil du technicien : les chantiers auxquels il est affecté.
///
/// Le filtrage vient de `project_members`, et les policies RLS ne font
/// descendre que ces chantiers-là. Un technicien ne voit rien d'autre, même en
/// fouillant la base locale de sa tablette.
class ProjectPickerScreen extends ConsumerWidget {
  const ProjectPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(assignedProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: const [AccountMenu(), SizedBox(width: Fs.xs)],
      ),
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: projects.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => EmptyState(
                title: 'Lecture impossible',
                body: '$e',
                icon: Icons.error_outline,
              ),
              data: (list) => list.isEmpty
                  // Cas fréquent après une inscription : le compte existe, mais
                  // personne ne l'a encore affecté. Sans explication, l'écran
                  // vide passerait pour une panne.
                  ? const EmptyState(
                      title: 'Aucun chantier affecté',
                      body: 'Un administrateur doit vous associer aux '
                          'chantiers sur lesquels vous intervenez. Ils '
                          'apparaîtront ici à la prochaine synchronisation.',
                      icon: Icons.apartment_outlined,
                    )
                  : ReadableWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Fs.lg),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Fs.sm),
                        itemBuilder: (context, i) => _ProjectPlate(list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPlate extends ConsumerWidget {
  const _ProjectPlate(this.project);

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider(project.clientId)).valueOrNull;

    return Plate(
      onTap: () => context.push('/projects/${project.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: Fs.xs),
                Text(
                  client?.name ?? 'Client à synchroniser',
                  style: Fs.metaOf(context),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 21, color: Fs.inkMuted),
        ],
      ),
    );
  }
}
