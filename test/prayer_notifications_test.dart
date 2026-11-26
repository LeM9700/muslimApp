import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/adhan_mode.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/repositories/prayer_settings_repository.dart';
import 'package:muslim_app/models/adhan_dua.dart';
import 'package:muslim_app/screens/adhan_player_screen.dart';
import 'package:muslim_app/screens/notification_settings_screen.dart';
import 'package:muslim_app/services/adhan_audio.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_notification_service.dart';
import 'package:muslim_app/utils/french_dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_playback.dart';

const _paris = PrayerLocation(latitude: 48.8566, longitude: 2.3522, cityName: 'Paris');

/// Jour fictif : Fajr 06:00, Dhuhr 12:30, Asr 15:00, Maghrib 17:30,
/// Isha 19:00 (UTC+1).
Map<String, dynamic> _apiDay(DateTime date) {
  String at(int h, int m) =>
      '${date.year}-${_2(date.month)}-${_2(date.day)}T${_2(h)}:${_2(m)}:00+01:00';
  return {
    'timings': {
      'Fajr': at(6, 0),
      'Sunrise': at(7, 30),
      'Dhuhr': at(12, 30),
      'Asr': at(15, 0),
      'Maghrib': at(17, 30),
      'Isha': at(19, 0),
    },
    'date': {
      'gregorian': {'date': '${_2(date.day)}-${_2(date.month)}-${date.year}'},
    },
    'meta': {
      'method': {'id': 12, 'name': 'Union Organization Islamic de France'},
    },
  };
}

String _2(int n) => n.toString().padLeft(2, '0');

/// Faux serveur Aladhan : renvoie le mois demandé.
MockClient _aladhan({bool offline = false, List<Uri>? calls}) {
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
        'data': [for (var d = 1; d <= count; d++) _apiDay(DateTime(year, month, d))],
      })),
      200,
    );
  });
}

class FakeGateway implements NotificationGateway {
  bool permission;
  bool grantOnRequest;
  int requests = 0;
  final List<DailyNotification> daily = [];
  final List<PlannedNotification> prayers = [];
  int tests = 0;

  int prepared = 0;

  FakeGateway({this.permission = true, this.grantOnRequest = true});

  @override
  Future<void> prepare() async => prepared++;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    requests++;
    permission = grantOnRequest;
    return permission;
  }

  @override
  Future<void> cancelAll() async {
    daily.clear();
    prayers.clear();
  }

  @override
  Future<void> scheduleDaily(DailyNotification n) async => daily.add(n);

  @override
  Future<void> schedulePrayer(PlannedNotification n) async => prayers.add(n);

  @override
  Future<void> showTest({required String title, required String body}) async =>
      tests++;
}

/// 20 novembre 2026, 08:00 UTC (09:00 à Paris).
final _now = DateTime.utc(2026, 11, 20, 8);

PrayerNotificationService _service(
  FakeGateway gateway, {
  http.Client? client,
  DateTime? now,
}) =>
    PrayerNotificationService(
      store: PrayerSettingsRepository(),
      aladhan: AladhanRepository(client: client ?? _aladhan()),
      gateway: gateway,
      clock: () => now ?? _now,
    );

