import 'package:shared_preferences/shared_preferences.dart';

/// Gère la progression de l'onboarding progressif (Q11).
/// Chaque flow est indépendant — home, quran, quiz.
/// [🔒 SÉCURITÉ] Aucune donnée sensible — stockage local uniquement.
class OnboardingService {
  OnboardingService._();

  static const _keyHome   = 'onboarding_home_v1';
  static const _keyQuran  = 'onboarding_quran_v1';
  static const _keyQuiz   = 'onboarding_quiz_v1';

  // ── Lecture ───────────────────────────────────────────────────────────────

  /// Retourne true si l'onboarding home a déjà été complété/sauté.
  static Future<bool> isHomeOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHome) ?? false;
  }

  /// Retourne true si l'onboarding Quran a déjà été complété/sauté.
  static Future<bool> isQuranOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyQuran) ?? false;
  }

  /// Retourne true si l'onboarding Quiz a déjà été complété/sauté.
  static Future<bool> isQuizOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyQuiz) ?? false;
  }

  // ── Écriture ──────────────────────────────────────────────────────────────

  /// Marque l'onboarding home comme terminé (complété ou sauté).
  static Future<void> markHomeDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHome, true);
  }

  /// Marque l'onboarding Quran comme terminé.
  static Future<void> markQuranDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuran, true);
  }

  /// Marque l'onboarding Quiz comme terminé.
  static Future<void> markQuizDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuiz, true);
  }

  // ── Reset (debug / tests) ─────────────────────────────────────────────────

  /// Remet tous les flags à zéro — pour tester l'onboarding.
  /// [⚠️ PROD] Ne pas exposer dans l'UI de prod.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHome);
    await prefs.remove(_keyQuran);
    await prefs.remove(_keyQuiz);
  }
}
