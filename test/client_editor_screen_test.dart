import 'package:firestop_tracker/app/theme.dart';
import 'package:firestop_tracker/features/admin/client_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Création d'un client sans logo.
///
/// Le refus était prononcé dans `_creer`, qui rendait ensuite la main
/// normalement : `_save` fermait alors l'écran derrière le message. Le client
/// n'était pas créé, et le nom et l'adresse saisis étaient perdus — il fallait
/// tout retaper, en ayant lu un message qui disparaissait avec l'écran.
///
/// Aucun fournisseur n'est surchargé, et c'est voulu : un refus de validation
/// ne doit toucher ni la base ni le réseau. S'il le faisait, le test lèverait.
void main() {
  testWidgets('sans logo, l\'enregistrement est refusé et l\'écran reste ouvert',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: Fs.build(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClientEditorScreen(),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    // Poussé par-dessus un écran, comme dans l'application : c'est le seul
    // moyen de voir un `pop` intempestif.
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nom du client *'),
      'Client Test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Adresse *'),
      'Rue de l\'Industrie 12, 4000 Liège',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byType(ClientEditorScreen),
      findsOneWidget,
      reason: 'l\'écran se fermait derrière le refus, en perdant la saisie',
    );
    expect(
      find.text('Le logo est obligatoire : il figure sur chaque fiche.'),
      findsOneWidget,
    );
    // La saisie est toujours là, prête à être complétée d'un logo.
    expect(find.text('Client Test'), findsOneWidget);
  });
}
