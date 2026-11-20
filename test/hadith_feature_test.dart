import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/models/hadith.dart';
import 'package:muslim_app/models/hadith_category.dart';
import 'package:muslim_app/models/hadith_grade.dart';
import 'package:muslim_app/repositories/hadeethenc_repository.dart';
import 'package:muslim_app/repositories/hadith_cache_repository.dart';
import 'package:muslim_app/screens/hadith_detail_screen.dart';
import 'package:muslim_app/services/daily_hadith_selector.dart';
import 'package:muslim_app/services/hadith_service.dart';
import 'package:muslim_app/widgets/hadith/grade_badge.dart';
import 'package:muslim_app/widgets/hadith/grade_info_sheet.dart';
import 'package:muslim_app/widgets/hadith_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extrait réel (raccourci) de GET /hadeeths/one/?language=fr&id=66511
Map<String, dynamic> _oneJson({String id = '66511'}) => {
      'id': id,
      'title': 'Les actes ne valent que par les intentions',
      'hadeeth': 'D’après ‘Umar b. al‑Khattâb qui a dit : « Les actes ne '
          'valent que par les intentions. »',
      'hadeeth_intro': 'D’après ‘Umar b. al‑Khattâb qui a dit :',
      'attribution': 'Rapporté par Al Bukhârî et Muslim',
      'grade': 'Authentique',
      'grade_ar': 'صحيح',
      'explanation': 'Le Prophète explique que toutes les œuvres sont '
          'considérées en fonction de l’intention.\r',
      'hints': ['L’incitation à la sincérité.\r', '  '],
      'hadeeth_ar': 'إنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
    };

const _roots = [
  {'id': '1', 'title': 'Coran', 'hadeeths_count': '3', 'parent_id': null},
  {'id': '3', 'title': 'Dogme', 'hadeeths_count': '5', 'parent_id': null},
];

