import 'package:flutter/foundation.dart';

import '../models/hadith.dart';
import '../models/hadith_category_tree.dart';
import '../models/hadith_page.dart';
import '../repositories/hadeethenc_repository.dart';
import '../repositories/hadith_cache_repository.dart';

/// Règles d'accès aux données de la Bibliothèque de hadiths.
///
/// - Arborescence des thèmes : cache disque 7 jours, sinon API ; en cas
///   d'échec réseau, un cache expiré vaut mieux que rien.
/// - Pages de liste : mémoïsées en mémoire pour la session (retour arrière
///   instantané, pas de requête répétée en changeant de thème).
/// - Détail : cache disque (récents / hadith du jour), sinon API, puis
///   ajouté aux récents pour la lecture hors connexion.
class HadithLibraryService {
  HadithLibraryService({
    HadeethEncRepository? remote,
    HadithCacheRepository? cache,
    DateTime Function()? clock,
    this.pageSize = 20,
  })  : _remote = remote ?? HadeethEncRepository(),
        _cache = cache ?? HadithCacheRepository(),
        _clock = clock ?? DateTime.now;

  /// Instance partagée : la mémoïsation des pages profite à tous les écrans.
  static final HadithLibraryService instance = HadithLibraryService();

  final HadeethEncRepository _remote;
  final HadithCacheRepository _cache;
  final DateTime Function() _clock;
  final int pageSize;

  HadithCategoryTree? _tree;
  final Map<String, HadithPage> _pages = {};

  /// Arborescence des thèmes. Lève [HadeethEncException] si ni le réseau
  /// ni aucun cache ne sont disponibles.
  Future<HadithCategoryTree> getCategoryTree({bool forceRefresh = false}) async {
    if (!forceRefresh && _tree != null) return _tree!;
    final now = _clock();

    if (!forceRefresh) {
      final fresh = await _safe(() => _cache.readAllCategories(now: now));
      if (fresh != null && fresh.isNotEmpty) {
        return _tree = HadithCategoryTree(fresh);
      }
    }

    try {
      final categories = await _remote.fetchAllCategories();
      if (categories.isEmpty) {
        throw const HadeethEncException('Aucun thème disponible');
      }
      await _safe(() => _cache.writeAllCategories(categories, now: now));
      return _tree = HadithCategoryTree(categories);
    } on HadeethEncException {
      // Hors connexion : on accepte un cache même expiré.
      final stale = await _safe(
        () => _cache.readAllCategories(now: now, maxAge: const Duration(days: 3650)),
      );
      if (stale != null && stale.isNotEmpty) {
        return _tree = HadithCategoryTree(stale);
      }
      rethrow;
    }
  }

  /// Page [page] des hadiths de [categoryId] (sous-thèmes inclus).
  Future<HadithPage> getHadithPage(String categoryId, int page) async {
    final key = '$categoryId:$page';
    final cached = _pages[key];
    if (cached != null) return cached;
    final result = await _remote.fetchHadithPage(
      categoryId: categoryId,
      page: page,
      perPage: pageSize,
    );
    _pages[key] = result;
    return result;
  }

  /// Hadith complet à partir de son identifiant HadeethEnc brut.
  Future<Hadith> getHadith(String rawId) async {
    final cached = await _safe(() => _cache.findById('henc_$rawId'));
    if (cached != null) return cached;
    final hadith = await _remote.fetchHadith(rawId);
    await _safe(() => _cache.addRecent(hadith));
    return hadith;
  }

  /// Derniers hadiths lus (disponibles hors connexion).
  Future<List<Hadith>> getRecent() async =>
      await _safe(_cache.readRecent) ?? const [];

  Future<T?> _safe<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      debugPrint('HadithLibraryService: cache indisponible ($e)');
      return null;
    }
  }
}
