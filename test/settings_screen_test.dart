import 'package:firestop_tracker/app/providers.dart';
import 'package:firestop_tracker/app/theme.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
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

  /// Les produits se gèrent depuis leur fournisseur : pas d'onglet « Produits »,
  /// et la page ouverte ne montre que ceux du fournisseur touché.
  testWidgets('un fournisseur ouvre sur ses seuls produits', (tester) async {
    SettingOption option(String id, SettingKind kind, String label,
            {String? chez}) =>
        SettingOption(
          id: id,
          kind: kind,
          label: label,
          sortOrder: 0,
          parentId: chez,
          updatedAt: DateTime(2026, 10, 3),
        );
    // La surface par défaut (800 px) laisse l'onglet « Fournisseurs » hors
    // champ ; la cible est une tablette.
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final promat = option('s1', SettingKind.supplier, 'Promat');
    final hilti = option('s2', SettingKind.supplier, 'Hilti');
    final produits = [
      option('p1', SettingKind.product, 'Promastop-FC', chez: 's1'),
      option('p2', SettingKind.product, 'Promaseal-A', chez: 's1'),
      option('p3', SettingKind.product, 'CFS-F FX', chez: 's2'),
      option('p4', SettingKind.product, 'Alsijoint'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingOptionsProvider.overrideWith(
            (ref, kind) => Stream.value(switch (kind) {
              SettingKind.supplier => [promat, hilti],
              SettingKind.product => produits,
              _ => <SettingOption>[],
            }),
          ),
          productsOfSupplierProvider.overrideWith(
            (ref, id) => Stream.value(
              [for (final p in produits) if (p.parentId == id) p],
            ),
          ),
          syncStateProvider.overrideWith((ref) => Stream.value(SyncState.idle)),
          pendingCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(theme: Fs.build(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Produits'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Fournisseurs'));
    await tester.pumpAndSettle();

    expect(find.text('2 produits'), findsOneWidget);
    expect(find.text('1 produit'), findsOneWidget);
    expect(
      find.text('1 produit sans fournisseur — à rattacher'),
      findsOneWidget,
    );

    await tester.tap(find.text('Promat'));
    await tester.pumpAndSettle();

    expect(find.text('Produits — Promat'), findsOneWidget);
    expect(find.text('Promastop-FC'), findsOneWidget);
    expect(find.text('Promaseal-A'), findsOneWidget);
    expect(find.text('CFS-F FX'), findsNothing);
    expect(find.text('Nouveau produit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
