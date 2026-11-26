import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/prayer_schedule.dart';

class AladhanException implements Exception {
  final String message;
  const AladhanException(this.message);

  @override
  String toString() => 'AladhanException: $message';
}

/// Résultat d'un mois de calendrier.
class PrayerMonth {
  final List<PrayerDay> days;

  /// Autorité réellement utilisée (utile en mode automatique).
  final String methodName;

  const PrayerMonth(this.days, this.methodName);
}

/// Accès au calendrier mensuel d'Aladhan (https://aladhan.com).
///
/// Un seul appel couvre un mois entier : de quoi programmer les
/// notifications plusieurs jours à l'avance sans appel quotidien.
class AladhanRepository {
  AladhanRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.aladhan.com/v1';

  final http.Client _client;
  final Duration timeout;

  Future<PrayerMonth> fetchMonth({
    required int year,
    required int month,
    required PrayerLocation location,
    int? methodId,
  }) async {
    final uri = Uri.parse('$_baseUrl/calendar/$year/$month').replace(
      queryParameters: {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        // Heures ISO avec décalage : instants absolus, pas d'ambiguïté DST.
        'iso8601': 'true',
        if (methodId != null) 'method': '$methodId',
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on Exception catch (e) {
      throw AladhanException('Réseau indisponible : $e');
    }
    if (response.statusCode != 200) {
      throw AladhanException('Statut HTTP ${response.statusCode}');
    }

    try {
      final body = json.decode(utf8.decode(response.bodyBytes));
      return parseMonth(body as Map<String, dynamic>);
    } on AladhanException {
      rethrow;
    } on Object catch (e) {
      throw AladhanException('Réponse invalide : $e');
    }
  }

  /// Parse la réponse `/calendar`. Un jour incomplet est rejeté en entier :
  /// mieux vaut aucune notification qu'une notification à une heure fausse.
  static PrayerMonth parseMonth(Map<String, dynamic> body) {
    if (body['code'] != 200 || body['data'] is! List) {
      throw AladhanException('Réponse inattendue (${body['status']})');
    }
    final days = <PrayerDay>[];
    var methodName = '';
    for (final entry in (body['data'] as List).whereType<Map<String, dynamic>>()) {
      final timings = entry['timings'] as Map<String, dynamic>? ?? const {};
      final times = <Prayer, DateTime>{};
      for (final prayer in Prayer.values) {
        final parsed = DateTime.tryParse('${timings[prayer.apiKey]}');
        if (parsed != null) times[prayer] = parsed.toUtc();
      }
      if (times.length != Prayer.values.length) continue;

      final date = entry['date'] as Map<String, dynamic>?;
      final gregorian = date?['gregorian'] as Map<String, dynamic>?;
      days.add(PrayerDay(
        dateKey: _isoDate(gregorian?['date'] as String?) ??
            times[Prayer.fajr]!.toIso8601String().substring(0, 10),
        times: times,
        hijriMonth: _hijriMonth(date?['hijri']),
      ));
      methodName = ((entry['meta'] as Map<String, dynamic>?)?['method']
              as Map<String, dynamic>?)?['name'] as String? ??
          methodName;
    }
    if (days.isEmpty) throw const AladhanException('Aucun horaire exploitable');
    return PrayerMonth(days, methodName);
  }

  /// `date.hijri.month.number` (1 à 12), `null` si absent ou invalide.
  static int? _hijriMonth(Object? hijri) {
    if (hijri is! Map) return null;
    final month = hijri['month'];
    final number = month is Map ? month['number'] : null;
    final value = number is int ? number : int.tryParse('$number');
    return value != null && value >= 1 && value <= 12 ? value : null;
  }

  /// « 20-11-2026 » → « 2026-11-20 ».
  static String? _isoDate(String? ddmmyyyy) {
    final parts = ddmmyyyy?.split('-');
    if (parts == null || parts.length != 3) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }
}
