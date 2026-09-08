import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce dont l'application a réellement besoin d'un fournisseur d'identité.
///
/// Réduit au minimum pour que `AuthService` — qui porte toute la logique
/// délicate : purge, garde-fous, profil local — soit testable sans réseau ni
/// plugin.
abstract interface class AuthBackend {
  String? get currentUserId;
  String? get currentUserEmail;

  /// Émet à chaque ouverture ou fermeture de session.
  Stream<String?> get userIdChanges;

  Future<void> signIn({required String email, required String password});

  /// Crée un compte. Rend `true` si la session est immédiatement ouverte.
  ///
  /// `false` signifie que le projet Supabase exige une confirmation par
  /// courriel : le compte existe, mais l'utilisateur doit cliquer le lien reçu
  /// avant de pouvoir se connecter. Les deux cas doivent être distingués à
  /// l'écran, sans quoi l'inscription paraît avoir échoué.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut();
}

/// Échec de connexion, déjà formulé pour l'opérateur.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.isNetwork = false});

  final String message;

  /// Distingue « mauvais mot de passe » de « pas de réseau ». Sur un chantier,
  /// la seconde est de loin la plus fréquente, et la réponse à donner n'est pas
  /// la même : ressaisir, ou remonter chercher du signal.
  final bool isNetwork;

  @override
  String toString() => message;
}

class SupabaseAuthBackend implements AuthBackend {
  const SupabaseAuthBackend(this._auth);

  final GoTrueClient _auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Stream<String?> get userIdChanges =>
      _auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw AuthFailure(
        // Volontairement identique pour un compte inconnu et un mot de passe
        // faux : distinguer les deux révélerait quels comptes existent.
        e.statusCode == '400'
            ? 'Identifiants incorrects.'
            : 'Connexion refusée : ${e.message}',
      );
    } on SocketException {
      throw const AuthFailure(
        'Aucune connexion. La première ouverture de session doit se faire '
        'avec du réseau ; ensuite l\'application fonctionne hors ligne.',
        isNetwork: true,
      );
    } on HandshakeException {
      throw const AuthFailure(
        'Connexion sécurisée impossible. Vérifiez la date et l\'heure de '
        'l\'appareil.',
        isNetwork: true,
      );
    }
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // Repris par le trigger `handle_new_user`, qui crée le profil côté
        // serveur. Le rôle, lui, n'est jamais transmis : il vaut `operator` par
        // défaut en base, et seul un admin peut l'élever ensuite.
        data: {'full_name': fullName.trim()},
      );
      return response.session != null;
    } on AuthException catch (e) {
      throw AuthFailure(
        e.message.contains('already registered')
            ? 'Un compte existe déjà pour cette adresse.'
            : 'Inscription refusée : ${e.message}',
      );
    } on SocketException {
      throw const AuthFailure(
        'Aucune connexion. La création d\'un compte nécessite du réseau.',
        isNetwork: true,
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
