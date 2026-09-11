import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/tables/enums.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/admin/client_editor_screen.dart';
import '../features/admin/project_editor_screen.dart';
import '../features/admin/settings_screen.dart';
import '../features/admin/user_management_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/points/point_editor_screen.dart';
import '../features/points/points_list_screen.dart';
import '../features/projects/project_picker_screen.dart';
import '../features/reports/report_preview_screen.dart';
import 'providers.dart';

/// Chemins réservés aux administrateurs.
const _adminOnly = <String>{
  '/users',
  '/parametres',
  '/clients/new',
  '/projects/new',
};

bool _isAdminPath(String path) {
  if (_adminOnly.contains(path)) return true;
  if (path.startsWith('/clients/')) return true;
  // /projects/<id>/settings et /projects/<id>/report
  return path.endsWith('/settings') || path.endsWith('/report');
}

/// Routage de l'application.
///
/// Les redirections vivent ici et nulle part ailleurs. Dispersées dans les
/// écrans, elles finissent toujours par diverger : un écran oublie sa garde, et
/// une route devient atteignable par un compte qui ne devrait pas la voir.
///
/// La garde de rôle n'est qu'un confort d'interface. Le verrou réel est dans les
/// policies RLS, qui refusent côté serveur toute écriture d'administration
/// venant d'un technicien — un APK modifié ne gagne rien à contourner ceci.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(currentUserIdProvider) != null;
      final path = state.matchedLocation;
      final onAuthPage = path == '/login' || path == '/signup';

      if (!signedIn) return onAuthPage ? null : '/login';
      if (onAuthPage) return '/';

      // Le rôle vient du profil local. Pendant son chargement, ou à la toute
      // première connexion d'un admin hors ligne, il vaut `operator` : on
      // refuse par défaut plutôt que d'ouvrir la console à quiconque arrive
      // avant que la descente n'ait eu lieu.
      final isAdmin =
          ref.read(currentProfileProvider).valueOrNull?.role == UserRole.admin;
      if (!isAdmin && _isAdminPath(path)) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),

      GoRoute(path: '/', builder: (_, __) => const _Home()),

      GoRoute(path: '/users', builder: (_, __) => const UserManagementScreen()),

      // Les six listes déroulantes de la fiche de traversée. Sous `/parametres`
      // et non `/settings` : le reste des chemins visibles est en français, et
      // `/projects/:id/settings` désigne déjà tout autre chose — la
      // configuration d'un chantier.
      GoRoute(path: '/parametres', builder: (_, __) => const SettingsScreen()),

      GoRoute(
        path: '/clients/new',
        builder: (_, __) => const ClientEditorScreen(),
      ),
      GoRoute(
        path: '/clients/:clientId',
        builder: (_, state) => ClientEditorScreen(
          clientId: state.pathParameters['clientId'],
        ),
      ),

      // `new` avant `:projectId`, sinon il serait capturé comme identifiant.
      GoRoute(
        path: '/projects/new',
        builder: (_, __) => const ProjectEditorScreen(),
      ),
      GoRoute(
        path: '/projects/:projectId',
        // Un clic sur un chantier mène directement au relevé, pour l'admin
        // comme pour le technicien : c'est le contenu, la configuration n'est
        // qu'un détour occasionnel.
        builder: (_, state) => PointsListScreen(
          projectId: state.pathParameters['projectId']!,
        ),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (_, state) => ProjectEditorScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
          GoRoute(
            path: 'report',
            builder: (_, state) => ReportPreviewScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/points/:pointId',
        builder: (_, state) => PointEditorScreen(
          pointId: state.pathParameters['pointId']!,
        ),
      ),
    ],
  );
});

/// Accueil, selon le rôle.
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return profile?.role == UserRole.admin
        ? const AdminHomeScreen()
        : const ProjectPickerScreen();
  }
}

/// Réveille le routeur quand la session ou le rôle change.
///
/// Sans cela, un technicien promu administrateur resterait sur l'interface
/// technicien jusqu'au prochain redémarrage de l'application.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _subscriptions = [
      ref.listen(currentUserIdProvider, (_, __) => notifyListeners()),
      ref.listen(currentProfileProvider, (_, __) => notifyListeners()),
    ];
  }

  late final List<ProviderSubscription<Object?>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    super.dispose();
  }
}
