import 'package:flutter/foundation.dart';

import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import '../services/prayer_notification_service.dart';

/// Message ponctuel à afficher après une action (bandeau / snackbar).
enum SettingsNotice { none, permissionDenied, noLocation, testSent }

/// État et actions de l'écran « Notifications ».
class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController({PrayerNotificationService? service})
      : _service = service ?? PrayerNotificationService.instance;

  final PrayerNotificationService _service;

  NotificationStatus? _status;
  bool _busy = false;
  SettingsNotice _notice = SettingsNotice.none;
  bool _disposed = false;

  NotificationStatus? get status => _status;
  NotificationSettings get settings =>
      _status?.settings ?? const NotificationSettings();
  bool get isLoading => _status == null;
  bool get isBusy => _busy;
  SettingsNotice get notice => _notice;

  /// L'autorisation manque alors que l'utilisateur a activé quelque chose :
  /// il l'a refusée ou retirée dans les Réglages iOS.
  bool get permissionMissing {
    final s = _status;
    if (s == null || s.hasPermission) return false;
    return _notice == SettingsNotice.permissionDenied ||
        s.settings.prayersEnabled;
  }

  Future<void> load() async {
    _status = await _service.status();
    _notify();
  }

  void clearNotice() {
    if (_notice == SettingsNotice.none) return;
    _notice = SettingsNotice.none;
    _notify();
  }

  Future<void> setPrayersEnabled(bool enabled) => _run(() async {
        if (!enabled) {
          await _service.updateSettings(settings.copyWith(prayersEnabled: false));
          return;
        }
        final outcome = await _service.enablePrayers();
        _notice = switch (outcome) {
          EnableOutcome.enabled => SettingsNotice.none,
          EnableOutcome.permissionDenied => SettingsNotice.permissionDenied,
          EnableOutcome.noLocation => SettingsNotice.noLocation,
        };
      });

  Future<void> togglePrayer(Prayer prayer, bool enabled) => _run(() {
        final prayers = {...settings.prayers};
        enabled ? prayers.add(prayer) : prayers.remove(prayer);
        return _service.updateSettings(settings.copyWith(prayers: prayers));
      });

  Future<void> setReminder(int minutes) => _run(
      () => _service.updateSettings(settings.copyWith(reminderMinutes: minutes)));

  Future<void> setMethod(int? methodId) => _run(
      () => _service.updateSettings(settings.copyWith(methodId: () => methodId)));

  Future<void> setHadithDaily(bool enabled) =>
      _setDaily(() => settings.copyWith(hadithDaily: enabled), enabled);

  Future<void> setQuizDaily(bool enabled) =>
      _setDaily(() => settings.copyWith(quizDaily: enabled), enabled);

  Future<void> sendTest() => _run(() async {
        await _service.sendTest();
        _notice = SettingsNotice.testSent;
      });

  Future<void> _setDaily(
    NotificationSettings Function() update,
    bool enabling,
  ) =>
      _run(() async {
        if (enabling && !await _service.ensurePermission()) {
          _notice = SettingsNotice.permissionDenied;
        }
        await _service.updateSettings(update());
      });

  /// Une action à la fois : les interrupteurs sont désactivés pendant
  /// l'opération (évite les doubles appuis et les états incohérents).
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _notice = SettingsNotice.none;
    _notify();
    try {
      await action();
    } finally {
      _status = await _service.status();
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
    super.dispose();
  }
}
