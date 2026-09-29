import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/firebase_service.dart';

/// Service pour initialiser les données dans Firestore
/// Charge les questions depuis assets/data/quizzes.json (195 questions)
/// Charge les 42 hadiths Nawawi depuis assets/data/nawawi_hadiths_fr.json
class FirebaseDataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialise toutes les collections avec les données
  static Future<void> seedAllData() async {
    if (kReleaseMode) {
      print('Seeding disabled in release builds');
      return;
    }

    if (!FirebaseService.isAvailable) {
      print('⚠️ Firebase non disponible - pas de seeding');
      return;
    }

    try {
      print('🌱 Début du seeding des données...');

      await Future.wait([
        _seedHadithsFromJson(),
        _seedQuizQuestionsFromJson(),
      ]);

      print('✅ Seeding terminé avec succès');
    } on FirebaseException catch (fe) {
      print(
          '❌ FirebaseException during seeding (ignored): ${fe.code} - ${fe.message}');
    } catch (e) {
      print('❌ Erreur lors du seeding : $e');
    }
  }

  /// Charge et insère les 42 hadiths Nawawi depuis le JSON asset
  static Future<void> _seedHadithsFromJson() async {
    try {
      // Vérifier si les données existent déjà
      final exists = (await _firestore.collection('hadiths').limit(1).get())
          .docs
          .isNotEmpty;
      if (exists) {
        print('ℹ️ Hadiths already exist — skipping');
        return;
      }

      // Charger le JSON depuis les assets
      final jsonString =
          await rootBundle.loadString('assets/data/nawawi_hadiths_fr.json');
      final hadithsList = json.decode(jsonString) as List<dynamic>;

      print('📖 Chargement de ${hadithsList.length} hadiths Nawawi...');

      // Firestore batch limit = 500, on est bien en dessous
      final batch = _firestore.batch();
      for (int i = 0; i < hadithsList.length; i++) {
        final h = hadithsList[i] as Map<String, dynamic>;
        final docId = 'nawawi_${h['number']}';
        final docRef = _firestore.collection('hadiths').doc(docId);

        batch.set(docRef, {
          'id': docId,
          'text': '${h['textArabic']}\n\n${h['textFrench']}',
          'source': '${h['source']} — Rapporté par ${h['narrator']}',
          'number': h['number'].toString(),
          'theme': h['theme'] ?? '',
          'title': h['title'] ?? '',
          'reviewed': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ ${hadithsList.length} hadiths Nawawi créés');
    } on FirebaseException catch (fe) {
      print('❌ _seedHadithsFromJson failed: ${fe.code} - ${fe.message}');
    } catch (e) {
      print('❌ Erreur chargement hadiths JSON: $e');
    }
  }

  /// Charge et insère les 195 questions quiz depuis le JSON asset
  static Future<void> _seedQuizQuestionsFromJson() async {
    try {
      // Vérifier si les données existent déjà
      final exists =
          (await _firestore.collection('quiz_questions').limit(1).get())
              .docs
              .isNotEmpty;
      if (exists) {
        print('ℹ️ Quiz questions already exist — skipping');
        return;
      }

      // Charger le JSON depuis les assets
      final jsonString =
          await rootBundle.loadString('assets/data/quizzes.json');
      final questionsList = json.decode(jsonString) as List<dynamic>;

      print('📝 Chargement de ${questionsList.length} questions quiz...');

      // Firestore batch limit = 500, on split si nécessaire
      const batchSize = 450;
      for (int start = 0; start < questionsList.length; start += batchSize) {
        final end = (start + batchSize > questionsList.length)
            ? questionsList.length
            : start + batchSize;
        final batch = _firestore.batch();

        for (int i = start; i < end; i++) {
          final q = questionsList[i] as Map<String, dynamic>;
          final docId = 'quiz_${i + 1}';
          final docRef = _firestore.collection('quiz_questions').doc(docId);

          batch.set(docRef, {
            'id': docId,
            'question': q['question'],
            'options': List<String>.from(q['options'] as List),
            'correctIndex': q['correctIndex'],
            'difficulty': q['difficulty'] ?? 'novice',
            'points': q['points'] ?? 1,
            'explanation': q['explanation'] ?? '',
            'tags': List<String>.from((q['tags'] ?? <dynamic>[]) as List),
            'language': q['language'] ?? 'fr',
            'reviewed': true, // Marqué validé pour usage immédiat
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        print(
            '  ✅ Batch ${start ~/ batchSize + 1}: questions ${start + 1}-$end insérées');
      }
      print('✅ ${questionsList.length} questions quiz créées');
    } on FirebaseException catch (fe) {
      print('❌ _seedQuizQuestionsFromJson failed: ${fe.code} - ${fe.message}');
    } catch (e) {
      print('❌ Erreur chargement questions JSON: $e');
    }
  }

  /// Nettoie toutes les collections (pour les tests)
  static Future<void> clearAllData() async {
    if (!FirebaseService.isAvailable) return;

    final collections = ['hadiths', 'quiz_questions'];

    for (final collection in collections) {
      final snapshot = await _firestore.collection(collection).get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }

    print('🧹 Toutes les données ont été supprimées');
  }

  /// Re-seed après nettoyage (pour corriger les données)
  static Future<void> clearAndReseed() async {
    if (!FirebaseService.isAvailable) {
      print('⚠️ Firebase non disponible - pas de re-seeding');
      return;
    }

    try {
      print('🧹 Nettoyage des données existantes...');
      await clearAllData();

      print('🌱 Re-seeding avec les données corrigées...');
      await seedAllData();

      print('✅ Re-seeding terminé avec succès');
    } catch (e) {
      print('❌ Erreur lors du re-seeding : $e');
    }
  }
}
