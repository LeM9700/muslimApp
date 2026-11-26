import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/fasting.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/models/shawwal_progress.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/fasting_screen.dart';
import 'package:muslim_app/services/calendar_preferences.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gateway.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

Map<String, dynamic> _apiDay(DateTime d) {
  String at(int h) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}T${_pad(h)}:00:00+01:00';
  return {
    'timings': {
      'Fajr': at(6),
      'Dhuhr': at(12),
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

/// 1 Chawwal 1447 = vendredi 20 mars 2026 (Aïd) ; le 25 mars = 6 Chawwal.
PrayerNotificationService _service(FakeGateway gateway, DateTime now) =>
    PrayerNotificationService(
      store: PrayerSettingsRepository(),
      aladhan: AladhanRepository(client: _aladhan()),
      gateway: gateway,
      widget: FakeWidgetGateway(),
      clock: () => now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ShawwalProgress', () {
    test('cocher, décocher, objectif de 6', () {
      var p = const ShawwalProgress(hijriYear: 1447);
      for (var d = 21; d <= 26; d++) {
        p = p.toggle('2026-03-$d');
      }
      expect(p.count, 6);
      expect(p.isComplete, isTrue);
      p = p.toggle('2026-03-21');
      expect(p.count, 5);
      expect(p.isComplete, isFalse);
    });

    test('[🔒] lecture défensive', () {
      expect(ShawwalProgress.fromJson(null), isNull);
      expect(ShawwalProgress.fromJson({'hijriYear': 'x'}), isNull);
      final p = ShawwalProgress.fromJson({
        'hijriYear': 1447,
        'days': ['2026-03-21', 42, 'pas une date'],
      })!;
      expect(p.days, {'2026-03-21'});
    });
  });

  group('Service', () {
    test('6 jours cochés : le rappel de mi-Chawwal disparaît', () async {
      final store = PrayerSettingsRepository();
      await store.writeLocation(_paris);
      await store.writeSettings(
          const NotificationSettings(fasting: FastingSettings(enabled: true)));
      final gateway = FakeGateway();
      final service = _service(gateway, DateTime.utc(2026, 3, 27, 8));
      await service.reschedule(force: true);
      bool midShawwal() => gateway.prayers.any((n) => n.fastKind == FastKind.shawwal);
      expect(midShawwal(), isTrue, reason: 'veille du 15 Chawwal (2 avril)');

      for (var d = 21; d <= 26; d++) {
        await service.toggleShawwalDay(DateTime(2026, 3, d));
      }
      expect((await service.shawwalProgress())!.isComplete, isTrue);
      expect(midShawwal(), isFalse, reason: 'reprogrammé à l’objectif atteint');
      // Le 15 Chawwal reste un jour blanc : ce rappel-là est conservé.
      expect(
          gateway.prayers.any((n) =>
              n.fastKind == FastKind.whiteDays &&
              n.when == DateTime.utc(2026, 4, 2, 18, 30)),
          isTrue);
    });

    test('Aïd ou hors Chawwal : refusé ; nouvelle année : suivi remis à zéro',
        () async {
      final service = _service(FakeGateway(), DateTime.utc(2026, 3, 25));
      expect(() => service.toggleShawwalDay(DateTime(2026, 3, 20)),
          throwsArgumentError, reason: 'Aïd al-Fitr');
      expect(() => service.toggleShawwalDay(DateTime(2026, 5, 1)), throwsArgumentError);

      await PrayerSettingsRepository().writeShawwal(
          const ShawwalProgress(hijriYear: 1446, days: {'2025-04-01'}));
      final p = await service.toggleShawwalDay(DateTime(2026, 3, 21));
      expect(p.hijriYear, 1447);
      expect(p.days, {'2026-03-21'});
    });
  });

  test('planificateur : année complète → plus de rappel de Chawwal', () {
    final plan = PrayerNotificationPlanner.plan(
      days: _days(DateTime(2026, 3, 30), 5),
      settings: const NotificationSettings(fasting: FastingSettings(enabled: true)),
      shawwalCompletedYears: const {1447},
      now: DateTime.utc(2026, 3, 30),
      cityName: 'Paris',
    );
    expect(plan.notifications.where((n) => n.fastKind == FastKind.shawwal), isEmpty);
    expect(plan.notifications.map((n) => n.title), contains('Demain : Jour blanc'));
  });

  group('UI', () {
    Future<void> pump(WidgetTester tester, DateTime today) async {
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: FastingScreen(
            service: _service(FakeGateway(), today.toUtc()),
            calendar: CalendarPreferences(),
            clock: () => today,
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    testWidgets('pendant Chawwal : cocher un jour fait avancer le compteur',
        (tester) async {
      await pump(tester, DateTime(2026, 3, 25, 10));
      expect(find.text('6 jours de Chawwal'), findsOneWidget);
      expect(find.text('0 / 6'), findsOneWidget);
      for (var d = 2; d <= 6; d++) {
        expect(find.text('$d Chawwal'), findsOneWidget);
      }
      await tester.tap(find.text('2 Chawwal'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1 / 6'), findsOneWidget);
    });

    testWidgets('jour de l’Aïd : message, aucun jour à cocher', (tester) async {
      await pump(tester, DateTime(2026, 3, 20, 10));
      expect(find.textContaining('Aïd moubarak'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('hors Chawwal : pas de panneau', (tester) async {
      await pump(tester, DateTime(2026, 5, 20, 10));
      expect(find.text('6 jours de Chawwal'), findsNothing);
    });
  });
}
