import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/hadith.dart';
import '../models/quiz_question.dart';
import 'hadith_api_service.dart';
import 'local_content_service.dart';

/// Service centralisé pour toutes les interactions Firebase
/// Gère l'initialisation, la disponibilité et les fallbacks
class FirebaseService {
  static FirebaseFirestore? _firestore;
  static bool _isFirebaseAvailable = false;
  static String? _unavailableReason;

  /// Initialise Firebase et vérifie la disponibilité
  static Future<void> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (_containsPlaceholderValues(options)) {
        _markUnavailable(
          'Firebase options are placeholders. Run flutterfire configure for the current Firebase project.',
        );
        return;
      }

      // Vérifier si Firebase est déjà initialisé
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: options,
        );
      }
      _firestore = FirebaseFirestore.instance;

      // Configuration Firestore
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isFirebaseAvailable = true;
      _unavailableReason = null;
      print('✅ Firebase initialisé avec succès');

      // Test de connectivité rapide avec timeout
      await _firestore!.enableNetwork();

      // Test simple de lecture pour vérifier la connexion
      await _firestore!
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      print('✅ Firestore connecté et opérationnel');
    } catch (e) {
      _markUnavailable(e.toString());
      print('⚠️ Firebase non disponible : $e');
      // Mode offline - utiliser les données en cache si disponibles
      print('📱 Mode hors ligne activé');
    }
  }

  /// Vérifie si Firebase est disponible
  static bool get isAvailable => _isFirebaseAvailable && _firestore != null;

  /// Raison lisible quand Firebase est indisponible.
  static String? get unavailableReason => _unavailableReason;

  static bool _containsPlaceholderValues(FirebaseOptions options) {
    final values = <String?>[
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
      options.storageBucket,
      options.authDomain,
    ];

    return values
        .whereType<String>()
        .any((value) => value.isEmpty || value.contains('REPLACE_'));
  }

  static void _markUnavailable(String reason) {
    _firestore = null;
    _isFirebaseAvailable = false;
    _unavailableReason = reason;
    debugPrint('Firebase unavailable: $reason');
  }

  /// Service Hadiths - Récupère le hadith du jour
  /// Source primaire : API Sunnah.com (avec cache quotidien)
  /// Fallback : Firestore (hadiths Nawawi seedés localement)
  static Future<Hadith?> getHadithOfTheDay() async {
    // 1. Essayer l'API Sunnah.com en premier (cache quotidien intégré)
    try {
      final apiHadith = await HadithApiService.getHadithOfTheDay();
      if (apiHadith != null) return apiHadith;
    } catch (e) {
      print('⚠️ API Sunnah non disponible, fallback Firestore : $e');
    }

    // 2. Fallback Firestore (hadiths Nawawi), puis JSON embarqué
    if (!isAvailable) return _getLocalHadith();

    try {
      final countResult = await _firestore!
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .count()
          .get()
          .timeout(Duration(seconds: 5));

      final totalCount = countResult.count ?? 0;
      if (totalCount == 0) return _getLocalHadith();

      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
      final todayIndex = dayOfYear % totalCount;

      final snapshot = await _firestore!
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .orderBy(FieldPath.documentId)
          .limit(todayIndex + 1)
          .get()
          .timeout(Duration(seconds: 8));

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.last;
        final data = doc.data();
        data['id'] = doc.id;
        return Hadith.fromMap(data);
      }

      return _getLocalHadith();
    } catch (e) {
      print('⚠️ Erreur Firestore Hadith : $e');
      return _getLocalHadith();
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
    if (!isAvailable) return _getLocalQuizQuestion();

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

      return _getLocalQuizQuestion();
    } catch (e) {
      print('⚠️ Erreur Firestore Quiz : $e');
      return _getLocalQuizQuestion();
    }
  }

  /// Service Quiz - Plusieurs questions pour un quiz complet
  /// Si [difficulty] est passé, filtre par niveau de difficulté
  static Future<List<QuizQuestion>> getMultipleQuestions(int count,
      {String? difficulty}) async {
    if (!isAvailable) return _getLocalQuestions(count, difficulty);

    try {
      Query<Map<String, dynamic>> query = _firestore!
          .collection('quiz_questions')
          .where('reviewed', isEqualTo: true);

      // Filtre par difficulté si spécifié
      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query
          .limit(count * 3) // Prendre plus pour mélanger
          .get()
          .timeout(Duration(seconds: 8));

      final questions = snapshot.docs
          .map((doc) => QuizQuestion.fromFirestore(doc.data(), doc.id))
          .toList();

      // Collection vide (non seedée) → questions embarquées
      if (questions.isEmpty) return _getLocalQuestions(count, difficulty);

      // Mélanger et prendre le nombre demandé
      questions.shuffle();
      return questions.take(count).toList();
    } catch (e) {
      print('⚠️ Erreur récupération questions multiples : $e');
      return _getLocalQuestions(count, difficulty);
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

  /// Fallbacks sur le contenu embarqué (assets/data), puis sur les mocks
  /// si la lecture de l'asset échoue.
  static Future<Hadith> _getLocalHadith() async {
    try {
      return await LocalContentService.getHadithOfTheDay() ?? _getMockHadith();
    } catch (e) {
      print('⚠️ Hadiths locaux indisponibles : $e');
      return _getMockHadith();
    }
  }

  static Future<QuizQuestion> _getLocalQuizQuestion() async {
    try {
      return await LocalContentService.getRandomQuestion() ??
          _getMockQuizQuestion();
    } catch (e) {
      print('⚠️ Questions locales indisponibles : $e');
      return _getMockQuizQuestion();
    }
  }

  static Future<List<QuizQuestion>> _getLocalQuestions(
      int count, String? difficulty) async {
    try {
      final questions =
          await LocalContentService.getQuestions(count, difficulty: difficulty);
      if (questions.isNotEmpty) return questions;
    } catch (e) {
      print('⚠️ Questions locales indisponibles : $e');
    }
    return _getMockQuestions(count);
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
        explanation:
            'Il y a 5 prières obligatoires par jour : Fajr, Dhuhr, Asr, Maghrib et Isha.',
        reviewed: true,
      ),
      QuizQuestion(
        id: 'mock_002',
        question: 'Quel est le premier pilier de l\'Islam ?',
        options: ['La prière', 'La Shahada', 'Le jeûne', 'La zakat'],
        answerIndex: 1,
        explanation:
            'La Shahada (attestation de foi) est le premier pilier de l\'Islam.',
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
        options: [
          'Une fois dans sa vie',
          'Chaque année',
          'Jamais',
          'Selon ses moyens'
        ],
        answerIndex: 0,
        explanation:
            'Le Hajj est obligatoire une fois dans la vie pour ceux qui en ont les moyens.',
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
          .collection('hadiths')
          .where('reviewed', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      _unavailableReason = e.toString();
      return false;
    }
  }
}
