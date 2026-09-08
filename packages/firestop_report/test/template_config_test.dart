import 'package:firestop_report/firestop_report.dart';
import 'package:test/test.dart';

/// Un gabarit est saisi par un administrateur, dans un champ JSON libre.
/// Refuser de produire un rapport de conformité — document contractuel — parce
/// qu'une clé est mal orthographiée serait bien pire que de le produire avec
/// les valeurs par défaut. Ces tests verrouillent cette tolérance.
void main() {
  _exemplesDocumentes();

  group('lecture tolerante', () {
    test('un objet vide donne le gabarit par defaut', () {
      final config = TemplateConfig.fromJson(const {});

      expect(config.brand.accentColor, 0xFFC8102E);
      expect(config.cover.enabled, isTrue);
      expect(config.pointCard.layout, PhotoLayout.twoUp);
      expect(config.pointCard.pageBreakPerPoint, isTrue);
    });

    test('une couleur invalide retombe sur l\'accent par defaut', () {
      for (final invalid in ['#GG0000', 'rouge', '#12345', '', 42]) {
        final config = TemplateConfig.fromJson({
          'brand': {'accentColor': invalid},
        });
        expect(
          config.brand.accentColor,
          0xFFC8102E,
          reason: 'la saisie $invalid a fait derailler le gabarit',
        );
      }
    });

    test('une couleur valide est lue, avec ou sans alpha', () {
      expect(
        TemplateConfig.fromJson(const {
          'brand': {'accentColor': '#0057B8'},
        }).brand.accentColor,
        0xFF0057B8,
      );
      expect(
        TemplateConfig.fromJson(const {
          'brand': {'accentColor': '#800057B8'},
        }).brand.accentColor,
        0x800057B8,
      );
    });

    test('une disposition inconnue retombe sur twoUp', () {
      expect(
        TemplateConfig.fromJson(const {
          'pointCard': {'layout': 'mosaique3d'},
        }).pointCard.layout,
        PhotoLayout.twoUp,
      );
    });

    test('grid2x2 reste accepte pour ne pas casser les gabarits existants', () {
      expect(
        TemplateConfig.fromJson(const {
          'pointCard': {'layout': 'grid2x2'},
        }).pointCard.layout,
        PhotoLayout.grid,
      );
    });

    test('une liste de champs vide ou illisible affiche tout', () {
      for (final value in [<String>[], ['inexistant'], 'texte', null]) {
        final config = TemplateConfig.fromJson({
          'pointCard': {'fields': value},
        });
        expect(
          config.pointCard.fields,
          const PointCardConfig().fields,
          reason: 'une fiche muette est pire qu\'une fiche trop bavarde',
        );
      }
    });

    test('les champs reconnus sont conserves, les inconnus ignores', () {
      final config = TemplateConfig.fromJson(const {
        'pointCard': {
          'fields': ['ref', 'inconnu', 'materials'],
        },
      });

      expect(config.pointCard.fields, [PointField.ref, PointField.materials]);
      expect(config.pointCard.shows(PointField.description), isFalse);
    });
  });

  group('gabarit reel', () {
    test('le gabarit livre dans seed.sql est lu integralement', () {
      final config = TemplateConfig.fromJson(const {
        'version': 1,
        'brand': {'accentColor': '#C8102E', 'fontFamily': 'Roboto'},
        'cover': {
          'enabled': true,
          'showClientLogo': true,
          'subtitle': 'Rapport de conformité — calfeutrement de traversées',
        },
        'pointCard': {
          'layout': 'twoUp',
          'fields': ['ref', 'location', 'materials', 'description'],
          'pageBreak': 'perPoint',
        },
        'header': {'left': '{{client.name}}', 'right': '{{project.name}}'},
        'footer': {'text': 'Page {{page}}/{{pages}} — généré le {{date}}'},
      });

      expect(config.version, 1);
      expect(config.cover.subtitle, contains('calfeutrement'));
      expect(config.pointCard.fields, hasLength(4));
      expect(config.header.left, '{{client.name}}');
      expect(
        config.footer.center,
        contains('{{page}}'),
        reason: 'seed.sql ecrit « text » la ou le modele attend « center »',
      );
    });

    test('pageBreak absent ou different garde une fiche par page', () {
      expect(
        TemplateConfig.fromJson(const {'pointCard': {}})
            .pointCard
            .pageBreakPerPoint,
        isTrue,
      );
      expect(
        TemplateConfig.fromJson(const {
          'pointCard': {'pageBreak': 'flow'},
        }).pointCard.pageBreakPerPoint,
        isFalse,
      );
    });
  });
}

