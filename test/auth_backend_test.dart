import 'dart:convert';
import 'dart:io';

import 'package:firestop_tracker/features/auth/auth_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le vrai `GoTrueClient`, branché sur un client HTTP qui échoue à la demande.
///
/// Ce qui est vérifié ici n'est pas notre traduction des messages, c'est ce que
/// `gotrue` lance réellement : il enveloppe toute erreur de transport dans une
/// `AuthRetryableFetchException`. Un faux client d'authentification aurait
/// levé la `SocketException` que le code attendait — et le test serait passé
/// sur le bogue même qu'il doit empêcher.
SupabaseAuthBackend _backend(MockClientHandler handler) {
  return SupabaseAuthBackend(
    GoTrueClient(
      url: 'https://exemple.supabase.co/auth/v1',
      headers: const {'apikey': 'cle-de-test'},
      httpClient: MockClient(handler),
      autoRefreshToken: false,
      // `pkce` exige un stockage pour l'inscription ; le chemin d'erreur, lui,
      // est le même dans les deux modes.
      flowType: AuthFlowType.implicit,
    ),
  );
}

/// Réponse du serveur d'authentification à une connexion réussie.
///
/// Le jeton d'accès est un vrai JWT — non signé, `gotrue` ne vérifie pas la
/// signature à la connexion — parce que la session en lit l'expiration.
Map<String, Object?> _session() {
  String segment(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final jeton = '${segment({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment({'sub': 'u1', 'exp': 4102444800, 'role': 'authenticated'})}.'
      'signature';

  return {
    'access_token': jeton,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'refresh_token': 'jeton-de-rafraichissement',
    'user': {
      'id': 'u1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'tech@exemple.be',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

Future<AuthFailure> _echecConnexion(SupabaseAuthBackend backend) async {
  try {
    await backend.signIn(email: 'tech@exemple.be', password: 'secret');
  } on AuthFailure catch (e) {
    return e;
  }
  fail('La connexion aurait dû échouer.');
}

Future<AuthFailure> _echecInscription(SupabaseAuthBackend backend) async {
  try {
    await backend.signUp(
      email: 'tech@exemple.be',
      password: 'secret123',
      fullName: 'Tech',
    );
  } on AuthFailure catch (e) {
    return e;
  }
  fail("L'inscription aurait dû échouer.");
}

void main() {
  // Ce que produit une tablette sans DNS : `http` lève une `ClientException`
  // qui est aussi une `SocketException`, et c'est son texte qui s'affichait.
  Future<http.Response> sansReseau(http.Request _) => throw const SocketException(
        "Failed host lookup: 'exemple.supabase.co'",
      );

  group('connexion', () {
    test('sans réseau : message clair, jamais la trace technique', () async {
      final e = await _echecConnexion(_backend(sansReseau));

      expect(e.isNetwork, isTrue);
      expect(e.message, startsWith('Aucune connexion.'));
      expect(e.message, isNot(contains('Exception')));
    });

    test('poignée de main TLS refusée : renvoie vers la date', () async {
      final e = await _echecConnexion(
        _backend(
          (_) => throw const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
      );

      expect(e.isNetwork, isTrue);
      expect(e.message, contains("la date et l'heure"));
    });

    test('serveur en 5xx : ni « identifiants » ni « pas de réseau »', () async {
      final e = await _echecConnexion(
        _backend((_) async => http.Response('upstream timeout', 503)),
      );

      expect(e.isNetwork, isFalse);
      expect(e.message, contains('503'));
      expect(e.message, isNot(contains('upstream')));
    });

    test('mauvais mot de passe : toujours « Identifiants incorrects »',
        () async {
      final e = await _echecConnexion(
        _backend(
          (_) async => http.Response(
            '{"code":400,"error_code":"invalid_credentials",'
            '"msg":"Invalid login credentials"}',
            400,
          ),
        ),
      );

      expect(e.isNetwork, isFalse);
      expect(e.message, 'Identifiants incorrects.');
    });

    test('adresse non confirmée : le dire, pas « identifiants incorrects »',
        () async {
      // Le serveur répond 400 ici aussi. Traduit d'après le seul statut, le
      // refus envoyait le technicien ressaisir un mot de passe juste, au lieu
      // d'aller cliquer le lien reçu par courriel.
      final e = await _echecConnexion(
        _backend(
          (_) async => http.Response(
            '{"code":400,"error_code":"email_not_confirmed",'
            '"msg":"Email not confirmed"}',
            400,
          ),
        ),
      );

      expect(e.message, contains('pas encore confirmée'));
      expect(e.message, isNot(contains('Email')));
    });

    test('trop de tentatives : patienter, pas ressaisir', () async {
      final e = await _echecConnexion(
        _backend(
          (_) async => http.Response(
            '{"code":429,"error_code":"over_request_rate_limit",'
            '"msg":"Request rate limit reached"}',
            429,
          ),
        ),
      );

      expect(e.message, startsWith('Trop de tentatives'));
    });
  });

  group('inscription', () {
    test('sans réseau : message clair', () async {
      final e = await _echecInscription(_backend(sansReseau));

      expect(e.isNetwork, isTrue);
      expect(e.message, startsWith('Aucune connexion.'));
      expect(e.message, isNot(contains('Exception')));
    });

    test('mot de passe trop faible : en français', () async {
      final e = await _echecInscription(
        _backend(
          (_) async => http.Response(
            '{"code":422,"error_code":"weak_password",'
            '"msg":"Password should be at least 6 characters.",'
            '"weak_password":{"reasons":["length"]}}',
            422,
          ),
        ),
      );

      expect(e.message, startsWith('Mot de passe trop faible'));
    });
  });

  test('déconnexion hors réseau : aboutit, sans exception', () async {
    // `gotrue` efface la session locale puis prévient le serveur. Hors réseau,
    // ce second temps échoue — et l'exception remontait jusqu'au menu, alors
    // que la déconnexion avait bel et bien eu lieu.
    final backend = _backend((requete) async {
      if (requete.url.path.endsWith('/logout')) {
        throw const SocketException("Failed host lookup: 'exemple.supabase.co'");
      }
      return http.Response(jsonEncode(_session()), 200);
    });

    await backend.signIn(email: 'tech@exemple.be', password: 'secret');
    expect(backend.currentUserId, 'u1');

    await backend.signOut();

    expect(
      backend.currentUserId,
      isNull,
      reason: 'la session locale doit être fermée, réseau ou pas',
    );
  });
}
