import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/calendar_settings.dart';
import 'package:muslim_app/models/hijri_date.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/notification_settings_screen.dart';
import 'package:muslim_app/services/calendar_preferences.dart';
import 'package:muslim_app/services/hijri_converter.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:muslim_app/utils/french_dates.dart';
import 'package:muslim_app/widgets/today_date_label.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gateway.dart';
import 'support/fake_playback.dart';

/// Débuts de mois du calendrier Umm al-Qura relevés sur Aladhan
/// (`/gToHCalendar?calendarMethod=UAQ`) : [date grégorienne, année, mois].
/// La conversion locale a aussi été comparée jour par jour sur ces deux
/// années (730 jours, 0 écart).
const _monthStarts = [
  ['2026-01-20', 1447, 8],
  ['2026-02-18', 1447, 9],
  ['2026-03-20', 1447, 10],
  ['2026-04-18', 1447, 11],
  ['2026-05-18', 1447, 12],
  ['2026-06-16', 1448, 1],
  ['2026-07-15', 1448, 2],
  ['2026-08-14', 1448, 3],
  ['2026-09-12', 1448, 4],
  ['2026-10-12', 1448, 5],
  ['2026-11-11', 1448, 6],
  ['2026-12-10', 1448, 7],
  ['2027-01-09', 1448, 8],
  ['2027-02-08', 1448, 9],
  ['2027-03-09', 1448, 10],
  ['2027-04-08', 1448, 11],
  ['2027-05-07', 1448, 12],
  ['2027-06-06', 1449, 1],
  ['2027-07-05', 1449, 2],
  ['2027-08-03', 1449, 3],
  ['2027-09-02', 1449, 4],
  ['2027-10-01', 1449, 5],
  ['2027-10-31', 1449, 6],
  ['2027-11-29', 1449, 7],
  ['2027-12-29', 1449, 8],
];

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

