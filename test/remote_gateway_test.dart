import 'dart:async';

import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/sync/backoff.dart';
import 'package:firestop_tracker/sync/remote_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un serveur qui accepte la connexion et ne répond jamais.
///
/// Le cas du portail captif, ou du Wi-Fi de chantier saturé. Sans délai de
/// garde, l'appel restait suspendu pour toujours — et `SyncEngine.syncNow`,
/// qui rend le cycle en cours plutôt que d'en lancer un second, figeait toute
/// la synchronisation jusqu'au redémarrage de l'application.
///
/// Le vrai client Supabase est utilisé, branché sur un client HTTP qui ne
/// répond jamais : c'est bien la pile réelle qui doit être bornée, pas un
/// double qui aurait levé de lui-même.
void main() {
  late SupabaseClient client;
  late SupabaseRemoteGateway gateway;

  setUp(() {
    client = SupabaseClient(
      'https://exemple.supabase.co',
      'cle-de-test',
      httpClient: MockClient((_) => Completer<http.Response>().future),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    gateway = SupabaseRemoteGateway(
      client,
      delaiRequete: const Duration(milliseconds: 50),
      delaiTransfert: const Duration(milliseconds: 50),
    );
  });

  tearDown(() => client.dispose());

  // Transitoire : le cycle s'interrompt proprement et le suivant réessaiera.
  // Une erreur définitive aurait mis le relevé de côté pour arbitrage humain,
  // pour une simple panne de réseau.
  final coupureReseau = throwsA(
    isA<SyncException>().having((e) => e.isTransient, 'isTransient', isTrue),
  );

  test('un envoi sans réponse devient une coupure réseau', () {
    expect(
      gateway.upsert(OutboxEntity.point, {'id': 'p1'}),
      coupureReseau,
    );
  });

  test('une page de descente sans réponse aussi', () {
    expect(
      gateway.fetchSince(
        entity: PullEntity.project,
        since: null,
        offset: 0,
        limit: 10,
      ),
      coupureReseau,
    );
  });

  test('un téléchargement de cliché sans réponse aussi', () {
    expect(gateway.downloadPhoto('p1/pt1/ph1.jpg'), coupureReseau);
  });
}
