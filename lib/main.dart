import 'dart:async';

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
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final container = ProviderContainer();

  // Réinstalle le profil local de la session persistée. Purement local, aucun
  // appel réseau : l'application doit s'ouvrir dans un sous-sol.
  await container.read(authServiceProvider).restoreSession();

  // Le moteur démarre avant le premier écran : une session précédente peut
  // avoir laissé des relevés non poussés, et ils doivent partir dès que le
  // réseau le permet, sans attendre une action de l'opérateur.
  await container.read(syncEngineProvider).start();

  // Ménage des fichiers laissés par un crash entre la compression d'un cliché
  // et son enregistrement en base. Sans attendre : c'est de l'entretien, il n'a
  // aucune raison de retarder l'affichage.
  unawaited(
    container
        .read(photoStorageProvider)
        .sweepOrphans(container.read(databaseProvider)),
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
