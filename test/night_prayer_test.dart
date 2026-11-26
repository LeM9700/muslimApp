import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/adhan_mode.dart';
import 'package:muslim_app/models/night_prayer_settings.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/notification_settings_screen.dart';
import 'package:muslim_app/services/adhan_sound_resolver.dart';
import 'package:muslim_app/services/night_prayer_calculator.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/notification_router.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:muslim_app/utils/french_dates.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_gateway.dart';
import 'support/fake_playback.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

/// Entrée `/calendar` d'Aladhan. Dhuhr et Asr ne servent pas à la prière
/// de nuit : valeurs fixes, seulement pour que le jour soit complet.
Map<String, dynamic> _entry({
  required String date,
  required String fajr,
  required String maghrib,
  required String isha,
  int? hijriMonth,
}) {
  final offset = fajr.substring(19);
  return {
    'timings': {
      'Fajr': fajr,
      'Dhuhr': '${date}T12:30:00$offset',
      'Asr': '${date}T15:00:00$offset',
      'Maghrib': maghrib,
      'Isha': isha,
    },
    'date': {
      'gregorian': {
        'date': '${date.substring(8, 10)}-${date.substring(5, 7)}-${date.substring(0, 4)}',
      },
      if (hijriMonth != null)
        'hijri': {
          'month': {'number': hijriMonth},
        },
    },
    'meta': {
      'method': {'id': 12, 'name': 'Union Organization Islamic de France'},
    },
  };
}

List<PrayerDay> _parse(List<Map<String, dynamic>> entries) =>
    AladhanRepository.parseMonth({'code': 200, 'data': entries}).days;

/// Jour synthétique (UTC+1) : Fajr 06:00, Maghrib 17:30, Isha 19:00.
/// Nuit de 12 h 30 → dernier tiers à 01:50 (00:50 UTC).
Map<String, dynamic> _synthetic(DateTime d, {int? hijriMonth = 5}) {
  final date = '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  return _entry(
    date: date,
    fajr: '${date}T06:00:00+01:00',
    maghrib: '${date}T17:30:00+01:00',
    isha: '${date}T19:00:00+01:00',
    hijriMonth: hijriMonth,
  );
}

List<PrayerDay> _days(int count, {DateTime? from, int? Function(DateTime)? hijri}) {
  final start = from ?? DateTime(2026, 11, 20);
  return _parse([
    for (var i = 0; i < count; i++)
      _synthetic(start.add(Duration(days: i)),
          hijriMonth: hijri == null ? 5 : hijri(start.add(Duration(days: i)))),
  ]);
}

/// 20 novembre 2026, 08:00 UTC.
final _now = DateTime.utc(2026, 11, 20, 8);

const _nightOnly = NotificationSettings(
  night: NightPrayerSettings(enabled: true),
);

String _fmtUtc(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}';

PrayerPlan _plan(
  List<PrayerDay> days,
  NotificationSettings settings, {
  DateTime? now,
  int budget = PrayerNotificationPlanner.defaultBudget,
}) =>
    PrayerNotificationPlanner.plan(
      days: days,
      settings: settings,
      now: now ?? _now,
      cityName: 'Paris',
      budget: budget,
      formatTime: _fmtUtc,
    );

Iterable<PlannedNotification> _slot(PrayerPlan plan, NightSlot slot) =>
    plan.notifications.where((n) => n.nightSlot == slot);

/// Faux Aladhan : jours synthétiques, mois hégirien au choix.
MockClient _aladhan({List<Uri>? calls, bool offline = false}) {
  return MockClient((request) async {
    calls?.add(request.url);
    if (offline) throw http.ClientException('offline');
    final segments = request.url.pathSegments;
    final year = int.parse(segments[segments.length - 2]);
    final month = int.parse(segments.last);
    final count = DateTime(year, month + 1, 0).day;
    return http.Response.bytes(
      utf8.encode(json.encode({
        'code': 200,
        'status': 'OK',
        'data': [
          for (var d = 1; d <= count; d++) _synthetic(DateTime(year, month, d)),
        ],
      })),
      200,
    );
  });
}