/// Les gabarits publiés dans `docs/gabarit-rapport.md`.
///
/// Verrouillés ici pour qu'une évolution du moteur ne rende pas la
/// documentation fausse en silence : un administrateur qui copie un exemple
/// doit obtenir ce qui est annoncé.
void _exemplesDocumentes() {
  group('exemples de la documentation', () {
    test('exemple complet : toutes les cles sont bien lues', () {
      final c = TemplateConfig.fromJson(const {
        'version': 1,
        'brand': {'accentColor': '#C8102E', 'showLogo': true},
        'cover': {
          'enabled': true,
          'subtitle': 'Rapport de conformité - calfeutrement de traversées',
          'showSummary': true,
        },
        'pointCard': {
          'layout': 'twoUp',
          'fields': ['ref', 'location', 'materials', 'description', 'author', 'date'],
          'pageBreak': 'perPoint',
        },
        'header': {'left': '{{client.name}}', 'right': '{{project.name}}'},
        'footer': {'center': 'Page {{page}}/{{pages}} - généré le {{date}}'},
      });

      expect(c.brand.accentColor, 0xFFC8102E);
      expect(c.brand.showLogo, isTrue);
      expect(c.cover.showSummary, isTrue);
      expect(c.pointCard.layout, PhotoLayout.twoUp);
      expect(c.pointCard.fields, hasLength(6));
      expect(c.pointCard.pageBreakPerPoint, isTrue);
      expect(c.header.left, '{{client.name}}');
      expect(c.footer.center, contains('{{pages}}'));
    });

    test('variante « dossier de controle detaille »', () {
      final c = TemplateConfig.fromJson(const {
        'version': 1,
        'brand': {'accentColor': '#0057B8'},
        'cover': {'enabled': false, 'showSummary': true},
        'pointCard': {
          'layout': 'grid',
          'fields': ['ref', 'location', 'materials', 'description', 'author', 'date'],
          'pageBreak': 'perPoint',
        },
        'header': {'left': '{{client.name}}', 'right': '{{project.name}}'},
        'footer': {'center': 'Annexe technique - page {{page}}/{{pages}}'},
      });

      expect(c.brand.accentColor, 0xFF0057B8);
      expect(c.cover.enabled, isFalse);
      expect(c.pointCard.layout, PhotoLayout.grid);
      expect(
        c.brand.showLogo,
        isTrue,
        reason: 'showLogo absent doit retomber sur true, pas sur false',
      );
    });

    test('variante « synthese compacte »', () {
      final c = TemplateConfig.fromJson(const {
        'version': 1,
        'brand': {'accentColor': '#2E7D32', 'showLogo': true},
        'cover': {
          'enabled': true,
          'showSummary': false,
          'subtitle': 'Synthèse des traversées calfeutrées',
        },
        'pointCard': {
          'layout': 'twoUp',
          'fields': ['ref', 'location', 'materials'],
          'pageBreak': 'flow',
        },
        'header': {'right': '{{project.name}}'},
        'footer': {'center': '{{date}} - page {{page}}/{{pages}}'},
      });

      expect(c.cover.showSummary, isFalse);
      expect(c.pointCard.pageBreakPerPoint, isFalse);
      expect(c.pointCard.fields, [
        PointField.ref,
        PointField.location,
        PointField.materials,
      ]);
      expect(c.pointCard.shows(PointField.description), isFalse);
      expect(c.header.left, isEmpty, reason: 'zone gauche non definie');
    });

    test('le gabarit livre dans seed.sql se lit sans perte', () {
      // Recopie exacte de supabase/seed.sql. `showClientLogo` y figurait
      // autrefois : une cle que le moteur ne lit pas, donc un reglage sans
      // effet. Corrigee en `brand.showLogo`.
      final c = TemplateConfig.fromJson(const {
        'version': 1,
        'brand': {'accentColor': '#C8102E', 'showLogo': true},
        'cover': {
          'enabled': true,
          'showSummary': true,
          'subtitle': 'Rapport de conformité - calfeutrement de traversées',
        },
        'pointCard': {
          'layout': 'twoUp',
          'fields': ['ref', 'location', 'materials', 'description', 'author', 'date'],
          'pageBreak': 'perPoint',
        },
        'header': {'left': '{{client.name}}', 'right': '{{project.name}}'},
        'footer': {'text': 'Page {{page}}/{{pages}} - généré le {{date}}'},
      });

      expect(c.brand.showLogo, isTrue);
      expect(c.cover.showSummary, isTrue);
      expect(
        c.footer.center,
        contains('{{page}}'),
        reason: 'seed.sql ecrit « text » la ou le modele attend « center »',
      );
    });
  });
}
