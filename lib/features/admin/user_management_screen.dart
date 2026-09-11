import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../shared/widgets/sync_status_bar.dart';
import '../../sync/backoff.dart';

/// Gestion des comptes : qui existe, qui est administrateur, qui est affecté.
///
/// L'affectation aux chantiers se fait depuis la fiche d'un chantier, où le
/// contexte est celui du terrain. Ici on voit l'inverse — combien de chantiers
/// par personne — ce qui sert à repérer un technicien oublié ou un compte
/// dormant.
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    final counts =
        ref.watch(assignmentCountsProvider).valueOrNull ?? const <String, int>{};
    final me = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: profiles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Lecture des comptes impossible : $e')),
              data: (list) => list.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _UserTile(
                        profile: list[i],
                        projectCount: counts[list[i].id] ?? 0,
                        isSelf: list[i].id == me,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({
    required this.profile,
    required this.projectCount,
    required this.isSelf,
  });

  final Profile profile;
  final int projectCount;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = profile.role == UserRole.admin;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isAdmin ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        child: Icon(
          isAdmin ? Icons.shield : Icons.person,
          size: 18,
        ),
      ),
      title: Text(
        profile.fullName.isEmpty ? profile.email : profile.fullName,
      ),
      subtitle: Text(
        isAdmin
            ? 'Administrateur — accès à tous les chantiers'
            : projectCount == 0
                ? 'Technicien — aucun chantier affecté'
                : 'Technicien — $projectCount chantier'
                    '${projectCount > 1 ? 's' : ''}',
        style: TextStyle(
          color: !isAdmin && projectCount == 0 ? scheme.error : null,
        ),
      ),
      trailing: isSelf
          // On ne se rétrograde pas soi-même : le dernier administrateur d'une
          // installation qui le ferait la rendrait impossible à administrer,
          // sans aucun moyen de revenir en arrière depuis l'application.
          ? const Chip(
              visualDensity: VisualDensity.compact,
              label: Text('vous', style: TextStyle(fontSize: 11)),
            )
          : PopupMenuButton<UserRole>(
              onSelected: (role) => _changeRole(context, ref, role),
              itemBuilder: (context) => [
                if (!isAdmin)
                  const PopupMenuItem(
                    value: UserRole.admin,
                    child: Text('Élever au rang d\'administrateur'),
                  ),
                if (isAdmin)
                  const PopupMenuItem(
                    value: UserRole.operator,
                    child: Text('Ramener au rang de technicien'),
                  ),
              ],
            ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    final name = profile.fullName.isEmpty ? profile.email : profile.fullName;
    final promoting = role == UserRole.admin;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(promoting ? 'Élever $name ?' : 'Rétrograder $name ?'),
        content: Text(
          promoting
              ? 'Un administrateur voit et modifie tous les chantiers, tous '
                  'les clients, et peut clôturer un dossier de conformité.'
              : '$name perdra l\'accès à l\'administration et ne verra plus '
                  'que les chantiers qui lui sont affectés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(promoting ? 'Élever' : 'Rétrograder'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userAdminServiceProvider).setRole(profile.id, role);
      messenger.showSnackBar(
        SnackBar(content: Text('$name est désormais '
            '${promoting ? 'administrateur' : 'technicien'}.')),
      );
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.isTransient
                ? 'Changement de rôle impossible sans réseau. Un droit '
                    'd\'administration ne se met pas en file d\'attente : il '
                    's\'appliquerait des heures plus tard, peut-être après que '
                    'vous avez changé d\'avis.'
                : 'Refusé : ${e.message}',
          ),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Aucun compte connu de cet appareil.\n\n'
          'Les profils redescendent à la synchronisation.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
