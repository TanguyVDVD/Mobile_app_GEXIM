import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Prise de vue plein écran. Rend le fichier brut via `Navigator.pop`.
///
/// L'écran ne connaît ni la base ni la compression : il produit un fichier, et
/// `PhotoCaptureService` se charge du reste. Cette séparation permet de tester
/// tout l'enchaînement sans caméra.
class CameraScreen extends StatefulWidget {
  const CameraScreen({required this.title, super.key});

  final String title;

  static Future<File?> push(BuildContext context, String title) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => CameraScreen(title: title)),
    );
  }

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Android reprend la caméra dès que l'app passe en arrière-plan. Ne pas
    // libérer le contrôleur laisserait un aperçu figé au retour.
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Aucune caméra disponible sur cet appareil.');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // `ultraHigh` et non `max` : la définition maximale du capteur monopolise
      // la mémoire et ralentit le déclenchement, alors que la compression
      // ramène de toute façon le cliché à ~2000 px. `ultraHigh` laisse la marge
      // nécessaire sans faire attendre l'opérateur entre deux prises.
      final controller = CameraController(
        back,
        ResolutionPreset.ultraHigh,
        // Pas de micro : demander la permission audio pour photographier un mur
        // ferait légitimement hésiter l'utilisateur au moment de l'accorder.
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      // `initialize()` déclenche lui-même la demande de permission Android : le
      // plugin s'en charge, inutile d'ajouter permission_handler. En revanche
      // le refus revient sous forme de code technique, que personne ne peut
      // interpréter sur un chantier — d'où ce message explicite.
      setState(() {
        _error = e.code == 'CameraAccessDenied'
            ? 'Accès à la caméra refusé.\n\n'
                'Autorisez-le dans Réglages › Applications › FireStop Tracker '
                '› Autorisations, puis revenez sur cet écran.'
            : e.description ?? 'Caméra indisponible.';
      });
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || _busy) return;

    // Verrou anti double-déclenchement : sur un écran tactile utilisé avec des
    // gants, le double appui involontaire est la règle plus que l'exception.
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(File(shot.path));
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.description ?? 'Échec de la prise de vue.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: switch ((_error, controller)) {
        (final String message, _) => _Message(message),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final CameraController c) => Center(child: CameraPreview(c)),
      },
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller == null
          ? null
          : FloatingActionButton.large(
              onPressed: _busy ? null : _shoot,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.camera_alt),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
