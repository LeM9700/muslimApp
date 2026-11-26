import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/screens/notification_settings_screen.dart';
import 'package:muslim_app/services/calendar_preferences.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:muslim_app/services/prayer_timeline_builder.dart';
import 'package:muslim_app/services/prayer_widget_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_gateway.dart';
import 'support/fake_playback.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

String _pad(int n) => n.toString().padLeft(2, '0');

/// Jour synthétique (UTC+1) : Fajr 06:00, Dhuhr 12:30, Asr 15:00,
/// Maghrib 17:30, Isha 19:00 → en UTC : 05:00, 11:30, 14:00, 16:30, 18:00.
Map<String, dynamic> _apiDay(DateTime d) {
  String at(int h, int m) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}T${_pad(h)}:${_pad(m)}:00+01:00';
  return {
    'timings': {
      'Fajr': at(6, 0),
      'Dhuhr': at(12, 30),
      'Asr': at(15, 0),
      'Maghrib': at(17, 30),
      'Isha': at(19, 0),
    },
    'date': {
      'gregorian': {'date': '${_pad(d.day)}-${_pad(d.month)}-${d.year}'},
    },
  };
}

List<PrayerDay> _days(int count, {DateTime? from}) {
  final start = from ?? DateTime(2026, 11, 20);
  return AladhanRepository.parseMonth({
    'code': 200,
    'data': [for (var i = 0; i < count; i++) _apiDay(start.add(Duration(days: i)))],
  }).days;
}

