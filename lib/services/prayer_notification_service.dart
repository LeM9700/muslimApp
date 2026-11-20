import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import '../repositories/aladhan_repository.dart';
import '../repositories/prayer_settings_repository.dart';
import 'notification_gateway.dart';
import 'prayer_notification_planner.dart';

enum EnableOutcome { enabled, permissionDenied, noLocation }

/// État présenté à l'écran de réglages.
class NotificationStatus {
  final NotificationSettings settings;
  final PrayerLocation? location;
  final bool hasPermission;

  /// Dernière notification de prière programmée (« couvert jusqu'au… »).
  final DateTime? coveredUntil;

  /// Autorité de calcul effectivement utilisée par Aladhan.
  final String methodName;

  /// Horaires du jour (pour les afficher à côté de chaque interrupteur).
  final PrayerDay? today;

  /// Vrai si les rappels sont activés mais qu'aucun horaire n'a pu être
  /// obtenu (hors connexion sans cache) : à signaler à l'utilisateur.
  final bool calendarUnavailable;

  const NotificationStatus({
    required this.settings,
    required this.location,
    required this.hasPermission,
    required this.coveredUntil,
    required this.methodName,
    required this.today,
    required this.calendarUnavailable,
  });
}

/// Orchestration des notifications : réglages → calendrier → planification
/// → système.
///
/// Stratégie : à chaque ouverture de l'app (et à chaque changement de
/// réglage ou de ville), on annule tout et on reprogramme les ~60
/// prochaines notifications. Opération idempotente et peu coûteuse, qui
/// évite toute désynchronisation entre état stocké et notifications réelles.
class PrayerNotificationService {
  PrayerNotificationService({
    PrayerSettingsRepository? store,
    AladhanRepository? aladhan,
    NotificationGateway? gateway,
    DateTime Function()? clock,
  })  : _store = store ?? PrayerSettingsRepository(),
        _aladhan = aladhan ?? AladhanRepository(),
        _gateway = gateway ?? LocalNotificationGateway(),
        _clock = clock ?? DateTime.now;

  static final PrayerNotificationService instance = PrayerNotificationService();

  final PrayerSettingsRepository _store;
  final AladhanRepository _aladhan;
  final NotificationGateway _gateway;
  final DateTime Function() _clock;

  /// Re-télécharger le calendrier quand il couvre moins de N jours.
  static const int minDaysAhead = 7;

  /// Pas de reprogrammation automatique plus d'une fois par intervalle
  /// (retours au premier plan répétés).
  static const Duration resumeThrottle = Duration(minutes: 30);

  DateTime? _lastRun;
  PrayerPlan _lastPlan = PrayerPlan.empty;
  String _methodName = '';
  bool _calendarUnavailable = false;

  /// Sérialise les reprogrammations (démarrage + retour au premier plan +
  /// changement de réglage peuvent se chevaucher).
  Future<void> _queue = Future.value();

  Future<NotificationStatus> status() async {
    final settings = await _store.readSettings();
    final location = await _store.readLocation();
    var calendar = await _store.readCalendar();
    if (location != null &&
        (calendar == null || !calendar.matches(location, settings.methodId))) {
      // Afficher les horaires aide à choisir, même avant l'autorisation :
      // on télécharge le calendrier sans rien programmer.
      await _calendarFor(location, settings.methodId, _clock());
      calendar = await _store.readCalendar();
    }
    final usable = location != null &&
        calendar != null &&
        calendar.matches(location, settings.methodId);
    return NotificationStatus(
      settings: settings,
      location: location,
      hasPermission: await _gateway.hasPermission(),
      coveredUntil: _lastPlan.coveredUntil,
      methodName: usable ? calendar.methodName : _methodName,
      today: usable ? _todayIn(calendar.days) : null,
      calendarUnavailable: settings.prayersEnabled && _calendarUnavailable,
    );
  }

  /// Reprogramme tout. [force] ignore la limitation de fréquence.
  Future<void> reschedule({bool force = false}) {
    final run = _queue.then((_) => _reschedule(force: force));
    _queue = run.catchError((Object _) {});
    return run;
  }

  /// Active les rappels de prière : demande l'autorisation au bon moment
  /// (geste explicite de l'utilisateur), comme le recommande Apple.
  Future<EnableOutcome> enablePrayers() async {
    if (await _store.readLocation() == null) return EnableOutcome.noLocation;
    final granted =
        await _gateway.hasPermission() || await _gateway.requestPermission();
    if (!granted) return EnableOutcome.permissionDenied;
    final settings = await _store.readSettings();
    await _store.writeSettings(settings.copyWith(prayersEnabled: true));
    await reschedule(force: true);
    return EnableOutcome.enabled;
  }

