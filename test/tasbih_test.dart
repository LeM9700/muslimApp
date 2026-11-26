import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/controllers/tasbih_controller.dart';
import 'package:muslim_app/models/dhikr.dart';
import 'package:muslim_app/repositories/tasbih_repository.dart';
import 'package:muslim_app/screens/tasbih_screen.dart';
import 'package:muslim_app/services/tasbih_counter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TasbihCounter', () {
    test('objectif de 33 : atteint au 33e appui, puis nouveau tour', () {
      final c = TasbihCounter.single(Dhikr.subhanAllah, 33);
      for (var i = 1; i < 33; i++) {
        expect(c.tap(), TasbihEvent.counted);
      }
      expect(c.tap(), TasbihEvent.targetReached);
      expect(c.count, 33);
      expect(c.rounds, 1);
      expect(c.progress, 1);
      expect(c.tap(), TasbihEvent.counted);
      expect(c.count, 1, reason: 'nouveau tour');
    });

    test('sans limite : on compte indéfiniment', () {
      final c = TasbihCounter.single(Dhikr.astaghfirullah, 0);
      for (var i = 0; i < 250; i++) {
        expect(c.tap(), TasbihEvent.counted);
      }
      expect(c.count, 250);
      expect(c.progress, isNull);
    });

    test('après la prière : 33 + 33 + 33 + 1 = 100 (Muslim 597)', () {
      final c = TasbihCounter.afterPrayer();
      final events = [for (var i = 0; i < 100; i++) c.tap()];
      expect(events.where((e) => e == TasbihEvent.stepDone), hasLength(3));
      expect(events.last, TasbihEvent.sequenceDone);
      expect(events.indexOf(TasbihEvent.stepDone), 32, reason: '33e appui');
      expect(c.current.dhikr, Dhikr.tahlilComplete);
      expect(c.rounds, 1);
      c.tap();
      expect(c.current.dhikr, Dhikr.subhanAllah, reason: 'on recommence');
      expect(c.count, 1);
    });

    test('remise à zéro', () {
      final c = TasbihCounter.afterPrayer();
      for (var i = 0; i < 40; i++) {
        c.tap();
      }
      expect(c.stepIndex, 1);
      c.reset();
      expect([c.stepIndex, c.count], [0, 0]);
    });
  });

  group('TasbihController', () {
    test('total du jour enregistré (par lot) et rechargé', () async {
      final events = <TasbihEvent>[];
      final c = TasbihController(
        clock: () => DateTime(2026, 11, 26, 10),
        haptic: events.add,
        saveDelay: const Duration(milliseconds: 10),
      );
      await c.load();
      for (var i = 0; i < 33; i++) {
        c.tap();
      }
      expect(c.todayTotal, 33);
      expect(events.last, TasbihEvent.targetReached);
      expect(events.where((e) => e == TasbihEvent.counted), hasLength(32));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await TasbihRepository().readTotal('2026-11-26'), 33);

      final again = TasbihController(clock: () => DateTime(2026, 11, 26, 18), haptic: (_) {});
      await again.load();
      expect(again.todayTotal, 33);
      final tomorrow = TasbihController(clock: () => DateTime(2026, 11, 27, 8), haptic: (_) {});
      await tomorrow.load();
      expect(tomorrow.todayTotal, 0, reason: 'nouveau jour');
    });

    test('minuit passé pendant la séance : le total repart de zéro', () async {
      var now = DateTime(2026, 11, 26, 23, 59);
      final c = TasbihController(clock: () => now, haptic: (_) {});
      await c.load();
      c.tap();
      c.tap();
      now = DateTime(2026, 11, 27, 0, 1);
      c.tap();
      expect(c.todayTotal, 1);
      await c.flush();
      expect(await TasbihRepository().readTotal('2026-11-27'), 1);
    });

    test('changer de formule ou d’objectif recommence le compte', () {
      final c = TasbihController(haptic: (_) {});
      c.tap();
      c.selectTarget(99);
      expect(c.counter.count, 0);
      expect(c.counter.current.target, 99);
      c.selectDhikr(Dhikr.laIlaha);
      expect(c.dhikr, Dhikr.laIlaha);
      c.setAfterPrayer(true);
      expect(c.counter.isSequence, isTrue);
    });
  });

  group('UI', () {
    Future<List<TasbihEvent>> pump(WidgetTester tester) async {
      final events = <TasbihEvent>[];
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: TasbihScreen(
            clock: () => DateTime(2026, 11, 26, 10),
            haptic: events.add,
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      return events;
    }

    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('appuyer compte, vibre et met à jour le total', (tester) async {
      final events = await pump(tester);
      expect(find.text('سُبْحَانَ اللَّهِ'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('tasbih-tap')));
        await tester.pump();
      }
      expect(text(tester, 'tasbih-count'), '3');
      expect(text(tester, 'tasbih-total'), 'Aujourd’hui : 3');
      expect(events, hasLength(3));

      await tester.tap(find.byTooltip('Remettre à zéro'));
      await tester.pump();
      expect(text(tester, 'tasbih-count'), '0');
      expect(text(tester, 'tasbih-total'), 'Aujourd’hui : 3', reason: 'le total reste');
    });

    testWidgets('petit écran (iPhone SE, 375×667) : aucun débordement',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester);
      await tester.tap(find.text('Après la prière'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tasbih-count')), findsOneWidget);
    });

    testWidgets('mode après la prière : étapes affichées', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Après la prière'));
      await tester.pump();
      expect(text(tester, 'tasbih-status'), 'Étape 1 / 4');
      for (var i = 0; i < 34; i++) {
        await tester.tap(find.byKey(const ValueKey('tasbih-tap')));
      }
      await tester.pump();
      expect(text(tester, 'tasbih-status'), 'Étape 2 / 4');
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);
    });
  });
}
