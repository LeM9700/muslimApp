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
  static const String home    = '/';
  static const String quran   = '/quran';
  static const String sura    = '/sura';
  static const String quiz    = '/quiz';
  static const String qibla   = '/qibla';
  static const String profile = '/profile';

  // ── Builders d'écrans ────────────────────────────────────────────────────────

  static Widget _buildScreen(String routeName, Object? arguments) {
    switch (routeName) {
      case home:
        return const MainNavigation();
      case quran:
        return const QuranScreen();
      case sura:
        final args = arguments as Map?;
        return SuraDetailScreen(
          suraId: args?['suraId'] as String? ?? '1',
          suraName: args?['suraName'] as String? ?? 'Al-Fatiha',
        );
      case quiz:
        return const QuizScreen();
      case qibla:
        return const QiblaScreen();
      case profile:
        return const ProfileScreen();
      default:
        return const MainNavigation();
    }
  }

  // ── onGenerateRoute — transition fade+scale (Hero-friendly) ─────────────────

  /// Transition fade + scale 0.95→1.0 avec Curves.easeInOutCubic (300ms).
  /// Amplifie l'effet des Hero animations (morphing simultané à la transition).
  /// À passer dans MaterialApp.onGenerateRoute à la place de routes:.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final screen = _buildScreen(settings.name ?? home, settings.arguments);

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Courbe éasing premium
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ── Compat — garder getRoutes() pour l'éventuel usage résiduel ──────────────

  /// @deprecated Utiliser onGenerateRoute dans MaterialApp.
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home:    (_) => const MainNavigation(),
      quran:   (_) => const QuranScreen(),
      sura:    (ctx) {
        final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
        return SuraDetailScreen(
          suraId: args?['suraId'] as String? ?? '1',
          suraName: args?['suraName'] as String? ?? 'Al-Fatiha',
        );
      },
      quiz:    (_) => const QuizScreen(),
      qibla:   (_) => const QiblaScreen(),
      profile: (_) => const ProfileScreen(),
    };
  }

  // ── Navigation helpers ───────────────────────────────────────────────────────

  /// Navigation vers SuraDetailScreen avec arguments typés.
  static void navigateToSura(
    BuildContext context,
    String suraId,
    String suraName,
  ) {
    Navigator.pushNamed(
      context,
      sura,
      arguments: {'suraId': suraId, 'suraName': suraName},
    );
  }

  /// Construit un SuraDetailScreen pour navigation directe (sans route nommée).
  static Widget buildSuraDetailScreen(String suraId, String suraName) {
    return SuraDetailScreen(suraId: suraId, suraName: suraName);
  }
}