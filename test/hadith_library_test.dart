import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_app/controllers/category_hadiths_controller.dart';
import 'package:muslim_app/controllers/hadith_library_controller.dart';
import 'package:muslim_app/models/hadith_category.dart';
import 'package:muslim_app/models/hadith_category_tree.dart';
import 'package:muslim_app/models/hadith_page.dart';
import 'package:muslim_app/repositories/hadeethenc_repository.dart';
import 'package:muslim_app/repositories/hadith_cache_repository.dart';
import 'package:muslim_app/screens/hadith_category_screen.dart';
import 'package:muslim_app/screens/hadith_detail_screen.dart';
import 'package:muslim_app/screens/hadith_library_screen.dart';
import 'package:muslim_app/services/hadith_library_service.dart';
import 'package:muslim_app/widgets/hadith/theme_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extrait réel (raccourci) de /categories/list/?language=fr
const _categories = [
  {'id': '3', 'title': 'Le dogme', 'hadeeths_count': '364', 'parent_id': null},
  {'id': '1', 'title': 'Le Noble Coran et ses sciences', 'hadeeths_count': '55', 'parent_id': null},
  {'id': '59', 'title': 'La foi en Allah', 'hadeeths_count': '113', 'parent_id': '3'},
  {'id': '60', 'title': 'La foi dans les Anges.', 'hadeeths_count': '28', 'parent_id': '3'},
  {'id': '130', 'title': 'Les Noms et Attributs d’Allah', 'hadeeths_count': '40', 'parent_id': '59'},
  {'id': '8', 'title': 'La révélation du Noble Coran', 'hadeeths_count': '10', 'parent_id': '1'},
  {'id': '999', 'title': 'Thème vide', 'hadeeths_count': '0', 'parent_id': '1'},
];

HadithCategoryTree _tree() =>
    HadithCategoryTree(_categories.map(HadithCategory.fromJson).toList());

Map<String, dynamic> _pageJson(int page, int lastPage, {int perPage = 2}) => {
      'data': [
        for (var i = 0; i < perPage; i++)
          {'id': '${page * 10 + i}', 'title': 'Hadith ${page * 10 + i}\r'},
      ],
      'meta': {
        'current_page': '$page',
        'last_page': lastPage,
        'total_items': lastPage * perPage,
        'per_page': '$perPage',
      },
    };

Map<String, dynamic> _oneJson(String id) => {
      'id': id,
      'title': 'Titre $id',
      'hadeeth': 'D’après Abû Hurayra : « Texte $id »',
      'hadeeth_intro': 'D’après Abû Hurayra :',
      'attribution': 'Rapporté par Muslim',
      'grade': 'Authentique',
      'grade_ar': 'صحيح',
      'explanation': 'Explication $id',
      'hints': ['Enseignement'],
      'hadeeth_ar': 'نص',
    };

/// Faux serveur. [failPages] : pages de liste qui échouent.
MockClient _server({
  bool offline = false,
  Set<int> failPages = const {},
  List<Uri>? calls,
  int lastPage = 3,
}) {
  return MockClient((request) async {
    calls?.add(request.url);
    if (offline) throw http.ClientException('offline');
    final q = request.url.queryParameters;
    final path = request.url.path;
    if (path.endsWith('/categories/list/')) {
      return http.Response.bytes(utf8.encode(json.encode(_categories)), 200);
    }
    if (path.endsWith('/hadeeths/list/')) {
      final page = int.parse(q['page']!);
      if (failPages.contains(page)) return http.Response('', 500);
      return http.Response(json.encode(_pageJson(page, lastPage)), 200);
    }
    if (path.endsWith('/hadeeths/one/')) {
      return http.Response.bytes(
        utf8.encode(json.encode(_oneJson(q['id']!))),
        200,
      );
    }
    return http.Response('', 404);
  });
}

