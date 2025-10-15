import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_stats.dart';

/// Service pour gérer les statistiques de quiz
/// Utilise SharedPreferences pour la persistance locale
class QuizStatsService {
  static const String _statsKey = 'quiz_stats';
  static QuizStats? _cachedStats;

  /// Charge les statistiques depuis SharedPreferences
  static Future<QuizStats> getStats() async {
    if (_cachedStats != null) return _cachedStats!;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_statsKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedStats = QuizStats.fromJson(json);
      } else {
        _cachedStats = const QuizStats();
      }
      
      return _cachedStats!;
    } catch (e) {
      print('Erreur chargement stats quiz: $e');
      _cachedStats = const QuizStats();
      return _cachedStats!;
    }
  }

  /// Sauvegarde les statistiques dans SharedPreferences
  static Future<void> saveStats(QuizStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(stats.toJson());
      await prefs.setString(_statsKey, jsonString);
      _cachedStats = stats;
    } catch (e) {
      print('Erreur sauvegarde stats quiz: $e');
    }
  }

  /// Met à jour les statistiques après un quiz terminé
  static Future<QuizStats> updateAfterQuiz({
    required String difficulty,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    final currentStats = await getStats();
    final now = DateTime.now();
    
    // Calcul de la série (streak)
    int newStreak = currentStats.currentStreak;
    if (currentStats.lastQuizDate != null) {
      final daysDiff = now.difference(currentStats.lastQuizDate!).inDays;
      if (daysDiff == 1) {
        newStreak++;
      } else if (daysDiff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }
    
    // Mise à jour des scores récents (garde les 10 derniers)
    final newRecentScores = [...currentStats.recentScores, score];
    if (newRecentScores.length > 10) {
      newRecentScores.removeAt(0);
    }
    
    // Mise à jour des stats par difficulté
    final newDifficultyStats = Map<String, int>.from(currentStats.difficultyStats);
    newDifficultyStats[difficulty] = (newDifficultyStats[difficulty] ?? 0) + score;
    
    final updatedStats = currentStats.copyWith(
      totalQuizzesCompleted: currentStats.totalQuizzesCompleted + 1,
      totalPoints: currentStats.totalPoints + score,
      totalQuestionsAnswered: currentStats.totalQuestionsAnswered + totalQuestions,
      correctAnswers: currentStats.correctAnswers + correctAnswers,
      difficultyStats: newDifficultyStats,
      lastQuizDate: now,
      lastDifficulty: difficulty,
      recentScores: newRecentScores,
      currentStreak: newStreak,
      bestStreak: newStreak > currentStats.bestStreak ? newStreak : currentStats.bestStreak,
    );
    
    await saveStats(updatedStats);
    return updatedStats;
  }

  /// Réinitialise toutes les statistiques
  static Future<void> resetStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_statsKey);
      _cachedStats = const QuizStats();
    } catch (e) {
      print('Erreur reset stats quiz: $e');
    }
  }

  /// Vérifie si l'utilisateur peut faire le quiz aujourd'hui
  static Future<bool> canDoQuizToday() async {
    final stats = await getStats();
    return stats.canDoQuizToday;
  }

  /// Obtient le niveau suggéré pour l'utilisateur
  static Future<QuizDifficulty> getSuggestedDifficulty() async {
    final stats = await getStats();
    return QuizDifficultyExtension.fromString(stats.suggestedDifficulty);
  }

  /// Obtient les statistiques par niveau de difficulté
  static Future<Map<QuizDifficulty, int>> getDifficultyBreakdown() async {
    final stats = await getStats();
    final breakdown = <QuizDifficulty, int>{};
    
    for (final difficulty in QuizDifficulty.values) {
      final points = stats.difficultyStats[difficulty.key] ?? 0;
      breakdown[difficulty] = points;
    }
    
    return breakdown;
  }

  /// Calcule le rang de l'utilisateur basé sur les points totaux
  static String getRank(int totalPoints) {
    if (totalPoints >= 1000) return 'Maître';
    if (totalPoints >= 500) return 'Expert';
    if (totalPoints >= 200) return 'Avancé';
    if (totalPoints >= 100) return 'Intermédiaire';
    if (totalPoints >= 50) return 'Novice';
    return 'Débutant';
  }

  /// Calcule les points nécessaires pour le prochain rang
  static int getPointsToNextRank(int totalPoints) {
    if (totalPoints >= 1000) return 0; // Déjà au maximum
    if (totalPoints >= 500) return 1000 - totalPoints;
    if (totalPoints >= 200) return 500 - totalPoints;
    if (totalPoints >= 100) return 200 - totalPoints;
    if (totalPoints >= 50) return 100 - totalPoints;
    return 50 - totalPoints;
  }

  /// Obtient le prochain rang
  static String getNextRank(int totalPoints) {
    if (totalPoints >= 1000) return 'Maître'; // Déjà au maximum
    if (totalPoints >= 500) return 'Maître';
    if (totalPoints >= 200) return 'Expert';
    if (totalPoints >= 100) return 'Avancé';
    if (totalPoints >= 50) return 'Intermédiaire';
    return 'Novice';
  }
}