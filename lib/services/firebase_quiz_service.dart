import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/quiz_question.dart';

/// Service pour récupérer les questions de quiz depuis Firestore
/// Avec gestion des erreurs et fallback vers données de test
class FirebaseQuizService {
  static const String _collection = 'quiz_questions';

  /// Récupère la question quiz du jour depuis Firestore avec fallback
  /// Utilise des données de test si Firebase indisponible
  Future<QuizQuestion?> getDailyQuestion() async {
    try {
      // Vérifier si Firebase est initialisé
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase non initialisé, utilisation des données de test');
        return _getMockQuestion();
      }
      
      // Tentative d'accès à Firestore avec timeout
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection(_collection)
          .where('reviewed', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 5));

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return QuizQuestion.fromFirestore(doc.data(), doc.id);
      }

      return _getMockQuestion();
    } catch (e) {
      print('⚠️ Firestore indisponible, utilisation des données de test');
      print('Erreur: $e');
      return _getMockQuestion();
    }
  }
  
  /// Méthode pour obtenir plusieurs questions pour un quiz
  Future<List<QuizQuestion>> getMultipleQuestions(int count) async {
    try {
      if (Firebase.apps.isEmpty) {
        return _getMockQuestions(count);
      }
      
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('questions')
          .where('reviewed', isEqualTo: true)
          .limit(count)
          .get()
          .timeout(Duration(seconds: 5));
      
      return querySnapshot.docs
          .map((doc) => QuizQuestion.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('⚠️ Erreur récupération questions multiples: $e');
      return _getMockQuestions(count);
    }
  }
  
  /// Méthode pour obtenir le compte de questions validées
  Future<int> getValidatedQuestionsCount() async {
    try {
      if (Firebase.apps.isEmpty) {
        return 156; // Nombre de test
      }
      
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('questions')
          .where('reviewed', isEqualTo: true)
          .count()
          .get()
          .timeout(Duration(seconds: 5));
      
      return querySnapshot.count ?? 156;
    } catch (e) {
      print('⚠️ Erreur comptage questions: $e');
      return 156; // Fallback
    }
  }
  
  /// Question de test si Firebase non disponible
  static QuizQuestion _getMockQuestion() {
    return QuizQuestion(
      id: 'mock_question_001',
      question: "Combien de sourates compte le Coran ?",
      options: ["112", "114", "116", "118"],
      answerIndex: 1, // 114 sourates
      explanation: "Le Coran comprend 114 sourates, de Al-Fatiha à An-Nas.",
      reviewed: true,
    );
  }
  
  /// Génère plusieurs questions de test pour les quizzes
  static List<QuizQuestion> _getMockQuestions(int count) {
    final questions = [
      QuizQuestion(
        id: 'mock_001',
        question: "Combien de prières obligatoires y a-t-il par jour ?",
        options: ["3", "4", "5", "6"],
        answerIndex: 2,
        explanation: "Il y a 5 prières obligatoires par jour : Fajr, Dhuhr, Asr, Maghrib et Isha.",
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_002',
        question: "Quel est le premier pilier de l'Islam ?",
        options: ["La prière", "La Shahada", "Le jeûne", "La zakat"],
        answerIndex: 1,
        explanation: "La Shahada (attestation de foi) est le premier pilier de l'Islam.",
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_003',
        question: "Pendant quel mois les musulmans jeûnent-ils ?",
        options: ["Ramadan", "Shawwal", "Dhul-Hijjah", "Muharram"],
        answerIndex: 0,
        explanation: "Le jeûne obligatoire a lieu pendant le mois de Ramadan.",
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_004',
        question: "Combien de fois doit-on faire le pèlerinage ?",
        options: ["Une fois dans sa vie", "Chaque année", "Jamais", "Selon ses moyens"],
        answerIndex: 0,
        explanation: "Le Hajj est obligatoire une fois dans la vie pour ceux qui en ont les moyens.",
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_005',
        question: "Quelle est la direction de la prière ?",
        options: ["Le Nord", "La Mecque", "Médine", "Jérusalem"],
        answerIndex: 1,
        explanation: "Les musulmans prient en direction de la Mecque (Qibla).",
        reviewed: true,
      ),
    ];
    
    return questions.take(count).toList();
  }
}