import 'package:flutter/material.dart';

/// Langage visuel de l'application.
///
/// Il est emprunté à un objet réel du métier : **la plaque d'identification
/// coupe-feu**, rivetée à côté de chaque traversée conforme. Un rectangle
/// bordé, à angles francs, portant un numéro de référence, des couples
/// champ/valeur et une classification — conçu pour rester lisible sur un mur
/// poussiéreux dix ans plus tard.
///
/// D'où les partis pris : bordures nettes plutôt qu'ombres portées, angles
/// presque droits, fort contraste, et le rouge réservé au signal.
abstract final class Fs {
  // ---------------------------------------------------------------------------
  // Couleurs
  // ---------------------------------------------------------------------------

  /// Blanc froid de documentation technique. Volontairement pas un crème chaud :
  /// on est dans la fiche produit, pas dans le papier d'édition.
  static const ground = Color(0xFFF1F3F4);
  static const plate = Color(0xFFFFFFFF);

  /// Noir à dominante bleutée, comme une impression technique.
  static const ink = Color(0xFF14181C);
  static const inkMuted = Color(0xFF626D78);
  static const hairline = Color(0xFFD9DDE1);

  /// Rouge coupe-feu. **Signal uniquement** : ce qui manque, ce qui détruit,
  /// ce qui classe. Jamais un aplat décoratif.
  static const signal = Color(0xFFC8102E);
  static const signalWash = Color(0xFFFCEBEE);

  // ---------------------------------------------------------------------------
  // Rythme
  // ---------------------------------------------------------------------------

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Presque droit. La plaque est un objet rigide ; un rayon de 12 px en ferait
  /// une carte logicielle générique.
  static const radius = BorderRadius.all(Radius.circular(3));
  static const radiusAction = BorderRadius.all(Radius.circular(6));

  static const border = BorderSide(color: hairline);

  // ---------------------------------------------------------------------------
  // Typographie
  // ---------------------------------------------------------------------------
  //
  // L'échelle est travaillée, pas la famille : embarquer une fonte demanderait
  // un fichier absent du dépôt. En attendant, la personnalité vient des sauts
  // de graisse et de l'interlettrage.

  static const _display = TextStyle(
    fontSize: 29,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: ink,
  );

  static const _title = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: ink,
  );

  static const _heading = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: ink,
  );

  static const _body = TextStyle(
    fontSize: 16.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: ink,
  );

  static const _meta = TextStyle(
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: inkMuted,
  );

  /// Chiffres à chasse fixe pour les numéros de traversée : ils forment un
  /// registre, et des colonnes de chiffres qui dansent se lisent mal.
  static const reference = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle metaOf(BuildContext context) => _meta;

  // ---------------------------------------------------------------------------
  // Thème
  // ---------------------------------------------------------------------------

  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: signal,
      onPrimary: Colors.white,
      primaryContainer: signalWash,
      onPrimaryContainer: signal,
      secondary: ink,
      onSecondary: Colors.white,
      surface: plate,
      onSurface: ink,
      surfaceContainerHighest: ground,
      onSurfaceVariant: inkMuted,
      outline: hairline,
      outlineVariant: hairline,
      error: signal,
      onError: Colors.white,
      errorContainer: signalWash,
      onErrorContainer: signal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ground,
      splashFactory: InkSparkle.splashFactory,

      textTheme: const TextTheme(
        headlineMedium: _display,
        titleLarge: _title,
        titleMedium: _heading,
        titleSmall: _heading,
        bodyLarge: _body,
        bodyMedium: _body,
        bodySmall: _meta,
        labelLarge: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: ink,
        ),
        labelMedium: _meta,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: ground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _title,
        titleSpacing: lg,
      ),

      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),

      // Angles francs et bordure nette : la plaque, pas la carte flottante.
      cardTheme: const CardThemeData(
        color: plate,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: lg, vertical: sm),
        titleTextStyle: _body,
        subtitleTextStyle: _meta,
        iconColor: inkMuted,
        minVerticalPadding: md,
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: plate,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: md,
          vertical: md,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        labelStyle: _meta,
        floatingLabelStyle: TextStyle(fontSize: 14.5, color: ink),
        helperStyle: _meta,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          // Cibles généreuses : l'écran est touché avec des gants.
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: xl),
          shape: const RoundedRectangleBorder(borderRadius: radiusAction),
          textStyle: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 56),
          side: border,
          shape: const RoundedRectangleBorder(borderRadius: radiusAction),
          textStyle: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 2,
        extendedTextStyle: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: radiusAction),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: plate,
        selectedColor: ink,
        checkmarkColor: Colors.white,
        side: border,
        shape: RoundedRectangleBorder(borderRadius: radiusAction),
        labelStyle: TextStyle(fontSize: 15, color: ink),
        secondaryLabelStyle: TextStyle(
          fontSize: 15,
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: sm, vertical: sm),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: inkMuted,
        indicatorColor: signal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: hairline,
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 15),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(fontSize: 15.5, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusAction),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: plate,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius, side: border),
        titleTextStyle: _title,
        contentTextStyle: _body,
      ),

      popupMenuTheme: const PopupMenuThemeData(
        color: plate,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: radius, side: border),
        textStyle: _body,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        linearMinHeight: 2,
      ),
    );
  }
}
