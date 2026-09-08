import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/database.dart';

/// Emplacement disque des clichés compressés.
class PhotoStorage {
  const PhotoStorage({Directory? root}) : _root = root;

  /// Racine de substitution.
  ///
  /// `path_provider` passe par un canal de plateforme, indisponible dans un
  /// test unitaire. Sans cette échappatoire, toute logique qui touche au
  /// stockage — la purge d'un changement de compte, par exemple — deviendrait
  /// intestable, alors que c'est précisément celle qui détruit des données.
  final Directory? _root;

  /// Répertoire des photos, dans l'espace **documents** et non le cache.
  ///
  /// Distinction critique : Android purge le cache sous pression de stockage.
  /// Une photo de calfeutrement non encore transférée y disparaîtrait, et le
  /// relevé de l'opérateur serait irrécupérable — sur un chantier où repasser
  /// coûte une demi-journée.
  Future<Directory> directory() async {
    final base = _root ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> fileFor(String photoId) async =>
      File(p.join((await directory()).path, '$photoId.jpg'));

  /// Supprime les fichiers que plus aucune ligne ne référence. Rend le nombre
  /// de fichiers effacés.
  ///
  /// Ces orphelins existent parce que la capture écrit **d'abord** le fichier
  /// compressé, **ensuite** la ligne en base. Un crash entre les deux laisse un
  /// fichier sans propriétaire. L'ordre inverse serait pire : une ligne
  /// pointant vers un fichier absent, c'est une photo perdue et une
  /// synchronisation en échec permanent. Mieux vaut une fuite de stockage
  /// réparable qu'une donnée manquante.
  ///
  /// Le délai de grâce protège la capture en cours : au moment où le fichier
  /// vient d'être écrit, la ligne n'existe pas encore, et un balayage trop
  /// zélé effacerait la photo que l'opérateur est en train de prendre.
  Future<int> sweepOrphans(
    AppDatabase db, {
    Duration grace = const Duration(hours: 1),
  }) async {
    final dir = await directory();
    if (!dir.existsSync()) return 0;

    final rows = await db
        .customSelect(
          'SELECT local_path FROM photos WHERE local_path IS NOT NULL',
          readsFrom: {db.photos},
        )
        .get();
    final referenced = {
      for (final row in rows) row.read<String>('local_path'),
    };

    final cutoff = DateTime.now().subtract(grace);
    var removed = 0;

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (referenced.contains(entity.path)) continue;
      if (entity.statSync().modified.isAfter(cutoff)) continue;

      await entity.delete();
      removed++;
    }
    return removed;
  }
}
