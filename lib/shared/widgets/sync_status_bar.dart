import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../sync/sync_engine.dart';

/// Bandeau d'état de la synchronisation.
///
/// Sur un chantier sans réseau, c'est la **seule** preuve visible pour
/// l'opérateur que son travail n'est pas perdu. Affiché en permanence et non
/// signalé par une notification passagère : quelqu'un qui doute de ce que
/// contient sa tablette doit pouvoir vérifier d'un coup d'œil.
///
/// Réduit à une ligne fine et silencieuse quand tout va bien — un bandeau
/// coloré en permanence finirait par ne plus être vu du tout, et ne signalerait
/// donc plus rien le jour où il compte.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).valueOrNull ?? SyncState.idle;
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;

    final attention = state == SyncState.needsAttention;
    final waiting = pending > 0 || state == SyncState.offline;

    final label = switch (state) {
      // « bloquée » et non « envoi refusé » : l'alerte couvre aussi une
      // descente interrompue, et un technicien à qui l'on parle d'envoi
      // chercherait ce qu'il a mal saisi.
      SyncState.needsAttention =>
        'Synchronisation bloquée — prévenez un administrateur, puis touchez '
            'pour réessayer',
      SyncState.syncing => 'Envoi en cours',
      SyncState.offline when pending > 0 =>
        'Hors ligne — $pending synchronisation${pending > 1 ? 's' : ''} en attente',
      SyncState.offline => 'Hors ligne',
      SyncState.idle when pending > 0 =>
        '$pending synchronisation${pending > 1 ? 's' : ''} en attente',
      SyncState.idle => 'Tout est envoyé',
    };

    final tone = attention
        ? Fs.signal
        : waiting
            ? Fs.ink
            : Fs.inkMuted;

    return Material(
      color: attention ? Fs.signalWash : Fs.ground,
      child: InkWell(
        // Un appui force un cycle : l'opérateur qui retrouve du réseau n'a pas
        // à attendre le battement périodique pour être rassuré.
        //
        // Après un refus définitif, le même appui réarme les envois abandonnés.
        // La cause est presque toujours réparable côté serveur — un chantier
        // rouvert, une affectation rétablie — et sans ce geste le relevé
        // resterait bloqué jusqu'à réinstallation.
        onTap: () => attention
            ? ref.read(syncEngineProvider).retryFailed()
            : ref.read(syncEngineProvider).syncNow(),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: Fs.border),
          ),
          padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.sm, Fs.lg, Fs.sm),
          child: Row(
            children: [
              _Dot(tone: tone, pulsing: state == SyncState.syncing),
              const SizedBox(width: Fs.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: tone,
                    fontWeight: attention || waiting
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille d'état. La seule animation non déclenchée de l'application, et
/// uniquement pendant un envoi : elle dit qu'il se passe quelque chose.
class _Dot extends StatefulWidget {
  const _Dot({required this.tone, required this.pulsing});

  final Color tone;
  final bool pulsing;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  // Créé dans `initState`, et surtout pas via un initialiseur `late final` :
  // celui-ci est **paresseux**. Tant que la pastille ne pulse pas, personne ne
  // touche le contrôleur — et c'est alors `dispose()` qui déclenche sa
  // construction, avec un `TickerProvider` déjà démonté. L'exception tombe à la
  // destruction de l'écran, loin de sa cause.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1,
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `MediaQuery.disableAnimations` respecte le réglage système
    // « réduire les animations ».
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return FadeTransition(
      opacity: widget.pulsing && !reduced
          ? Tween<double>(begin: 0.35, end: 1).animate(_controller)
          : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.tone,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }
}
