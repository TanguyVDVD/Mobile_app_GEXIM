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

  testWidgets('le registre affiche numéro, état des clichés et vide',
      (tester) async {
    await tester.pumpWidget(
      dansUneListe(const [
        Plate(
          child: Row(
            children: [
              ReferenceTag(label: '12'),
              SizedBox(width: 12),
              PointStatus(photos: 1, missingValues: 1),
            ],
          ),
        ),
        EmptyState(title: 'Rien ici', body: 'Commencez par relever.'),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(
      find.text('1 photo ajoutée, 1 valeur manquante', findRichText: true),
      findsOneWidget,
      reason: 'ce que la fiche a et ce qui lui manque doit se lire en clair',
    );
    expect(find.text('Rien ici'), findsOneWidget);
  });

  group('l\'etat d\'une fiche', () {
    /// Les morceaux affichés, chacun avec sa couleur.
    Future<List<(String, Color?)>> morceaux(
      WidgetTester tester,
      int photos,
      int manquantes,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointStatus(photos: photos, missingValues: manquantes),
          ),
        ),
      );
      final sortie = <(String, Color?)>[];
      // La couleur s'hérite de morceau en morceau : on descend l'arbre en la
      // portant, au lieu de ne lire que le style propre à chaque feuille.
      void descendre(InlineSpan span, Color? heritee) {
        if (span is! TextSpan) return;
        final couleur = span.style?.color ?? heritee;
        if (span.text != null) sortie.add((span.text!, couleur));
        for (final enfant in span.children ?? const <InlineSpan>[]) {
          descendre(enfant, couleur);
        }
      }

      descendre(tester.widget<RichText>(find.byType(RichText)).text, null);
      // Seuls les morceaux qui portent une information, pas la virgule.
      return sortie.where((m) => m.$1.trim() != ',').toList();
    }

    testWidgets('complet : au moins une photo et plus rien a remplir',
        (tester) async {
      expect(await morceaux(tester, 1, 0), [('Complet', Fs.inkMuted)]);
      expect(await morceaux(tester, 2, 0), [('Complet', Fs.inkMuted)]);
    });

    testWidgets('des photos, des valeurs manquantes : gris puis rouge',
        (tester) async {
      // Une photo ajoutée est un constat, pas une alerte : seul ce qui
      // manque est en rouge.
      expect(await morceaux(tester, 1, 1), [
        ('1 photo ajoutée', Fs.inkMuted),
        ('1 valeur manquante', Fs.signal),
      ]);
      expect(await morceaux(tester, 2, 4), [
        ('2 photos ajoutées', Fs.inkMuted),
        ('4 valeurs manquantes', Fs.signal),
      ]);
    });

    testWidgets('aucune photo : en rouge, avec ou sans valeur manquante',
        (tester) async {
      expect(await morceaux(tester, 0, 3), [
        ('Aucune photo ajoutée', Fs.signal),
        ('3 valeurs manquantes', Fs.signal),
      ]);
      // Tout est rempli, mais rien à montrer : pas « complet ».
      expect(await morceaux(tester, 0, 0), [
        ('Aucune photo ajoutée', Fs.signal),
      ]);
    });
  });
}