MockClient _aladhan({bool offline = false}) => MockClient((request) async {
      if (offline) throw http.ClientException('offline');
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

/// 20 novembre 2026, 08:00 UTC (09:00 à Paris).
final _now = DateTime.utc(2026, 11, 20, 8);

PrayerTimeline _build(List<PrayerDay> days, {DateTime? now}) =>
    PrayerTimelineBuilder.build(days: days, now: now ?? _now, cityName: 'Paris');

TimelineEntry _at(PrayerTimeline t, DateTime instant) =>
    t.entries.lastWhere((e) => !e.start.isAfter(instant));

PrayerNotificationService _service(
  FakeGateway gateway,
  FakeWidgetGateway widget, {
  http.Client? client,
}) =>
    PrayerNotificationService(
      store: PrayerSettingsRepository(),
      aladhan: AladhanRepository(client: client ?? _aladhan()),
      gateway: gateway,
      widget: widget,
      clock: () => _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PrayerTimelineBuilder', () {
    test('maintenant : prochaine prière, avancement et prière passée', () {
      final t = _build(_days(3));
      final first = t.entries.first;
      expect(first.start, _now, reason: 'à l’instant exact, pas arrondi');
      expect(first.next, Prayer.dhuhr);
      expect(first.nextAt, DateTime.utc(2026, 11, 20, 11, 30));
      expect(first.current, Prayer.fajr);
      expect(first.dayIndex, 0);
      // (08:00 − 05:00) / (18:00 − 05:00) = 3/13.
      expect(first.progress, closeTo(3 / 13, 1e-9));
    });

    test('points de l’arc proportionnels au temps, du Fajr (0) à l’Isha (1)', () {
      final markers = _build(_days(2)).markers.first;
      expect(markers.map((m) => m.prayer), Prayer.values);
      expect(markers.first.position, 0);
      expect(markers[1].position, closeTo(6.5 / 13, 1e-9));
      expect(markers.last.position, 1);
    });

    test('à chaque prière, la suivante devient la prochaine', () {
      final t = _build(_days(2));
      final atAsr = _at(t, DateTime.utc(2026, 11, 20, 14));
      expect(atAsr.start, DateTime.utc(2026, 11, 20, 14));
      expect(atAsr.next, Prayer.maghrib);
      expect(atAsr.current, Prayer.asr);
      final justBefore = _at(t, DateTime.utc(2026, 11, 20, 13, 59));
      expect(justBefore.next, Prayer.asr);
    });

    test('après l’Isha : arc du lendemain, point au début, Fajr à venir', () {
      final t = _build(_days(2));
      final night = _at(t, DateTime.utc(2026, 11, 20, 22));
      expect(night.dayIndex, 1);
      expect(night.next, Prayer.fajr);
      expect(night.nextAt, DateTime.utc(2026, 11, 21, 5));
      expect(night.progress, 0);
      expect(night.current, isNull);
    });

    test('entrées triées, tous les quarts d’heure et à chaque prière', () {
      final t = _build(_days(2));
      for (var i = 1; i < t.entries.length; i++) {
        expect(t.entries[i].start.isAfter(t.entries[i - 1].start), isTrue);
        expect(t.entries[i].start.difference(t.entries[i - 1].start),
            lessThanOrEqualTo(PrayerTimelineBuilder.step));
      }
      final starts = t.entries.map((e) => e.start).toSet();
      for (final p in [Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]) {
        expect(starts, contains(_days(1).first.times[p]));
      }
      expect(t.validUntil, DateTime.utc(2026, 11, 21, 18));
      expect(t.entries.last.nextAt, t.validUntil);
    });

    test('[⚡] 7 jours maximum, JSON compact', () {
      final t = _build(_days(30));
      expect(t.dayKeys, hasLength(PrayerTimelineBuilder.maxDays));
      expect(t.entries.length, lessThan(7 * 101));
      expect(utf8.encode(t.encode()).length, lessThan(100 * 1024));
    });

    test('ne devine jamais : jours passés ou incomplets ignorés, vide sinon', () {
      final days = _days(3, from: DateTime(2026, 11, 19));
      final t = _build(days);
      expect(t.dayKeys.first, '2026-11-20', reason: 'le 19 est terminé');
      final incomplete = PrayerDay(
        dateKey: '2026-11-21',
        times: {Prayer.fajr: DateTime.utc(2026, 11, 21, 5)},
      );
      expect(_build([days[1], incomplete]).dayKeys, ['2026-11-20']);
      expect(_build(const []).isEmpty, isTrue);
      expect(_build(_days(1), now: DateTime.utc(2026, 11, 20, 23)).isEmpty, isTrue);
    });

    test('format JSON lu par le widget Swift', () {
      final decoded =
          json.decode(_build(_days(2)).encode()) as Map<String, dynamic>;
      expect(decoded['v'], PrayerTimeline.version);
      expect(decoded['city'], 'Paris');
      final day = (decoded['days'] as List).first as Map<String, dynamic>;
      expect(day['date'], '2026-11-20');
      final marker = (day['markers'] as List).first as Map<String, dynamic>;
      expect(marker.keys, containsAll(['name', 'key', 'at', 'pos']));
      final entry = (decoded['entries'] as List).first as Map<String, dynamic>;
      expect(entry, {
        't': _now.millisecondsSinceEpoch ~/ 1000,
        'day': 0,
        'progress': 0.2308,
        'current': 'fajr',
        'next': 'Dhuhr',
        'nextKey': 'dhuhr',
        'nextAt': DateTime.utc(2026, 11, 20, 11, 30).millisecondsSinceEpoch ~/ 1000,
      });
    });
  });

  group('Réglage lockScreenWidget', () {
    test('[⚠️ migration] réglages v1.3.0 sans la clé → désactivé', () {
      final s = NotificationSettings.fromJson({
        'prayersEnabled': true,
        'modes': {'fajr': 'adhanFull'},
        'reminderMinutes': 0,
      });
      expect(s.lockScreenWidget, isFalse);
      expect(const NotificationSettings().lockScreenWidget, isFalse);
    });

    test('aller-retour JSON ; nécessite le calendrier', () {
      const s = NotificationSettings(lockScreenWidget: true);
      expect(NotificationSettings.fromJson(s.toJson()).lockScreenWidget, isTrue);
      expect(s.needsCalendar, isTrue);
      expect(NotificationSettings.fromJson({'lockScreenWidget': 'yes'}).lockScreenWidget,
          isFalse);
    });
  });

  group('PrayerNotificationService · widget', () {
    test('sans position : activation refusée avec la raison', () async {
      final outcome =
          await _service(FakeGateway(), FakeWidgetGateway()).enableLockScreenWidget();
      expect(outcome, EnableOutcome.noLocation);
    });

    test('activé sans autorisation de notifier : publié, rien de programmé',
        () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final gateway = FakeGateway(permission: false);
      final widget = FakeWidgetGateway();
      final outcome = await _service(gateway, widget).enableLockScreenWidget();
      expect(outcome, EnableOutcome.enabled);
      expect(gateway.requests, 0, reason: 'aucune demande d’autorisation');
      expect(gateway.prayers, isEmpty);
      expect(widget.current, isNotNull);
      final decoded = json.decode(widget.current!) as Map<String, dynamic>;
      expect(decoded['city'], 'Paris');
      expect((await PrayerSettingsRepository().readSettings()).lockScreenWidget, isTrue);
    });

    test('désactivé : le widget est vidé', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final widget = FakeWidgetGateway();
      final service = _service(FakeGateway(), widget);
      await service.enableLockScreenWidget();
      final settings = await PrayerSettingsRepository().readSettings();
      await service.updateSettings(settings.copyWith(lockScreenWidget: false));
      expect(widget.current, isNull);
      expect(widget.clears, greaterThan(0));
    });

    test('hors connexion sans cache : vidé plutôt que des heures fausses',
        () async {
      final store = PrayerSettingsRepository();
      await store.writeLocation(_paris);
      await store.writeSettings(const NotificationSettings(lockScreenWidget: true));
      final widget = FakeWidgetGateway();
      await _service(FakeGateway(), widget, client: _aladhan(offline: true))
          .reschedule(force: true);
      expect(widget.published, isEmpty);
      expect(widget.clears, 1);
    });

    test('avec les prières : le widget et les notifications coexistent', () async {
      final store = PrayerSettingsRepository();
      await store.writeLocation(_paris);
      await store.writeSettings(
          const NotificationSettings(prayersEnabled: true, lockScreenWidget: true));
      final gateway = FakeGateway();
      final widget = FakeWidgetGateway();
      await _service(gateway, widget).reschedule(force: true);
      expect(widget.published, hasLength(1));
      expect(gateway.prayers, isNotEmpty);
    });
  });

  group('MethodChannelPrayerWidgetGateway', () {
    const channel = MethodChannel(MethodChannelPrayerWidgetGateway.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('iOS : publie la chronologie puis efface', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final gateway = MethodChannelPrayerWidgetGateway(isIos: true);
      await gateway.publish('{"v":1}');
      await gateway.clear();
      expect(calls.map((c) => c.method), ['publish', 'clear']);
      expect(calls.first.arguments, {'timeline': '{"v":1}'});
    });

    test('[⚠️] erreur native ou extension absente : jamais d’exception', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'no_app_group');
      });
      await MethodChannelPrayerWidgetGateway(isIos: true).publish('{}');
      messenger.setMockMethodCallHandler(channel, null);
      await MethodChannelPrayerWidgetGateway(isIos: true).clear();
    });

    test('hors iOS : aucun appel natif', () async {
      var called = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return null;
      });
      await MethodChannelPrayerWidgetGateway(isIos: false).publish('{}');
      expect(called, isFalse);
    });
  });

  group('UI · écran verrouillé', () {
    Future<FakeWidgetGateway> pump(WidgetTester tester, TargetPlatform platform) async {
      final widget = FakeWidgetGateway();
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: platform),
          home: NotificationSettingsScreen(
            service: _service(FakeGateway(), widget),
            preview: FakePlayback(),
            calendar: CalendarPreferences(),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      return widget;
    }

    testWidgets('iOS : activation, publication et marche à suivre', (tester) async {
      final widget = await pump(tester, TargetPlatform.iOS);
      await tester.scrollUntilVisible(find.text('Écran verrouillé'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Écran verrouillé'), findsOneWidget);
      expect(find.text('Pour l’ajouter'), findsNothing);

      await tester.ensureVisible(find.text('Chronologie des prières'));
      await tester.pump();
      await tester.tap(find.text('Chronologie des prières'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(widget.current, isNotNull);
      expect(find.text('Pour l’ajouter'), findsOneWidget);
      expect(find.textContaining('choisissez « Deen »'), findsOneWidget);
    });

    testWidgets('Android : section absente', (tester) async {
      await pump(tester, TargetPlatform.android);
      // Jusqu'à la section suivante : la nôtre aurait été construite.
      await tester.scrollUntilVisible(find.text('Rappels quotidiens'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Calendrier'), findsOneWidget);
      expect(find.text('Écran verrouillé'), findsNothing);
      expect(find.text('Chronologie des prières'), findsNothing);
    });
  });
}
