/// Modèle pour une question de quiz provenant de Firestore
/// Représente une question avec options multiples, réponse et explication
class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final bool reviewed;
  final DateTime? createdAt;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.reviewed,
    this.createdAt,
  });

  /// Crée une QuizQuestion depuis un document Firestore
  /// Utilise les champs : question, options, answerIndex, explanation, reviewed
  factory QuizQuestion.fromFirestore(Map<String, dynamic> data, String id) {
    return QuizQuestion(
      id: id,
      question: data['question'] as String? ?? '',
      options: List<String>.from(data['options'] as List? ?? []),
      answerIndex: data['answerIndex'] as int? ?? 0,
      explanation: data['explanation'] as String? ?? '',
      reviewed: data['reviewed'] as bool? ?? false,
      createdAt: data['created_at']?.toDate() as DateTime?,
    );
  }

  /// Convertit la QuizQuestion en Map pour Firestore
  /// Utilisé si besoin d'écriture (admin uniquement)
  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'answerIndex': answerIndex,
      'explanation': explanation,
      'reviewed': reviewed,
      'created_at': createdAt,
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
    DateTime? createdAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      answerIndex: answerIndex ?? this.answerIndex,
      explanation: explanation ?? this.explanation,
      reviewed: reviewed ?? this.reviewed,
      createdAt: createdAt ?? this.createdAt,
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