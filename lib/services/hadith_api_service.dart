import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith.dart';

/// Service pour interagir avec l'API Sunnah.com (v1)
/// Documentation : https://sunnah.com/developers
///
/// [🔒 SÉCURITÉ] La clé API Sunnah doit être proxifiée côté serveur
/// en production. En attendant ce backend proxy, laisser vide → le service
/// tombe automatiquement en fallback Firestore (firebase_service.dart).
///
/// Collections disponibles : bukhari, muslim, tirmidhi, abudawud,
///   nasai, ibnmajah, malik, riyadussalihin, nawawi40, etc.
class HadithApiService {
  static const String _baseUrl = 'https://api.sunnah.com/v1';

  /// [🔒 SÉCURITÉ] Ne jamais mettre la clé en dur ici.
  /// À remplacer par un appel à un endpoint proxy /api/hadith/today
  /// qui appellera Sunnah.com côté serveur avec la clé secrète.
  // ignore: prefer_const_declarations
  static const String _apiKey = '';

  /// Headers requis par l'API
  /// Si _apiKey est vide, l'API retournera 401 → fallback Firestore automatique
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': _apiKey,
  };

  /// Clé pour le cache du hadith du jour
  static const String _cacheKey = 'hadith_of_the_day';
  static const String _cacheDateKey = 'hadith_of_the_day_date';

  // ─────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────

  /// Récupère un hadith aléatoire depuis l'API
  /// Endpoint : GET /v1/hadiths/random
  static Future<Hadith?> getRandomHadith() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/hadiths/random'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHadithEntry(data);
      }

      print('⚠️ API Sunnah random: status ${response.statusCode}');
      return null;
    } catch (e) {
      print('⚠️ API Sunnah random error: $e');
      return null;
    }
  }

  /// Hadith du jour — cache local pour éviter les appels répétés
  /// Appelle l'API une seule fois par jour, stocke dans SharedPreferences
  static Future<Hadith?> getHadithOfTheDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final cachedDate = prefs.getString(_cacheDateKey);

      // Si on a déjà un hadith pour aujourd'hui, le retourner
      if (cachedDate == today) {
        final cachedJson = prefs.getString(_cacheKey);
        if (cachedJson != null) {
          final map = json.decode(cachedJson) as Map<String, dynamic>;
          return Hadith.fromMap(map);
        }
      }

      // Sinon, en demander un nouveau
      final hadith = await getRandomHadith();
      if (hadith != null) {
        // Sauvegarder en cache
        await prefs.setString(_cacheDateKey, today);
        await prefs.setString(
          _cacheKey,
          json.encode({
            'id': hadith.id,
            'text': hadith.text,
            'source': hadith.source,
            'reviewed': hadith.reviewed,
            'collection': hadith.collection,
            'hadithNumber': hadith.hadithNumber,
            'grade': hadith.grade,
          }),
        );
      }
      return hadith;
    } catch (e) {
      print('⚠️ getHadithOfTheDay error: $e');
      return null;
    }
  }

  /// Récupère un hadith précis par collection et numéro
  /// Endpoint : GET /v1/collections/{collectionName}/hadiths/{hadithNumber}
  static Future<Hadith?> getHadithByNumber(
    String collectionName,
    String hadithNumber,
  ) async {
    try {
      final url =
          '$_baseUrl/collections/$collectionName/hadiths/$hadithNumber';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHadithEntry(data);
      }

      print('⚠️ API Sunnah byNumber: status ${response.statusCode}');
      return null;
    } catch (e) {
      print('⚠️ API Sunnah byNumber error: $e');
      return null;
    }
  }

  /// Récupère un hadith par son URN
  /// Endpoint : GET /v1/hadiths/{urn}
  static Future<Hadith?> getHadithByUrn(int urn) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/hadiths/$urn'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHadithEntry(data);
      }

      print('⚠️ API Sunnah byUrn: status ${response.statusCode}');
      return null;
    } catch (e) {
      print('⚠️ API Sunnah byUrn error: $e');
      return null;
    }
  }

  /// Récupère une liste de hadiths d'un livre dans une collection
  /// Endpoint : GET /v1/collections/{collectionName}/books/{bookNumber}/hadiths
  static Future<List<Hadith>> getHadithsByBook(
    String collectionName,
    String bookNumber, {
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final url = '$_baseUrl/collections/$collectionName/books/$bookNumber/hadiths'
          '?limit=$limit&page=$page';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final dataList = body['data'] as List<dynamic>? ?? [];
        return dataList
            .map((e) => _parseHadithEntry(e as Map<String, dynamic>))
            .whereType<Hadith>()
            .toList();
      }

      print('⚠️ API Sunnah byBook: status ${response.statusCode}');
      return [];
    } catch (e) {
      print('⚠️ API Sunnah byBook error: $e');
      return [];
    }
  }

  /// Récupère une liste paginée de hadiths
  /// Endpoint : GET /v1/hadiths
  static Future<List<Hadith>> getHadiths({int limit = 20, int page = 1}) async {
    try {
      final url = '$_baseUrl/hadiths?limit=$limit&page=$page';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final dataList = body['data'] as List<dynamic>? ?? [];
        return dataList
            .map((e) => _parseHadithEntry(e as Map<String, dynamic>))
            .whereType<Hadith>()
            .toList();
      }

      print('⚠️ API Sunnah list: status ${response.statusCode}');
      return [];
    } catch (e) {
      print('⚠️ API Sunnah list error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  //  PARSING
  // ─────────────────────────────────────────────

  /// Mappe la réponse API en objet Hadith
  ///
  /// Structure API :
  /// ```json
  /// {
  ///   "collection": "bukhari",
  ///   "hadithNumber": "1",
  ///   "hadith": [
  ///     { "lang": "ar", "body": "...", "grades": [...] },
  ///     { "lang": "en", "body": "...", "grades": [...] }
  ///   ]
  /// }
  /// ```
  static Hadith? _parseHadithEntry(Map<String, dynamic> entry) {
    try {
      final collection = entry['collection'] as String? ?? '';
      final hadithNumber = entry['hadithNumber'] as String? ?? '';
      final hadithList = entry['hadith'] as List<dynamic>? ?? [];

      if (hadithList.isEmpty) return null;

      // Chercher la version arabe et anglaise/française
      String arabicBody = '';
      String translationBody = '';
      String grade = '';

      for (final h in hadithList) {
        final lang = h['lang'] as String? ?? '';
        final body = _cleanHtmlBody(h['body'] as String? ?? '');

        if (lang == 'ar') {
          arabicBody = body;
        } else {
          // Prendre la première traduction disponible (en, fr, etc.)
          if (translationBody.isEmpty) {
            translationBody = body;
          }
        }

        // Récupérer le grade du premier qui en a un
        if (grade.isEmpty) {
          final grades = h['grades'] as List<dynamic>? ?? [];
          if (grades.isNotEmpty) {
            final g = grades.first as Map<String, dynamic>;
            grade = g['grade'] as String? ?? '';
          }
        }
      }

      // Construire le texte : arabe + traduction
      String text;
      if (arabicBody.isNotEmpty && translationBody.isNotEmpty) {
        text = '$arabicBody\n\n$translationBody';
      } else if (arabicBody.isNotEmpty) {
        text = arabicBody;
      } else {
        text = translationBody;
      }

      if (text.isEmpty) return null;

      // Construire la source lisible
      final collectionName = _collectionDisplayName(collection);
      final source = 'Hadith n°$hadithNumber — $collectionName';

      return Hadith(
        id: '${collection}_$hadithNumber',
        text: text,
        source: source,
        reviewed: true,
        collection: collection,
        hadithNumber: hadithNumber,
        grade: grade,
      );
    } catch (e) {
      print('⚠️ Parse hadith error: $e');
      return null;
    }
  }

  /// Nettoie le HTML léger retourné par l'API (balises <p>, <b>, etc.)
  static String _cleanHtmlBody(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Supprimer les balises HTML
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  /// Nom d'affichage des collections connues
  static String _collectionDisplayName(String collection) {
    const names = {
      'bukhari': 'Sahih al-Bukhari',
      'muslim': 'Sahih Muslim',
      'tirmidhi': 'Jami` at-Tirmidhi',
      'abudawud': 'Sunan Abu Dawud',
      'nasai': 'Sunan an-Nasa\'i',
      'ibnmajah': 'Sunan Ibn Majah',
      'malik': 'Muwatta Malik',
      'riyadussalihin': 'Riyad as-Salihin',
      'nawawi40': 'Les 40 Hadith Nawawi',
      'qudsi40': 'Les 40 Hadith Qudsi',
      'adab': 'Al-Adab Al-Mufrad',
      'bulugh': 'Bulugh al-Maram',
      'shamail': 'Ash-Shama\'il al-Muhammadiyya',
    };
    return names[collection] ?? collection;
  }
}
