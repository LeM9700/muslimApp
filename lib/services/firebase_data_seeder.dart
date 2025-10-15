import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

/// Service pour initialiser les données de test dans Firestore
class FirebaseDataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialise toutes les collections avec des données de test
  static Future<void> seedAllData() async {
    if (!FirebaseService.isAvailable) {
      print('⚠️ Firebase non disponible - pas de seeding');
      return;
    }

    try {
      print('🌱 Début du seeding des données...');
      
      await Future.wait([
        _seedHadiths(),
        _seedQuizQuestions(),
        _seedSurahs(),
        _seedPrayerTimes(),
      ]);
      
      print('✅ Seeding terminé avec succès');
    } on FirebaseException catch (fe) {
      // Gérer les erreurs Firestore (ex: PERMISSION_DENIED)
      print('❌ FirebaseException during seeding (ignored): ${fe.code} - ${fe.message}');
    } catch (e) {
      print('❌ Erreur lors du seeding : $e');
    }
  }

  /// Crée des hadiths de test
  static Future<void> _seedHadiths() async {
    try {
      // Vérifier si les données existent déjà
      final exists = (await _firestore.collection('hadiths').limit(1).get()).docs.isNotEmpty;
      if (exists) {
        print('ℹ️ Hadiths already exist — skipping');
        return;
      }

      final hadiths = [
        {
          'id': 'hadith_1',
          'text': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ - Les œuvres ne valent que par les intentions',
          'source': 'Sahih al-Bukhari',
          'number': '1',
          'theme': 'Intention',
          'reviewed': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'hadith_2', 
          'text': 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ - Que celui qui croit en Allah et au Jour dernier dise du bien ou qu\'il se taise',
          'source': 'Sahih al-Bukhari',
          'number': '6018',
          'theme': 'Parole',
          'reviewed': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'hadith_3',
          'text': 'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ - Le musulman est celui dont les musulmans sont à l\'abri de sa langue et de sa main',
          'source': 'Sahih al-Bukhari',
          'number': '10',
          'theme': 'Fraternité',
          'reviewed': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      final batch = _firestore.batch();
      for (final hadith in hadiths) {
        final docRef = _firestore.collection('hadiths').doc(hadith['id'] as String);
        batch.set(docRef, hadith);
      }
      await batch.commit();
      print('✅ Hadiths créés');
    } on FirebaseException catch (fe) {
      print('❌ _seedHadiths failed: ${fe.code} - ${fe.message}');
    }
  }

  /// Crée des questions de quiz
  static Future<void> _seedQuizQuestions() async {
    final questions = [
      {
        'id': 'quiz_1',
        'question': 'Combien de piliers compte l\'Islam ?',
        'options': ['3', '4', '5', '6'],
        'answerIndex': 2, // Index de '5'
        'explanation': 'L\'Islam compte 5 piliers : la Shahada, la Salat, la Zakat, le Sawm et le Hajj.',
        'difficulty': 'facile',
        'category': 'Piliers de l\'Islam',
        'reviewed': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'quiz_2',
        'question': 'Quelle est la première sourate du Coran ?',
        'options': ['Al-Baqarah', 'Al-Fatiha', 'An-Nas', 'Al-Ikhlas'],
        'answerIndex': 1, // Index de 'Al-Fatiha'
        'explanation': 'Al-Fatiha (L\'Ouverture) est la première sourate du Coran.',
        'difficulty': 'facile',
        'category': 'Coran',
        'reviewed': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'quiz_3',
        'question': 'Combien de fois par jour un musulman doit-il prier ?',
        'options': ['3', '4', '5', '6'],
        'answerIndex': 2, // Index de '5'
        'explanation': 'Les 5 prières quotidiennes sont : Fajr, Dhuhr, Asr, Maghrib et Isha.',
        'difficulty': 'facile',
        'category': 'Prière',
        'reviewed': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (final question in questions) {
      final docRef = _firestore.collection('quiz_questions').doc(question['id'] as String);
      batch.set(docRef, question);
    }
    await batch.commit();
    print('✅ Questions de quiz créées');
  }

  /// Crée des informations sur les sourates
  static Future<void> _seedSurahs() async {
    final surahs = [
      {
        'id': 'surah_1',
        'number': 1,
        'name': 'Al-Fatiha',
        'arabicName': 'الفاتحة',
        'translation': 'L\'Ouverture',
        'verses': 7,
        'type': 'Mecquoise',
        'description': 'La sourate d\'ouverture, récitée dans chaque prière.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'surah_2',
        'number': 2,
        'name': 'Al-Baqarah',
        'arabicName': 'البقرة',
        'translation': 'La Vache',
        'verses': 286,
        'type': 'Médinoise',
        'description': 'La plus longue sourate du Coran.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'surah_112',
        'number': 112,
        'name': 'Al-Ikhlas',
        'arabicName': 'الإخلاص',
        'translation': 'Le Monothéisme pur',
        'verses': 4,
        'type': 'Mecquoise',
        'description': 'Sourate sur l\'unicité d\'Allah.',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (final surah in surahs) {
      final docRef = _firestore.collection('surahs').doc(surah['id'] as String);
      batch.set(docRef, surah);
    }
    await batch.commit();
    print('✅ Sourates créées');
  }

  /// Crée des données pour les horaires de prière
  static Future<void> _seedPrayerTimes() async {
    final prayerData = {
      'default_location': {
        'city': 'Paris',
        'country': 'France',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'timezone': 'Europe/Paris',
        'createdAt': FieldValue.serverTimestamp(),
      },
      'calculation_method': {
        'method': 'ISNA', // Islamic Society of North America
        'fajr_angle': 15.0,
        'isha_angle': 15.0,
        'madhab': 'shafi', // Pour Asr
        'createdAt': FieldValue.serverTimestamp(),
      }
    };

    final batch = _firestore.batch();
    for (final entry in prayerData.entries) {
      final docRef = _firestore.collection('prayer_settings').doc(entry.key);
      batch.set(docRef, entry.value);
    }
    await batch.commit();
    print('✅ Paramètres de prière créés');
  }



  /// Nettoie toutes les collections (pour les tests)
  static Future<void> clearAllData() async {
    if (!FirebaseService.isAvailable) return;

    final collections = ['hadiths', 'quiz_questions', 'surahs', 'prayer_settings'];
    
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