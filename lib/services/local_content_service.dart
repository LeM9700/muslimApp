import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/hadith.dart';
import '../models/quiz_question.dart';

/// Contenu embarqué dans l'app (assets/data) utilisé quand Firestore ou
/// l'API Sunnah.com ne renvoient rien : 195 questions de quiz et les 42
/// hadiths Nawawi. Les fichiers sont lus une seule fois puis gardés en mémoire.
class LocalContentService {
  static List<QuizQuestion>? _questions;
  static List<Hadith>? _hadiths;
  static final Random _random = Random();

  static Future<List<QuizQuestion>> _loadQuestions() async {
    if (_questions != null) return _questions!;
    final raw = await rootBundle.loadString('assets/data/quizzes.json');
    final list = json.decode(raw) as List<dynamic>;
    // Marquées validées comme lors du seeding Firestore (firebase_data_seeder)
    _questions = [
      for (var i = 0; i < list.length; i++)
        QuizQuestion.fromFirestore(
          list[i] as Map<String, dynamic>,
          'quiz_${i + 1}',
        ).copyWith(reviewed: true),
    ];
    return _questions!;
  }

  static Future<List<Hadith>> _loadHadiths() async {
    if (_hadiths != null) return _hadiths!;
    final raw = await rootBundle.loadString('assets/data/nawawi_hadiths_fr.json');
    final list = json.decode(raw) as List<dynamic>;
    _hadiths = list.map((e) {
      final h = e as Map<String, dynamic>;
      // Même format que les hadiths seedés dans Firestore (firebase_data_seeder)
      return Hadith(
        id: 'nawawi_${h['number']}',
        text: '${h['textArabic']}\n\n${h['textFrench']}',
        source: '${h['source']} — Rapporté par ${h['narrator']}',
        reviewed: true,
        collection: 'nawawi40',
        hadithNumber: h['number'].toString(),
      );
    }).toList();
    return _hadiths!;
  }

  /// [count] questions aléatoires, filtrées par [difficulty] si fourni.
  static Future<List<QuizQuestion>> getQuestions(int count,
      {String? difficulty}) async {
    final all = await _loadQuestions();
    final pool = (difficulty == null || difficulty.isEmpty)
        ? List<QuizQuestion>.of(all)
        : all.where((q) => q.difficulty == difficulty).toList();
    pool.shuffle(_random);
    return pool.take(count).toList();
  }

  static Future<QuizQuestion?> getRandomQuestion() async {
    final questions = await getQuestions(1);
    return questions.isEmpty ? null : questions.first;
  }

  /// Hadith déterministe pour la journée (même hadith toute la journée).
  static Future<Hadith?> getHadithOfTheDay() async {
    final hadiths = await _loadHadiths();
    if (hadiths.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return hadiths[dayOfYear % hadiths.length];
  }

  /// Hadith aléatoire, différent de [excludeId] quand c'est possible.
  static Future<Hadith?> getRandomHadith({String? excludeId}) async {
    final hadiths = await _loadHadiths();
    if (hadiths.isEmpty) return null;
    final candidates = hadiths.where((h) => h.id != excludeId).toList();
    final pool = candidates.isEmpty ? hadiths : candidates;
    return pool[_random.nextInt(pool.length)];
  }
}