MockClient _aladhan() => MockClient((request) async {
      final segments = request.url.pathSegments;
      final year = int.parse(segments[segments.length - 2]);
      final month = int.parse(segments.last);
      final count = DateTime(year, month + 1, 0).day;
      String at(int d, int h) =>
          '$year-${_pad(month)}-${_pad(d)}T${_pad(h)}:00:00+01:00';
      return http.Response.bytes(
        utf8.encode(json.encode({
          'code': 200,
          'data': [
            for (var d = 1; d <= count; d++)
              {
                'timings': {
                  'Fajr': at(d, 6),
                  'Dhuhr': at(d, 12),
                  'Asr': at(d, 15),
                  'Maghrib': at(d, 17),
                  'Isha': at(d, 19),
                },
                'date': {
                  'gregorian': {'date': '${_pad(d)}-${_pad(month)}-$year'},
                },
              },
          ],
        })),
        200,
      );
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HijriConverter', () {
    test('identique au calendrier Umm al-Qura d’Aladhan (2026–2027)', () {
      for (final start in _monthStarts) {
        final date = DateTime.parse(start[0] as String);
        final h = HijriConverter.fromCivil(date)!;
        expect([h.year, h.month, h.day], [start[1], start[2], 1],
            reason: '${start[0]}');
        final eve = HijriConverter.fromCivil(date.subtract(const Duration(days: 1)))!;
        expect(eve.day, anyOf(29, 30), reason: 'veille de ${start[0]}');
      }
    });

    test('ajustement : +1 = les mois commencent un jour plus tard', () {
      final feb18 = DateTime(2026, 2, 18);
      expect(HijriConverter.fromCivil(feb18), const HijriDate(1447, 9, 1));
      expect(HijriConverter.fromCivil(feb18, adjustment: 1),
          const HijriDate(1447, 8, 29));
      expect(HijriConverter.fromCivil(DateTime(2026, 2, 19), adjustment: 1),
          const HijriDate(1447, 9, 1));
      expect(HijriConverter.fromCivil(DateTime(2026, 2, 17), adjustment: -1),
          const HijriDate(1447, 9, 1));
    });

    test('seule la date civile compte, pas l’heure ni le fuseau', () {
      expect(HijriConverter.fromCivil(DateTime(2026, 2, 18, 23, 59)),
          HijriConverter.fromCivil(DateTime.utc(2026, 2, 18)));
      expect(HijriConverter.fromDateKey('2026-02-18'), const HijriDate(1447, 9, 1));
      expect(HijriConverter.fromDateKey('n’importe quoi'), isNull);
    });

    test('hors de la table Umm al-Qura : null, jamais d’exception', () {
      expect(HijriConverter.fromCivil(DateTime(2150, 1, 1)), isNull);
      expect(HijriConverter.fromCivil(DateTime(1900, 1, 1)), isNull);
    });
  });

  group('Libellés de date', () {
    test('noms des mois en français, « 1er » le premier jour', () {
      expect(const HijriDate(1447, 9, 1).label, '1er Ramadan 1447');
      expect(const HijriDate(1448, 6, 16).label, '16 Joumada ath-thania 1448');
      expect(HijriDate.monthNames, hasLength(12));
      expect(FrenchDates.fullDate(DateTime(2026, 11, 26)), 'jeudi 26 novembre 2026');
      expect(FrenchDates.fullDate(DateTime(2026, 12, 1)), 'mardi 1er décembre 2026');
    });

    test('ordre selon le calendrier préféré', () {
      final day = DateTime(2026, 11, 26);
      final g = DateLabels.of(day, const CalendarSettings());
      expect(g.primary, 'jeudi 26 novembre 2026');
      expect(g.secondary, '16 Joumada ath-thania 1448');
      final h = DateLabels.of(
          day, const CalendarSettings(primary: DateCalendar.hijri));
      expect(h.primary, '16 Joumada ath-thania 1448');
      expect(h.secondary, 'jeudi 26 novembre 2026');
      final adjusted = DateLabels.of(day,
          const CalendarSettings(primary: DateCalendar.hijri, hijriAdjustment: 1));
      expect(adjusted.primary, '15 Joumada ath-thania 1448');
    });

    test('dans une phrase (« jusqu’au … »)', () {
      final instant = DateTime(2026, 12, 1, 12);
      expect(DateLabels.inSentence(instant, const CalendarSettings()),
          'mardi 1er décembre');
      expect(
          DateLabels.inSentence(
              instant, const CalendarSettings(primary: DateCalendar.hijri)),
          '21 Joumada ath-thania 1448');
    });
  });

  group('CalendarSettings', () {
    test('par défaut : grégorien, sans ajustement ; aller-retour JSON', () {
      const s = CalendarSettings();
      expect(s.primary, DateCalendar.gregorian);
      expect(s.hijriAdjustment, 0);
      const custom = CalendarSettings(primary: DateCalendar.hijri, hijriAdjustment: -1);
      final back = CalendarSettings.fromJson(
          json.decode(json.encode(custom.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), custom.toJson());
    });

    test('[🔒] valeurs inattendues → défauts', () {
      final s = CalendarSettings.fromJson({'primary': 'julian', 'hijriAdjustment': 9});
      expect(s.primary, DateCalendar.gregorian);
      expect(s.hijriAdjustment, 0);
      expect(CalendarSettings.fromJson(null).primary, DateCalendar.gregorian);
      expect(CalendarSettings.fromJson('x').hijriAdjustment, 0);
    });

    test('stockage : absent = défauts, puis relu tel quel', () async {
      final store = PrayerSettingsRepository();
      expect((await store.readCalendarSettings()).primary, DateCalendar.gregorian);
      await store.writeCalendarSettings(
          const CalendarSettings(primary: DateCalendar.hijri, hijriAdjustment: 1));
      final read = await store.readCalendarSettings();
      expect(read.primary, DateCalendar.hijri);
      expect(read.hijriAdjustment, 1);
    });
  });

  group('UI · calendrier', () {
    testWidgets('accueil : date du jour dans le calendrier préféré',
        (tester) async {
      final prefs = CalendarPreferences();
      final clock = DateTime(2026, 2, 18, 10);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: TodayDateLabel(preferences: prefs, clock: () => clock)),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.text('mercredi 18 février 2026'), findsOneWidget);
      expect(find.text('1er Ramadan 1447'), findsOneWidget);

      // Un changement fait ailleurs (écran Notifications) se voit ici.
      await tester.runAsync(() => prefs.update(
          const CalendarSettings(primary: DateCalendar.hijri, hijriAdjustment: 1)));
      await tester.pump();
      expect(find.text('29 Cha‘bane 1447'), findsOneWidget);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(texts.indexOf('29 Cha‘bane 1447') < texts.indexOf('mercredi 18 février 2026'),
          isTrue, reason: 'hégirien en premier');
    });

    Future<(FakeGateway, CalendarPreferences)> pumpScreen(WidgetTester tester) async {
      final gateway = FakeGateway();
      final prefs = CalendarPreferences();
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: NotificationSettingsScreen(
            service: PrayerNotificationService(
              store: PrayerSettingsRepository(),
              aladhan: AladhanRepository(client: _aladhan()),
              gateway: gateway,
              clock: () => DateTime.utc(2026, 11, 20, 8),
            ),
            preview: FakePlayback(),
            calendar: prefs,
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      return (gateway, prefs);
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump();
      await tester.tap(find.text(text));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('écran Notifications : choix du calendrier et ajustement',
        (tester) async {
      final (gateway, prefs) = await pumpScreen(tester);
      final today = DateLabels.of(DateTime.now(), const CalendarSettings());
      expect(find.text(today.primary), findsOneWidget);
      expect(find.text(today.secondary), findsOneWidget);

      await tapText(tester, 'Hégirien');
      expect(prefs.settings.primary, DateCalendar.hijri);
      final primary = tester.widget<Text>(find.byKey(const ValueKey('calendar-primary')));
      expect(primary.data, today.secondary);

      await tapText(tester, '+1 j');
      final saved = await tester.runAsync(PrayerSettingsRepository().readCalendarSettings);
      expect(saved!.hijriAdjustment, 1);
      expect(saved.primary, DateCalendar.hijri);
      expect(gateway.daily, isNotEmpty, reason: 'reprogrammé après le changement');
      final adjusted = DateLabels.of(DateTime.now(), saved);
      expect(tester.widget<Text>(find.byKey(const ValueKey('calendar-primary'))).data,
          adjusted.primary);
    });
  });
}
