import 'package:firestop_tracker/app/theme.dart';
import 'package:firestop_tracker/shared/widgets/plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les briques visuelles rendues **dans une liste**.
///
/// C'est le contexte qui compte : une `ListView` donne une hauteur non bornée,
/// et c'est précisément là qu'une contrainte mal posée explose. Un `Plate`
/// vérifié isolément dans un `Scaffold` — donc borné — passerait sans rien
/// prouver.
void main() {
  Widget dansUneListe(List<Widget> enfants) {
    return MaterialApp(
      theme: Fs.build(),
      home: Scaffold(
        body: ListView(children: enfants),
      ),
    );
  }

  testWidgets('un Plate se pose dans une liste, avec et sans liseré',
      (tester) async {
    await tester.pumpWidget(
      dansUneListe(const [
        Plate(child: Text('sans liseré')),
        SizedBox(height: 8),
        Plate(accent: true, child: Text('avec liseré')),
      ]),
    );

    // `pumpWidget` n'échoue pas sur une exception de mise en page : elle est
    // capturée et transformée en erreur de test. D'où la vérification
    // explicite.
    expect(
      tester.takeException(),
      isNull,
      reason: 'une contrainte infinie ici abandonne la mise en page de toute '
          'la liste, qui apparait alors vide sans le moindre message',
    );
    expect(find.text('sans liseré'), findsOneWidget);
    expect(find.text('avec liseré'), findsOneWidget);
  });

  testWidgets('le liseré prend la hauteur du contenu, quelle qu\'elle soit',
      (tester) async {
    await tester.pumpWidget(
      dansUneListe(const [
        Plate(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ligne 1'),
              Text('ligne 2'),
              Text('ligne 3'),
            ],
          ),
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Plate)).height, greaterThan(60));
  });

  testWidgets('le registre affiche numéro, état des clichés et vide', (tester) async {
    await tester.pumpWidget(
      dansUneListe(const [
        Plate(
          child: Row(
            children: [
              ReferenceTag(label: '12'),
              SizedBox(width: 12),
              SealRule(before: true, after: false),
            ],
          ),
        ),
        EmptyState(title: 'Rien ici', body: 'Commencez par relever.'),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(
      find.text('Après manquant'),
      findsOneWidget,
      reason: 'l\'etat des deux cliches reglementaires doit se lire en clair',
    );
    expect(find.text('Rien ici'), findsOneWidget);
  });
}
