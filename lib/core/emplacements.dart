import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'plateforme.dart';

/// Racine des données privées de l'application : base SQLite et clichés.
///
/// Le même appel `path_provider` ne rend **pas** la même sorte de dossier
/// partout, et la différence compte :
///
/// | | `getApplicationDocumentsDirectory()` |
/// |---|---|
/// | Android | `/data/data/<pkg>/app_flutter` — bac à sable privé, invisible |
/// | Windows | `C:\Users\<nom>\Documents` — **les vrais documents de l'utilisateur** |
///
/// Sur PC, laisser le défaut déposait `firestop.sqlite` et un dossier `photos/`
/// au beau milieu des documents personnels. Deux problèmes, dont un grave :
///
///  1. l'encombrement, visible et incompréhensible pour l'utilisateur ;
///  2. surtout, **« Documents » est très souvent synchronisé par OneDrive**.
///     Un client de synchronisation copie le fichier pendant qu'il est écrit et
///     désynchronise la base de son journal WAL : c'est un mode de corruption
///     SQLite connu et documenté. Or cette base n'est pas un cache, c'est la
///     source de vérité de l'application — le relevé d'un chantier y vit avant
///     d'être poussé.
///
/// D'où `getApplicationSupportDirectory()` sur les postes de bureau, qui rend
/// `%APPDATA%\be.gexim\firestop_tracker` — hors de portée de la synchronisation,
/// et déjà l'endroit où `shared_preferences` écrit ses réglages.
///
/// **Android garde le dossier historique**, délibérément : `Support` y serait
/// tout aussi valable, mais changer de chemin orphelinerait la base et les
/// clichés des tablettes déjà en service. Un relevé non synchronisé y
/// disparaîtrait sans un mot — exactement ce que toute l'architecture cherche à
/// éviter. Une migration ne se ferait qu'en déplaçant l'existant, et rien ne le
/// justifie ici.
Future<Directory> racineDonnees() {
  return Plateforme.estBureau
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();
}
