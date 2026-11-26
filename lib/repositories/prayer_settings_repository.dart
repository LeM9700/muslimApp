import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_settings.dart';
import '../models/notification_settings.dart';
import '../models/shawwal_progress.dart';
import '../models/prayer_schedule.dart';

/// Calendrier mis en cache, lié à la position et à la méthode qui l'ont
/// produit : si l'une change, le cache est invalide.
class CachedCalendar {
  final String locationKey;
  final int? methodId;
  final String methodName;
  final List<PrayerDay> days;

  const CachedCalendar({
    required this.locationKey,
    required this.methodId,
    required this.methodName,
    required this.days,
  });

  bool matches(PrayerLocation location, int? method) =>
      locationKey == location.cacheKey && methodId == method;

  factory CachedCalendar.fromJson(Map<String, dynamic> json) => CachedCalendar(
        locationKey: json['location'] as String? ?? '',
        methodId: json['methodId'] as int?,
        methodName: json['methodName'] as String? ?? '',
        days: (json['days'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PrayerDay.fromJson)
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'location': locationKey,
        'methodId': methodId,
        'methodName': methodName,
        'days': days.map((d) => d.toJson()).toList(),
      };
}

/// Stockage local : réglages, position retenue et calendrier.
/// [⚡ PERF] Le calendrier pèse ~150 octets/jour, ~10 Ko pour 2 mois.
class PrayerSettingsRepository {
  static const String _settingsKey = 'notif_settings_v1';
  static const String _locationKey = 'prayer_location_v1';
  static const String _calendarKey = 'prayer_calendar_v1';
  static const String _promptDismissedKey = 'notif_prompt_dismissed_v1';
  static const String _calendarSettingsKey = 'calendar_settings_v1';
  static const String _shawwalKey = 'shawwal_progress_v1';

  Future<NotificationSettings> readSettings() async {
    final map = await _readMap(_settingsKey);
    return map == null
        ? const NotificationSettings()
        : NotificationSettings.fromJson(map);
  }

  Future<void> writeSettings(NotificationSettings settings) =>
      _write(_settingsKey, settings.toJson());

  Future<PrayerLocation?> readLocation() async {
    final map = await _readMap(_locationKey);
    if (map == null) return null;
    try {
      return PrayerLocation.fromJson(map);
    } on Object {
      return null;
    }
  }

  Future<void> writeLocation(PrayerLocation location) =>
      _write(_locationKey, location.toJson());

  Future<CachedCalendar?> readCalendar() async {
    final map = await _readMap(_calendarKey);
    return map == null ? null : CachedCalendar.fromJson(map);
  }

  Future<void> writeCalendar(CachedCalendar calendar) =>
      _write(_calendarKey, calendar.toJson());

  /// Préférences de calendrier (grégorien / hégirien, ajustement).
  Future<CalendarSettings> readCalendarSettings() async =>
      CalendarSettings.fromJson(await _readMap(_calendarSettingsKey));

  Future<void> writeCalendarSettings(CalendarSettings settings) =>
      _write(_calendarSettingsKey, settings.toJson());

  /// Suivi des 6 jours de Chawwal (dernière année suivie seulement).
  Future<ShawwalProgress?> readShawwal() async =>
      ShawwalProgress.fromJson(await _readMap(_shawwalKey));

  Future<void> writeShawwal(ShawwalProgress progress) =>
      _write(_shawwalKey, progress.toJson());

  Future<bool> isPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptDismissedKey) ?? false;
  }

  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptDismissedKey, true);
  }

  Future<void> _write(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(value));
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
