import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../features/auth/auth_service.dart';

/// Identité de la session et déconnexion.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final name = profile == null
        ? 'Session'
        : profile.fullName.isNotEmpty
            ? profile.fullName
            : profile.email;

    return PopupMenuButton<String>(
      tooltip: 'Compte',
      // Agrandie : c'est le seul point d'entree vers l'identite et la
      // deconnexion, et une icone de 22 px se cherche sur un ecran tenu a
      // bout de bras.
      iconSize: 30,
      padding: const EdgeInsets.symmetric(horizontal: Fs.md),
      icon: const Icon(Icons.account_circle_outlined, size: 30),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          height: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Fs.ink,
                ),
              ),
              Text(
                profile?.role.name == 'admin' ? 'Administrateur' : 'Technicien',
                style: const TextStyle(fontSize: 14, color: Fs.inkMuted),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          height: 44,
          child: Text('Se déconnecter'),
        ),
      ],
      onSelected: (_) => _signOut(context, ref),
    );
  }

  /// Déconnexion, refusée tant qu'il reste des relevés sur l'appareil.
  ///
  /// Le refus est délibérément explicite. Se déconnecter ouvre la porte à une
  /// connexion d'un autre compte, qui purge la base : le travail d'une journée
  /// disparaîtrait sans que personne ne s'en aperçoive avant l'audit.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authServiceProvider).signOut();
    } on PendingWorkBlocked catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Envoyer',
            textColor: Colors.white,
            onPressed: () => ref.read(syncEngineProvider).syncNow(),
          ),
        ),
      );
    }
  }
}
