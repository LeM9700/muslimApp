import 'package:flutter/foundation.dart';

import '../models/adhan_mode.dart';
import '../models/calendar_settings.dart';
import '../models/night_prayer_settings.dart';
import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import '../services/adhan_audio.dart';
import '../services/calendar_preferences.dart';
import '../services/prayer_notification_service.dart';

/// Message ponctuel à afficher après une action (bandeau / snackbar).
///
/// [nightNoLocation] : même cause que [noLocation], affichée dans la
/// section « Prière de nuit » (là où l'utilisateur a agi).
enum SettingsNotice { none, permissionDenied, noLocation, nightNoLocation, testSent }

/// État et actions de l'écran « Notifications ».
class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController({
    PrayerNotificationService? service,
    AdhanPlayback? preview,
    CalendarPreferences? calendar,
  })  : _service = service ?? PrayerNotificationService.instance,
        _calendar = calendar ?? CalendarPreferences.instance,
        _previewFactory = _factoryFor(preview) {
    _calendar.addListener(_notify);
  }

  static AdhanPlayback Function() _factoryFor(AdhanPlayback? preview) =>
      preview == null ? JustAudioAdhanPlayback.new : () => preview;

  final PrayerNotificationService _service;
  final CalendarPreferences _calendar;

  /// Lecteur d'aperçu créé à la première écoute (pas de player natif
  /// alloué pour rien si l'utilisateur n'écoute jamais).
  final AdhanPlayback Function() _previewFactory;
  AdhanPlayback? _preview;
  AdhanMode? _previewing;

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
        s.settings.prayersEnabled ||
        s.settings.night.enabled;
  }

  Future<void> load() async {
    await _calendar.load();
    _status = await _service.status();
    _notify();
  }

  /// Préférences de calendrier (partagées avec l'accueil).
  CalendarSettings get calendar => _calendar.settings;

  Future<void> setPrimaryCalendar(DateCalendar primary) =>
      _setCalendar(calendar.copyWith(primary: primary));

  /// L'ajustement déplace aussi le Ramadan : on reprogramme.
  Future<void> setHijriAdjustment(int days) =>
      _setCalendar(calendar.copyWith(hijriAdjustment: days));

  Future<void> _setCalendar(CalendarSettings next) => _run(() async {
        await _calendar.update(next);
        await _service.reschedule(force: true);
      });

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

  /// Active ou désactive la prière de nuit (section dédiée).
  Future<void> setNightEnabled(bool enabled) => _run(() async {
        if (!enabled) {
          await _updateNight(settings.night.copyWith(enabled: false));
          return;
        }
        final outcome = await _service.enableNightPrayer();
        _notice = switch (outcome) {
          EnableOutcome.enabled => SettingsNotice.none,
          EnableOutcome.permissionDenied => SettingsNotice.permissionDenied,
          EnableOutcome.noLocation => SettingsNotice.nightNoLocation,
        };
      });

  /// Mode d'un créneau de nuit (Désactivé, Silencieux ou Notification).
  Future<void> setNightMode(NightSlot slot, AdhanMode mode) =>
      _run(() => _updateNight(settings.night.withMode(slot, mode)));

  Future<void> setEveningDelay(int hours) => _run(() =>
      _updateNight(settings.night.copyWith(eveningDelayHours: hours)));

  Future<void> setFajrMargin(int minutes) => _run(() =>
      _updateNight(settings.night.copyWith(fajrMarginMinutes: minutes)));

  Future<void> _updateNight(NightPrayerSettings night) =>
      _service.updateSettings(settings.copyWith(night: night));

  /// Profil actif, `null` = réglage personnalisé.
  AdhanPreset? get activePreset => AdhanPreset.matching(settings.modes);

  /// Mode dont l'aperçu est en cours de lecture.
  AdhanMode? get previewing => _previewing;

  Future<void> setMode(Prayer prayer, AdhanMode mode) => _run(
      () => _service.updateSettings(settings.withMode(prayer, mode)));

  /// Applique [mode] aux 5 prières.
  Future<void> setModeForAll(AdhanMode mode) => _run(() => _service
      .updateSettings(settings.copyWith(modes: {for (final p in Prayer.values) p: mode})));

  Future<void> applyPreset(AdhanPreset preset) =>
      _run(() => _service.updateSettings(settings.copyWith(modes: preset.modes)));

  /// Écoute (ou arrête) le son de notification d'un mode d'adhan.
  Future<void> togglePreview(AdhanMode mode) async {
    final asset = AdhanAudioCatalog.previewFor(mode);
    if (asset == null) return;
    final player = _preview ??= _createPreview();
    if (_previewing == mode && player.isPlaying.value) {
      await player.stop();
      return;
    }
    try {
      await player.playFirstAvailable([asset]);
      // Après le stop() interne du lecteur, qui remet `_previewing` à null.
      _previewing = mode;
    } on AdhanPlaybackException {
      _previewing = null;
    }
    _notify();
  }

  Future<void> stopPreview() async => _preview?.stop();

  AdhanPlayback _createPreview() {
    final player = _previewFactory();
    player.isPlaying.addListener(() {
      if (!player.isPlaying.value) _previewing = null;
      _notify();
    });
    return player;
  }

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
    _calendar.removeListener(_notify);
    _preview?.dispose();
    super.dispose();
  }
}
