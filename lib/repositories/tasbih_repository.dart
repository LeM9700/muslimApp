import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Total de dhikr du jour (remis à zéro chaque jour civil).
class TasbihRepository {
  static const String _key = 'tasbih_daily_v1';

  /// Total enregistré pour [dateKey] (« AAAA-MM-JJ »), 0 sinon.
  Future<int> readTotal(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return 0;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return map['date'] == dateKey ? (map['total'] as int? ?? 0) : 0;
    } on Object {
      await prefs.remove(_key);
      return 0;
    }
  }

  Future<void> writeTotal(String dateKey, int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode({'date': dateKey, 'total': total}));
  }
}
