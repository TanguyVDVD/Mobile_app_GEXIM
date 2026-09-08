import 'dart:io';

import '../../database/daos/point_dao.dart';
import '../../database/tables/enums.dart';
import 'image_compressor.dart';

/// Enchaînement complet d'une prise de vue : compression, écriture disque,
/// enregistrement en base.
///
/// Rien n'attend le réseau. L'opérateur photographie une traversée dans un
/// sous-sol en béton, la vignette apparaît immédiatement, et le transfert se
/// fera plus tard tout seul.
class PhotoCaptureService {
  const PhotoCaptureService({
    required PointDao dao,
    required PhotoProcessor processor,
  })  : _dao = dao,
        _processor = processor;

  final PointDao _dao;
  final PhotoProcessor _processor;

  /// Traite un cliché brut et le rattache au point. Rend l'identifiant créé.
  ///
  /// [original] est le fichier temporaire produit par la caméra. Il est
  /// **supprimé** une fois la version compressée écrite : à 4 Mo pièce, le
  /// conserver remplirait la tablette en une centaine de photos.
  Future<String> capture({
    required String pointId,
    required PhotoKind kind,
    required File original,
  }) async {
    final compressed = await _processor.compress(original);
    await _discard(original);

    // `before` et `after` sont les deux clichés exigés par la norme : un seul
    // de chaque. Reprendre la photo doit remplacer la précédente, pas
    // l'empiler — un rapport montrant deux « avant » contradictoires ne serait
    // pas défendable en audit.
    if (kind != PhotoKind.extra) {
      await _retireExisting(pointId, kind);
    }

    return _dao.registerPhoto(
      pointId: pointId,
      kind: kind,
      localPath: compressed.path,
      bytes: compressed.bytes,
      width: compressed.width,
      height: compressed.height,
      sha256: compressed.sha256,
      sortOrder: kind == PhotoKind.extra
          ? await _dao.nextSortOrder(pointId)
          : _slotOrder(kind),
    );
  }

  /// Retire une photo complémentaire choisie par l'opérateur.
  Future<void> retire(String photoId) async {
    final orphan = await _dao.retirePhoto(photoId);
    if (orphan != null) await _discard(File(orphan));
  }

  Future<void> _retireExisting(String pointId, PhotoKind kind) async {
    for (final photo in await _dao.photosOfKind(pointId, kind)) {
      final orphan = await _dao.retirePhoto(photo.id);
      if (orphan != null) await _discard(File(orphan));
    }
  }

  static int _slotOrder(PhotoKind kind) =>
      kind == PhotoKind.before ? -2 : -1;

  /// Suppression best-effort : l'échec n'est jamais bloquant.
  ///
  /// Le fichier a déjà été compressé et enregistré ; refuser la photo parce que
  /// le ménage a échoué ferait perdre le relevé pour un problème de ménage. Le
  /// balayage des orphelins repassera.
  Future<void> _discard(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Rien à faire ici, et surtout rien à propager.
    }
  }
}
