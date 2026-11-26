import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/friday_reminders.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/notification_settings_screen.dart';
import 'package:muslim_app/services/adhan_sound_resolver.dart';
import 'package:muslim_app/services/calendar_preferences.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/notification_router.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gateway.dart';
import 'support/fake_playback.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

/// Jour synthétique (UTC+1) : Dhuhr à 12:30, soit 11:30 UTC.
Map<String, dynamic> _apiDay(DateTime d) {
  String at(int h, [int m = 0]) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}T${_pad(h)}:${_pad(m)}:00+01:00';
  return {
    'timings': {
      'Fajr': at(6),
      'Dhuhr': at(12, 30),
      'Asr': at(15),
      'Maghrib': at(17),
      'Isha': at(19),
    },
    'date': {
      'gregorian': {'date': '${_pad(d.day)}-${_pad(d.month)}-${d.year}'},
    },
  };
}

List<PrayerDay> _days(DateTime from, int count) => AladhanRepository.parseMonth({
      'code': 200,
      'data': [
        for (var i = 0; i < count; i++)
          _apiDay(DateTime(from.year, from.month, from.day + i)),
      ],
    }).days;

MockClient _aladhan() => MockClient((request) async {
      final segments = request.url.pathSegments;
      final year = int.parse(segments[segments.length - 2]);
      final month = int.parse(segments.last);
      final count = DateTime(year, month + 1, 0).day;
      return http.Response.bytes(
        utf8.encode(json.encode({
          'code': 200,
          'data': [for (var d = 1; d <= count; d++) _apiDay(DateTime(year, month, d))],
        })),
        200,
      );
    });

/// Jeudi 19 novembre 2026, 08:00 UTC : la veille du vendredi 20.
final _thursday = DateTime.utc(2026, 11, 19, 8);

PrayerNotificationService _service(FakeGateway gateway) => PrayerNotificationService(
      store: PrayerSettingsRepository(),
      aladhan: AladhanRepository(client: _aladhan()),
      gateway: gateway,
      widget: FakeWidgetGateway(),
      clock: () => _thursday,
    );

PrayerPlan _plan(FridaySettings friday) => PrayerNotificationPlanner.plan(
      days: _days(DateTime(2026, 11, 19), 9),
      settings: NotificationSettings(friday: friday),
      now: _thursday,
      cityName: 'Paris',
      formatTime: (t) => '${_pad(t.hour)}:${_pad(t.minute)}',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FridaySettings', () {
    test('désactivés par défaut ; [⚠️ migration] réglages v1.3.0', () {
      expect(const NotificationSettings().friday.isActive, isFalse);
      final v13 = NotificationSettings.fromJson({'prayersEnabled': true});
      expect(v13.friday.isActive, isFalse);
    });

    test('aller-retour JSON, valeurs inconnues ignorées', () {
      final s = const FridaySettings().toggle(FridayReminder.kahf, true);
      final back = NotificationSettings.fromJson(
          json.decode(json.encode(NotificationSettings(friday: s).toJson()))
              as Map<String, dynamic>);
      expect(back.friday.enabled, {FridayReminder.kahf});
      expect(FridaySettings.fromJson(['jumua', 'futur']).enabled,
          {FridayReminder.jumua});
      expect(FridaySettings.fromJson('x').isActive, isFalse);
      expect(back.needsCalendar, isTrue);
    });
  });

  group('Planificateur', () {
    test('al-Kahf à 9 h (heure locale) chaque vendredi, rien les autres jours',
        () {
      final plan = _plan(const FridaySettings(enabled: {FridayReminder.kahf}));
      final kahf = plan.notifications;
      // Vendredis du 20 et du 27 novembre.
      expect(kahf.map((n) => n.when), [
        DateTime(2026, 11, 20, 9).toUtc(),
        DateTime(2026, 11, 27, 9).toUtc(),
      ]);
      expect(kahf.first.kind, PlannedKind.friday);
      expect(kahf.first.title, 'Vendredi : sourate al-Kahf');
      expect(kahf.first.payload, 'friday:kahf');
    });

    test('Jumu‘a 45 min avant le Dhuhr, avec l’heure du Dhuhr', () {
      final plan = _plan(const FridaySettings(enabled: {FridayReminder.jumua}));
      final jumua = plan.notifications.first;
      expect(jumua.when, DateTime.utc(2026, 11, 20, 10, 45));
      expect(jumua.title, 'Jumu‘a dans 45 min');
      expect(jumua.body, startsWith('Dhuhr à 11:30.'));
      expect(jumua.body, contains('Bukhari 883'));
      expect(jumua.payload, 'friday:jumua');
      expect(plan.notifications, hasLength(2));
    });

    test('désactivé : aucun rappel', () {
      expect(_plan(const FridaySettings()).notifications, isEmpty);
    });
  });

  group('Payload, canal et routeur', () {
    test('[🔒] FridayPayload défensif', () {
      expect(FridayPayload.decode('friday:kahf')!.reminder, FridayReminder.kahf);
      for (final raw in [null, '', 'friday', 'friday:x', 'friday:kahf:1', 'fast:arafat']) {
        expect(FridayPayload.decode(raw), isNull, reason: '$raw');
      }
      expect(FastPayload.decode('friday:kahf'), isNull);
    });

    test('canal Android dédié', () {
      final ids = AdhanSoundResolver.channels.map((s) => s.androidChannelId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(LocalNotificationGateway.fridayDetails().android!.channelId, 'friday_v1');
    });

    testWidgets('tap : al-Kahf ouvre la sourate, la Jumu‘a ouvre l’app',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
      var kahf = 0;
      var fasting = 0;
      final router = NotificationRouter(
        navigatorKey: key,
        openKahf: (_) => kahf++,
        openFasting: (_) => fasting++,
        openPlayer: (_, __) {},
      );
      expect(router.handle('friday:kahf'), isTrue);
      expect(router.handle('friday:jumua'), isFalse);
      expect([kahf, fasting], [1, 0]);
    });
  });

  group('Service et écran', () {
    test('sans position : refus avec la raison', () async {
      expect(await _service(FakeGateway()).enableFriday(FridayReminder.kahf),
          EnableOutcome.noLocation);
    });

    testWidgets('activer al-Kahf depuis Notifications : programmé', (tester) async {
      final gateway = FakeGateway(permission: false);
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: NotificationSettingsScreen(
            service: _service(gateway),
            preview: FakePlayback(),
            calendar: CalendarPreferences(),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Sourate al-Kahf'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Sourate al-Kahf'));
      await tester.pump();
      await tester.tap(find.text('Sourate al-Kahf'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(gateway.requests, 1, reason: 'autorisation demandée au geste');
      expect(gateway.prayers.where((n) => n.fridayReminder == FridayReminder.kahf),
          isNotEmpty);
      final saved = await tester.runAsync(PrayerSettingsRepository().readSettings);
      expect(saved!.friday.has(FridayReminder.kahf), isTrue);
    });
  });
}
