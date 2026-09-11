// Régénère `supabase/bootstrap.sql` à partir de `supabase/migrations/`.
//
//   dart run tools/bootstrap.dart
//
// `bootstrap.sql` installe un projet Supabase vierge en un seul collage dans
// l'éditeur SQL. Il est **généré** : la source de vérité reste le dossier des
// migrations, et ce fichier doit être régénéré à chaque changement de l'une
// d'elles — sans quoi une installation neuve partirait d'un schéma périmé.
//
// L'éditeur Supabase exécute le tout en **une seule transaction**, contrairement
// au banc d'essai Docker qui joue chaque fichier en autocommit. Une migration
// qui ajoute une étiquette d'enum puis l'emploie passerait donc au banc et
// échouerait ici : voir `CLAUDE.md`.

import 'dart:io';

const _entete = '''
-- =============================================================================
-- FireStop Tracker -- installation initiale, en un seul bloc
-- =============================================================================
--
-- FICHIER GENERE par tools/bootstrap.dart. Ne pas modifier : la source de
-- verite reste supabase/migrations/.
--
-- A coller tel quel dans le SQL Editor de Supabase, pour un projet VIERGE.
-- Toute evolution ulterieure passe par une nouvelle migration, jamais par ce
-- fichier -- le rejouer sur une base existante echouerait sur les types et
-- policies deja crees.
-- =============================================================================

''';

void main() {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    // L'ordre des noms est l'ordre d'exécution : ils commencent par leur date.
    ..sort((a, b) => a.path.compareTo(b.path));

  if (migrations.isEmpty) {
    stderr.writeln('Aucune migration trouvée : lancer depuis la racine du dépôt.');
    exitCode = 1;
    return;
  }

  final sortie = StringBuffer(_entete);
  for (final (int i, File fichier) in migrations.indexed) {
    final chemin = fichier.path.replaceAll(r'\', '/');
    if (i > 0) sortie.write('\n');
    sortie
      ..write('-- ${'>' * 20}  $chemin  ${'<' * 20}\n\n')
      ..write(fichier.readAsStringSync().replaceAll('\r\n', '\n'));
  }

  File('supabase/bootstrap.sql').writeAsStringSync(sortie.toString());
  stdout.writeln(
    'supabase/bootstrap.sql régénéré : ${migrations.length} migrations.',
  );
}
