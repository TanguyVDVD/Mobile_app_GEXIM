import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../core/emplacements.dart';

/// La base locale sur tablette : un fichier SQLite dans le dossier privé de
/// l'application.
QueryExecutor ouvrirConnexion() {
  return LazyDatabase(() async {
    final dir = await racineDonnees();
    final file = File(p.join(dir.path, 'firestop.sqlite'));

    // Répare le résolveur de tmpdir sur certains Android, faute de quoi les
    // requêtes qui débordent en mémoire échouent sur appareil bas de gamme.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}
