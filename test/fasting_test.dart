import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/calendar_settings.dart';
import 'package:muslim_app/models/fasting.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/fasting_screen.dart';
import 'package:muslim_app/services/adhan_sound_resolver.dart';
import 'package:muslim_app/services/calendar_preferences.dart';
import 'package:muslim_app/services/fast_calendar.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/notification_router.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:muslim_app/utils/relative_days.dart';
import 'package:muslim_app/widgets/next_fast_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gateway.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

/// Jour synthétique (UTC+1) : Isha à 19:00, soit 18:00 UTC.
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
      'data': [for (var i = 0; i < count; i++) _apiDay(DateTime(from.year, from.month, from.day + i))],
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

FastDay? _on(int y, int m, int d, {int adjustment = 0, Set<FastKind>? kinds}) =>
    FastCalendar.on(DateTime(y, m, d), adjustment: adjustment, kinds: kinds);

const _enabled = NotificationSettings(fasting: FastingSettings(enabled: true));
const _allKinds = NotificationSettings(
  fasting: FastingSettings(enabled: true, kinds: {...FastKind.values}),
);

PrayerPlan _plan(List<PrayerDay> days, NotificationSettings settings,
        {DateTime? now, CalendarSettings calendar = const CalendarSettings()}) =>
    PrayerNotificationPlanner.plan(
      days: days,
      settings: settings,
      calendar: calendar,
      now: now ?? DateTime.utc(days.first.times[Prayer.fajr]!.year,
          days.first.times[Prayer.fajr]!.month, days.first.times[Prayer.fajr]!.day),
      cityName: 'Paris',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FastCalendar (dates réelles, Umm al-Qura)', () {
    test('Arafat 1447 : mardi 26 mai 2026', () {
      final arafat = _on(2026, 5, 26)!;
      expect(arafat.kinds, [FastKind.arafat]);
      expect(arafat.title, 'Jour d’Arafat');
      expect(arafat.hijri.month, 12);
      expect(arafat.hijri.day, 9);
    });

    test('[⚠️] jours interdits : Aïd et Tachriq, même un jeudi ou un « 13 »',
        () {
      expect(_on(2026, 5, 27), isNull, reason: 'Aïd al-Adha');
      expect(_on(2026, 5, 28), isNull, reason: 'Tachriq, jeudi et 11 Dhou al-hijja');
      expect(_on(2026, 5, 30), isNull, reason: '13 Dhou al-hijja : pas un jour blanc');
      expect(_on(2026, 3, 20), isNull, reason: 'Aïd al-Fitr');
      final h = FastCalendar.on(DateTime(2026, 5, 31))!.hijri;
      expect(FastCalendar.isForbidden(h), isFalse);
    });

    test('jours blancs ; un jour blanc qui est aussi un lundi', () {
      expect(_on(2026, 5, 31)!.kinds, [FastKind.whiteDays], reason: '14 Dhou al-hijja');
      final monday = _on(2026, 6, 1)!;
      expect(monday.kinds, [FastKind.whiteDays, FastKind.mondayThursday]);
      expect(monday.title, 'Jour blanc');
    });

    test('Tasu‘a et Achoura 1448 : 24 et 25 juin 2026', () {
      expect(_on(2026, 6, 24)!.title, 'Tasu‘a');
      final ashura = _on(2026, 6, 25)!;
      expect(ashura.title, 'Achoura');
      expect(ashura.kinds, [FastKind.ashura, FastKind.mondayThursday]);
    });

    test('Ramadan : seul le 1er jour, pas de lundi/jeudi ni de jours blancs', () {
      expect(_on(2026, 2, 18)!.kinds, [FastKind.ramadanStart]);
      expect(_on(2026, 2, 19), isNull, reason: 'jeudi en Ramadan');
      expect(_on(2026, 3, 2), isNull, reason: '13 Ramadan, un lundi');
    });

    test('6 jours de Chawwal : le 2 puis rappel à mi-mois', () {
      expect(_on(2026, 3, 21)!.title, 'Début des 6 jours de Chawwal');
      final mid = _on(2026, 4, 3)!;
      expect(mid.kinds, [FastKind.shawwal, FastKind.whiteDays]);
      expect(mid.title, '6 jours de Chawwal : mi-mois');
    });

    test('ajustement +1 : tout se décale d’un jour, Aïd compris', () {
      expect(_on(2026, 5, 26, adjustment: 1), isNull, reason: '8 Dhou al-hijja');
      expect(_on(2026, 5, 27, adjustment: 1)!.mainKind, FastKind.arafat);
      expect(_on(2026, 5, 28, adjustment: 1), isNull, reason: 'Aïd décalé');
    });

    test('filtre par type, liste ordonnée et prochain jeûne', () {
      final arafatOnly = FastCalendar.upcoming(DateTime(2026, 5, 1),
          days: 60, kinds: {FastKind.arafat});
      expect(arafatOnly.map((d) => d.date), [DateTime(2026, 5, 26)]);
      final all = FastCalendar.upcoming(DateTime(2026, 5, 20), days: 30);
      for (var i = 1; i < all.length; i++) {
        expect(all[i].date.isAfter(all[i - 1].date), isTrue);
      }
      expect(FastCalendar.next(DateTime(2026, 5, 20),
              kinds: FastingSettings.defaultKinds)!
          .date, DateTime(2026, 5, 26));
    });

    test('libellés relatifs', () {
      final today = DateTime(2026, 5, 20);
      expect(relativeDays(today, DateTime(2026, 5, 20)), 'Aujourd’hui');
      expect(relativeDays(today, DateTime(2026, 5, 21)), 'Demain');
      expect(relativeDays(today, DateTime(2026, 5, 26)), 'Dans 6 jours');
    });
  });

  group('FastingSettings', () {
    test('par défaut : désactivé, tout sauf lundi et jeudi', () {
      const s = NotificationSettings();
      expect(s.fasting.enabled, isFalse);
      expect(s.fasting.isActive, isFalse);
      expect(s.fasting.kinds, isNot(contains(FastKind.mondayThursday)));
      expect(s.fasting.kinds, hasLength(5));
    });

    test('[⚠️ migration] réglages v1.3.0 sans clé fasting → désactivé', () {
      final s = NotificationSettings.fromJson({
        'prayersEnabled': true,
        'modes': {'fajr': 'adhanFull'},
      });
      expect(s.fasting.enabled, isFalse);
      expect(s.fasting.kinds, FastingSettings.defaultKinds);
    });

    test('aller-retour JSON, types inconnus ignorés', () {
      final s = const FastingSettings(enabled: true)
          .toggle(FastKind.mondayThursday, true)
          .toggle(FastKind.whiteDays, false);
      final back = NotificationSettings.fromJson(
          json.decode(json.encode(NotificationSettings(fasting: s).toJson()))
              as Map<String, dynamic>);
      expect(back.fasting.toJson(), s.toJson());
      final future = FastingSettings.fromJson({
        'enabled': true,
        'kinds': ['arafat', 'jour_futur'],
      });
      expect(future.kinds, {FastKind.arafat});
    });
  });

  group('Planificateur · rappels de jeûne', () {
    test('la veille, 30 min après l’Isha, avec la référence', () {
      final plan = _plan(_days(DateTime(2026, 5, 24), 5), _enabled);
      final fasts = plan.notifications.where((n) => n.kind == PlannedKind.fast).toList();
      expect(fasts, hasLength(1), reason: 'Arafat seulement (Aïd, Tachriq exclus)');
      final arafat = fasts.single;
      expect(arafat.when, DateTime.utc(2026, 5, 25, 18, 30));
      expect(arafat.title, 'Demain : Jour d’Arafat');
      expect(arafat.body, contains('Muslim 1162'));
      expect(arafat.payload, 'fast:arafat');
      expect(arafat.fastKind, FastKind.arafat);
    });

    test('lundi/jeudi activé : jamais la veille d’un jour de Tachriq', () {
      final plan = _plan(_days(DateTime(2026, 5, 24), 5), _allKinds);
      final eves = plan.notifications
          .where((n) => n.kind == PlannedKind.fast)
          .map((n) => n.when.day)
          .toList();
      expect(eves, isNot(contains(27)), reason: 'veille du jeudi 28 (Tachriq)');
    });

    test('veille du Ramadan et mi-Chawwal : textes dédiés', () {
      final ramadan = _plan(_days(DateTime(2026, 2, 16), 3), _enabled)
          .notifications
          .singleWhere((n) => n.kind == PlannedKind.fast);
      expect(ramadan.title, 'Le Ramadan commence demain');
      expect(ramadan.when, DateTime.utc(2026, 2, 17, 18, 30));

      final april = _plan(_days(DateTime(2026, 4, 1), 3), _enabled)
          .notifications
          .where((n) => n.kind == PlannedKind.fast)
          .toList();
      // Veille du 14 Chawwal (jour blanc), puis du 15 (mi-Chawwal).
      expect(april.first.title, 'Demain : Jour blanc');
      expect(april.first.body,
          'Le Prophète ﷺ recommandait de jeûner les 13, 14 et 15 du mois '
          '(Tirmidhi 761). Pensez à l’intention et au sahour.');
      final mid = april.singleWhere((n) => n.fastKind == FastKind.shawwal);
      expect(mid.body, startsWith('Il reste la moitié du mois'));
    });

    test('désactivé ou ajustement +1', () {
      final days = _days(DateTime(2026, 5, 24), 5);
      expect(_plan(days, const NotificationSettings()).notifications, isEmpty);
      final shifted = _plan(days, _enabled,
              calendar: const CalendarSettings(hijriAdjustment: 1))
          .notifications
          .where((n) => n.kind == PlannedKind.fast);
      expect(shifted.single.when, DateTime.utc(2026, 5, 26, 18, 30));
    });
  });

  group('Payload, canal et routeur', () {
    test('[🔒] FastPayload défensif, formats existants inchangés', () {
      expect(FastPayload.decode('fast:arafat')!.kind, FastKind.arafat);
      for (final raw in [null, '', 'fast', 'fast:', 'fast:x', 'fast:arafat:1', 'prayer:fajr']) {
        expect(FastPayload.decode(raw), isNull, reason: '$raw');
      }
      expect(NotificationPayload.decode('fast:arafat'), isNull);
      expect(NightPayload.decode('fast:arafat'), isNull);
    });

    test('canal Android dédié, notification non urgente', () {
      final ids = AdhanSoundResolver.channels.map((s) => s.androidChannelId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, contains('fasting_v1'));
      final d = LocalNotificationGateway.fastDetails();
      expect(d.android!.channelId, 'fasting_v1');
      expect(d.android!.actions, isNull);
    });

    testWidgets('tap sur un rappel de jeûne : ouvre l’écran Jeûnes',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
      var fasting = 0;
      var player = 0;
      final router = NotificationRouter(
        navigatorKey: key,
        openPlayer: (_, __) => player++,
        openFasting: (_) => fasting++,
      );
      expect(router.handle('fast:ashura'), isTrue);
      expect(router.handle('night:lastThird:notification'), isFalse);
      expect(router.handle('prayer:asr:notification'), isFalse);
      expect([fasting, player], [1, 0]);
    });
  });

  group('Service', () {
    PrayerNotificationService service(FakeGateway gateway, DateTime now) =>
        PrayerNotificationService(
          store: PrayerSettingsRepository(),
          aladhan: AladhanRepository(client: _aladhan()),
          gateway: gateway,
          widget: FakeWidgetGateway(),
          clock: () => now,
        );

    test('sans position : refus avec la raison', () async {
      final outcome =
          await service(FakeGateway(), DateTime.utc(2026, 5, 20, 8)).enableFasting();
      expect(outcome, EnableOutcome.noLocation);
    });

    test('activation : autorisation demandée puis rappel d’Arafat programmé',
        () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final gateway = FakeGateway(permission: false);
      final outcome = await service(gateway, DateTime.utc(2026, 5, 20, 8)).enableFasting();
      expect(outcome, EnableOutcome.enabled);
      expect(gateway.requests, 1);
      final fasts = gateway.prayers.where((n) => n.kind == PlannedKind.fast);
      expect(fasts.map((n) => n.fastKind), contains(FastKind.arafat));
    });
  });

  group('UI', () {
    final may20 = DateTime(2026, 5, 20, 10);

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('carte de l’accueil : prochain jeûne et ouverture', (tester) async {
      var opened = 0;
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: NextFastCard(
              preferences: CalendarPreferences(),
              clock: () => may20,
              onOpen: () => opened++,
            ),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.text('Prochain jeûne'), findsOneWidget);
      expect(find.text('Jour d’Arafat'), findsOneWidget);
      expect(find.text('Dans 6 jours'), findsOneWidget);
      expect(find.text('mardi 26 mai 2026'), findsOneWidget);
      await tester.tap(find.text('Jour d’Arafat'));
      expect(opened, 1);
    });

    testWidgets('écran Jeûnes : liste, activation et choix des types',
        (tester) async {
      final gateway = FakeGateway();
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: FastingScreen(
            service: PrayerNotificationService(
              store: PrayerSettingsRepository(),
              aladhan: AladhanRepository(client: _aladhan()),
              gateway: gateway,
              widget: FakeWidgetGateway(),
              clock: () => may20.toUtc(),
            ),
            calendar: CalendarPreferences(),
            clock: () => may20,
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Me rappeler la veille'), findsOneWidget);
      expect(find.text('Jour d’Arafat'), findsOneWidget);
      expect(find.text('Dans 6 jours'), findsOneWidget);
      expect(find.byKey(const ValueKey('fasting-kind-arafat')), findsNothing);

      await tester.tap(find.text('Me rappeler la veille'));
      await settle(tester);
      expect(find.byKey(const ValueKey('fasting-kind-arafat')), findsOneWidget);
      expect(gateway.prayers.where((n) => n.kind == PlannedKind.fast), isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('fasting-kind-mondayThursday')));
      await settle(tester);
      final saved = await tester.runAsync(PrayerSettingsRepository().readSettings);
      expect(saved!.fasting.enabled, isTrue);
      expect(saved.fasting.kinds, contains(FastKind.mondayThursday));
    });
  });
}
