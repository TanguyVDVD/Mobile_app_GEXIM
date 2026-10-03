import 'package:firestop_tracker/app/providers.dart';
import 'package:firestop_tracker/app/theme.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:firestop_tracker/features/points/point_editor_screen.dart';
import 'package:firestop_tracker/sync/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le bouton « Supprimer » de la fiche d'une traversée.
///
/// Il restait inerte à l'ouverture de la fiche, et ne s'éveillait qu'après un
/// autre geste. Il lisait un drapeau posé **pendant** l'affichage, plus bas
/// dans le même `build` : construit avant, il le voyait encore faux, et rien
/// ne redemandait l'affichage ensuite. D'où ce test, qui regarde le bouton
/// sans avoir touché à rien d'autre.
void main() {
  final point = Point(
    id: 'pt1',
    projectId: 'p1',
    refNumber: '1.40',
    authorId: 'u1',
    capturedAt: DateTime(2026, 10, 3),
    updatedAt: DateTime(2026, 10, 3),
  );
  final chantier = Project(
    id: 'p1',
    clientId: 'c1',
    name: 'Hall logistique',
    status: ProjectStatus.inProgress,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  Widget fiche() {
    return ProviderScope(
      overrides: [
        pointProvider.overrideWith((ref, id) => Stream.value(point)),
        projectProvider.overrideWith((ref, id) => Stream.value(chantier)),
        pointPhotosProvider.overrideWith((ref, id) => Stream.value([])),
        refNumberTakenProvider.overrideWith((ref, id) => Stream.value(false)),
        settingOptionsProvider.overrideWith((ref, kind) => Stream.value([])),
        productsOfSupplierProvider.overrideWith((ref, id) => Stream.value([])),
        settingOptionLabelsProvider.overrideWith((ref) => Stream.value({})),
        syncStateProvider.overrideWith((ref) => Stream.value(SyncState.idle)),
        pendingCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: MaterialApp(
        theme: Fs.build(),
        home: const PointEditorScreen(pointId: 'pt1'),
      ),
    );
  }

  IconButton boutonSupprimer(WidgetTester tester) => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );

  testWidgets('est actif des que la fiche est affichee', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(fiche());
    await tester.pumpAndSettle();

    // La fiche est là…
    expect(find.text('Hall logistique'), findsOneWidget);
    // … et le bouton répond, sans qu'on ait rien touché d'autre.
    expect(boutonSupprimer(tester).onPressed, isNotNull);
  });

  testWidgets('ouvre un avertissement avant de supprimer quoi que ce soit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(fiche());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Supprimer définitivement cette traversée ?'),
      findsOneWidget,
    );

    // « Annuler » referme sans rien faire : la fiche est toujours là.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hall logistique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
