import 'package:firestop_tracker/app/providers.dart';
import 'package:firestop_tracker/app/theme.dart';
import 'package:firestop_tracker/features/admin/settings_screen.dart';
import 'package:firestop_tracker/sync/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La boîte de saisie d'un libellé, fermée sans rien enregistrer.
///
/// Le contrôleur du champ était libéré dès le retour de `showDialog`, alors que
/// la boîte jouait encore son animation de sortie : « Annuler » levait « A
/// TextEditingController was used after being disposed ». D'où le
/// `pumpAndSettle` — c'est pendant l'animation que l'erreur tombe, pas au
/// moment de l'appui.
void main() {
  Widget ecran() {
    return ProviderScope(
      overrides: [
        settingOptionsProvider.overrideWith((ref, kind) => Stream.value([])),
        syncStateProvider.overrideWith((ref) => Stream.value(SyncState.idle)),
        pendingCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: MaterialApp(theme: Fs.build(), home: const SettingsScreen()),
    );
  }

  Future<void> ouvrirLaSaisie(WidgetTester tester) async {
    await tester.pumpWidget(ecran());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle configuration'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('annuler la saisie ferme la boîte sans erreur', (tester) async {
    await ouvrirLaSaisie(tester);
    await tester.enterText(find.byType(TextField), 'Traversée murale');

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('enregistrer un libellé vide vaut annulation, sans erreur',
      (tester) async {
    await ouvrirLaSaisie(tester);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
