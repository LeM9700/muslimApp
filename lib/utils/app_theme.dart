import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// AppColors — Design DNA : glassmorphism iridescent CLAIR
// Mood : spirituel · éthéré · premium
// Pivot : dark navy #0A1E32 → gradient pastel peach/lavande/rose
// =============================================================================

class AppColors {
  AppColors._();

  // Fond gradient animé (peach → lavande → rose)
  static const Color backgroundStart = Color(0xFFFFDDD2); // peach doux
  static const Color backgroundMid   = Color(0xFFE8D5FF); // lavande
  static const Color backgroundEnd   = Color(0xFFFFD6E8); // rose pâle

  // Glass cards — frosted light (utiliser avec BackdropFilter)
  static const Color glassLight      = Color(0x44FFFFFF); // rgba(255,255,255,0.27)
  static const Color glassMedium     = Color(0x66FFFFFF); // rgba(255,255,255,0.40)
  static const Color glassBorder     = Color(0x4DFFFFFF); // rgba(255,255,255,0.30)

  // Bordures iridescentes (LinearGradient topLeft → bottomRight)
  static const Color iridStart       = Color(0xFFB39DDB); // violet doux
  static const Color iridMid         = Color(0xFFF48FB1); // rose chaud
  static const Color iridEnd         = Color(0xFF81D4FA); // bleu ciel

  // Accents principaux
  static const Color emerald         = Color(0xFF10B981); // accent 1 — prière, succès
  static const Color emeraldLight    = Color(0xFF34D399);
  static const Color copper          = Color(0xFFB87333); // accent 2 — Coran, premium
  static const Color copperLight     = Color(0xFFD4956A);

  // Texte (dark on light)
  static const Color textPrimary     = Color(0xFF1A1A2E); // quasi-noir
  static const Color textSecondary   = Color(0xFF4A4A6A); // gris bleuté
  static const Color textMuted       = Color(0xFF8888AA); // gris clair
  static const Color textOnAccent    = Colors.white;      // texte sur boutons colorés

  // Semantic
  static const Color success         = emerald;
  static const Color warning         = Color(0xFFF59E0B);
  static const Color error           = Color(0xFFEF4444);

  // Effet de lueur prière (prayer glow)
  static const Color prayerGlow      = Color(0x3310B981);
}

// =============================================================================
// AppTheme
// =============================================================================

class AppTheme {
  AppTheme._();

  /// [⚠️ PROD] SystemOverlayStyle doit être réglé en dark ici car fond lumineux.
  /// Sans ça, les icônes de status bar restent blanches sur fond clair → illisibles.
  static void applySystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,   // icônes sombres sur fond clair
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.emerald,
      scaffoldBackgroundColor: Colors.transparent, // fond géré par IridescentBackground

      colorScheme: const ColorScheme.light(
        primary: AppColors.emerald,
        secondary: AppColors.copper,
        surface: AppColors.glassLight,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),

      // AppBar transparente — le fond vient de IridescentBackground
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cards glass light
      cardTheme: CardThemeData(
        color: AppColors.glassLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      // Typography — texte sombre sur fond clair
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emerald,
          side: const BorderSide(color: AppColors.emerald, width: 1.5),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
      ),

      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.emerald,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 0.5,
      ),
    );
  }

  /// Conservé pour compatibilité — retourne désormais le thème clair iridescent.
  /// [🔒 SÉCURITÉ] Ne pas supprimer : d'autres fichiers appellent encore getDarkTheme().
  static ThemeData getDarkTheme() => getLightTheme();

  // ── Backward-compat aliases ── use AppColors directly in new code ──────────

  /// @deprecated Use AppColors.textPrimary
  static const Color primaryDark = AppColors.backgroundStart;

  /// @deprecated Use AppColors.emerald
  static const Color accentBlue = AppColors.emerald;

  /// @deprecated Use AppColors.copper
  static const Color accentGold = AppColors.copper;

  /// @deprecated Use AppColors.backgroundStart
  static const Color gradientStart = AppColors.backgroundStart;

  /// @deprecated Use AppColors.backgroundEnd
  static const Color gradientEnd = AppColors.backgroundEnd;

  // -------------------------------------------------------------------------
  // Styles texte spéciaux
  // -------------------------------------------------------------------------

  /// Style pour texte arabe (Coran, hadiths)
  /// [TODO] Activer NotoNaskhArabic après ajout de la police dans assets/fonts/
  static TextStyle getArabicTextStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      // fontFamily: 'NotoNaskhArabic',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.8,
    );
  }

  /// Style pour traductions françaises / sous-titres
  static TextStyle getFrenchTranslationStyle({
    double fontSize = 15,
    Color color = AppColors.textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
      height: 1.5,
      fontStyle: FontStyle.italic,
    );
  }
}
