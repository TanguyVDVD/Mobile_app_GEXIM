import 'dart:io';

import '../../database/daos/point_dao.dart';
import '../../database/tables/enums.dart';
import 'galerie.dart';
import 'image_compressor.dart';

/// Enchaînement complet d'une prise de vue : compression, écriture disque,
/// enregistrement en base, copie dans la galerie de la tablette.
///
/// Rien n'attend le réseau. L'opérateur photographie une traversée dans un
/// sous-sol en béton, la vignette apparaît immédiatement, et le transfert se
/// fera plus tard tout seul.
class PhotoCaptureService {
  const PhotoCaptureService({
    required PointDao dao,
    required PhotoProcessor processor,
    Galerie? galerie,
  })  : _dao = dao,
        _processor = processor,
        _galerie = galerie;

  final PointDao _dao;
  final PhotoProcessor _processor;

  /// `null` là où il n'y a pas de galerie — et dans les tests qui n'en
  /// parlent pas.
  final Galerie? _galerie;

  /// Traite un cliché brut et le rattache au point. Rend l'identifiant créé.
  ///
  /// [original] est le fichier temporaire produit par la caméra. L'application
  /// n'en garde que la version compressée : c'est elle qui est synchronisée
  /// et qui entre dans le classeur. L'original, lui, part dans la galerie de
  /// la tablette, puis le fichier temporaire est **supprimé** dans tous les
  /// cas.
  ///
  /// Lève [GalerieEchec] si le cliché n'a pas pu être copié dans la galerie.
  /// À ce moment-là il est **déjà enregistré** sur la fiche : l'appelant doit
  /// le dire tel quel, et surtout ne pas faire reprendre la photo.
  Future<String> capture({
    required String pointId,
    required PhotoKind kind,
    required File original,
  }) async {
    try {
      return await _enregistrer(pointId, kind, original);
    } finally {
      await _discard(original);
    }
  }

  Future<String> _enregistrer(
    String pointId,
    PhotoKind kind,
    File original,
  ) async {
    final compressed = await _processor.compress(original);

    // `before` et `after` sont les deux clichés exigés par la norme : un seul
    // de chaque. Reprendre la photo doit remplacer la précédente, pas
    // l'empiler — un rapport montrant deux « avant » contradictoires ne serait
    // pas défendable en audit.
    if (kind != PhotoKind.extra) {
      await _retireExisting(pointId, kind);
    }

    final id = await _dao.registerPhoto(
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

    // En dernier : la fiche d'abord, la galerie ensuite. Une copie qui échoue
    // ne doit rien coûter au relevé.
    await _versGalerie(pointId, kind, original);
    return id;
  }

  /// Copie le cliché **original**, tel que sorti du capteur — demande du
  /// bureau : la fiche porte la version réduite, la tablette garde la pleine
  /// définition.
  Future<void> _versGalerie(String pointId, PhotoKind kind, File cliche) async {
    final galerie = _galerie;
    if (galerie == null) return;

    try {
      final repere = await _dao.repere(pointId);
      await galerie.ajouter(
        cliche,
        nom: nomDeCliche(
          chantier: repere?.chantier ?? '',
          numero: repere?.numero,
          nature: kind,
          prisLe: DateTime.now(),
        ),
      );
    } on GalerieEchec {
      rethrow;
    } on Object catch (e) {
      throw GalerieEchec('$e');
    }
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
