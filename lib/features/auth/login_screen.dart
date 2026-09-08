import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'auth_backend.dart';
import 'auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
      // Aucune navigation ici : le `redirect` du routeur observe la session et
      // bascule seul.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PendingWorkBlocked catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Fs.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: Fs.xxl),

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Adresse e-mail'),
                  ),
                  const SizedBox(height: Fs.md),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    // Le clavier de chantier se referme mal : valider depuis la
                    // touche entrée évite de viser le bouton avec des gants.
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Fs.lg),
                    _ErrorNote(_error!),
                  ],

                  const SizedBox(height: Fs.xl),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Se connecter'),
                  ),
                  const SizedBox(height: Fs.md),
                  TextButton(
                    onPressed: _busy ? null : () => context.push('/signup'),
                    child: const Text('Créer un compte'),
                  ),

                  const SizedBox(height: Fs.xl),
                  Text(
                    'La première connexion demande du réseau. Ensuite, '
                    'l\'application s\'ouvre et fonctionne hors ligne : les '
                    'relevés partent d\'eux-mêmes au retour du signal.',
                    textAlign: TextAlign.center,
                    style: Fs.metaOf(context),
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

/// Marque : le trait rouge coupe-feu, seul élément de couleur de l'écran.
///
/// Reprend le liseré des étiquettes de repérage. C'est là que l'audace est
/// dépensée sur cet écran ; tout le reste est encre et papier.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 52, height: 5, color: Fs.signal),
        const SizedBox(height: Fs.lg),
        Text(
          'FireStop',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          'Registre des traversées coupe-feu',
          style: Fs.metaOf(context),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Fs.md),
      decoration: const BoxDecoration(
        color: Fs.signalWash,
        borderRadius: Fs.radius,
        border: Border(left: BorderSide(color: Fs.signal, width: 3)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 15, color: Fs.ink, height: 1.4),
      ),
    );
  }
}
