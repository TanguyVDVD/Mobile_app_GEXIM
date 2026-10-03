import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// La base locale dans un navigateur : le même SQLite, compilé en WebAssembly,
/// rangé dans le stockage du site.
///
/// Deux fichiers l'accompagnent, servis à côté de l'application (dossier
/// `web/`) : `sqlite3.wasm`, le moteur, et `drift_worker.js`, le fil
/// d'arrière-plan qui le fait tourner — et qui permet à plusieurs onglets de
/// partager une seule base au lieu de s'écraser l'un l'autre. Leur origine et
/// la façon de les régénérer sont dans `tools/web/LISEZMOI.md` : **ils doivent
/// correspondre aux versions de `sqlite3` et de `drift` du `pubspec.lock`**.
///
/// Le navigateur peut vider le stockage d'un site — manque de place, ménage
/// fait par l'utilisateur. C'est pourquoi le relevé de terrain reste l'affaire
/// de la tablette : ici, la base est une copie de travail de ce que le serveur
/// détient, et ce qui n'est pas encore envoyé part dans les secondes qui
/// suivent, le poste étant en ligne.
QueryExecutor ouvrirConnexion() {
  return LazyDatabase(() async {
    final resultat = await WasmDatabase.open(
      databaseName: 'firestop',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    // Drift choisit seul le meilleur stockage que ce navigateur offre. S'il
    // retombe sur une base en mémoire, tout est perdu à la fermeture de
    // l'onglet : le dire dans la console, c'est la première chose à regarder
    // devant un « j'ai tout perdu en rechargeant ».
    if (resultat.missingFeatures.isNotEmpty) {
      developer.log(
        'Stockage retenu : ${resultat.chosenImplementation.name} ; '
        'absents de ce navigateur : ${resultat.missingFeatures}',
        name: 'base',
      );
    }
    return resultat.resolvedExecutor;
  });
}
