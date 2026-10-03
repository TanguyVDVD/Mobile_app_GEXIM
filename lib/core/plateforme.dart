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
/// | `share_plus` 12.0.2 | android, ios, linux, macos, web, **windows** |
/// | `file_picker` 10.3.10 | android, ios, linux, macos, web, **windows** |
/// | `sqlite3_flutter_libs` 0.5.42 | android, ios, linux, macos, **windows** |
/// | `path_provider` 2.1.6 | android, ios, linux, macos, **windows** |
/// | `connectivity_plus` 6.1.5 | android, ios, linux, macos, web, **windows** |
///
/// Le socle — base locale, synchronisation, export du classeur Excel — est
/// donc complet sur Windows. Ne manquent que la capture et la compression
/// native, toutes deux liées au capteur photo.
abstract final class Plateforme {
  /// Poste de bureau : l'administrateur depuis son PC.
  static bool get estBureau =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
  /// clichés sert **aussi** à l'export du classeur, qui est précisément ce que
  /// l'administrateur vient faire sur son PC. Sans repli, chaque cliché
  /// remonterait `null` et toutes les fiches sortiraient sans photo. Voir
  /// `ReductionJpeg`.
  static bool get compressionNativeDisponible =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Sur un poste de bureau, un fichier produit se range où son propriétaire
  /// le décide. Sur une tablette il n'y a pas d'arborescence à proposer : le
  /// classeur part par le sélecteur de partage du système.
  static bool get enregistrementLocalDisponible => estBureau;
}