  /// Active un rappel quotidien (hadith ou quiz) : même logique de
  /// demande d'autorisation au moment du geste.
  Future<bool> ensurePermission() async =>
      await _gateway.hasPermission() || await _gateway.requestPermission();

  Future<void> updateSettings(NotificationSettings settings) async {
    await _store.writeSettings(settings);
    await reschedule(force: true);
  }

  /// Appelé quand l'utilisateur change de ville ou que le GPS donne une
  /// nouvelle position : les rappels suivent.
  Future<void> setLocation(PrayerLocation location) async {
    final current = await _store.readLocation();
    if (current != null &&
        current.cacheKey == location.cacheKey &&
        current.cityName == location.cityName) {
      return;
    }
    await _store.writeLocation(location);
    await reschedule(force: true);
  }

  Future<void> sendTest() => _gateway.showTest(
        title: 'Notifications activées',
        body: 'Vous recevrez ainsi l’heure de chaque prière.',
      );

  Future<void> _reschedule({required bool force}) async {
    final now = _clock();
    if (!force &&
        _lastRun != null &&
        now.difference(_lastRun!) < resumeThrottle) {
      return;
    }
    _lastRun = now;

    final settings = await _store.readSettings();
    if (!await _gateway.hasPermission()) {
      // Sans autorisation, rien ne serait délivré : inutile de programmer.
      _lastPlan = PrayerPlan.empty;
      return;
    }

    await _gateway.cancelAll();
    if (settings.hadithDaily) await _gateway.scheduleDaily(DailyNotification.hadith);
    if (settings.quizDaily) await _gateway.scheduleDaily(DailyNotification.quiz);

    final location = await _store.readLocation();
    if (!settings.prayersEnabled || location == null) {
      _lastPlan = PrayerPlan.empty;
      return;
    }

    final days = await _calendarFor(location, settings.methodId, now);
    _calendarUnavailable = days.isEmpty;
    final plan = PrayerNotificationPlanner.plan(
      days: days,
      settings: settings,
      now: now,
      cityName: location.cityName,
    );
    for (final n in plan.notifications) {
      await _gateway.schedulePrayer(n);
    }
    _lastPlan = plan;
    debugPrint('Notifications : ${plan.notifications.length} rappels de prière '
        'programmés jusqu’au ${plan.coveredUntil?.toLocal()}');
  }

  /// Calendrier couvrant au moins [minDaysAhead] jours : cache si possible,
  /// sinon Aladhan (mois courant + suivant si besoin). Hors connexion, un
  /// cache même court vaut mieux que rien ; sans cache, liste vide.
  Future<List<PrayerDay>> _calendarFor(
    PrayerLocation location,
    int? methodId,
    DateTime now,
  ) async {
    final cached = await _store.readCalendar();
    final cacheOk = cached != null && cached.matches(location, methodId);
    if (cacheOk &&
        PrayerNotificationPlanner.daysAhead(cached.days, now) >= minDaysAhead) {
      _methodName = cached.methodName;
      return cached.days;
    }

    try {
      final current = await _aladhan.fetchMonth(
        year: now.year,
        month: now.month,
        location: location,
        methodId: methodId,
      );
      var days = current.days;
      final daysLeftInMonth =
          DateTime(now.year, now.month + 1, 0).day - now.day;
      if (daysLeftInMonth < 12) {
        final next = DateTime(now.year, now.month + 1);
        final following = await _aladhan.fetchMonth(
          year: next.year,
          month: next.month,
          location: location,
          methodId: methodId,
        );
        days = [...days, ...following.days];
      }
      // On ne garde que d'hier à la fin : le cache reste petit.
      final yesterday = now.toUtc().subtract(const Duration(days: 1));
      days = days
          .where((d) => d.times[Prayer.isha]?.isAfter(yesterday) ?? false)
          .toList();
      _methodName = current.methodName;
      await _store.writeCalendar(CachedCalendar(
        locationKey: location.cacheKey,
        methodId: methodId,
        methodName: current.methodName,
        days: days,
      ));
      return days;
    } on Object catch (e) {
      debugPrint('Notifications : calendrier indisponible ($e)');
      if (cacheOk) {
        _methodName = cached.methodName;
        return cached.days;
      }
      return const [];
    }
  }

  PrayerDay? _todayIn(List<PrayerDay> days) {
    final now = _clock();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    for (final d in days) {
      if (d.dateKey == key) return d;
    }
    return null;
  }
}
