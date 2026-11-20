import 'hadith_category.dart';

/// Résultat de recherche : une catégorie et son chemin depuis la racine.
class CategorySearchResult {
  final HadithCategory category;

  /// Ancêtres, de la racine au parent direct (vide pour une racine).
  final List<HadithCategory> ancestors;

  const CategorySearchResult(this.category, this.ancestors);

  /// « Le dogme › La foi en Allah » : situe le thème trouvé.
  String get breadcrumb => ancestors.map((c) => c.title).join(' › ');

  /// Chemin sans la racine (déjà signalée par l'icône du thème) : sur
  /// mobile, la racine longue masquait le parent direct, le plus utile.
  String get shortBreadcrumb => ancestors.length <= 1
      ? breadcrumb
      : ancestors.skip(1).map((c) => c.title).join(' › ');
}

/// Arborescence des thèmes, construite une fois à partir de la liste plate
/// renvoyée par `/categories/list`. Toutes les lectures sont en O(1) ou
/// O(profondeur) ; la recherche parcourt les ~420 catégories (négligeable).
class HadithCategoryTree {
  HadithCategoryTree(List<HadithCategory> categories)
      : _byId = {for (final c in categories) c.id: c},
        _children = _groupChildren(categories);

  final Map<String, HadithCategory> _byId;
  final Map<String?, List<HadithCategory>> _children;

  bool get isEmpty => _byId.isEmpty;

  List<HadithCategory> get roots => childrenOf(null);

  int get totalHadithCount =>
      roots.fold(0, (sum, c) => sum + c.hadithCount);

  HadithCategory? byId(String id) => _byId[id];

  /// Enfants directs, triés par identifiant (ordre éditorial HadeethEnc).
  List<HadithCategory> childrenOf(String? parentId) =>
      _children[parentId] ?? const [];

  /// Ancêtres de [id], de la racine au parent direct.
  List<HadithCategory> ancestorsOf(String id) {
    final path = <HadithCategory>[];
    var parentId = _byId[id]?.parentId;
    // Garde-fou contre une donnée cyclique : profondeur max raisonnable.
    for (var guard = 0; parentId != null && guard < 16; guard++) {
      final parent = _byId[parentId];
      if (parent == null) break;
      path.insert(0, parent);
      parentId = parent.parentId;
    }
    return path;
  }

  /// Thème racine de [id] (lui-même s'il est racine).
  HadithCategory? rootOf(String id) {
    final ancestors = ancestorsOf(id);
    return ancestors.isEmpty ? _byId[id] : ancestors.first;
  }

  /// Recherche insensible à la casse et aux accents dans les titres.
  /// Les titres qui commencent par la requête passent en premier, puis les
  /// thèmes les plus fournis.
  List<CategorySearchResult> search(String query, {int limit = 30}) {
    final q = normalizeForSearch(query);
    if (q.length < 2) return const [];
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();

    final matches = _byId.values.where((c) {
      final title = normalizeForSearch(c.title);
      return words.every(title.contains);
    }).toList()
      ..sort((a, b) {
        final aStarts = normalizeForSearch(a.title).startsWith(q) ? 0 : 1;
        final bStarts = normalizeForSearch(b.title).startsWith(q) ? 0 : 1;
        if (aStarts != bStarts) return aStarts - bStarts;
        return b.hadithCount.compareTo(a.hadithCount);
      });

    return matches
        .take(limit)
        .map((c) => CategorySearchResult(c, ancestorsOf(c.id)))
        .toList(growable: false);
  }

  static Map<String?, List<HadithCategory>> _groupChildren(
    List<HadithCategory> categories,
  ) {
    final map = <String?, List<HadithCategory>>{};
    for (final c in categories) {
      if (c.hadithCount <= 0) continue; // thème vide : rien à lire
      (map[c.parentId] ??= []).add(c);
    }
    for (final list in map.values) {
      list.sort((a, b) =>
          (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));
    }
    return map;
  }
}

/// Minuscules, sans accents ni ponctuation, espaces normalisés :
/// « Prière » et « priere » doivent se trouver mutuellement.
String normalizeForSearch(String input) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o',
    'û': 'u', 'ù': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
    'ḥ': 'h', 'ṣ': 's', 'ṭ': 't', 'ḍ': 'd', 'ẓ': 'z',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(accents[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r"[’'`\-_.,;:!?()«»\[\]]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
