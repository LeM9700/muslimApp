import 'package:flutter/foundation.dart';

import '../models/calendar_settings.dart';
import '../repositories/prayer_settings_repository.dart';

/// Préférences de calendrier partagées par les écrans (accueil,
/// notifications) : un changement fait sur l'un se voit sur l'autre.
class CalendarPreferences extends ChangeNotifier {
  CalendarPreferences({PrayerSettingsRepository? store})
      : _store = store ?? PrayerSettingsRepository();

  static final CalendarPreferences instance = CalendarPreferences();

  final PrayerSettingsRepository _store;
  CalendarSettings _settings = const CalendarSettings();
  bool _loaded = false;

  CalendarSettings get settings => _settings;

  /// Lit les préférences stockées (une seule fois, sauf [force]).
  Future<CalendarSettings> load({bool force = false}) async {
    if (_loaded && !force) return _settings;
    _settings = await _store.readCalendarSettings();
    _loaded = true;
    notifyListeners();
    return _settings;
  }

  Future<void> update(CalendarSettings settings) async {
    await _store.writeCalendarSettings(settings);
    _settings = settings;
    _loaded = true;
    notifyListeners();
  }
}