HadithLibraryService _service(http.Client client, {DateTime? now}) =>
    HadithLibraryService(
      remote: HadeethEncRepository(client: client),
      cache: HadithCacheRepository(),
      clock: () => now ?? DateTime(2026, 11, 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HadithCategoryTree', () {
    test('racines et enfants triés par identifiant, thèmes vides exclus', () {
      final tree = _tree();
      expect(tree.roots.map((c) => c.id), ['1', '3']);
      expect(tree.childrenOf('3').map((c) => c.id), ['59', '60']);
      expect(tree.childrenOf('1').map((c) => c.id), ['8']);
      expect(tree.totalHadithCount, 419);
    });

    test('ancêtres et racine d’un sous-thème profond', () {
      final tree = _tree();
      expect(tree.ancestorsOf('130').map((c) => c.id), ['3', '59']);
      expect(tree.rootOf('130')?.id, '3');
      expect(tree.rootOf('3')?.id, '3');
      expect(tree.ancestorsOf('3'), isEmpty);
    });

    test('recherche insensible aux accents et à la casse', () {
      final results = _tree().search('REVELATION');
      expect(results.single.category.id, '8');
      expect(results.single.breadcrumb, 'Le Noble Coran et ses sciences');
      expect(_tree().search('noms attributs').single.shortBreadcrumb,
          'La foi en Allah');
    });

    test('tous les mots doivent correspondre, préfixe en premier', () {
      final tree = _tree();
      expect(tree.search('foi anges').single.category.id, '60');
      // « La foi… » commence par « la » : avant « Les Noms… ».
      final ids = tree.search('la').map((r) => r.category.id).toList();
      expect(ids.indexOf('59'), lessThan(ids.indexOf('130')));
    });

    test('requête trop courte → aucun résultat', () {
      expect(_tree().search('a'), isEmpty);
      expect(_tree().search('  '), isEmpty);
    });

    test('normalizeForSearch retire accents, apostrophes et ponctuation', () {
      expect(normalizeForSearch('L’Héritage, (Fiqh)!'), 'l heritage fiqh');
    });
  });

  group('HadithPage', () {
    test('parse meta en chaîne ou en entier et nettoie les titres', () {
      final page = HadithPage.fromJson(_pageJson(2, 3));
      expect(page.page, 2);
      expect(page.lastPage, 3);
      expect(page.hasMore, isTrue);
      expect(page.items.first.title, 'Hadith 20');
      expect(page.items.first.hadithId, 'henc_20');
    });

    test('retire la ponctuation orpheline en début de titre', () {
      expect(HadithSummary.cleanTitle('! Dis-moi quelque chose\r'),
          'Dis-moi quelque chose');
      expect(HadithSummary.cleanTitle('» , Ô gens'), 'Ô gens');
      expect(HadithSummary.cleanTitle('« Les actes »'), '« Les actes »');
    });

    test('dernière page → hasMore faux', () {
      expect(HadithPage.fromJson(_pageJson(3, 3)).hasMore, isFalse);
    });
  });

  group('HadithLibraryService', () {
    test('arborescence mise en cache sur disque et en mémoire', () async {
      final calls = <Uri>[];
      final service = _service(_server(calls: calls));
      await service.getCategoryTree();
      await service.getCategoryTree();
      expect(calls, hasLength(1));

      // Nouvelle instance (redémarrage) : lu depuis le disque.
      calls.clear();
      await _service(_server(calls: calls)).getCategoryTree();
      expect(calls, isEmpty);
    });

    test('hors ligne : cache expiré accepté plutôt qu’une erreur', () async {
      await _service(_server()).getCategoryTree();
      final later = DateTime(2027, 6, 1);
      final tree = await _service(_server(offline: true), now: later)
          .getCategoryTree();
      expect(tree.roots, hasLength(2));
    });

    test('hors ligne sans cache → HadeethEncException', () async {
      expect(
        () => _service(_server(offline: true)).getCategoryTree(),
        throwsA(isA<HadeethEncException>()),
      );
    });

    test('pages mémoïsées pendant la session', () async {
      final calls = <Uri>[];
      final service = _service(_server(calls: calls));
      await service.getHadithPage('3', 1);
      await service.getHadithPage('3', 1);
      await service.getHadithPage('3', 2);
      expect(calls, hasLength(2));
    });

    test('un hadith lu est ensuite servi hors ligne', () async {
      final online = _service(_server());
      final hadith = await online.getHadith('42');
      expect(hadith.explanation, 'Explication 42');
      expect((await online.getRecent()).first.id, 'henc_42');

      final offline = _service(_server(offline: true));
      expect((await offline.getHadith('42')).id, 'henc_42');
    });
  });

  group('CategoryHadithsController', () {
    test('charge les pages successives jusqu’à la dernière', () async {
      final c = CategoryHadithsController(
        categoryId: '3',
        service: _service(_server(lastPage: 2)),
      );
      await c.loadFirstPage();
      expect(c.items, hasLength(2));
      expect(c.hasMore, isTrue);
      expect(c.totalItems, 4);

      await c.loadMore();
      expect(c.items, hasLength(4));
      expect(c.hasMore, isFalse);

      await c.loadMore(); // sans effet
      expect(c.items, hasLength(4));
    });

    test('échec d’une page suivante : garde la liste et permet de réessayer',
        () async {
      final c = CategoryHadithsController(
        categoryId: '3',
        service: _service(_server(failPages: {2})),
      );
      await c.loadFirstPage();
      await c.loadMore();
      expect(c.hasError, isTrue);
      expect(c.isInitial, isFalse);
      expect(c.items, hasLength(2));
    });

    test('échec de la première page → état initial en erreur', () async {
      final c = CategoryHadithsController(
        categoryId: '3',
        service: _service(_server(offline: true)),
      );
      await c.loadFirstPage();
      expect(c.isInitial, isTrue);
      expect(c.hasError, isTrue);
    });

    test('ignore les appels concurrents (défilement rapide)', () async {
      final calls = <Uri>[];
      final c = CategoryHadithsController(
        categoryId: '3',
        service: _service(_server(calls: calls)),
      );
      await Future.wait([c.loadMore(), c.loadMore(), c.loadMore()]);
      expect(calls, hasLength(1));
    });
  });

  group('HadithLibraryController', () {
    test('recherche active à partir de 2 caractères', () async {
      final c = HadithLibraryController(service: _service(_server()));
      await c.load();
      expect(c.status, LoadStatus.ready);

      c.setQuery('a');
      expect(c.isSearching, isFalse);
      c.setQuery('anges');
      expect(c.searchResults.single.category.id, '60');
    });

    test('hors ligne : erreur mais récents conservés', () async {
      await _service(_server()).getHadith('7');
      final c = HadithLibraryController(service: _service(_server(offline: true)));
      await c.load();
      expect(c.status, LoadStatus.error);
      expect(c.recent.single.id, 'henc_7');
    });
  });

  test('formatHadithCount : singulier, pluriel, milliers', () {
    expect(formatHadithCount(1), '1 hadith');
    expect(formatHadithCount(55), '55 hadiths');
    expect(formatHadithCount(2115), '2 115 hadiths');
  });

  group('UI', () {
    Future<void> pumpAsync(WidgetTester tester, Widget widget) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: widget));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('accueil : thèmes, compteur et recherche', (tester) async {
      await pumpAsync(
        tester,
        HadithLibraryScreen(service: _service(_server())),
      );

      expect(find.text('Le dogme'), findsOneWidget);
      expect(find.text('Le Noble Coran et ses sciences'), findsOneWidget);
      expect(find.textContaining('419 hadiths traduits'), findsOneWidget);
      expect(find.text('Comprendre les degrés d’authenticité'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'anges');
      await tester.pump();
      expect(find.text('La foi dans les Anges.'), findsOneWidget);
      expect(find.text('1 thème trouvé'), findsOneWidget);
      expect(find.text('Le Noble Coran et ses sciences'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.textContaining('Aucun thème ne correspond'), findsOneWidget);
    });

    testWidgets('hors ligne : message clair et bouton Réessayer',
        (tester) async {
      await pumpAsync(
        tester,
        HadithLibraryScreen(service: _service(_server(offline: true))),
      );
      expect(find.text('Bibliothèque indisponible hors connexion'),
          findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('thème : sous-thèmes, liste et ouverture du détail',
        (tester) async {
      final service = _service(_server());
      await tester.runAsync(service.getCategoryTree);
      final dogme = (await tester.runAsync(service.getCategoryTree))!
          .byId('3')!;

      await pumpAsync(
        tester,
        HadithCategoryScreen(category: dogme, service: service),
      );

      expect(find.text('Le dogme'), findsWidgets);
      expect(find.text('Affiner par sous-thème'), findsOneWidget);
      expect(find.text('La foi en Allah · 113'), findsOneWidget);
      expect(find.text('Hadith 10'), findsOneWidget);

      await tester.tap(find.text('Hadith 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HadithDetailScreen), findsOneWidget);
    });
  });
}
