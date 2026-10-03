import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Fait télécharger [octets] par le navigateur, sous le nom [nom].
///
/// Le geste habituel d'une page web : un lien invisible vers les données,
/// cliqué par le code. Le fichier arrive dans le dossier de téléchargements,
/// ou là où le navigateur est réglé pour demander.
void telecharger({
  required String nom,
  required Uint8List octets,
  required String typeMime,
}) {
  final blob = web.Blob(
    [octets.toJS].toJS,
    web.BlobPropertyBag(type: typeMime),
  );
  final url = web.URL.createObjectURL(blob);

  final lien = web.HTMLAnchorElement()
    ..href = url
    ..download = nom
    ..style.display = 'none';
  web.document.body!.append(lien);
  lien.click();
  lien.remove();

  // Le navigateur a pris les données en charge dès le clic : l'adresse
  // temporaire peut être rendue, sans quoi le classeur resterait en mémoire
  // jusqu'à la fermeture de l'onglet.
  web.URL.revokeObjectURL(url);
}
