import 'package:flutter/foundation.dart';

/// Ce que la plateforme courante sait faire.
///
/// Deux cibles, deux métiers :
///
///  * la **tablette Android** est l'outil du technicien, et le cœur du projet :
///    relevé hors ligne, prise de vue, clichés gardés sur l'appareil ;
///  * le **navigateur** est le poste de l'administrateur : chantiers, clients,
///    listes, affectations, et l'export des fiches. Il est en ligne par
///    nature.
///
/// Un seul endroit décide de ce qui les sépare. Disséminés dans les écrans,
/// ces tests finissent toujours par diverger : un bouton reste affiché là où
/// ce qui le sert n'existe pas.
///
/// **Aucun `dart:io` ici.** `Platform.isAndroid` lève dans un navigateur ;
/// `kIsWeb` et `defaultTargetPlatform` se lisent partout.
abstract final class Plateforme {
  /// L'application tourne dans un navigateur.
  static bool get estNavigateur => kIsWeb;

  /// Un système de fichiers existe : les clichés vivent sur l'appareil, sont
  /// lus depuis le disque, et se rangent dans un dossier.
  ///
  /// Un navigateur n'en a pas. Les clichés y sont lus depuis le serveur, à la
  /// demande, et rien de ce qui manipule un `File` ne doit y être appelé —
  /// le code compile, mais lève à l'exécution.
  static bool get fichiersLocaux => !kIsWeb;

  /// La prise de vue est le travail du technicien, devant le mur : elle se
  /// fait sur tablette. Le navigateur consulte les clichés, il n'en prend pas.
  static bool get captureDisponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Chaque cliché pris est aussi copié dans la galerie de l'appareil. Android
  /// seulement : la copie passe par un canal vers `MainActivity`, qui n'a pas
  /// d'équivalent ailleurs.
  static bool get galerieDisponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
