# Les deux fichiers de la base locale, côté navigateur

La version navigateur fait tourner SQLite en WebAssembly. Deux fichiers sont
servis à côté de l'application, depuis `web/` :

| Fichier | Rôle | Doit correspondre à |
|---|---|---|
| `web/sqlite3.wasm` | le moteur SQLite | la version de `sqlite3` dans `pubspec.lock` |
| `web/drift_worker.js` | le fil d'arrière-plan qui le fait tourner | la version de `drift` dans `pubspec.lock` |

**Après toute montée de version de `drift` ou de `sqlite3`, les régénérer.**
Un décalage ne casse pas la compilation : la base refuse de s'ouvrir dans le
navigateur, à l'exécution.

```powershell
# Le moteur : publié avec chaque version du paquet sqlite3 (ici 2.9.4).
curl.exe -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm

# Le fil d'arrière-plan : compilé depuis ce dossier, avec le drift du projet.
dart compile js -O4 tools/web/drift_worker.dart -o web/drift_worker.js
Remove-Item web/drift_worker.js.deps, web/drift_worker.js.map -ErrorAction SilentlyContinue
```
