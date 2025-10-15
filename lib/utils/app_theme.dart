import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thème glassmorphism moderne pour l'application Muslim App
/// Design liquide avec effets de verre et transparence
class AppTheme {
  // Couleurs glassmorphism
  static const Color primaryDark = Color(0xFF0A1E32);  // Bleu nuit profond
  static const Color gradientStart = Color(0xFF1A2F47); // Bleu-gris
  static const Color gradientEnd = Color(0xFF2A3F57);   // Bleu-gris plus clair
  static const Color glassColor = Color(0x40FFFFFF);    // Blanc translucide
  static const Color glassBorder = Color(0x30FFFFFF);   // Bordure verre
  static const Color textPrimary = Colors.white;        // Blanc pur
  static const Color textSecondary = Color(0xB3FFFFFF); // Blanc 70%
  static const Color accentBlue = Color(0xFF4A90E2);    // Bleu lumineux
  static const Color accentGold = Color(0xFFFFD700);    // Or pour accents

  /// Retourne le thème sombre personnalisé pour l'app
  /// Optimisé pour la lisibilité et l'accessibilité (contraste AA)
  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: primaryDark,
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: glassColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Text theme optimized for readability
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textSecondary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
      
      // Button themes with proper touch targets (44px+)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gradientStart,
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentGold,
        foregroundColor: primaryDark,
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      
      // Input decoration for forms
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
    );
  }

  /// Style spécial pour texte arabe (Coran, hadiths)
  /// Utilise police système temporairement (TODO: ajouter Noto Naskh Arabic)
  static TextStyle getArabicTextStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
  }) {
    return TextStyle(
      // fontFamily: 'NotoNaskhArabic', // TODO: activer après ajout de la police
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.8, // Espacement vertical pour lisibilité
    );
  }

  /// Style pour traductions françaises
  /// Contraste AA minimum, taille 14-16
  static TextStyle getFrenchTranslationStyle({
    double fontSize = 15,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
      height: 1.5,
      fontStyle: FontStyle.italic,
    );
  }
}