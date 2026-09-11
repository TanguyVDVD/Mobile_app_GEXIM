import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../shared/widgets/account_menu.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';

/// Console d'administration : chantiers, clients, comptes.
///
/// Écrit dans la même base locale et la même file d'attente que l'application
/// technicien. Un admin peut donc créer un chantier depuis un bureau sans
/// réseau ; il partira tout seul. Les policies RLS rejouent de toute façon le
/// contrôle de rôle côté serveur.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accueil'),
          actions: [
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push('/parametres'),
            ),
            const AccountMenu(),
            const SizedBox(width: Fs.xs),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chantiers', height: 44),
              Tab(text: 'Clients', height: 44),
              Tab(text: 'Équipe', height: 44),
            ],
          ),
        ),
        body: const Column(
          children: [
            SyncStatusBar(),
            Expanded(
              child: TabBarView(
                children: [_ProjectsTab(), _ClientsTab(), _TeamTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(allProjectsProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];

    return Scaffold(
      body: projects.when(
        loading: () => const _Loading(),
        error: (e, _) => EmptyState(
          title: 'Lecture impossible',
          body: '$e',
          icon: Icons.error_outline,
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'Aucun chantier',
                body: 'Créez un chantier, rattachez-le à un client, puis '
                    'affectez-y les techniciens qui interviendront.',
                icon: Icons.apartment_outlined,
              )
            : ReadableWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.lg, Fs.lg, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Fs.sm),
                  itemBuilder: (context, i) => _ProjectPlate(list[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Un chantier appartient nécessairement à un client : sans client, la
        // création n'a nulle part où s'accrocher.
        onPressed: clients.isEmpty
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Créez d\'abord un client.'),
                  ),
                )
            : () => context.push('/projects/new'),
        icon: const Icon(Icons.add, size: 24),
        label: const Text('Nouveau chantier'),
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
    final closed = project.status == ProjectStatus.completed;

    return Plate(
      // Directement sur le relevé, pas sur la configuration : c'est le contenu
      // du chantier qu'un admin vient consulter neuf fois sur dix.
      onTap: () => context.push('/projects/${project.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: closed ? Fs.inkMuted : Fs.ink,
                  ),
                ),
                const SizedBox(height: Fs.xs),
                Row(
                  children: [
                    Text(client?.name ?? '…', style: Fs.metaOf(context)),
                    const SizedBox(width: Fs.sm),
                    _StatusMark(project.status),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            closed ? Icons.lock_outline : Icons.arrow_forward,
            size: 21,
            color: Fs.inkMuted,
          ),
        ],
      ),
    );
  }
}

/// Statut, en texte discret plutôt qu'en pastille colorée.
///
/// Des puces de couleur dans une liste attireraient l'œil sur le statut, qui
/// n'est pas ce qu'on vient y chercher.
class _StatusMark extends StatelessWidget {
  const _StatusMark(this.status);

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ProjectStatus.inProgress => 'En cours',
      ProjectStatus.completed => 'Clôturé',
    };

    return Row(
      children: [
        Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Fs.inkMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Fs.sm),
        Text(label, style: Fs.metaOf(context)),
      ],
    );
  }
}

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);

    return Scaffold(
      body: clients.when(
        loading: () => const _Loading(),
        error: (e, _) => EmptyState(
          title: 'Lecture impossible',
          body: '$e',
          icon: Icons.error_outline,
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'Aucun client',
                body: 'Un client porte son adresse et son logo, qui figurent '
                    'en tête de chaque fiche du rapport. C\'est le point de '
                    'départ de tout chantier.',
                icon: Icons.business_outlined,
              )
            : ReadableWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.lg, Fs.lg, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Fs.sm),
                  itemBuilder: (context, i) {
                    final client = list[i];

                    return Plate(
                      onTap: () => context.push('/clients/${client.id}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (client.contactName?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: Fs.xs),
                                  Text(
                                    client.contactName!,
                                    style: Fs.metaOf(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            size: 21,
                            color: Fs.inkMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clients/new'),
        icon: const Icon(Icons.add, size: 24),
        label: const Text('Nouveau client'),
      ),
    );
  }
}

/// Vue d'ensemble des comptes.
class _TeamTab extends ConsumerWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    final counts = ref.watch(assignmentCountsProvider).valueOrNull ??
        const <String, int>{};

    return profiles.when(
      loading: () => const _Loading(),
      error: (e, _) => EmptyState(
        title: 'Lecture impossible',
        body: '$e',
        icon: Icons.error_outline,
      ),
      data: (list) {
        final admins = list.where((p) => p.role == UserRole.admin).length;
        // Le chiffre qui appelle une action : un technicien sans affectation
        // s'est inscrit et attend devant un écran vide.
        final orphans = list
            .where(
                (p) => p.role == UserRole.operator && (counts[p.id] ?? 0) == 0)
            .length;

        return ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(Fs.lg),
            children: [
              Plate(
                accent: orphans > 0,
                onTap: () => context.push('/users'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${list.length}',
                                style: Fs.reference.copyWith(
                                  fontSize: 26,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(width: Fs.sm),
                              Text(
                                'compte${list.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 16.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: Fs.xs),
                          Text(
                            '$admins administrateur${admins > 1 ? 's' : ''}',
                            style: Fs.metaOf(context),
                          ),
                          if (orphans > 0) ...[
                            const SizedBox(height: Fs.xs),
                            Text(
                              '$orphans technicien${orphans > 1 ? 's' : ''} '
                              'sans chantier affecté',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Fs.signal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 21,
                      color: Fs.inkMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Fs.xl),
              Text(
                'Les comptes se créent par inscription depuis l\'écran de '
                'connexion. Un nouveau compte est toujours technicien et ne voit '
                'aucun chantier tant qu\'un administrateur ne l\'a pas affecté.',
                style: Fs.metaOf(context),
              ),
            ],
          ),
        );
      },
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
