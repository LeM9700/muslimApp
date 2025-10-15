import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/hadith.dart';
import '../models/quiz_question.dart';

/// Service centralisé pour toutes les interactions Firebase
/// Gère l'initialisation, la disponibilité et les fallbacks
class FirebaseService {
  static FirebaseFirestore? _firestore;
  static bool _isFirebaseAvailable = false;
  
  /// Initialise Firebase et vérifie la disponibilité
  static Future<void> initialize() async {
    try {
      // Vérifier si Firebase est déjà initialisé
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firestore = FirebaseFirestore.instance;
      
      // Configuration Firestore
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      _isFirebaseAvailable = true;
      print('✅ Firebase initialisé avec succès');
      
      // Test de connectivité rapide avec timeout
      await _firestore!.enableNetwork();
      
      // Test simple de lecture pour vérifier la connexion
      await _firestore!.collection('test').limit(1).get();
      print('✅ Firestore connecté et opérationnel');
    } catch (e) {
      _isFirebaseAvailable = false;
      print('⚠️ Firebase non disponible : $e');
      // Mode offline - utiliser les données en cache si disponibles
      print('📱 Mode hors ligne activé');
    }
  }
  
  /// Vérifie si Firebase est disponible
  static bool get isAvailable => _isFirebaseAvailable && _firestore != null;
  
  /// Service Hadiths - Récupère le hadith du jour
  static Future<Hadith?> getHadithOfTheDay() async {
    if (!isAvailable) return _getMockHadith();
    
    try {
      final snapshot = await _firestore!
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 8));
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return Hadith.fromMap(data);
      }
      
      return _getMockHadith();
    } catch (e) {
      print('⚠️ Erreur Firestore Hadith : $e');
      return _getMockHadith();
    }
  }
  
  /// Service Hadiths - Compte les hadiths validés
  static Future<int> getValidatedHadithsCount() async {
    if (!isAvailable) return 42;
    
    try {
      final snapshot = await _firestore!
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .count()
          .get()
          .timeout(Duration(seconds: 5));
      
      return snapshot.count ?? 42;
    } catch (e) {
      print('⚠️ Erreur comptage hadiths : $e');
      return 42;
    }
  }
  
  /// Service Quiz - Question aléatoire du jour
  static Future<QuizQuestion?> getRandomQuizQuestion() async {
    if (!isAvailable) return _getMockQuizQuestion();
    
    try {
      final snapshot = await _firestore!
          .collection('quiz_questions')
          .where('reviewed', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 8));
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return QuizQuestion.fromFirestore(data, snapshot.docs.first.id);
      }
      
      return _getMockQuizQuestion();
    } catch (e) {
      print('⚠️ Erreur Firestore Quiz : $e');
      return _getMockQuizQuestion();
    }
  }
  
  /// Service Quiz - Plusieurs questions pour un quiz complet
  static Future<List<QuizQuestion>> getMultipleQuestions(int count) async {
    if (!isAvailable) return _getMockQuestions(count);
    
    try {
      final snapshot = await _firestore!
          .collection('quiz_questions')
          .where('reviewed', isEqualTo: true)
          .limit(count)
          .get()
          .timeout(Duration(seconds: 8));
      
      return snapshot.docs
          .map((doc) => QuizQuestion.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('⚠️ Erreur récupération questions multiples : $e');
      return _getMockQuestions(count);
    }
  }
  
  /// Service Quiz - Compte les questions validées
  static Future<int> getValidatedQuestionsCount() async {
    if (!isAvailable) return 156;
    
    try {
      final snapshot = await _firestore!
          .collection('quiz_questions')
          .where('reviewed', isEqualTo: true)
          .count()
          .get()
          .timeout(Duration(seconds: 5));
      
      return snapshot.count ?? 156;
    } catch (e) {
      print('⚠️ Erreur comptage questions : $e');
      return 156;
    }
  }
  
  /// Données de test - Hadith de fallback
  static Hadith _getMockHadith() {
    return Hadith(
      id: 'mock_hadith_001',
      text: 'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى',
      source: 'صحيح البخاري',
      reviewed: true,
    );
  }
  
  /// Données de test - Question de quiz de fallback
  static QuizQuestion _getMockQuizQuestion() {
    return QuizQuestion(
      id: 'mock_quiz_001',
      question: 'Combien de sourates compte le Coran ?',
      options: ['112', '114', '116', '118'],
      answerIndex: 1,
      explanation: 'Le Coran comprend 114 sourates, de Al-Fatiha à An-Nas.',
      reviewed: true,
    );
  }
  
  /// Génère plusieurs questions de test pour les quizzes
  static List<QuizQuestion> _getMockQuestions(int count) {
    final questions = [
      QuizQuestion(
        id: 'mock_001',
        question: 'Combien de prières obligatoires y a-t-il par jour ?',
        options: ['3', '4', '5', '6'],
        answerIndex: 2,
        explanation: 'Il y a 5 prières obligatoires par jour : Fajr, Dhuhr, Asr, Maghrib et Isha.',
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_002',
        question: 'Quel est le premier pilier de l\'Islam ?',
        options: ['La prière', 'La Shahada', 'Le jeûne', 'La zakat'],
        answerIndex: 1,
        explanation: 'La Shahada (attestation de foi) est le premier pilier de l\'Islam.',
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_003',
        question: 'Pendant quel mois les musulmans jeûnent-ils ?',
        options: ['Ramadan', 'Shawwal', 'Dhul-Hijjah', 'Muharram'],
        answerIndex: 0,
        explanation: 'Le jeûne obligatoire a lieu pendant le mois de Ramadan.',
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_004',
        question: 'Combien de fois doit-on faire le pèlerinage ?',
        options: ['Une fois dans sa vie', 'Chaque année', 'Jamais', 'Selon ses moyens'],
        answerIndex: 0,
        explanation: 'Le Hajj est obligatoire une fois dans la vie pour ceux qui en ont les moyens.',
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_005',
        question: 'Quelle est la direction de la prière ?',
        options: ['Le Nord', 'La Mecque', 'Médine', 'Jérusalem'],
        answerIndex: 1,
        explanation: 'Les musulmans prient en direction de la Mecque (Qibla).',
        reviewed: true,
      ),
    ];
    
    return questions.take(count).toList();
  }
  
  /// Vérifie l'état de la connexion Firebase
  static Future<bool> checkConnectivity() async {
    if (!isAvailable) return false;
    
    try {
      await _firestore!
          .collection('test')
          .limit(1)
          .get()
          .timeout(Duration(seconds: 3));
      return true;
    } catch (e) {
      return false;
    }
  }
}