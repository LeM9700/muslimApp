import 'package:flutter/foundation.dart';

import '../models/hadith_page.dart';
import '../services/hadith_library_service.dart';

/// Pagination infinie des hadiths d'un thème.
///
/// Distingue l'échec de la première page (écran d'erreur plein) de l'échec
/// d'une page suivante (bandeau « Réessayer » en bas de liste, sans perdre
/// ce qui est déjà affiché).
class CategoryHadithsController extends ChangeNotifier {
  CategoryHadithsController({
    required this.categoryId,
    HadithLibraryService? service,
  }) : _service = service ?? HadithLibraryService.instance;

  final String categoryId;
  final HadithLibraryService _service;

  final List<HadithSummary> _items = [];
  int _loadedPage = 0;
  int _lastPage = 1;
  int _totalItems = 0;
  bool _isLoading = false;
  Object? _error;
  bool _disposed = false;

  List<HadithSummary> get items => List.unmodifiable(_items);
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  bool get hasMore => _loadedPage < _lastPage;
  bool get hasError => _error != null;

  /// Aucune donnée encore : afficher un squelette ou une erreur plein écran.
  bool get isInitial => _loadedPage == 0;

  Future<void> loadFirstPage() async {
    _items.clear();
    _loadedPage = 0;
    _lastPage = 1;
    await loadMore();
  }

  /// Charge la page suivante. Ignore les appels concurrents (scroll rapide).
  Future<void> loadMore() async {
    if (_isLoading || !hasMore) return;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final page = await _service.getHadithPage(categoryId, _loadedPage + 1);
      // Évite les doublons si l'API décale ses pages entre deux appels.
      final known = _items.map((h) => h.id).toSet();
      _items.addAll(page.items.where((h) => known.add(h.id)));
      _loadedPage = page.page > 0 ? page.page : _loadedPage + 1;
      _lastPage = page.lastPage;
      _totalItems = page.totalItems;
    } on Object catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