PrayerNotificationService _service(FakeGateway gateway, {http.Client? client}) =>
    PrayerNotificationService(
      store: PrayerSettingsRepository(),
      aladhan: AladhanRepository(client: client ?? _aladhan()),
      gateway: gateway,
      clock: () => _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NightPrayerCalculator', () {
    // Paris, 1er mars 2026, UOIF, données réelles d'Aladhan.
    final march = _parse([
      _entry(
        date: '2026-03-01',
        fajr: '2026-03-01T06:25:00+01:00',
        maghrib: '2026-03-01T18:34:00+01:00',
        isha: '2026-03-01T19:42:00+01:00',
        hijriMonth: 9,
      ),
      _entry(
        date: '2026-03-02',
        fajr: '2026-03-02T06:23:00+01:00',
        maghrib: '2026-03-02T18:35:00+01:00',
        isha: '2026-03-02T19:44:00+01:00',
        hijriMonth: 9,
      ),
    ]);

    test('dernier tiers = Fajr(J+1) − (Fajr(J+1) − Maghrib(J)) / 3', () {
      final night = NightPrayerCalculator.nightOf(march[0], march[1])!;
      expect(night.length, const Duration(hours: 11, minutes: 49));
      // 18:34 → 06:23 : 11 h 49 ; tiers 3 h 56 min 20 s → 02:26:40 (+01:00).
      expect(night.lastThirdStart, DateTime.utc(2026, 3, 2, 1, 26, 40));
    });

    test('écart avec le champ Lastthird d’Aladhan (coucher → lever du soleil)',
        () {
      final night = NightPrayerCalculator.nightOf(march[0], march[1])!;
      // Valeur réelle d'Aladhan pour cette nuit : 03:13 (+01:00).
      final aladhan = DateTime.parse('2026-03-02T03:13:00+01:00');
      final gap = aladhan.difference(night.lastThirdStart);
      expect(gap.inMinutes, 46);
    });

    test('ne devine jamais : lendemain absent, non consécutif ou incohérent',
        () {
      final days = _days(3);
      expect(NightPrayerCalculator.nightOf(days[2], null), isNull);
      expect(NightPrayerCalculator.nightOf(days[0], days[2]), isNull,
          reason: 'jour manquant entre les deux');
      expect(NightPrayerCalculator.nightOf(days[1], days[0]), isNull);
      final broken = PrayerDay(
        dateKey: days[1].dateKey,
        times: {Prayer.fajr: days[0].times[Prayer.maghrib]!},
      );
      expect(NightPrayerCalculator.nightOf(days[0], broken), isNull,
          reason: 'Fajr avant le Maghrib');
    });

    test('garde-fou : au plus tard N min avant le Fajr', () {
      final night = NightWindow(
        maghrib: DateTime.utc(2026, 6, 20, 20),
        fajrNext: DateTime.utc(2026, 6, 21, 2),
      );
      // Nuit de 6 h : dernier tiers à 00:00 UTC, Fajr à 02:00.
      expect(NightPrayerCalculator.lastThird(night, fajrMarginMinutes: 0)!.at,
          DateTime.utc(2026, 6, 21));
      final free = NightPrayerCalculator.lastThird(night, fajrMarginMinutes: 60)!;
      expect(free.at, DateTime.utc(2026, 6, 21));
      expect(free.clampedByMargin, isFalse);

      final short = NightWindow(
        maghrib: DateTime.utc(2026, 6, 20, 22),
        fajrNext: DateTime.utc(2026, 6, 21, 1),
      );
      // Nuit de 3 h : dernier tiers à 00:00, marge 60 → 00:00 = Fajr − 60.
      final clamped =
          NightPrayerCalculator.lastThird(short, fajrMarginMinutes: 60)!;
      expect(clamped.at, DateTime.utc(2026, 6, 21));
      final c45 = NightPrayerCalculator.lastThird(short, fajrMarginMinutes: 45)!;
      expect(c45.at, DateTime.utc(2026, 6, 21), reason: 'pas de recul inutile');

      final tiny = NightWindow(
        maghrib: DateTime.utc(2026, 6, 21, 0, 40),
        fajrNext: DateTime.utc(2026, 6, 21, 1, 10),
      );
      final t = NightPrayerCalculator.lastThird(tiny, fajrMarginMinutes: 30);
      expect(t, isNull, reason: 'nuit plus courte que la marge');
      final c = NightPrayerCalculator.lastThird(tiny, fajrMarginMinutes: 0)!;
      expect(c.at, DateTime.utc(2026, 6, 21, 1));
    });

    test('marge qui avance l’heure : signalée', () {
      final night = NightWindow(
        maghrib: DateTime.utc(2026, 6, 20, 23),
        fajrNext: DateTime.utc(2026, 6, 21, 1, 30),
      );
      // Dernier tiers à 00:40, Fajr − 60 = 00:30.
      final r = NightPrayerCalculator.lastThird(night, fajrMarginMinutes: 60)!;
      expect(r.at, DateTime.utc(2026, 6, 21, 0, 30));
      expect(r.clampedByMargin, isTrue);
    });

    test('[heure d’hiver] nuit du 24 au 25 octobre 2026 : instants absolus', () {
      tz_data.initializeTimeZones();
      final paris = tz.getLocation('Europe/Paris');
      final days = _parse([
        _entry(
          date: '2026-10-24',
          fajr: '2026-10-24T07:15:00+02:00',
          maghrib: '2026-10-24T18:44:00+02:00',
          isha: '2026-10-24T19:53:00+02:00',
        ),
        _entry(
          date: '2026-10-25',
          fajr: '2026-10-25T06:17:00+01:00',
          maghrib: '2026-10-25T17:42:00+01:00',
          isha: '2026-10-25T18:52:00+01:00',
        ),
      ]);
      final night = NightPrayerCalculator.nightOf(days[0], days[1])!;
      // 11 h 33 à l'horloge murale, mais 12 h 33 réelles (heure reculée).
      expect(night.length, const Duration(hours: 12, minutes: 33));
      expect(night.lastThirdStart, DateTime.utc(2026, 10, 25, 1, 6));

      // Comme dans le gateway : instant absolu → fuseau de l'appareil.
      final local = tz.TZDateTime.from(night.lastThirdStart, paris);
      expect([local.hour, local.minute], [2, 6]);
      // 02:06 existe deux fois cette nuit-là : c'est la seconde (UTC+1).
      expect(local.timeZoneOffset, const Duration(hours: 1));
      // Un calcul naïf à l'horloge murale donnerait 02:26, 20 min trop tard.
    });

    test('Ramadan : la nuit appartient au jour hégirien du lendemain', () {
      int hijri(DateTime d) =>
          d.isBefore(DateTime(2026, 2, 18)) ? 8 : (d.isBefore(DateTime(2026, 3, 20)) ? 9 : 10);
      final days = _days(32, from: DateTime(2026, 2, 17), hijri: hijri);
      bool ramadan(int i) => NightPrayerCalculator.isRamadanNight(days[i], days[i + 1]);
      expect(ramadan(0), isTrue, reason: '17 fév. : veille du 1er jeûne');
      expect(ramadan(29), isTrue, reason: '18 mars : veille du 30 Ramadan');
      expect(ramadan(30), isFalse, reason: '19 mars : veille de l’Aïd');
      expect(NightPrayerCalculator.isRamadanNight(days[31], null), isFalse);
      final unknown = _days(2, hijri: (_) => null);
      expect(NightPrayerCalculator.isRamadanNight(unknown[0], unknown[1]), isFalse);
    });
  });

  group('NightPrayerSettings', () {
    test('désactivée par défaut, Notification par défaut sur chaque créneau', () {
      const s = NotificationSettings();
      expect(s.night.enabled, isFalse);
      expect(s.night.isActive, isFalse);
      expect(s.needsCalendar, isFalse);
      for (final slot in NightSlot.values) {
        expect(s.night.modeOf(slot), AdhanMode.notification);
      }
      expect(s.night.eveningDelayHours, 1);
      expect(s.night.fajrMarginMinutes, 30);
    });

    test('[⚠️ migration] réglages v1.3.0 sans clé night → désactivée', () {
      final v13 = {
        'prayersEnabled': true,
        'modes': {
          'fajr': 'adhanFull',
          'dhuhr': 'notification',
          'asr': 'silent',
          'maghrib': 'adhanShort',
          'isha': 'off',
        },
        'reminderMinutes': 15,
        'methodId': 12,
        'hadithDaily': false,
        'quizDaily': true,
      };
      final s = NotificationSettings.fromJson(v13);
      expect(s.night.enabled, isFalse);
      expect(s.night.isActive, isFalse);
      expect(s.prayersEnabled, isTrue);
      expect(s.modeOf(Prayer.fajr), AdhanMode.adhanFull);
      expect(s.reminderMinutes, 15);
      expect(s.hadithDaily, isFalse);
      // v1.2.0 aussi.
      final v12 = NotificationSettings.fromJson(
          {'prayersEnabled': true, 'prayers': ['fajr']});
      expect(v12.night.enabled, isFalse);
    });

    test('aller-retour JSON', () {
      final s = const NightPrayerSettings(enabled: true, eveningDelayHours: 2, fajrMarginMinutes: 0)
          .withMode(NightSlot.lastThird, AdhanMode.silent)
          .withMode(NightSlot.tarawih, AdhanMode.off);
      final back = NotificationSettings.fromJson(
          json.decode(json.encode(NotificationSettings(night: s).toJson()))
              as Map<String, dynamic>);
      expect(back.night.toJson(), s.toJson());
    });

    test('[🔒] valeurs inattendues → défauts, jamais d’adhan la nuit', () {
      final s = NightPrayerSettings.fromJson({
        'enabled': 'yes',
        'evening': 'adhanFull',
        'lastThird': 'bogus',
        'tarawih': 42,
        'eveningDelayHours': 5,
        'fajrMarginMinutes': -1,
      });
      expect(s.enabled, isFalse);
      expect(s.evening, AdhanMode.notification);
      expect(s.lastThird, AdhanMode.notification);
      expect(s.tarawih, AdhanMode.notification);
      expect(s.eveningDelayHours, 1);
      expect(s.fajrMarginMinutes, 30);
      expect(NightPrayerSettings.fromJson('garbage').enabled, isFalse);
      expect(const NightPrayerSettings().withMode(NightSlot.evening, AdhanMode.adhanShort).evening,
          AdhanMode.notification);
    });

    test('activée mais tous les créneaux désactivés : inactive', () {
      var s = const NightPrayerSettings(enabled: true);
      for (final slot in NightSlot.values) {
        s = s.withMode(slot, AdhanMode.off);
      }
      expect(s.isActive, isFalse);
    });
  });

  group('NightPayload', () {
    test('format distinct, aller-retour', () {
      const p = NightPayload(NightSlot.lastThird, AdhanMode.silent);
      expect(p.encode(), 'night:lastThird:silent');
      final back = NightPayload.decode(p.encode())!;
      expect(back.slot, NightSlot.lastThird);
      expect(back.mode, AdhanMode.silent);
    });

    test('[🔒] toute valeur inattendue → null, sans exception', () {
      for (final raw in [
        null,
        '',
        'night',
        'night:lastThird',
        'night:lastThird:off',
        'night:lastThird:adhanFull',
        'night:fajr:notification',
        'night:lastThird:notification:extra',
        'prayer:fajr:notification',
        'hadith_daily',
      ]) {
        expect(NightPayload.decode(raw), isNull, reason: '$raw');
      }
    });

    test('les formats existants restent valides et distincts', () {
      expect(NotificationPayload.decode('night:evening:notification'), isNull);
      expect(NotificationPayload.decode('prayer:fajr:adhanFull')!.prayer, Prayer.fajr);
      expect(NotificationPayload.decode('prayer:asr')!.mode, AdhanMode.notification);
    });

    test('tap sur une notification de nuit : ouvre juste l’app', () {
      var opened = 0;
      final router = NotificationRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        openPlayer: (_, __) => opened++,
      );
      expect(router.handle('night:lastThird:notification'), isFalse);
      expect(router.handle('night:tarawih:notification'), isFalse);
      expect(opened, 0);
    });
  });

  group('PrayerNotificationPlanner · prière de nuit', () {
    test('nuit seule : soir + dernier tiers, la dernière nuit est ignorée', () {
      final plan = _plan(_days(3), _nightOnly);
      expect(plan.notifications.every((n) => n.kind == PlannedKind.night), isTrue);
      // 3 jours → 2 nuits complètes (le 22 n'a pas de Fajr J+1).
      expect(_slot(plan, NightSlot.evening).map((n) => n.when), [
        DateTime.utc(2026, 11, 20, 19),
        DateTime.utc(2026, 11, 21, 19),
      ]);
      expect(_slot(plan, NightSlot.lastThird).map((n) => n.when), [
        DateTime.utc(2026, 11, 21, 0, 50),
        DateTime.utc(2026, 11, 22, 0, 50),
      ]);
      expect(_slot(plan, NightSlot.tarawih), isEmpty);
      expect(plan.notifications.map((n) => n.id), [100, 101, 102, 103]);
      expect(plan.notifications.first.payload, 'night:evening:notification');
      expect(plan.notifications.every((n) => n.prayer == null), isTrue);
    });

    test('texte du dernier tiers validé', () {
      final n = _slot(_plan(_days(2), _nightOnly), NightSlot.lastThird).single;
      expect(n.title, 'Prière de nuit · 00:50');
      expect(n.body,
          'Le dernier tiers de la nuit commence. Notre Seigneur descend au '
          'ciel le plus proche : « Qui M’invoque, que Je lui réponde ? »');
    });

    test('désactivée ou prières seules : aucune notification de nuit', () {
      expect(_plan(_days(3), const NotificationSettings()).notifications, isEmpty);
      final prayersOnly = _plan(_days(3), const NotificationSettings(prayersEnabled: true));
      expect(prayersOnly.notifications.where((n) => n.kind == PlannedKind.night), isEmpty);
    });

    test('créneau désactivé et mode silencieux respectés', () {
      final night = const NightPrayerSettings(enabled: true)
          .withMode(NightSlot.evening, AdhanMode.off)
          .withMode(NightSlot.lastThird, AdhanMode.silent);
      final plan = _plan(_days(3), NotificationSettings(night: night));
      expect(_slot(plan, NightSlot.evening), isEmpty);
      expect(_slot(plan, NightSlot.lastThird).map((n) => n.mode).toSet(),
          {AdhanMode.silent});
    });

    test('rappel du soir à Isha + 2 h, supprimé si le dernier tiers a commencé',
        () {
      const late = NotificationSettings(
          night: NightPrayerSettings(enabled: true, eveningDelayHours: 2));
      expect(_slot(_plan(_days(2), late), NightSlot.evening).single.when,
          DateTime.utc(2026, 11, 20, 20));

      // Été : Isha 23:55, dernier tiers à 01:52 → Isha + 2 h trop tard.
      final summer = _parse([
        _entry(
          date: '2026-06-20',
          fajr: '2026-06-20T03:50:00+02:00',
          maghrib: '2026-06-20T21:58:00+02:00',
          isha: '2026-06-20T23:55:00+02:00',
        ),
        _entry(
          date: '2026-06-21',
          fajr: '2026-06-21T03:50:00+02:00',
          maghrib: '2026-06-21T21:58:00+02:00',
          isha: '2026-06-21T23:55:00+02:00',
        ),
      ]);
      final plan = _plan(summer, late, now: DateTime.utc(2026, 6, 20, 8));
      expect(_slot(plan, NightSlot.evening), isEmpty);
      expect(_slot(plan, NightSlot.lastThird), hasLength(1));
    });

    test('garde-fou appliqué : texte « est entamé » avec l’heure du Fajr', () {
      // Nuit très courte : Maghrib 23:00 UTC, Fajr 01:30 UTC.
      final short = _parse([
        _entry(
          date: '2026-06-20',
          fajr: '2026-06-20T01:30:00+00:00',
          maghrib: '2026-06-20T23:00:00+00:00',
          isha: '2026-06-20T23:40:00+00:00',
        ),
        _entry(
          date: '2026-06-21',
          fajr: '2026-06-21T01:30:00+00:00',
          maghrib: '2026-06-21T23:00:00+00:00',
          isha: '2026-06-21T23:40:00+00:00',
        ),
      ]);
      const s = NotificationSettings(
          night: NightPrayerSettings(enabled: true, fajrMarginMinutes: 60));
      final n = _slot(_plan(short, s, now: DateTime.utc(2026, 6, 20, 8)),
              NightSlot.lastThird)
          .single;
      expect(n.when, DateTime.utc(2026, 6, 21, 0, 30));
      expect(n.body, startsWith('Le dernier tiers de la nuit est entamé, Fajr à 01:30.'));
    });

    test('Ramadan : Tarawih à Isha + 15 min remplace le rappel du soir', () {
      int hijri(DateTime d) => d.day >= 22 ? 9 : 8;
      final plan = _plan(_days(4, hijri: hijri), _nightOnly);
      // Nuits du 20 (lendemain en Chaabane), du 21 (veille du 1er jeûne)
      // et du 22 (Ramadan).
      expect(_slot(plan, NightSlot.evening).map((n) => n.when),
          [DateTime.utc(2026, 11, 20, 19)]);
      expect(_slot(plan, NightSlot.tarawih).map((n) => n.when), [
        DateTime.utc(2026, 11, 21, 18, 15),
        DateTime.utc(2026, 11, 22, 18, 15),
      ]);
      expect(_slot(plan, NightSlot.lastThird), hasLength(3));
      final t = _slot(plan, NightSlot.tarawih).first;
      expect(t.payload, 'night:tarawih:notification');
      expect(t.body, contains('Bukhari 37'));
    });

    test('Ramadan avec Tarawih désactivé : le rappel du soir reste', () {
      final night = const NightPrayerSettings(enabled: true)
          .withMode(NightSlot.tarawih, AdhanMode.off);
      final plan = _plan(_days(3, hijri: (_) => 9), NotificationSettings(night: night));
      expect(_slot(plan, NightSlot.tarawih), isEmpty);
      expect(_slot(plan, NightSlot.evening), hasLength(2));
    });

    test('[iOS] budget de 60 commun : tri par date, troncature des plus lointaines',
        () {
      const settings = NotificationSettings(
        prayersEnabled: true,
        reminderMinutes: 10,
        night: NightPrayerSettings(enabled: true),
      );
      final days = _days(30);
      final all = _plan(days, settings, budget: 1000).notifications;
      final plan = _plan(days, settings);

      expect(plan.notifications, hasLength(60));
      expect(
        plan.notifications.map((n) => n.when),
        all.take(60).map((n) => n.when),
        reason: 'les 60 plus proches, tous types confondus',
      );
      for (var i = 1; i < plan.notifications.length; i++) {
        expect(plan.notifications[i].when.isBefore(plan.notifications[i - 1].when),
            isFalse);
      }
      expect(plan.notifications.map((n) => n.id),
          [for (var i = 0; i < 60; i++) 100 + i]);
      // 10 prières/rappels + 2 de nuit par jour → 5 jours couverts.
      expect(plan.notifications.where((n) => n.kind == PlannedKind.night),
          hasLength(10));
      expect(plan.coveredUntil, plan.notifications.last.when);
      expect(plan.coveredUntil!.isBefore(DateTime.utc(2026, 11, 26)), isTrue);
    });
  });

  group('Sons et canaux de nuit', () {
    test('canaux dédiés, jamais d’adhan ni de flux alarme', () {
      final ids = AdhanSoundResolver.channels.map((s) => s.androidChannelId);
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, containsAll(['night_prayer_v1', 'night_prayer_silent_v1']));
      for (final mode in [AdhanMode.notification, AdhanMode.adhanFull]) {
        final s = AdhanSoundResolver.resolveNight(mode);
        expect(s.androidChannelId, 'night_prayer_v1');
        expect(s.androidRawSound, isNull);
        expect(s.useAlarmStream, isFalse);
      }
      expect(AdhanSoundResolver.resolveNight(AdhanMode.silent).playSound, isFalse);
      expect(() => AdhanSoundResolver.resolveNight(AdhanMode.off), throwsArgumentError);
    });

    test('Time Sensitive pour le dernier tiers seulement', () {
      final third = LocalNotificationGateway.nightDetailsFor(
          NightSlot.lastThird, AdhanMode.notification);
      expect(third.iOS!.interruptionLevel, InterruptionLevel.timeSensitive);
      expect(third.android!.audioAttributesUsage, AudioAttributesUsage.notification);
      expect(third.android!.actions, isNull);

      final evening = LocalNotificationGateway.nightDetailsFor(
          NightSlot.evening, AdhanMode.notification);
      expect(evening.iOS!.interruptionLevel, InterruptionLevel.active);

      final silent = LocalNotificationGateway.nightDetailsFor(
          NightSlot.lastThird, AdhanMode.silent);
      expect(silent.android!.channelId, 'night_prayer_silent_v1');
      expect(silent.android!.playSound, isFalse);
      expect(silent.iOS!.presentSound, isFalse);
      expect(silent.iOS!.interruptionLevel, InterruptionLevel.active);
    });
  });

  group('PrayerNotificationService · prière de nuit', () {
    test('sans position : activation refusée avec la raison', () async {
      final outcome = await _service(FakeGateway()).enableNightPrayer();
      expect(outcome, EnableOutcome.noLocation);
    });

    test('activée seule (sans les 5 prières) : programmée', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final gateway = FakeGateway(permission: false);
      final outcome = await _service(gateway).enableNightPrayer();
      expect(outcome, EnableOutcome.enabled);
      expect(gateway.requests, 1);
      final settings = await PrayerSettingsRepository().readSettings();
      expect(settings.night.enabled, isTrue);
      expect(settings.prayersEnabled, isFalse);
      expect(gateway.prayers, isNotEmpty);
      expect(gateway.prayers.every((n) => n.kind == PlannedKind.night), isTrue);
    });

    test('heure du dernier tiers de ce soir dans le statut', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final status = await _service(FakeGateway()).status();
      expect(status.tonightLastThird, DateTime.utc(2026, 11, 21, 0, 50));
    });

    test('[⚠️ cache v1.3.0] sans mois hégirien : retéléchargé si Tarawih actif',
        () async {
      final store = PrayerSettingsRepository();
      await store.writeLocation(_paris);
      await store.writeCalendar(CachedCalendar(
        locationKey: _paris.cacheKey,
        methodId: null,
        methodName: 'UOIF',
        days: _days(20, hijri: (_) => null),
      ));

      // Tarawih désactivé : le cache suffit, aucun appel réseau.
      final noTarawih = const NightPrayerSettings(enabled: true)
          .withMode(NightSlot.tarawih, AdhanMode.off);
      await store.writeSettings(NotificationSettings(night: noTarawih));
      final calls = <Uri>[];
      await _service(FakeGateway(), client: _aladhan(calls: calls))
          .reschedule(force: true);
      expect(calls, isEmpty);

      // Tarawih actif : un seul téléchargement, le cache est complété.
      await store.writeSettings(_nightOnly);
      await _service(FakeGateway(), client: _aladhan(calls: calls))
          .reschedule(force: true);
      expect(calls, isNotEmpty);
      final refreshed = await store.readCalendar();
      expect(refreshed!.days.every((d) => d.hijriMonth != null), isTrue);

      calls.clear();
      await _service(FakeGateway(), client: _aladhan(calls: calls))
          .reschedule(force: true);
      expect(calls, isEmpty);
    });

    test('cache v1.3.0 hors connexion : repli sur le cache, sans Tarawih',
        () async {
      final store = PrayerSettingsRepository();
      await store.writeLocation(_paris);
      await store.writeSettings(_nightOnly);
      await store.writeCalendar(CachedCalendar(
        locationKey: _paris.cacheKey,
        methodId: null,
        methodName: 'UOIF',
        days: _days(20, hijri: (_) => null),
      ));
      final gateway = FakeGateway();
      await _service(gateway, client: _aladhan(offline: true)).reschedule(force: true);
      expect(gateway.prayers, isNotEmpty);
      expect(gateway.prayers.where((n) => n.nightSlot == NightSlot.tarawih), isEmpty);
    });
  });

  group('UI · prière de nuit', () {
    Future<FakeGateway> pump(WidgetTester tester) async {
      final gateway = FakeGateway();
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: NotificationSettingsScreen(
            service: _service(gateway),
            preview: FakePlayback(),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      return gateway;
    }

    /// Fond animé en boucle : pas de pumpAndSettle.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump();
      await tester.tap(find.text(text));
      await settle(tester);
    }

    Finder inSheet(String text) => find.descendant(
        of: find.byType(BottomSheet), matching: find.text(text));

    testWidgets('désactivée par défaut, activation puis créneaux affichés',
        (tester) async {
      final gateway = await pump(tester);
      final toggle = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('night-switch')));
      expect(toggle.value, isFalse);
      expect(find.text('Dernier tiers de la nuit'), findsNothing);

      await tapText(tester, 'Rappels de la prière de nuit');

      expect(find.text('Rappel du soir'), findsOneWidget);
      expect(find.text('Dernier tiers de la nuit'), findsOneWidget);
      expect(find.text('Tarawih (Ramadan)'), findsOneWidget);
      final tonight = DateTime.utc(2026, 11, 21, 0, 50);
      expect(find.text('Cette nuit vers ${FrenchDates.time(tonight)}'),
          findsOneWidget);
      expect(gateway.prayers.map((n) => n.nightSlot).toSet(),
          {NightSlot.evening, NightSlot.lastThird});
    });

    testWidgets('mode du dernier tiers : pas d’adhan proposé, Silencieux appliqué',
        (tester) async {
      final gateway = await pump(tester);
      await tapText(tester, 'Rappels de la prière de nuit');

      await tapText(tester, 'Dernier tiers de la nuit');
      expect(inSheet('Silencieux'), findsOneWidget);
      expect(inSheet('Adhan court'), findsNothing);
      expect(inSheet('Adhan'), findsNothing);
      await tester.tap(inSheet('Silencieux'));
      await settle(tester);

      final third = gateway.prayers.where((n) => n.nightSlot == NightSlot.lastThird);
      expect(third, isNotEmpty);
      expect(third.map((n) => n.mode).toSet(), {AdhanMode.silent});
      final saved = await tester.runAsync(PrayerSettingsRepository().readSettings);
      expect(saved!.night.lastThird, AdhanMode.silent);
    });

    testWidgets('garde-fou et délai du soir réglables', (tester) async {
      final gateway = await pump(tester);
      await tapText(tester, 'Rappels de la prière de nuit');

      await tapText(tester, 'Isha + 2 h');
      expect(
        gateway.prayers.firstWhere((n) => n.nightSlot == NightSlot.evening).when,
        DateTime.utc(2026, 11, 20, 20),
      );
      await tapText(tester, '45 min');
      final saved = await tester.runAsync(PrayerSettingsRepository().readSettings);
      expect(saved!.night.fajrMarginMinutes, 45);
      expect(saved.night.eveningDelayHours, 2);
    });

    testWidgets('désactiver : plus aucune notification de nuit', (tester) async {
      final gateway = await pump(tester);
      await tapText(tester, 'Rappels de la prière de nuit');
      expect(gateway.prayers, isNotEmpty);
      await tapText(tester, 'Rappels de la prière de nuit');
      expect(gateway.prayers, isEmpty);
    });
  });
}
