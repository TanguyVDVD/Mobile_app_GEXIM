import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import 'auth_backend.dart';
import 'auth_service.dart';

/// Création de compte, ouverte à tous.
///
/// Le compte créé est **toujours** un simple technicien, sans accès à aucun
/// chantier : le rôle est fixé par défaut en base et n'est jamais transmis
/// depuis le client. C'est un administrateur qui affecte ensuite.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_fullName.text.trim().isEmpty) {
      setState(() => _error = 'Indiquez votre nom : il figurera sur les '
          'rapports de conformité, en regard de chaque traversée relevée.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Le mot de passe doit faire au moins '
          '8 caractères.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final opened = await ref.read(authServiceProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
          );

      if (!mounted) return;
      if (!opened) {
        // Confirmation par courriel activée sur le projet : le compte existe
        // mais la session n'est pas ouverte. Sans ce message, l'inscription
        // paraîtrait avoir échoué.
        setState(() => _notice =
            'Compte créé. Ouvrez le courriel de confirmation que vous venez '
            'de recevoir, puis connectez-vous.');
      }
      // Session ouverte : le routeur bascule seul, rien à faire ici.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PendingWorkBlocked catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      // Même filet qu'à la connexion : aucune issue ne doit rester muette.
      if (mounted) {
        setState(() => _error = 'Inscription interrompue par une erreur '
            'inattendue : $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _fullName,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Nom et prénom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      helperText: '8 caractères minimum',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _Banner(_error!, color: theme.colorScheme.errorContainer),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 16),
                    _Banner(
                      _notice!,
                      color: theme.colorScheme.secondaryContainer,
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Créer le compte'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    child: const Text('J\'ai déjà un compte'),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Votre compte n\'ouvre par défaut aucun chantier. Un '
                    'administrateur doit vous affecter à ceux sur lesquels '
                    'vous intervenez.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
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

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}
