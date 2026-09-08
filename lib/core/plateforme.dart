import 'dart:io';

/// Ce que la plateforme courante sait faire.
///
/// Un seul endroit interroge `Platform`. Disséminés dans les écrans, ces tests
/// finissent toujours par diverger : un bouton reste affiché là où le plugin
/// qui le sert n'existe pas, et l'appui remonte un `MissingPluginException`
/// que personne n'attrape.
///
/// Les réponses ne sont pas des préférences d'interface mais des **faits sur
/// les greffons embarqués**, vérifiés dans leur `pubspec.yaml` :
///
/// | Greffon | Plateformes déclarées |
/// |---|---|
/// | `camera` 0.11.4 | android, ios, web |
/// | `flutter_image_compress` 2.5.1 | android, ios, macos, web |
/// | `printing` 5.15.0 | android, ios, linux, macos, web, **windows** |
/// | `file_picker` 10.3.10 | android, ios, linux, macos, web, **windows** |
/// | `sqlite3_flutter_libs` 0.5.42 | android, ios, linux, macos, **windows** |
/// | `path_provider` 2.1.6 | android, ios, linux, macos, **windows** |
/// | `connectivity_plus` 6.1.5 | android, ios, linux, macos, web, **windows** |
///
/// Le socle — base locale, synchronisation, rendu et rasterisation du PDF —
/// est donc complet sur Windows. Ne manquent que la capture et la compression
/// native, toutes deux liées au capteur photo.
abstract final class Plateforme {
  /// Poste de bureau : l'administrateur depuis son PC.
  static bool get estBureau =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Tablette de chantier : le technicien.
  static bool get estMobile => Platform.isAndroid || Platform.isIOS;

  /// `camera` n'a pas d'implémentation Windows ni Linux.
  ///
  /// Ce n'est pas une privation : photographier une traversée est le travail du
  /// technicien sur place, pas de l'administrateur devant son écran. L'écran de
  /// traversée masque donc la prise de vue plutôt que de proposer un bouton qui
  /// échouerait.
  static bool get captureDisponible => Platform.isAndroid || Platform.isIOS;

  /// `flutter_image_compress` s'arrête à android, ios, macos et web.
  ///
  /// Windows en est absent, et c'est le piège de ce portage : la réduction des
  /// clichés sert **aussi** à la génération du rapport, qui est précisément ce
  /// que l'administrateur vient faire sur son PC. Sans repli, chaque cliché
  /// remonterait `null` et le document sortirait complet, paginé, signé — et
  /// vide de toute photo. Voir `ReductionJpeg`.
  static bool get compressionNativeDisponible =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Sur un poste de bureau, un fichier produit se range où son propriétaire
  /// le décide. Sur une tablette il n'y a pas d'arborescence à proposer : le
  /// rapport part par le sélecteur de partage du système.
  static bool get enregistrementLocalDisponible => estBureau;
}
