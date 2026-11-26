import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/controllers/adhkar_controller.dart';
import 'package:muslim_app/models/adhkar.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/adhkar_repository.dart';
import 'package:muslim_app/screens/adhkar_screen.dart';
import 'package:muslim_app/services/adhan_sound_resolver.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/notification_router.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lit le vrai fichier du recueil (celui qui part dans l'app).
AdhkarRepository _repository() =>
    AdhkarRepository(loadString: (key) => File(key).readAsString());

Map<String, dynamic> _raw() =>
    json.decode(File(AdhkarRepository.assetPath).readAsStringSync())
        as Map<String, dynamic>;

final _arabicLetters = RegExp(r'[ء-ي]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Recueil intégré (assets/adhkar/adhkar_fr.json)', () {
    test('chaque entrée est complète : aucune n’est écartée au chargement',
        () async {
      final book = await _repository().load();
      expect(book.items, hasLength((_raw()['items'] as List).length));
      expect(book.items.length, greaterThanOrEqualTo(12));
      final ids = book.items.map((i) => i.id).toSet();
      expect(ids, hasLength(book.items.length), reason: 'identifiants uniques');
      for (final item in book.items) {
        for (final period in item.periods) {
          final text = item.textFor(period);
          expect(_arabicLetters.hasMatch(text.arabic), isTrue, reason: item.id);
          expect(text.transliteration, isNotEmpty, reason: item.id);
          expect(text.translation, isNotEmpty, reason: item.id);
        }
        expect(item.reference, isNotEmpty, reason: '${item.id} : référence obligatoire');
      }
      expect(book.source, contains('Hisn al-Muslim'));
    });

    test('matin et soir : bonnes variantes et bons dhikr', () async {
      final book = await _repository().load();
      final morning = book.itemsFor(AdhkarPeriod.morning).map((i) => i.id);
      final evening = book.itemsFor(AdhkarPeriod.evening).map((i) => i.id);
      expect(morning, contains('tahlil_100'));
      expect(morning, isNot(contains('kalimat_tammat')));
      expect(evening, contains('kalimat_tammat'));
      final asbahna = book.items.firstWhere((i) => i.id == 'asbahna');
      expect(asbahna.textFor(AdhkarPeriod.morning).arabic, startsWith('أَصْبَحْنَا'));
      expect(asbahna.textFor(AdhkarPeriod.evening).arabic, startsWith('أَمْسَيْنَا'));
      final quls = book.items.where((i) => ['ikhlas', 'falaq', 'nas'].contains(i.id));
      expect(quls.map((i) => i.repeat), [3, 3, 3]);
    });

    test('[⚠️ PROD] marqué « à relire » tant que personne ne l’a validé', () {
      // Quand une personne qualifiée aura relu, passer reviewed à true :
      // ce test échouera alors volontairement, pour le retirer en conscience.
      expect(_raw()['reviewed'], isFalse);
    });

    test('[🔒] entrées incomplètes ignorées, jamais affichées à moitié', () {
      final book = AdhkarBook.fromJson({
        'reviewed': true,
        'items': [
          {'id': 'a', 'title': 'A', 'periods': ['morning'], 'repeat': 1, 'reference': 'R',
            'text': {'ar': 'سُبْحَانَ', 'tr': 'x', 'fr': 'y'}},
          {'id': 'b', 'title': 'B', 'periods': ['morning'], 'repeat': 0, 'reference': 'R',
            'text': {'ar': 'سُبْحَانَ', 'tr': 'x', 'fr': 'y'}},
          {'id': 'c', 'title': 'C', 'periods': ['noon'], 'repeat': 1, 'reference': 'R',
            'text': {'ar': 'سُبْحَانَ', 'tr': 'x', 'fr': 'y'}},
          {'id': 'd', 'title': 'D', 'periods': ['evening'], 'repeat': 1,
            'text': {'ar': 'سُبْحَانَ', 'tr': 'x', 'fr': 'y'}},
          'pas un objet',
        ],
      });
      expect(book.items.map((i) => i.id), ['a']);
      expect(AdhkarBook.fromJson({}).items, isEmpty);
    });
  });

  group('Rappels', () {
    test('réglages : désactivés par défaut, migration et aller-retour', () {
      expect(const NotificationSettings().adhkar.isActive, isFalse);
      expect(NotificationSettings.fromJson({'prayersEnabled': true}).adhkar.isActive,
          isFalse);
      final s = const AdhkarSettings().toggle(AdhkarPeriod.evening, true);
      final back = NotificationSettings.fromJson(
          NotificationSettings(adhkar: s).toJson());
      expect(back.adhkar.enabled, {AdhkarPeriod.evening});
    });

    test('matin 20 min après le Fajr, soir 20 min après l’Asr', () {
      final day = PrayerDay(dateKey: '2026-11-20', times: {
        Prayer.fajr: DateTime.utc(2026, 11, 20, 5, 50),
        Prayer.dhuhr: DateTime.utc(2026, 11, 20, 11, 50),
        Prayer.asr: DateTime.utc(2026, 11, 20, 14, 10),
        Prayer.maghrib: DateTime.utc(2026, 11, 20, 16, 10),
        Prayer.isha: DateTime.utc(2026, 11, 20, 17, 40),
      });
      final plan = PrayerNotificationPlanner.plan(
        days: [day],
        settings: const NotificationSettings(
            adhkar: AdhkarSettings(enabled: {AdhkarPeriod.morning, AdhkarPeriod.evening})),
        now: DateTime.utc(2026, 11, 20),
        cityName: 'Paris',
      );
      expect(plan.notifications.map((n) => n.when), [
        DateTime.utc(2026, 11, 20, 6, 10),
        DateTime.utc(2026, 11, 20, 14, 30),
      ]);
      expect(plan.notifications.map((n) => n.payload),
          ['adhkar:morning', 'adhkar:evening']);
      expect(plan.notifications.first.title, 'Adhkar du matin');
    });

    test('[🔒] payload défensif, canal dédié', () {
      expect(AdhkarPayload.decode('adhkar:evening')!.period, AdhkarPeriod.evening);
      for (final raw in [null, 'adhkar', 'adhkar:noon', 'adhkar:morning:x', 'friday:kahf']) {
        expect(AdhkarPayload.decode(raw), isNull, reason: '$raw');
      }
      final ids = AdhanSoundResolver.channels.map((s) => s.androidChannelId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(LocalNotificationGateway.adhkarDetails().android!.channelId, 'adhkar_v1');
    });

    testWidgets('tap : ouvre l’écran Adhkar sur le bon moment', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
      AdhkarPeriod? opened;
      final router = NotificationRouter(
        navigatorKey: key,
        openAdhkar: (_, p) => opened = p,
        openPlayer: (_, __) {},
      );
      expect(router.handle('adhkar:evening'), isTrue);
      expect(opened, AdhkarPeriod.evening);
    });
  });

  group('AdhkarController', () {
    test('moment par défaut selon l’heure, compteur borné, remise à zéro',
        () async {
      final haptics = <bool>[];
      final c = AdhkarController(
        repository: _repository(),
        clock: () => DateTime(2026, 11, 26, 7),
        haptic: haptics.add,
      );
      await c.load();
      expect(c.period, AdhkarPeriod.morning);
      final ikhlas = c.items.firstWhere((i) => i.id == 'ikhlas');
      for (var i = 0; i < 5; i++) {
        c.tap(ikhlas);
      }
      expect(c.countOf(ikhlas), 3, reason: 'borné au nombre recommandé');
      expect(c.isDone(ikhlas), isTrue);
      expect(haptics, [false, false, true]);
      expect(c.doneCount, 1);

      c.setPeriod(AdhkarPeriod.evening);
      expect(c.countOf(ikhlas), 0, reason: 'nouveau moment, nouvelle séance');
      expect(AdhkarController(repository: _repository(),
              clock: () => DateTime(2026, 11, 26, 17)).period,
          AdhkarPeriod.evening);
    });

    test('fichier illisible : état d’erreur, pas d’exception', () async {
      final c = AdhkarController(
        repository: AdhkarRepository(loadString: (_) async => throw Exception('x')),
      );
      await c.load();
      expect(c.failed, isTrue);
      expect(c.items, isEmpty);
    });
  });

  group('UI', () {
    Future<void> pump(WidgetTester tester, {AdhkarPeriod? period}) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: AdhkarScreen(
            repository: _repository(),
            initialPeriod: period,
            clock: () => DateTime(2026, 11, 26, 7),
            haptic: (_) {},
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    testWidgets('matin : bandeau de relecture, compteur au toucher', (tester) async {
      await pump(tester);
      expect(find.textContaining('en cours de relecture'), findsOneWidget);
      expect(find.text('Âyat al-Kursî'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Sourate al-Ikhlâs'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const ValueKey('adhkar-ikhlas')));
      await tester.pump();
      expect(find.text('0 / 3'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('adhkar-ikhlas')));
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('soir : variante « Amsaynâ » et dhikr du soir', (tester) async {
      await pump(tester, period: AdhkarPeriod.evening);
      await tester.scrollUntilVisible(find.textContaining('أَمْسَيْنَا وَأَمْسَى'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('أَمْسَيْنَا وَأَمْسَى'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Les paroles parfaites d’Allah'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Les paroles parfaites d’Allah'), findsOneWidget);
    });
  });
}
