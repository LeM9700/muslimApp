import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hadith.dart';
import '../models/hadith_category.dart';
import '../models/hadith_page.dart';

/// Erreur d'accès à l'API HadeethEnc (réseau, statut HTTP, format).
class HadeethEncException implements Exception {
  final String message;
  final int? statusCode;

  const HadeethEncException(this.message, {this.statusCode});

  @override
  String toString() => 'HadeethEncException($statusCode): $message';
}

/// Accès aux données de l'Encyclopédie des hadiths traduits
/// (https://hadeethenc.com). API publique, sans clé.
///
/// Repository « pur » : uniquement HTTP + parsing, aucune règle métier ni
/// cache (voir HadithService et HadithCacheRepository).
class HadeethEncRepository {
  HadeethEncRepository({
    http.Client? client,
    this.language = 'fr',
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://hadeethenc.com/api/v1';

  final http.Client _client;

  /// Langue des traductions demandées.
  final String language;

  final Duration requestTimeout;

  /// Catégories racines avec leur nombre de hadiths traduits.
  Future<List<HadithCategory>> fetchRootCategories() async {
    final body = await _getJson('/categories/roots/', {'language': language});
    if (body is! List) {
      throw const HadeethEncException('Format inattendu pour les catégories');
    }
    return body
        .whereType<Map<String, dynamic>>()
        .map(HadithCategory.fromJson)
        .toList(growable: false);
  }

  /// Toutes les catégories (racines et sous-catégories, ~420 entrées).
  Future<List<HadithCategory>> fetchAllCategories() async {
    final body = await _getJson('/categories/list/', {'language': language});
    if (body is! List) {
      throw const HadeethEncException('Format inattendu pour les catégories');
    }
    return body
        .whereType<Map<String, dynamic>>()
        .map(HadithCategory.fromJson)
        .toList(growable: false);
  }

  /// Page [page] (à partir de 1) des hadiths de [categoryId], sous-thèmes
  /// inclus.
  Future<HadithPage> fetchHadithPage({
    required String categoryId,
    required int page,
    int perPage = 20,
  }) async {
    final body = await _getJson('/hadeeths/list/', {
      'language': language,
      'category_id': categoryId,
      'page': '$page',
      'per_page': '$perPage',
    });
    if (body is! Map<String, dynamic>) {
      throw const HadeethEncException('Format inattendu pour la liste');
    }
    return HadithPage.fromJson(body);
  }

  /// Identifiant du hadith à la position [position] (à partir de 1) dans
  /// [categoryId]. Utilise `per_page=1` pour ne transférer qu'une entrée.
  Future<String> fetchHadithIdAt({
    required String categoryId,
    required int position,
  }) async {
    final body = await _getJson('/hadeeths/list/', {
      'language': language,
      'category_id': categoryId,
      'page': '$position',
      'per_page': '1',
    });
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! List || data.isEmpty) {
      throw HadeethEncException(
        'Aucun hadith en position $position de la catégorie $categoryId',
      );
    }
    final first = data.first;
    if (first is! Map<String, dynamic> || first['id'] == null) {
      throw const HadeethEncException('Format inattendu pour la liste');
    }
    return first['id'].toString();
  }

  /// Détail complet d'un hadith (traduction, degré, explication…).
  Future<Hadith> fetchHadith(String id) async {
    final body = await _getJson('/hadeeths/one/', {
      'language': language,
      'id': id,
    });
    if (body is! Map<String, dynamic>) {
      throw HadeethEncException('Hadith $id introuvable');
    }
    return parseHadith(body);
  }

  /// Mappe la réponse `/hadeeths/one` vers [Hadith].
  ///
  /// Le champ `hadeeth` contient l'introduction du rapporteur suivie des
  /// paroles rapportées : on les sépare pour mettre les paroles en avant.
  static Hadith parseHadith(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final full = _clean(json['hadeeth']);
    final intro = _clean(json['hadeeth_intro']);
    final arabic = _clean(json['hadeeth_ar']);
    final attribution = _clean(json['attribution']);

    if (id.isEmpty || full.isEmpty) {
      throw const HadeethEncException('Hadith sans identifiant ou sans texte');
    }

    final translation = (intro.isNotEmpty && full.startsWith(intro))
        ? full.substring(intro.length).trim()
        : full;

    return Hadith(
      id: 'henc_$id',
      text: arabic.isNotEmpty ? '$arabic\n\n$full' : full,
      source: attribution,
      reviewed: true,
      hadithNumber: id,
      grade: _clean(json['grade']),
      gradeArabic: _clean(json['grade_ar']),
      title: _clean(json['title']),
      translation: translation.isEmpty ? full : translation,
      narratorIntro: intro.isEmpty ? null : intro,
      textArabic: arabic.isEmpty ? null : arabic,
      explanation: _clean(json['explanation']),
      hints: (json['hints'] as List<dynamic>? ?? const [])
          .map(_clean)
          .where((h) => h.isNotEmpty)
          .toList(growable: false),
      provider: HadithProvider.hadeethEnc,
    );
  }

  /// Retire les `\r` et espaces parasites présents dans certaines entrées.
  static String _clean(Object? value) =>
      (value is String ? value : '').replaceAll('\r', '').trim();

  Future<Object?> _getJson(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(requestTimeout);
    } on Exception catch (e) {
      throw HadeethEncException('Réseau indisponible : $e');
    }

    if (response.statusCode != 200) {
      throw HadeethEncException(
        'Statut HTTP inattendu pour $path',
        statusCode: response.statusCode,
      );
    }
    try {
      // bodyBytes + utf8 : évite un mauvais décodage si le charset manque.
      return json.decode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HadeethEncException('JSON invalide pour $path');
    }
  }
}
