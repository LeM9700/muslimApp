import 'package:flutter/material.dart';

/// Modèle pour les statistiques de quiz utilisateur
/// Stocke les performances et progressions dans SharedPreferences
class QuizStats {
  final int totalQuizzesCompleted;
  final int totalPoints;
  final int totalQuestionsAnswered;
  final int correctAnswers;
  final Map<String, int> difficultyStats; // niveau -> points
  final DateTime? lastQuizDate;
  final String? lastDifficulty;
  final List<int> recentScores; // 10 derniers scores pour graphique
  final int currentStreak; // série de jours consécutifs
  final int bestStreak; // meilleure série
  final Map<String, int> categoryStats; // catégorie -> points

  const QuizStats({
    this.totalQuizzesCompleted = 0,
    this.totalPoints = 0,
    this.totalQuestionsAnswered = 0,
    this.correctAnswers = 0,
    this.difficultyStats = const {},
    this.lastQuizDate,
    this.lastDifficulty,
    this.recentScores = const [],
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.categoryStats = const {},
  });

  /// Pourcentage de réussite global
  double get accuracyPercentage {
    if (totalQuestionsAnswered == 0) return 0.0;
    return (correctAnswers / totalQuestionsAnswered) * 100;
  }

  /// Moyenne de points par quiz
  double get averageScore {
    if (totalQuizzesCompleted == 0) return 0.0;
    return totalPoints / totalQuizzesCompleted;
  }

  /// Vérifie si l'utilisateur peut faire le quiz aujourd'hui
  bool get canDoQuizToday {
    if (lastQuizDate == null) return true;
    final today = DateTime.now();
    final lastQuiz = lastQuizDate!;
    return !(today.year == lastQuiz.year && 
             today.month == lastQuiz.month && 
             today.day == lastQuiz.day);
  }

  /// Niveau suggéré basé sur les performances
  String get suggestedDifficulty {
    if (totalQuizzesCompleted == 0) return 'novice';
    if (accuracyPercentage >= 90 && totalQuizzesCompleted >= 5) return 'expert';
    if (accuracyPercentage >= 75 && totalQuizzesCompleted >= 3) return 'difficile';
    if (accuracyPercentage >= 60) return 'intermédiaire';
    return 'novice';
  }

  /// Crée une copie avec des modifications
  QuizStats copyWith({
    int? totalQuizzesCompleted,
    int? totalPoints,
    int? totalQuestionsAnswered,
    int? correctAnswers,
    Map<String, int>? difficultyStats,
    DateTime? lastQuizDate,
    String? lastDifficulty,
    List<int>? recentScores,
    int? currentStreak,
    int? bestStreak,
    Map<String, int>? categoryStats,
  }) {
    return QuizStats(
      totalQuizzesCompleted: totalQuizzesCompleted ?? this.totalQuizzesCompleted,
      totalPoints: totalPoints ?? this.totalPoints,
      totalQuestionsAnswered: totalQuestionsAnswered ?? this.totalQuestionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      difficultyStats: difficultyStats ?? this.difficultyStats,
      lastQuizDate: lastQuizDate ?? this.lastQuizDate,
      lastDifficulty: lastDifficulty ?? this.lastDifficulty,
      recentScores: recentScores ?? this.recentScores,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      categoryStats: categoryStats ?? this.categoryStats,
    );
  }

  /// Convertit en Map pour SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'totalQuizzesCompleted': totalQuizzesCompleted,
      'totalPoints': totalPoints,
      'totalQuestionsAnswered': totalQuestionsAnswered,
      'correctAnswers': correctAnswers,
      'difficultyStats': difficultyStats,
      'lastQuizDate': lastQuizDate?.toIso8601String(),
      'lastDifficulty': lastDifficulty,
      'recentScores': recentScores,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'categoryStats': categoryStats,
    };
  }

  /// Crée depuis JSON (SharedPreferences)
  factory QuizStats.fromJson(Map<String, dynamic> json) {
    return QuizStats(
      totalQuizzesCompleted: json['totalQuizzesCompleted'] as int? ?? 0,
      totalPoints: json['totalPoints'] as int? ?? 0,
      totalQuestionsAnswered: json['totalQuestionsAnswered'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      difficultyStats: Map<String, int>.from(json['difficultyStats'] as Map? ?? {}),
      lastQuizDate: json['lastQuizDate'] != null 
          ? DateTime.parse(json['lastQuizDate'] as String)
          : null,
      lastDifficulty: json['lastDifficulty'] as String?,
      recentScores: List<int>.from(json['recentScores'] as List? ?? []),
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      categoryStats: Map<String, int>.from(json['categoryStats'] as Map? ?? {}),
    );
  }

  @override
  String toString() {
    return 'QuizStats(completed: $totalQuizzesCompleted, points: $totalPoints, accuracy: ${accuracyPercentage.toStringAsFixed(1)}%)';
  }
}

/// Énumération des niveaux de difficulté
enum QuizDifficulty {
  novice('Novice', 'Questions de base', 1, 0xFF4CAF50),
  intermediate('Intermédiaire', 'Questions moyennes', 2, 0xFFFF9800),
  difficult('Difficile', 'Questions avancées', 3, 0xFFFF5722),
  expert('Expert', 'Questions d\'expert', 5, 0xFFE91E63);

  const QuizDifficulty(this.label, this.description, this.pointMultiplier, this.colorValue);
  
  final String label;
  final String description;
  final int pointMultiplier;
  final int colorValue;
  
  /// Couleur associée au niveau
  Color get color => Color(colorValue);
  
  /// Icône associée au niveau
  IconData get icon {
    switch (this) {
      case QuizDifficulty.novice:
        return Icons.school_outlined;
      case QuizDifficulty.intermediate:
        return Icons.trending_up_outlined;
      case QuizDifficulty.difficult:
        return Icons.local_fire_department_outlined;
      case QuizDifficulty.expert:
        return Icons.emoji_events_outlined;
    }
  }
}

/// Extension pour faciliter l'utilisation
extension QuizDifficultyExtension on QuizDifficulty {
  static QuizDifficulty fromString(String value) {
    switch (value.toLowerCase()) {
      case 'novice':
        return QuizDifficulty.novice;
      case 'intermédiaire':
      case 'intermediate':
        return QuizDifficulty.intermediate;
      case 'difficile':
      case 'difficult':
        return QuizDifficulty.difficult;
      case 'expert':
        return QuizDifficulty.expert;
      default:
        return QuizDifficulty.novice;
    }
  }
  
  String get key => toString().split('.').last;
}