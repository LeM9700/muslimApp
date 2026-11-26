import 'package:flutter/foundation.dart';

import '../models/calendar_settings.dart';
import '../models/fasting.dart';
import '../models/hijri_date.dart';
import '../models/notification_settings.dart';
import '../models/shawwal_progress.dart';
import '../services/calendar_preferences.dart';
import '../services/fast_calendar.dart';
import '../services/hijri_converter.dart';
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
  ShawwalProgress? _shawwal;
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

  /// Date hégirienne du jour (avec l'ajustement du croyant).
  HijriDate? get todayHijri =>
      HijriConverter.fromCivil(today, adjustment: calendar.hijriAdjustment);

  /// Pendant Chawwal : jours jeûnables écoulés (du 2 Chawwal à aujourd'hui),
  /// à cocher. Vide hors Chawwal (le 1er est l'Aïd : liste vide aussi).
  List<DateTime> get shawwalDays {
    final h = todayHijri;
    if (h == null || h.month != 10) return const [];
    return [
      for (var day = 2; day <= h.day; day++)
        DateTime(today.year, today.month, today.day - (h.day - day)),
    ];
  }

  bool get inShawwal => todayHijri?.month == 10;

  /// Suivi de l'année hégirienne en cours (vide si ancien ou absent).
  ShawwalProgress get shawwal {
    final year = todayHijri?.year ?? 0;
    final p = _shawwal;
    return p != null && p.hijriYear == year ? p : ShawwalProgress(hijriYear: year);
  }

  bool isShawwalFasted(DateTime day) => shawwal.days.contains(_key(day));

  Future<void> toggleShawwal(DateTime day) => _run(() async {
        _shawwal = await _service.toggleShawwalDay(day);
      });

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Vrai si un rappel sera envoyé la veille de [day].
  bool isReminded(FastDay day) =>
      fasting.enabled && day.kinds.any(fasting.kinds.contains);

  Future<void> load() async {
    await _calendar.load();
    _settings = await _service.readSettings();
    _shawwal = await _service.shawwalProgress();
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