List<PrayerDay> _days(int count, {DateTime? from}) {
  final start = from ?? DateTime(2026, 11, 20);
  return [
    for (var i = 0; i < count; i++)
      AladhanRepository.parseMonth({
        'code': 200,
        'data': [_apiDay(start.add(Duration(days: i)))],
      }).days.single,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AladhanRepository.parseMonth', () {
    test('heures ISO → instants UTC absolus', () {
      final day = _days(1).single;
      expect(day.dateKey, '2026-11-20');
      expect(day.times[Prayer.fajr], DateTime.utc(2026, 11, 20, 5));
      expect(day.times[Prayer.isha], DateTime.utc(2026, 11, 20, 18));
    });

    test('passage à l’heure d’été : le décalage de chaque jour est respecté',
        () {
      final month = AladhanRepository.parseMonth({
        'code': 200,
        'data': [
          {
            'timings': {
              for (final p in Prayer.values) p.apiKey: '2027-03-27T05:30:00+01:00',
            },
            'date': {'gregorian': {'date': '27-03-2027'}},
          },
          {
            'timings': {
              for (final p in Prayer.values) p.apiKey: '2027-03-28T06:28:00+02:00',
            },
            'date': {'gregorian': {'date': '28-03-2027'}},
          },
        ],
      });
      expect(month.days[0].times[Prayer.fajr], DateTime.utc(2027, 3, 27, 4, 30));
      expect(month.days[1].times[Prayer.fajr], DateTime.utc(2027, 3, 28, 4, 28));
    });

    test('un jour incomplet est ignoré, jamais deviné', () {
      final month = AladhanRepository.parseMonth({
        'code': 200,
        'data': [
          {'timings': {'Fajr': '2026-11-20T06:53:00+01:00'}},
          _apiDay(DateTime(2026, 11, 21)),
        ],
      });
      expect(month.days.single.dateKey, '2026-11-21');
    });

    test('réponse en erreur → AladhanException', () {
      expect(() => AladhanRepository.parseMonth({'code': 400, 'status': 'KO'}),
          throwsA(isA<AladhanException>()));
    });
  });

  group('PrayerNotificationPlanner', () {
    const enabled = NotificationSettings(prayersEnabled: true);

    test('désactivé → aucun rappel', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _days(3),
        settings: const NotificationSettings(),
        now: _now,
        cityName: 'Paris',
      );
      expect(plan.notifications, isEmpty);
    });

    test('ignore les prières passées, trie et numérote', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _days(2),
        settings: enabled,
        now: _now, // 09:00 Paris : Fajr du jour passé
        cityName: 'Paris',
        formatTime: (_) => 'HH:MM',
      );
      expect(plan.notifications, hasLength(9));
      expect(plan.notifications.first.prayer, Prayer.dhuhr);
      expect(plan.notifications.map((n) => n.id),
          List.generate(9, (i) => PrayerNotificationPlanner.firstId + i));
      expect(plan.notifications.first.title, 'Dhuhr · HH:MM');
      expect(plan.notifications.first.body, contains('à Paris'));
      expect(plan.coveredUntil, plan.notifications.last.when);
    });

    test('respecte les prières choisies', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _days(2),
        settings: const NotificationSettings(
          prayersEnabled: true,
          modes: {Prayer.fajr: AdhanMode.adhanFull, Prayer.maghrib: AdhanMode.silent},
        ),
        now: _now,
        cityName: '',
      );
      expect(plan.notifications.map((n) => n.prayer),
          [Prayer.maghrib, Prayer.fajr, Prayer.maghrib]);
    });

    test('rappel avant : 2 notifications par prière, 15 min plus tôt', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _days(1),
        settings: const NotificationSettings(
          prayersEnabled: true,
          modes: {Prayer.dhuhr: AdhanMode.notification},
          reminderMinutes: 15,
        ),
        now: _now,
        cityName: 'Paris',
        formatTime: (_) => '12:30',
      );
      final reminder = plan.notifications.first;
      expect(reminder.kind, PlannedKind.reminder);
      expect(reminder.title, 'Dhuhr dans 15 min');
      expect(plan.notifications.last.when.difference(reminder.when),
          const Duration(minutes: 15));
    });

    test('[iOS] ne dépasse jamais le budget de 60 notifications', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _days(30),
        settings: const NotificationSettings(prayersEnabled: true, reminderMinutes: 10),
        now: _now,
        cityName: 'Paris',
      );
      expect(plan.notifications, hasLength(PrayerNotificationPlanner.defaultBudget));
      // Les plus proches d'abord : iOS garderait de toute façon les 64 premières.
      final times = plan.notifications.map((n) => n.when).toList();
      expect(times, [...times]..sort());
    });

    test('ne programme pas ce qui tombe dans moins d’une minute', () {
      final dhuhr = _days(1).single.times[Prayer.dhuhr]!;
      final plan = PrayerNotificationPlanner.plan(
        days: _days(1),
        settings: enabled,
        now: dhuhr.subtract(const Duration(seconds: 30)),
        cityName: '',
      );
      expect(plan.notifications.first.prayer, Prayer.asr);
    });
  });

  group('NotificationSettings', () {
    test('aller-retour JSON', () {
      const s = NotificationSettings(
        prayersEnabled: true,
        modes: {Prayer.fajr: AdhanMode.adhanFull, Prayer.isha: AdhanMode.silent},
        reminderMinutes: 30,
        methodId: 12,
        hadithDaily: false,
      );
      final r = NotificationSettings.fromJson(s.toJson());
      expect(r.prayersEnabled, isTrue);
      expect(r.prayers, {Prayer.fajr, Prayer.isha});
      expect(r.modeOf(Prayer.fajr), AdhanMode.adhanFull);
      expect(r.modeOf(Prayer.isha), AdhanMode.silent);
      expect(r.modeOf(Prayer.dhuhr), AdhanMode.off);
      expect(r.reminderMinutes, 30);
      expect(r.methodId, 12);
      expect(r.hadithDaily, isFalse);
      expect(r.quizDaily, isTrue);
    });

    test('valeur de rappel inconnue → 0', () {
      expect(NotificationSettings.fromJson({'reminderMinutes': 7}).reminderMinutes, 0);
    });

    test('copyWith peut remettre la méthode en automatique', () {
      const s = NotificationSettings(methodId: 12);
      expect(s.copyWith(methodId: () => null).methodId, isNull);
      expect(s.copyWith(reminderMinutes: 10).methodId, 12);
    });
  });

  group('PrayerNotificationService', () {
    test('sans position : activation refusée avec la raison', () async {
      final gateway = FakeGateway();
      final outcome = await _service(gateway).enablePrayers();
      expect(outcome, EnableOutcome.noLocation);
      expect(gateway.requests, 0);
    });

    test('autorisation refusée : rien n’est activé', () async {
      final gateway = FakeGateway(permission: false, grantOnRequest: false);
      final service = _service(gateway);
      await PrayerSettingsRepository().writeLocation(_paris);

      expect(await service.enablePrayers(), EnableOutcome.permissionDenied);
      expect((await PrayerSettingsRepository().readSettings()).prayersEnabled,
          isFalse);
    });

    test('activation : demande d’autorisation puis programmation', () async {
      final gateway = FakeGateway(permission: false);
      final service = _service(gateway);
      await PrayerSettingsRepository().writeLocation(_paris);

      expect(await service.enablePrayers(), EnableOutcome.enabled);
      expect(gateway.requests, 1);
      expect(gateway.prayers, hasLength(PrayerNotificationPlanner.defaultBudget));
      expect(gateway.daily.map((d) => d.id), [1, 2]);

      final status = await service.status();
      expect(status.coveredUntil, isNotNull);
      expect(status.methodName, 'Union Organization Islamic de France');
      expect(status.today?.dateKey, '2026-11-20');
    });

    test('calendrier mis en cache : pas de nouvel appel réseau', () async {
      final calls = <Uri>[];
      final gateway = FakeGateway();
      final service = _service(gateway, client: _aladhan(calls: calls));
      await PrayerSettingsRepository().writeLocation(_paris);
      await service.enablePrayers();
      final first = calls.length;
      expect(first, greaterThan(0));

      await service.reschedule(force: true);
      expect(calls.length, first);
    });

    test('fin de mois : télécharge aussi le mois suivant', () async {
      final calls = <Uri>[];
      final gateway = FakeGateway();
      final service = _service(
        gateway,
        client: _aladhan(calls: calls),
        now: DateTime.utc(2026, 11, 25, 8),
      );
      await PrayerSettingsRepository().writeLocation(_paris);
      await service.enablePrayers();
      expect(calls.map((u) => u.pathSegments.last), ['11', '12']);
    });

    test('méthode choisie transmise à Aladhan, absente en automatique',
        () async {
      final calls = <Uri>[];
      final service = _service(FakeGateway(), client: _aladhan(calls: calls));
      await PrayerSettingsRepository().writeLocation(_paris);
      await service.enablePrayers();
      expect(calls.last.queryParameters.containsKey('method'), isFalse);
      expect(calls.last.queryParameters['iso8601'], 'true');

      final settings = await PrayerSettingsRepository().readSettings();
      await service.updateSettings(settings.copyWith(methodId: () => 21));
      expect(calls.last.queryParameters['method'], '21');
    });

    test('hors ligne sans cache : rien de programmé, état signalé', () async {
      final gateway = FakeGateway();
      final service = _service(gateway, client: _aladhan(offline: true));
      await PrayerSettingsRepository().writeLocation(_paris);
      await service.enablePrayers();

      expect(gateway.prayers, isEmpty);
      expect(gateway.daily, hasLength(2)); // hadith et quiz restent programmés
      expect((await service.status()).calendarUnavailable, isTrue);
    });

    test('hors ligne avec cache : on reprogramme depuis le cache', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      await _service(FakeGateway()).enablePrayers();

      final gateway = FakeGateway();
      await _service(gateway, client: _aladhan(offline: true))
          .reschedule(force: true);
      expect(gateway.prayers, isNotEmpty);
    });

    test('changer de ville invalide le cache et reprogramme', () async {
      final calls = <Uri>[];
      final gateway = FakeGateway();
      final service = _service(gateway, client: _aladhan(calls: calls));
      await PrayerSettingsRepository().writeLocation(_paris);
      await service.enablePrayers();
      final before = calls.length;

      await service.setLocation(const PrayerLocation(
        latitude: 43.2965,
        longitude: 5.3698,
        cityName: 'Marseille',
      ));
      final afterMove = calls.length;
      expect(afterMove, greaterThan(before));
      expect(gateway.prayers.first.body, contains('Marseille'));

      // Même position : aucun travail inutile.
      await service.setLocation(const PrayerLocation(
        latitude: 43.2965,
        longitude: 5.3698,
        cityName: 'Marseille',
      ));
      expect(calls.length, afterMove);
    });

    test('horaires affichés avant même l’autorisation', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      final gateway = FakeGateway(permission: false);
      final status = await _service(gateway).status();
      expect(status.today?.times[Prayer.fajr], DateTime.utc(2026, 11, 20, 5));
      expect(gateway.prayers, isEmpty);
    });

    test('sans autorisation : aucune programmation', () async {
      await PrayerSettingsRepository().writeLocation(_paris);
      await PrayerSettingsRepository()
          .writeSettings(const NotificationSettings(prayersEnabled: true));
      final gateway = FakeGateway(permission: false);
      await _service(gateway).reschedule(force: true);
      expect(gateway.prayers, isEmpty);
      expect(gateway.daily, isEmpty);
    });

    test('hadith et quiz désactivables séparément', () async {
      await PrayerSettingsRepository().writeSettings(
        const NotificationSettings(hadithDaily: false),
      );
      final gateway = FakeGateway();
      await _service(gateway).reschedule(force: true);
      expect(gateway.daily.map((d) => d.payload), ['quiz_daily']);
    });

    test('reprogrammation limitée à une fois par 30 min hors forçage',
        () async {
      final gateway = FakeGateway();
      final service = _service(gateway);
      await service.reschedule(force: true);
      gateway.daily.clear();
      await service.reschedule();
      expect(gateway.daily, isEmpty);
    });
  });

  test('FrenchDates : « 1er », jour et mois en français', () {
    final d = DateTime(2026, 12, 1, 9, 5);
    expect(FrenchDates.dayMonth(d), 'mardi 1er décembre');
    expect(FrenchDates.time(d), '09:05');
  });

  group('UI', () {
    Future<FakeGateway> pump(
      WidgetTester tester, {
      bool permission = true,
      AdhanPlayback? preview,
    }) async {
      final gateway = FakeGateway(permission: permission);
      await tester.runAsync(() async {
        await PrayerSettingsRepository().writeLocation(_paris);
        await tester.pumpWidget(MaterialApp(
          home: NotificationSettingsScreen(
            service: _service(gateway),
            preview: preview ?? FakePlayback(),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      return gateway;
    }

    testWidgets('activer les rappels affiche les prières et la couverture',
        (tester) async {
      final gateway = await pump(tester);
      expect(find.text('Horaires de Paris'), findsOneWidget);
      expect(find.text('Fajr'), findsNothing);

      await tester.runAsync(() async {
        await tester.tap(find.text('Notification à chaque prière'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(gateway.prayers, isNotEmpty);
      for (final p in Prayer.values) {
        expect(find.text(p.label), findsOneWidget);
      }
      expect(find.textContaining('Rappels programmés jusqu’au'), findsOneWidget);
      expect(find.textContaining('Automatique · Union'), findsOneWidget);
    });

    testWidgets('autorisation refusée : bandeau vers les Réglages',
        (tester) async {
      final gateway = await pump(tester, permission: false);
      gateway.grantOnRequest = false;

      await tester.runAsync(() async {
        await tester.tap(find.text('Notification à chaque prière'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Les notifications sont désactivées pour Deen'),
          findsOneWidget);
      expect(find.text('Ouvrir les Réglages'), findsOneWidget);
    });

    Future<void> enable(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Notification à chaque prière'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
    }

    /// Le fond animé tourne en boucle : pumpAndSettle ne se stabiliserait
    /// jamais. On avance l'horloge du temps d'une transition.
    Future<void> sheet(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await sheet(tester);
    }

    Finder inSheet(String text) => find.descendant(
        of: find.byType(BottomSheet), matching: find.text(text));

    Future<void> openPrayer(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
      await sheet(tester);
    }

    Map<Prayer, AdhanMode> scheduledModes(FakeGateway gateway) => {
          for (final n in gateway.prayers.where((n) => n.kind == PlannedKind.prayer))
            n.prayer: n.mode,
        };

    testWidgets('profil Équilibré par défaut, mode affiché par prière',
        (tester) async {
      final gateway = await pump(tester);
      await enable(tester);

      final balanced = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Équilibré'));
      expect(balanced.selected, isTrue);
      expect(find.text('Personnalisé'), findsNothing);
      expect(scheduledModes(gateway), AdhanPreset.balanced.modes);
    });

    testWidgets('changer une prière : reprogrammée avec son nouveau mode',
        (tester) async {
      final gateway = await pump(tester);
      await enable(tester);

      await openPrayer(tester, 'Dhuhr');
      await tester.tap(inSheet('Adhan court'));
      await settle(tester);

      expect(scheduledModes(gateway)[Prayer.dhuhr], AdhanMode.adhanShort);
      expect(scheduledModes(gateway)[Prayer.fajr], AdhanMode.adhanFull);
      expect(find.text('Personnalisé'), findsOneWidget);
    });

    testWidgets('« Appliquer à toutes » puis retour à un profil',
        (tester) async {
      final gateway = await pump(tester);
      await enable(tester);

      await openPrayer(tester, 'Asr');
      await tester.tap(inSheet('Appliquer à toutes les prières'));
      await tester.pump();
      await tester.tap(inSheet('Silencieux'));
      await settle(tester);

      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Discret'))
              .selected,
          isTrue);
      expect(scheduledModes(gateway).values.toSet(), {AdhanMode.silent});

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Adhan partout'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Adhan partout'));
      await settle(tester);
      expect(scheduledModes(gateway).values.toSet(), {AdhanMode.adhanFull});
    });

    testWidgets('écouter un son d’adhan depuis le sélecteur', (tester) async {
      final preview = FakePlayback(available: {AdhanAudioCatalog.shortPreview});
      await pump(tester, preview: preview);
      await enable(tester);

      await openPrayer(tester, 'Isha');
      await tester.tap(find.byTooltip('Écouter').first);
      await tester.pump();

      expect(preview.played, [AdhanAudioCatalog.shortPreview]);
      expect(find.byTooltip('Arrêter l’écoute'), findsOneWidget);

      // Fermer la feuille sans choisir : l'aperçu s'arrête.
      await tester.tapAt(const Offset(10, 10));
      await sheet(tester);
      expect(preview.stops, greaterThan(0));
    });
  });

  group('AdhanPlayerScreen', () {
    testWidgets('dou’a affichée, adhan intégral à la demande', (tester) async {
      final playback = FakePlayback(available: {AdhanAudioCatalog.full});
      await tester.pumpWidget(MaterialApp(
        home: AdhanPlayerScreen(prayer: Prayer.maghrib, playback: playback),
      ));
      expect(find.text('Prière du Maghrib'), findsOneWidget);
      expect(find.text(AdhanDua.source), findsOneWidget);
      expect(playback.played, isEmpty, reason: 'pas de lecture automatique');

      await tester.tap(find.text('Écouter l’adhan complet'));
      await tester.pump();
      expect(playback.played, [AdhanAudioCatalog.full]);
      expect(find.text('Arrêter'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(playback.disposed, isTrue);
    });
  });
}
