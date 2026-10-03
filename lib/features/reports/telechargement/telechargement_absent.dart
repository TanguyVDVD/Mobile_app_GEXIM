import 'dart:typed_data';

/// Hors d'un navigateur, il n'y a rien à télécharger : la tablette partage.
///
/// Ce fichier n'existe que pour que le code compile sur Android, où
/// `dart:js_interop` et `package:web` n'existent pas. Voir
/// `telechargement_web.dart`, et l'import conditionnel de
/// `report_exporter.dart`.
void telecharger({
  required String nom,
  required Uint8List octets,
  required String typeMime,
}) =>
    throw UnsupportedError('Le téléchargement n\'existe que dans un navigateur');
