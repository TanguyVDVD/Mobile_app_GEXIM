import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clés injectées au build (`--dart-define`) plutôt qu'écrites en dur : elles
  // diffèrent entre l'environnement de recette et la production, et n'ont rien
  // à faire dans le dépôt.
  const url = String.fromEnvironment('SUPABASE_URL');
  const cle = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // Sans elles, `Supabase.initialize` recevait des chaînes vides et
  // l'application mourait avant son premier écran, sur une trace illisible.
  // Une build mal configurée doit le dire, en clair, à qui la lance.
  if (url.isEmpty || cle.isEmpty) {
    runApp(
      const _EchecDemarrage(
        'Cette version a été compilée sans sa configuration serveur '
        '(SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY).\n\n'
        'Recompilez-la avec --dart-define-from-file=env.json.',
      ),
    );
    return;
  }

  final container = ProviderContainer();

  try {
    await Supabase.initialize(url: url, publishableKey: cle);

    // Réinstalle le profil local de la session persistée. Purement local,
    // aucun appel réseau : l'application doit s'ouvrir dans un sous-sol.
    await container.read(authServiceProvider).restoreSession();

    // Le moteur démarre avant le premier écran : une session précédente peut
    // avoir laissé des relevés non poussés, et ils doivent partir dès que le
    // réseau le permet, sans attendre une action de l'opérateur.
    await container.read(syncEngineProvider).start();
  } on Object catch (e, pile) {
    // Une base locale qui ne s'ouvre pas, ou qu'une autre version a créée :
    // sans ce filet, l'application se fermait sur un écran blanc. Le message
    // insiste sur ce qu'il ne faut pas faire à la légère — désinstaller
    // emporterait les relevés qui n'ont pas encore quitté l'appareil.
    developer.log(
      'Démarrage impossible',
      name: 'main',
      error: e,
      stackTrace: pile,
    );
    container.dispose();
    // Le message seul : `StateError.toString()` le préfixe de « Bad state: »,
    // un jargon de développeur qui n'a rien à faire devant un technicien.
    final cause = e is StateError ? e.message : '$e';
    runApp(
      _EchecDemarrage(
        'L\'application n\'a pas pu démarrer.\n\n$cause\n\n'
        'Redémarrez-la. Si le problème persiste, prévenez un administrateur '
        'avant toute désinstallation : les relevés non encore transmis sont '
        'sur cet appareil.',
      ),
    );
    return;
  }

  // Ménage des fichiers laissés par un crash entre la compression d'un cliché
  // et son enregistrement en base. Sans attendre : c'est de l'entretien, il n'a
  // aucune raison de retarder l'affichage — ni de le faire échouer.
  unawaited(
    container
        .read(photoStorageProvider)
        .sweepOrphans(container.read(databaseProvider))
        .catchError((Object e) {
      developer.log('Ménage des clichés orphelins interrompu',
          name: 'main', error: e);
      return 0;
    }),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FireStopApp(),
    ),
  );
}

class FireStopApp extends ConsumerStatefulWidget {
  const FireStopApp({super.key});

  @override
  ConsumerState<FireStopApp> createState() => _FireStopAppState();
}

class _FireStopAppState extends ConsumerState<FireStopApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Le retour au premier plan est le meilleur signal disponible : l'opérateur
    // ressort du bâtiment, la tablette retrouve du réseau et l'écran se rallume
    // souvent avant que l'événement de connectivité ne remonte.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(syncEngineProvider).syncNow(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FireStop Tracker',
      theme: Fs.build(),
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Application de secours, quand la vraie n'a pas pu démarrer.
///
/// Autonome : ni routeur, ni base, ni fournisseurs — c'est précisément ce qui a
/// pu échouer. Le message est sélectionnable, pour qu'on puisse le recopier à
/// qui dépannera.
class _EchecDemarrage extends StatelessWidget {
  const _EchecDemarrage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireStop Tracker',
      theme: Fs.build(),
      debugShowCheckedModeBanner: false,
      home: _MessageEchec(message),
    );
  }
}

class _MessageEchec extends StatelessWidget {
  const _MessageEchec(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Fs.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 52, height: 5, color: Fs.signal),
                  const SizedBox(height: Fs.lg),
                  Text(
                    'Démarrage impossible',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Fs.lg),
                  SelectableText(
                    message,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.45,
                      color: Fs.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