/// Faux serveur HadeethEnc. [fail] simule une panne réseau.
MockClient _server({bool fail = false, List<Uri>? calls}) {
  return MockClient((request) async {
    calls?.add(request.url);
    if (fail) throw http.ClientException('offline');
    final path = request.url.path;
    final q = request.url.queryParameters;
    if (path.endsWith('/categories/roots/')) {
      return http.Response(json.encode(_roots), 200);
    }
    if (path.endsWith('/hadeeths/list/')) {
      final id = '${q['category_id']}${q['page']}';
      return http.Response(
        json.encode({
          'data': [
            {'id': id, 'title': 't'},
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/hadeeths/one/')) {
      return http.Response.bytes(
        utf8.encode(json.encode(_oneJson(id: q['id']!))),
        200,
      );
    }
    return http.Response('', 404);
  });
}

HadithService _service({
  required http.Client client,
  DateTime? now,
}) {
  return HadithService(
    remote: HadeethEncRepository(client: client),
    cache: HadithCacheRepository(),
    clock: () => now ?? DateTime(2026, 11, 20, 9),
    random: Random(1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HadithGrade.fromLabels', () {
    test('priorise le libellé arabe', () {
      expect(
        HadithGrade.fromLabels(arabic: 'صحيح', label: 'Bon'),
        HadithGrade.sahih,
      );
      expect(HadithGrade.fromLabels(arabic: 'حسن'), HadithGrade.hasan);
      expect(HadithGrade.fromLabels(arabic: 'ضعيف'), HadithGrade.daif);
    });

    test('« hasan sahih » est rangé en authentique', () {
      expect(HadithGrade.fromLabels(arabic: 'حسن صحيح'), HadithGrade.sahih);
    });

    test('gère les jugements cités (An-Nawawî a dit…)', () {
      expect(
        HadithGrade.fromLabels(
          arabic: 'قال النووي: حديث حسن',
          label: 'An-Nawawî a dit : " Hadith bon. "',
        ),
        HadithGrade.hasan,
      );
    });

    test('se rabat sur le libellé français ou anglais', () {
      expect(HadithGrade.fromLabels(label: 'Authentique'), HadithGrade.sahih);
      expect(HadithGrade.fromLabels(label: 'Sahih'), HadithGrade.sahih);
      expect(HadithGrade.fromLabels(label: 'Faible'), HadithGrade.daif);
      expect(HadithGrade.fromLabels(label: ''), HadithGrade.unknown);
      expect(HadithGrade.fromLabels(), HadithGrade.unknown);
    });

    test('détecte le renforcement par d’autres chaînes', () {
      expect(HadithGrade.isReinforced(arabic: 'حسن لغيره'), isTrue);
      expect(HadithGrade.isReinforced(arabic: 'صحيح'), isFalse);
    });
  });

  group('DailyHadithSelector', () {
    final roots = _roots.map(HadithCategory.fromJson).toList();

    test('le pas est premier avec le total', () {
      for (final total in [1, 2, 10, 1543, 2115, 3086]) {
        final stride = DailyHadithSelector.strideFor(total);
        expect(_gcd(stride, total), 1, reason: 'total=$total');
      }
    });

    test('visite tous les hadiths avant de se répéter', () {
      const total = 2115;
      final start = DateTime(2026, 1, 1);
      final seen = {
        for (var d = 0; d < total; d++)
          DailyHadithSelector.indexForDate(start.add(Duration(days: d)), total),
      };
      expect(seen.length, total);
    });

    test('même date → même hadith, quelle que soit l’heure', () {
      expect(
        DailyHadithSelector.indexForDate(DateTime(2026, 3, 29, 0, 5), 100),
        DailyHadithSelector.indexForDate(DateTime(2026, 3, 29, 23, 55), 100),
      );
    });

    test('convertit un index global en catégorie et position', () {
      expect(DailyHadithSelector.totalCount(roots), 8);
      expect(DailyHadithSelector.slotForIndex(roots, 0),
          const HadithSlot('1', 1));
      expect(DailyHadithSelector.slotForIndex(roots, 2),
          const HadithSlot('1', 3));
      expect(DailyHadithSelector.slotForIndex(roots, 3),
          const HadithSlot('3', 1));
      expect(DailyHadithSelector.slotForIndex(roots, 7),
          const HadithSlot('3', 5));
      expect(() => DailyHadithSelector.slotForIndex(roots, 8),
          throwsRangeError);
    });

    test('dateKey est au format AAAA-MM-JJ', () {
      expect(DailyHadithSelector.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('HadeethEncRepository', () {
    test('parse un hadith : intro séparée, \\r et indices vides retirés', () {
      final h = HadeethEncRepository.parseHadith(_oneJson());

      expect(h.id, 'henc_66511');
      expect(h.provider, HadithProvider.hadeethEnc);
      expect(h.narratorIntro, 'D’après ‘Umar b. al‑Khattâb qui a dit :');
      expect(h.translation,
          '« Les actes ne valent que par les intentions. »');
      expect(h.gradeLevel, HadithGrade.sahih);
      expect(h.explanation, isNot(contains('\r')));
      expect(h.hints, ['L’incitation à la sincérité.']);
      expect(h.textArabic, isNotEmpty);
      expect(h.hasExplanation, isTrue);
    });

    test('demande la langue française', () async {
      final calls = <Uri>[];
      await HadeethEncRepository(client: _server(calls: calls))
          .fetchHadith('66511');
      expect(calls.single.queryParameters['language'], 'fr');
    });

    test('lève HadeethEncException sur 404 et sur panne réseau', () async {
      final notFound =
          HadeethEncRepository(client: MockClient((_) async => http.Response('', 404)));
      expect(() => notFound.fetchHadith('1'),
          throwsA(isA<HadeethEncException>()));

      final offline = HadeethEncRepository(client: _server(fail: true));
      expect(() => offline.fetchRootCategories(),
          throwsA(isA<HadeethEncException>()));
    });

    test('liste vide → exception', () async {
      final repo = HadeethEncRepository(
        client: MockClient(
          (_) async => http.Response(json.encode({'data': <Object>[]}), 200),
        ),
      );
      expect(() => repo.fetchHadithIdAt(categoryId: '1', position: 999),
          throwsA(isA<HadeethEncException>()));
    });
  });

  group('HadithCacheRepository', () {
    final hadith = HadeethEncRepository.parseHadith(_oneJson());

    test('aller-retour complet du hadith du jour', () async {
      final cache = HadithCacheRepository();
      await cache.writeDaily('2026-11-20', hadith);

      final read = await cache.readDaily('2026-11-20');
      expect(read?.id, hadith.id);
      expect(read?.explanation, hadith.explanation);
      expect(read?.hints, hadith.hints);
      expect(read?.provider, HadithProvider.hadeethEnc);
      expect(await cache.readDaily('2026-11-21'), isNull);
    });

    test('récents : sans doublon, plafonnés, plus récent en tête', () async {
      final cache = HadithCacheRepository(maxRecent: 3);
      for (final id in ['1', '2', '3', '4', '2']) {
        await cache.addRecent(
          HadeethEncRepository.parseHadith(_oneJson(id: id)),
        );
      }
      final ids = (await cache.readRecent()).map((h) => h.id).toList();
      expect(ids, ['henc_2', 'henc_4', 'henc_3']);
    });

    test('catégories expirées après 7 jours', () async {
      final cache = HadithCacheRepository();
      final now = DateTime(2026, 11, 20);
      await cache.writeRootCategories(
        _roots.map(HadithCategory.fromJson).toList(),
        now: now,
      );
      expect(await cache.readRootCategories(now: now), hasLength(2));
      expect(
        await cache.readRootCategories(now: now.add(const Duration(days: 8))),
        isNull,
      );
    });

    test('un cache corrompu est ignoré sans planter', () async {
      SharedPreferences.setMockInitialValues({'henc_recent_v1': '{oops'});
      expect(await HadithCacheRepository().readRecent(), isEmpty);
    });
  });

  group('HadithService', () {
    test('hadith du jour depuis HadeethEnc, puis servi par le cache',
        () async {
      final calls = <Uri>[];
      final service = _service(client: _server(calls: calls));

      final first = await service.getHadithOfTheDay();
      expect(first.isFallback, isFalse);
      expect(first.hadith.provider, HadithProvider.hadeethEnc);
      expect(calls, hasLength(3)); // catégories + liste + détail

      calls.clear();
      final second = await service.getHadithOfTheDay();
      expect(second.hadith.id, first.hadith.id);
      expect(calls, isEmpty);
    });

    test('hors ligne sans cache → Nawawi en français', () async {
      final result =
          await _service(client: _server(fail: true)).getHadithOfTheDay();

      expect(result.isFallback, isTrue);
      expect(result.hadith.provider, HadithProvider.nawawiLocal);
      expect(result.hadith.translation, isNotEmpty);
    });

    test('autre hadith hors ligne → pris dans le cache récent', () async {
      final online = _service(client: _server());
      final daily = await online.getHadithOfTheDay();
      await online.getAnotherHadith(excludeId: daily.hadith.id);

      final offline = _service(client: _server(fail: true));
      final result = await offline.getAnotherHadith(excludeId: daily.hadith.id);

      expect(result.isFallback, isTrue);
      expect(result.hadith.provider, HadithProvider.hadeethEnc);
      expect(result.hadith.id, isNot(daily.hadith.id));
    });

    test('autre hadith hors ligne sans cache → Nawawi', () async {
      final result = await _service(client: _server(fail: true))
          .getAnotherHadith(excludeId: 'nawawi_1');
      expect(result.hadith.provider, HadithProvider.nawawiLocal);
      expect(result.hadith.id, isNot('nawawi_1'));
    });

    test('réseau trop lent → secours sans attendre indéfiniment', () async {
      final slow = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return http.Response('[]', 200);
      });
      final service = HadithService(
        remote: HadeethEncRepository(client: slow),
        remoteTimeout: const Duration(milliseconds: 50),
      );
      final result = await service.getHadithOfTheDay();
      expect(result.isFallback, isTrue);
    });
  });

  group('UI', () {
    testWidgets('le badge ouvre l’explication des degrés', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: GradeBadge(grade: HadithGrade.hasan))),
      ));

      expect(find.text('Bon'), findsOneWidget);
      expect(tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(48));

      await tester.tap(find.byType(GradeBadge));
      await tester.pumpAndSettle();

      expect(find.byType(GradeInfoContent), findsOneWidget);
      expect(find.text('Comprendre les degrés d’authenticité'), findsOneWidget);
      expect(find.textContaining('Ce hadith est jugé « Bon »'), findsOneWidget);
    });

    testWidgets('pas de badge quand le degré est inconnu', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: GradeBadge(grade: HadithGrade.unknown)),
      ));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('la carte affiche le hadith et ouvre l’explication',
        (tester) async {
      // Les appels HTTP simulés passent par de vrais Futures.
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HadithCard(service: _service(client: _server())),
            ),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('Hadith du jour'), findsOneWidget);
      expect(find.textContaining('Les actes ne valent'), findsOneWidget);
      expect(find.text('Authentique'), findsOneWidget);

      await tester.tap(find.text('Lire l’explication complète'));
      // Pas de pumpAndSettle : le fond de l'écran de détail est animé en
      // boucle (AnimatedGlassBackground) et ne se « stabilise » jamais.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HadithDetailScreen), findsOneWidget);
      expect(find.text('Explication'), findsOneWidget);
      expect(find.text('Enseignements à retenir'), findsOneWidget);
    });
  });
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
