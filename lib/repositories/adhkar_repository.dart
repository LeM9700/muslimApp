import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/adhkar.dart';

/// Lit le recueil d'adhkar intégré à l'app (hors connexion).
class AdhkarRepository {
  AdhkarRepository({Future<String> Function(String key)? loadString})
      : _loadString = loadString ?? rootBundle.loadString;

  static const String assetPath = 'assets/adhkar/adhkar_fr.json';

  final Future<String> Function(String key) _loadString;
  AdhkarBook? _cache;

  Future<AdhkarBook> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _loadString(assetPath);
    return _cache = AdhkarBook.fromJson(json.decode(raw) as Map<String, dynamic>);
  }
}
