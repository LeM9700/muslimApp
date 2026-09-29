/// Modèle pour une question de quiz provenant de Firestore
/// Représente une question avec options multiples, réponse et explication
class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final bool reviewed;
  final String? difficulty;
  final int points;
  final List<String> tags;
  final String language;
  final String? authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.reviewed,
    this.difficulty,
    this.points = 1,
    this.tags = const [],
    this.language = 'fr',
    this.authorId,
    this.createdAt,
    this.updatedAt,
  });

  /// Crée une QuizQuestion depuis un document Firestore
  /// Supporte les deux formats : 'answerIndex' (legacy) et 'correctIndex' (JSON seed)
  factory QuizQuestion.fromFirestore(Map<String, dynamic> data, String id) {
    return QuizQuestion(
      id: id,
      question: data['question'] as String? ?? '',
      options: List<String>.from(data['options'] as List? ?? []),
      answerIndex: data['answerIndex'] as int? ?? data['correctIndex'] as int? ?? 0,
      explanation: data['explanation'] as String? ?? '',
      reviewed: data['reviewed'] as bool? ?? false,
      difficulty: data['difficulty'] as String?,
      points: data['points'] as int? ?? 1,
      tags: List<String>.from(data['tags'] as List? ?? []),
      language: data['language'] as String? ?? 'fr',
      authorId: data['authorId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is String
              ? DateTime.tryParse(data['createdAt'] as String)
              : (data['createdAt'] as dynamic)?.toDate() as DateTime?)
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is String
              ? DateTime.tryParse(data['updatedAt'] as String)
              : (data['updatedAt'] as dynamic)?.toDate() as DateTime?)
          : null,
    );
  }

  /// Convertit la QuizQuestion en Map pour Firestore
  /// Utilisé si besoin d'écriture (admin uniquement)
  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctIndex': answerIndex,
      'explanation': explanation,
      'reviewed': reviewed,
      'difficulty': difficulty,
      'points': points,
      'tags': tags,
      'language': language,
      'authorId': authorId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Retourne la bonne réponse (texte de l'option correcte)
  /// Utilisé pour afficher la réponse après validation
  String get correctAnswer {
    if (answerIndex >= 0 && answerIndex < options.length) {
      return options[answerIndex];
    }
    return '';
  }

  /// Vérifie si une réponse donnée est correcte
  /// [selectedIndex] : index de l'option sélectionnée par l'utilisateur
  bool isCorrectAnswer(int selectedIndex) {
    return selectedIndex == answerIndex;
  }

  /// Copie la question avec modifications optionnelles
  /// Utile pour mises à jour locales
  QuizQuestion copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? answerIndex,
    String? explanation,
    bool? reviewed,
    String? difficulty,
    int? points,
    List<String>? tags,
    String? language,
    String? authorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      answerIndex: answerIndex ?? this.answerIndex,
      explanation: explanation ?? this.explanation,
      reviewed: reviewed ?? this.reviewed,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QuizQuestion(id: $id, question: ${question.substring(0, question.length.clamp(0, 50))}..., optionsCount: ${options.length}, reviewed: $reviewed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizQuestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}