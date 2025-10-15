import 'package:flutter/material.dart';
import '../navigation/main_navigation.dart';
import '../screens/sura_detail_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/qibla_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/quiz_screen.dart';

/// Configuration des routes nommées de l'application
/// Centralise toute la navigation pour faciliter la maintenance
class AppRoutes {
  // Noms des routes
  static const String home = '/';
  static const String quran = '/quran';
  static const String sura = '/sura';
  static const String quiz = '/quiz';
  static const String qibla = '/qibla';
  static const String profile = '/profile';

  /// Retourne la map des routes avec leurs widgets correspondants
  /// Chaque route est associée à un écran spécifique
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const MainNavigation(),
      quran: (context) => const QuranScreen(),
      sura: (context) {
        // Récupère l'ID de la sourate depuis les arguments
        final args = ModalRoute.of(context)?.settings.arguments as Map?;
        final suraId = args?['suraId'] as String? ?? '1';
        final suraName = args?['suraName'] as String? ?? 'Al-Fatiha';
        return SuraDetailScreen(suraId: suraId, suraName: suraName);
      },
      quiz: (context) => const QuizScreen(),
      qibla: (context) => const QiblaScreen(),
      profile: (context) => const ProfileScreen(),
    };
  }

  /// Navigation helper pour passer des arguments facilement
  /// Utilisé notamment pour SuraDetailScreen
  static void navigateToSura(BuildContext context, String suraId, String suraName) {
    Navigator.pushNamed(
      context,
      sura,
      arguments: {
        'suraId': suraId,
        'suraName': suraName,
      },
    );
  }

  /// Construit un écran SuraDetailScreen pour navigation directe
  static Widget buildSuraDetailScreen(String suraId, String suraName) {
    return SuraDetailScreen(suraId: suraId, suraName: suraName);
  }
}