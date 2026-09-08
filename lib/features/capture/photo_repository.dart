import 'dart:io';

import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../sync/remote_gateway.dart';
import 'photo_storage.dart';

/// Accès au fichier d'une photo, où qu'il se trouve.
///
/// Une photo prise par un collègue redescend avec sa métadonnée mais sans son
/// binaire : le pull ne rapatrie jamais les fichiers, un chantier pesant
/// plusieurs gigaoctets. Le téléchargement se fait donc **à l'affichage**, une
/// image à la fois.
class PhotoRepository {
  PhotoRepository(
    this._db,
    this._gateway, [
    this._storage = const PhotoStorage(),
  ]);

  final AppDatabase _db;
  final RemoteGateway _gateway;
  final PhotoStorage _storage;

  /// Téléchargements en cours, indexés par photo.
  ///
  /// Une grille de vignettes reconstruite pendant un défilement redemande la
  /// même image plusieurs fois en quelques millisecondes. Sans ce partage, on
  /// paierait le même transfert autant de fois — sur le forfait data d'un
  /// chantier.
  final Map<String, Future<File?>> _inFlight = {};

  /// Fichier local de la photo, téléchargé si nécessaire.
  /// Rend `null` si le binaire n'existe nulle part.
  Future<File?> fileFor(Photo photo) {
    final local = photo.localPath;
    if (local != null) {
      final file = File(local);
      if (file.existsSync()) return Future.value(file);
    }

    if (photo.remotePath == null) return Future.value(null);

    return _inFlight.putIfAbsent(
      photo.id,
      () => _download(photo).whenComplete(() => _inFlight.remove(photo.id)),
    );
  }

  Future<File?> _download(Photo photo) async {
    final bytes = await _gateway.downloadPhoto(photo.remotePath!);
    final target = await _storage.fileFor(photo.id);

    // Écriture en deux temps : un crash au milieu du transfert laisserait
    // sinon un JPEG tronqué que `existsSync()` déclarerait valide, et la photo
    // s'afficherait corrompue pour toujours — plus rien ne la retéléchargerait.
    final partial = File('${target.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename(target.path);

    // Seul `localPath` est touché. `updatedAt` reste inchangé : c'est un champ
    // strictement local, le rafraîchir ferait gagner cet appareil au
    // last-write-wins et propagerait une modification vide à tout le monde.
    await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(localPath: Value(target.path)),
    );

    return target;
  }
}
