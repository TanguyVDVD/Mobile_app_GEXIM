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

  /// Ferme la session **sur cet appareil**. Ne doit pas échouer faute de
  /// réseau : voir [SupabaseAuthBackend.signOut].
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
    } on AuthRetryableFetchException catch (e) {
      throw _transport(
        e,
        horsLigne: 'Aucune connexion. La première ouverture de session doit '
            'se faire avec du réseau ; ensuite l\'application fonctionne hors '
            'ligne.',
      );
    } on AuthException catch (e) {
      throw AuthFailure(
        _motif(e) ??
            // Volontairement identique pour un compte inconnu et un mot de
            // passe faux : distinguer les deux révélerait quels comptes
            // existent. Un ancien serveur répond 400 sans autre précision.
            (e.statusCode == '400'
                ? 'Identifiants incorrects.'
                : 'Connexion refusée : ${e.message}'),
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
    } on AuthRetryableFetchException catch (e) {
      throw _transport(
        e,
        horsLigne:
            'Aucune connexion. La création d\'un compte nécessite du réseau.',
      );
    } on AuthException catch (e) {
      throw AuthFailure(
        _motif(e) ??
            (e.message.contains('already registered')
                ? 'Un compte existe déjà pour cette adresse.'
                : 'Inscription refusée : ${e.message}'),
      );
    }
  }

  /// Message pour les refus que le serveur **nomme**.
  ///
  /// `gotrue` expose le code d'erreur stable du serveur (`error_code`) dans
  /// [AuthException.code]. On s'y fie plutôt qu'au texte, qui est en anglais
  /// et change d'une version du serveur à l'autre.
  ///
  /// Le cas qui a motivé cette table : une adresse **non confirmée** répond,
  /// elle aussi, en HTTP 400. Elle s'affichait donc « Identifiants
  /// incorrects », et le technicien ressaisissait indéfiniment un mot de passe
  /// juste au lieu d'aller cliquer le lien reçu par courriel.
  ///
  /// Rend `null` pour un code inconnu : l'appelant garde alors son repli.
  static String? _motif(AuthException e) {
    const tropDeTentatives =
        'Trop de tentatives. Patientez quelques minutes avant de réessayer.';
    const motDePasseFaible = 'Mot de passe trop faible. Choisissez-en un plus '
        'long, mêlant lettres, chiffres et symboles.';

    // Levée sans code par certaines versions de `gotrue`.
    if (e is AuthWeakPasswordException) return motDePasseFaible;

    final parCode = switch (e.code) {
      'invalid_credentials' => 'Identifiants incorrects.',
      'email_not_confirmed' => 'Adresse e-mail pas encore confirmée. Ouvrez '
          'le lien reçu par courriel, puis reconnectez-vous.',
      'user_already_exists' ||
      'email_exists' =>
        'Un compte existe déjà pour cette adresse.',
      'weak_password' => motDePasseFaible,
      'email_address_invalid' || 'validation_failed' => 'Adresse e-mail '
          'invalide.',
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' =>
        tropDeTentatives,
      'signup_disabled' || 'email_provider_disabled' => 'La création de '
          'compte est désactivée. Demandez un accès à un administrateur.',
      'user_banned' => 'Ce compte est suspendu. Contactez un administrateur.',
      _ => null,
    };
    if (parCode != null) return parCode;

    // Serveur plus ancien, sans code : le statut suffit à reconnaître la
    // limitation de débit.
    if (e.statusCode == '429') return tropDeTentatives;
    return null;
  }

  /// Traduit un échec de transport.
  ///
  /// `gotrue` ne laisse jamais passer une `SocketException` : il attrape toute
  /// erreur du client HTTP et la relance en [AuthRetryableFetchException] — une
  /// sous-classe d'[AuthException], dont le message est le `toString()` de
  /// l'erreur d'origine. Des branches `on SocketException` placées après
  /// `on AuthException` ne sont donc jamais atteintes, et c'est ce qui
  /// affichait « Connexion refusée : ClientException with SocketException:
  /// Failed host lookup » à un technicien simplement privé de réseau.
  ///
  /// Sans code HTTP, la requête n'a pas abouti. Avec un code (5xx), le serveur
  /// a répondu, mais mal : ressaisir ne servirait à rien.
  static AuthFailure _transport(
    AuthRetryableFetchException e, {
    required String horsLigne,
  }) {
    if (e.statusCode != null) {
      return AuthFailure(
        'Le service d\'authentification ne répond pas correctement '
        '(${e.statusCode}). Réessayez dans un instant.',
      );
    }
    // L'exception d'origine est perdue : seul son texte subsiste.
    if (e.message.contains('HandshakeException')) {
      return const AuthFailure(
        'Connexion sécurisée impossible. Vérifiez la date et l\'heure de '
        'l\'appareil.',
        isNetwork: true,
      );
    }
    return AuthFailure(horsLigne, isNetwork: true);
  }

  /// Ferme la session sur l'appareil, réseau ou pas.
  ///
  /// `gotrue` efface la session locale **avant** de prévenir le serveur (voir
  /// `GoTrueClient._signOut`), puis relance l'échec de cet appel. Hors réseau,
  /// la déconnexion avait donc bien lieu — l'écran de connexion s'affichait —
  /// mais l'appelant recevait une exception que personne n'attrapait. Le jeton
  /// côté serveur expirera de lui-même : rien ne justifie de signaler un échec
  /// pour un geste qui a réussi.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException {
      // Session locale déjà effacée : voir ci-dessus.
    }
  }
}
