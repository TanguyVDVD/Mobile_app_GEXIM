import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Dossier où vivent la base locale et les clichés de la tablette.
///
/// `/data/data/<pkg>/app_flutter` : le bac à sable privé de l'application,
/// invisible des autres et de l'utilisateur.
///
/// **Ne pas changer ce chemin.** Il orphelinerait la base et les clichés des
/// tablettes déjà en service : un relevé non synchronisé disparaîtrait sans un
/// mot. Une migration ne se ferait qu'en déplaçant l'existant.
///
/// Sans objet dans un navigateur, qui n'a pas de système de fichiers : la base
/// y est ouverte par `connexion_web.dart`, et cette fonction n'y est jamais
/// appelée.
Future<Directory> racineDonnees() => getApplicationDocumentsDirectory();
