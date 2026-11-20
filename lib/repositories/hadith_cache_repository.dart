import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hadith.dart';
import '../models/hadith_category.dart';

/// Cache local des hadiths (SharedPreferences).
///
/// - hadith du jour : un seul, valable pour la date enregistrée ;
/// - hadiths récents : les derniers consultés, servis hors ligne quand
///   l'utilisateur demande un autre hadith ;
/// - catégories racines : servent à choisir le hadith du jour.
///
/// [⚡ PERF] Une entrée HadeethEnc pèse ~5-15 Ko (arabe + explication).
/// On plafonne les récents à [maxRecent] pour garder SharedPreferences léger
/// (chargé entièrement en mémoire au démarrage).
class HadithCacheRepository {
  HadithCacheRepository({this.maxRecent = 20});

  final int maxRecent;

  static const String _dailyKey = 'henc_daily_v1';
  static const String _recentKey = 'henc_recent_v1';
  static const String _rootsKey = 'henc_roots_v1';

  /// Hadith du jour mis en cache pour [dateKey] (format AAAA-MM-JJ).
  Future<Hadith?> readDaily(String dateKey) async {
    final map = await _readMap(_dailyKey);
    if (map == null || map['date'] != dateKey) return null;
    final hadith = map['hadith'];
    return hadith is Map<String, dynamic> ? Hadith.fromMap(hadith) : null;
  }

  Future<void> writeDaily(String dateKey, Hadith hadith) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dailyKey,
      json.encode({'date': dateKey, 'hadith': hadith.toMap()}),
    );
  }

  /// Hadiths récemment chargés, du plus récent au plus ancien.
  Future<List<Hadith>> readRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null) return const [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Hadith.fromMap)
          .toList(growable: false);
    } on Object {
      // Cache corrompu : on repart de zéro plutôt que de planter.
      await prefs.remove(_recentKey);
      return const [];
    }
  }

  /// Ajoute [hadith] en tête des récents (sans doublon, plafonné).
  Future<void> addRecent(Hadith hadith) async {
    final current = await readRecent();
    final updated = [
      hadith,
      ...current.where((h) => h.id != hadith.id),
    ].take(maxRecent).map((h) => h.toMap()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentKey, json.encode(updated));
  }

  /// Catégories racines si le cache a moins de [maxAge].
  Future<List<HadithCategory>?> readRootCategories({
    required DateTime now,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final map = await _readMap(_rootsKey);
    if (map == null) return null;
    final fetchedAt = DateTime.tryParse(map['fetchedAt'] as String? ?? '');
    if (fetchedAt == null || now.difference(fetchedAt) > maxAge) return null;
    final roots = map['roots'];
    if (roots is! List) return null;
    return roots
        .whereType<Map<String, dynamic>>()
        .map(HadithCategory.fromJson)
        .toList(growable: false);
  }

  Future<void> writeRootCategories(
    List<HadithCategory> roots, {
    required DateTime now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rootsKey,
      json.encode({
        'fetchedAt': now.toIso8601String(),
        'roots': roots.map((c) => c.toJson()).toList(),
      }),
    );
  }

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } on Object {
      await prefs.remove(key);
      return null;
    }
  }
}
