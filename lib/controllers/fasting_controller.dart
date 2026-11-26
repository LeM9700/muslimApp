import 'package:flutter/foundation.dart';

import '../models/calendar_settings.dart';
import '../models/fasting.dart';
import '../models/notification_settings.dart';
import '../services/calendar_preferences.dart';
import '../services/fast_calendar.dart';
import '../services/prayer_notification_service.dart';

/// Message ponctuel de l'écran « Jeûnes ».
enum FastingNotice { none, permissionDenied, noLocation }

/// État et actions de l'écran « Jeûnes ».
class FastingController extends ChangeNotifier {
  FastingController({
    PrayerNotificationService? service,
    CalendarPreferences? calendar,
    DateTime Function()? clock,
  })  : _service = service ?? PrayerNotificationService.instance,
        _calendar = calendar ?? CalendarPreferences.instance,
        _clock = clock ?? DateTime.now {
    _calendar.addListener(_notify);
  }

  final PrayerNotificationService _service;
  final CalendarPreferences _calendar;
  final DateTime Function() _clock;

  /// Horizon de la liste « Prochains jeûnes ».
  static const int horizonDays = 90;

  NotificationSettings? _settings;
  bool _busy = false;
  bool _disposed = false;
  FastingNotice _notice = FastingNotice.none;

  bool get isLoading => _settings == null;
  bool get isBusy => _busy;
  FastingNotice get notice => _notice;
  FastingSettings get fasting =>
      _settings?.fasting ?? const FastingSettings();
  CalendarSettings get calendar => _calendar.settings;
  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Tous les jeûnes à venir (y compris les types non rappelés : la liste
  /// sert aussi de calendrier).
  List<FastDay> get upcoming => FastCalendar.upcoming(today,
      days: horizonDays, adjustment: calendar.hijriAdjustment);

  /// Vrai si un rappel sera envoyé la veille de [day].
  bool isReminded(FastDay day) =>
      fasting.enabled && day.kinds.any(fasting.kinds.contains);

  Future<void> load() async {
    await _calendar.load();
    _settings = await _service.readSettings();
    _notify();
  }

  Future<void> setEnabled(bool enabled) => _run(() async {
        if (!enabled) {
          final s = await _service.readSettings();
          await _service.updateSettings(
              s.copyWith(fasting: s.fasting.copyWith(enabled: false)));
          return;
        }
        _notice = switch (await _service.enableFasting()) {
          EnableOutcome.enabled => FastingNotice.none,
          EnableOutcome.permissionDenied => FastingNotice.permissionDenied,
          EnableOutcome.noLocation => FastingNotice.noLocation,
        };
      });

  Future<void> setKind(FastKind kind, bool on) => _run(() async {
        final s = await _service.readSettings();
        await _service.updateSettings(
            s.copyWith(fasting: s.fasting.toggle(kind, on)));
      });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _notice = FastingNotice.none;
    _notify();
    try {
      await action();
    } finally {
      _settings = await _service.readSettings();
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _calendar.removeListener(_notify);
    super.dispose();
  }
}
