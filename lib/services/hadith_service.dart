import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/hadith.dart';
import '../models/hadith_category.dart';
import '../repositories/hadeethenc_repository.dart';
import '../repositories/hadith_cache_repository.dart';
import 'daily_hadith_selector.dart';
import 'hadith_api_service.dart';
import 'local_content_service.dart';

/// Résultat d'un chargement, avec l'information utile à l'UI.
class HadithResult {
  final Hadith hadith;

  /// Vrai si HadeethEnc n'a pas répondu et qu'on sert un contenu de secours
  /// (cache récent ou Nawawi embarqués).
  final bool isFallback;

  const HadithResult(this.hadith, {this.isFallback = false});
}

/// Orchestration des hadiths affichés dans l'app (toujours en français).
///
/// Hadith du jour : cache du jour → HadeethEnc → Sunnah.com (si FR) →
/// Nawawi embarqués.
/// Autre hadith : HadeethEnc aléatoire → cache récent → Nawawi embarqués.
///
/// Les Nawawi embarqués (assets) ne peuvent pas échouer hors ligne, ce qui
/// garantit qu'un hadith est toujours affiché.
class HadithService {
  HadithService({
    HadeethEncRepository? remote,
    HadithCacheRepository? cache,
    DateTime Function()? clock,
    Random? random,
    this.remoteTimeout = const Duration(seconds: 10),
  })  : _remote = remote ?? HadeethEncRepository(),
        _cache = cache ?? HadithCacheRepository(),
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final HadeethEncRepository _remote;
  final HadithCacheRepository _cache;
  final DateTime Function() _clock;
  final Random _random;

  /// [⚠️ PROD] Délai global du chemin réseau (jusqu'à 3 requêtes en série).
  /// Au-delà, on sert le secours : mieux vaut un hadith Nawawi tout de suite
  /// qu'un chargement de 20 s sur un réseau mobile faible.
  final Duration remoteTimeout;

  /// Hadith du jour, identique pour tous les utilisateurs à une date donnée.
  Future<HadithResult> getHadithOfTheDay() async {
    final now = _clock();
    final dateKey = DailyHadithSelector.dateKey(now);

    final cached = await _safe(() => _cache.readDaily(dateKey));
    if (cached != null) return HadithResult(cached);

    final remote = await _safe(
      () => _fetchDailyFromRemote(now).timeout(remoteTimeout),
    );
    if (remote != null) {
      await _safe(() => _cache.writeDaily(dateKey, remote));
      await _safe(() => _cache.addRecent(remote));
      return HadithResult(remote);
    }

    final sunnah = await _safe(HadithApiService.getHadithOfTheDay);
    if (sunnah != null) return HadithResult(sunnah, isFallback: true);

    final local = await _safe(LocalContentService.getHadithOfTheDay);
    return HadithResult(local ?? _lastResort, isFallback: true);
  }

  /// Un autre hadith que [excludeId] (bouton « Autre hadith »).
  Future<HadithResult> getAnotherHadith({String? excludeId}) async {
    final remote = await _safe(
      () => _fetchRandomFromRemote(excludeId).timeout(remoteTimeout),
    );
    if (remote != null) {
      await _safe(() => _cache.addRecent(remote));
      return HadithResult(remote);
    }

    final recent = (await _safe(_cache.readRecent) ?? const <Hadith>[])
        .where((h) => h.id != excludeId)
        .toList();
    if (recent.isNotEmpty) {
      return HadithResult(
        recent[_random.nextInt(recent.length)],
        isFallback: true,
      );
    }

    final local = await _safe(
      () => LocalContentService.getRandomHadith(excludeId: excludeId),
    );
    return HadithResult(local ?? _lastResort, isFallback: true);
  }

  Future<Hadith> _fetchDailyFromRemote(DateTime now) async {
    final roots = await _rootCategories(now);
    final total = DailyHadithSelector.totalCount(roots);
    final index = DailyHadithSelector.indexForDate(now, total);
    final slot = DailyHadithSelector.slotForIndex(roots, index);
    final id = await _remote.fetchHadithIdAt(
      categoryId: slot.categoryId,
      position: slot.position,
    );
    return _remote.fetchHadith(id);
  }

  Future<Hadith> _fetchRandomFromRemote(String? excludeId) async {
    final roots = await _rootCategories(_clock());
    final total = DailyHadithSelector.totalCount(roots);
    // Deux essais suffisent : la probabilité de retomber sur le même
    // hadith parmi ~2 000 est négligeable.
    for (var attempt = 0; attempt < 2; attempt++) {
      final slot =
          DailyHadithSelector.slotForIndex(roots, _random.nextInt(total));
      final id = await _remote.fetchHadithIdAt(
        categoryId: slot.categoryId,
        position: slot.position,
      );
      if ('henc_$id' != excludeId) return _remote.fetchHadith(id);
    }
    throw const HadeethEncException('Aucun nouveau hadith trouvé');
  }

  Future<List<HadithCategory>> _rootCategories(DateTime now) async {
    final cached = await _safe(() => _cache.readRootCategories(now: now));
    if (cached != null && DailyHadithSelector.totalCount(cached) > 0) {
      return cached;
    }
    final roots = await _remote.fetchRootCategories();
    if (DailyHadithSelector.totalCount(roots) == 0) {
      throw const HadeethEncException('Aucune catégorie disponible');
    }
    await _safe(() => _cache.writeRootCategories(roots, now: now));
    return roots;
  }

  /// Exécute [action] en avalant l'erreur : chaque source est optionnelle,
  /// l'échec de l'une déclenche simplement la suivante.
  Future<T?> _safe<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      debugPrint('HadithService: source indisponible ($e)');
      return null;
    }
  }

  /// Ultime recours si même l'asset embarqué est illisible.
  static const Hadith _lastResort = Hadith(
    id: 'fallback_intentions',
    text: 'Les actes ne valent que par les intentions, et chacun n’aura que '
        'ce qu’il a eu l’intention de faire.',
    translation: 'Les actes ne valent que par les intentions, et chacun '
        'n’aura que ce qu’il a eu l’intention de faire.',
    source: 'Rapporté par Al-Bukhârî et Muslim',
    reviewed: true,
    grade: 'Authentique',
    provider: HadithProvider.other,
  );
}
