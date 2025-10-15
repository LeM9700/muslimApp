import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quran_models.dart';

/// Service pour interagir avec l'API Quran Foundation v4
/// https://api.quran.com/api/v4
class QuranApiService {  
  QuranApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = 'https://api.quran.com/api/v4';

  /// À ajuster après un appel /resources/translations (FR Montada Islamic Foundation)
  /// Utilisons 136 par défaut mais on devra vérifier via listTranslations()
  static const int defaultFrenchTranslationId = 136;
  
  /// À ajuster après choix d'un réciteur (ex: Mishari Rashid Alafasy)
  /// Utilisons 7 par défaut mais on devra vérifier via listReciters()
  static const int defaultReciterId = 7;

  /// ID de traduction français trouvé dynamiquement (utilisé en priorité)
  int? _frenchTranslationId;

  /// Récupère les versets d'une sourate avec traduction FR et audio
  Future<List<Verse>> getVersesByChapter({
    required int chapterNumber,
    int page = 1,
    int perPage = 50,                 // max 50 selon doc API
    int? translationId,
    int reciterId = defaultReciterId,
  }) async {
    // Utilise l'ID trouvé dynamiquement en priorité
    final effectiveTranslationId = translationId ?? _frenchTranslationId ?? defaultFrenchTranslationId;
    try {
      final uri = Uri.parse('$_base/verses/by_chapter/$chapterNumber').replace(
        queryParameters: {
          'language': 'fr',
          'page': '$page',
          'per_page': '$perPage',
          // Champs demandés selon la doc API
          'fields': 'text_uthmani,verse_key,verse_number',
          'translations': '$effectiveTranslationId',
          'audio': '$reciterId',
        },
      );

      print('🌐 API Request: $uri');
      
      final response = await _client.get(uri);
      
      if (response.statusCode != 200) {
        throw QuranApiException(
          'Erreur API Quran (sourate $chapterNumber): ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final versesRaw = (data['verses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      print('✅ Loaded ${versesRaw.length} verses for chapter $chapterNumber');
      
      // Debug pour voir le premier verset et sa traduction
      if (versesRaw.isNotEmpty) {
        final firstVerse = versesRaw.first;
        print('🔍 Verset 1 debug:');
        print('  - text_uthmani: ${firstVerse['text_uthmani']}');
        print('  - translations: ${firstVerse['translations']}');
        print('  - audio: ${firstVerse['audio']}');
      }
      
      return versesRaw.map(Verse.fromApi).toList();
    } catch (e) {
      print('❌ Error loading verses: $e');
      if (e is QuranApiException) rethrow;
      throw QuranApiException('Erreur réseau: $e', 0);
    }
  }

  /// Récupère les métadonnées d'une sourate
  Future<ChapterInfo> getChapterMeta(int chapterNumber) async {
    try {
      final uri = Uri.parse('$_base/chapters/$chapterNumber?language=ar');
      
      print('🌐 API Chapter Request: $uri');
      
      final response = await _client.get(uri);
      
      if (response.statusCode != 200) {
        throw QuranApiException(
          'Erreur chapitre $chapterNumber: ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final chapterData = data['chapter'] as Map<String, dynamic>;
      
      final chapterInfo = ChapterInfo.fromApi(chapterData);
      print('✅ Loaded chapter meta: $chapterInfo');
      
      return chapterInfo;
    } catch (e) {
      print('❌ Error loading chapter meta: $e');
      if (e is QuranApiException) rethrow;
      throw QuranApiException('Erreur réseau: $e', 0);
    }
  }

  /// Récupère la liste des traductions disponibles pour découvrir l'ID français
  Future<List<Translation>> listTranslations() async {
    try {
      final uri = Uri.parse('$_base/resources/translations');
      
      print('🌐 API Translations Request: $uri');
      
      final response = await _client.get(uri);
      
      if (response.statusCode != 200) {
        throw QuranApiException(
          'Erreur listTranslations: ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final translationsRaw = (data['translations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final translations = translationsRaw.map(Translation.fromApi).toList();
      
      // Log des traductions françaises pour debug
      final frenchTranslations = translations.where(
        (t) => t.languageName.toLowerCase().contains('french') || 
               t.languageName.toLowerCase().contains('français')
      ).toList();
      
      print('✅ Found ${translations.length} translations, ${frenchTranslations.length} French:');
      for (final tr in frenchTranslations) {
        print('  - ID ${tr.id}: ${tr.name} (${tr.authorName})');
      }
      
      return translations;
    } catch (e) {
      print('❌ Error loading translations: $e');
      if (e is QuranApiException) rethrow;
      throw QuranApiException('Erreur réseau: $e', 0);
    }
  }

  /// Récupère la liste des récitateurs disponibles
  Future<List<Reciter>> listReciters() async {
    try {
      final uri = Uri.parse('$_base/resources/recitations');
      
      print('🌐 API Reciters Request: $uri');
      
      final response = await _client.get(uri);
      
      if (response.statusCode != 200) {
        throw QuranApiException(
          'Erreur listReciters: ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final recitersRaw = (data['recitations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final reciters = recitersRaw.map(Reciter.fromApi).toList();
      
      print('✅ Found ${reciters.length} reciters');
      for (final reciter in reciters.take(5)) { // Log premiers 5
        print('  - ID ${reciter.id}: ${reciter.name} (${reciter.style})');
      }
      
      return reciters;
    } catch (e) {
      print('❌ Error loading reciters: $e');
      if (e is QuranApiException) rethrow;
      throw QuranApiException('Erreur réseau: $e', 0);
    }
  }

  /// Récupère la liste des sourates (alternative à Firestore)
  Future<List<ChapterInfo>> getAllChapters() async {
    try {
      final uri = Uri.parse('$_base/chapters?language=ar');
      
      print('🌐 API Chapters Request: $uri');
      
      final response = await _client.get(uri);
      
      if (response.statusCode != 200) {
        throw QuranApiException(
          'Erreur getAllChapters: ${response.statusCode}',
          response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final chaptersRaw = (data['chapters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final chapters = chaptersRaw.map(ChapterInfo.fromApi).toList();
      
      print('✅ Loaded ${chapters.length} chapters');
      
      return chapters;
    } catch (e) {
      print('❌ Error loading chapters: $e');
      if (e is QuranApiException) rethrow;
      throw QuranApiException('Erreur réseau: $e', 0);
    }
  }

  /// Test pour trouver la bonne traduction française
  Future<void> findFrenchTranslation() async {
    try {
      final translations = await listTranslations();
      
      print('🔍 Recherche traductions françaises...');
      final frenchTranslations = translations.where((t) => 
        t.languageName.toLowerCase().contains('french') || 
        t.languageName.toLowerCase().contains('français') ||
        t.name.toLowerCase().contains('french') ||
        t.name.toLowerCase().contains('français') ||
        t.name.toLowerCase().contains('hamidullah')
      ).toList();
      
      for (final tr in frenchTranslations) {
        print('🇫🇷 ID ${tr.id}: ${tr.name} - ${tr.authorName} (${tr.languageName})');
      }
      
      if (frenchTranslations.isNotEmpty) {
        _frenchTranslationId = frenchTranslations.first.id;
        print('✅ Utiliser ID $_frenchTranslationId pour la traduction française');
      }
    } catch (e) {
      print('❌ Erreur recherche traductions: $e');
    }
  }

  /// Test de connectivité API
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_base/chapters/1'); // Test avec Al-Fatiha
      final response = await _client.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ API Connection test failed: $e');
      return false;
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}

/// Exception personnalisée pour les erreurs API Quran
class QuranApiException implements Exception {
  final String message;
  final int statusCode;

  QuranApiException(this.message, this.statusCode);

  @override
  String toString() => 'QuranApiException: $message (Status: $statusCode)';
}