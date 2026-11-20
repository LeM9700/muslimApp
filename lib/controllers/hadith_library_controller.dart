import 'package:flutter/foundation.dart';

import '../models/hadith.dart';
import '../models/hadith_category_tree.dart';
import '../services/hadith_library_service.dart';

enum LoadStatus { loading, ready, error }

/// État de l'écran d'accueil de la Bibliothèque : thèmes, recherche et
/// lectures récentes.
class HadithLibraryController extends ChangeNotifier {
  HadithLibraryController({HadithLibraryService? service})
      : _service = service ?? HadithLibraryService.instance;

  final HadithLibraryService _service;

  LoadStatus _status = LoadStatus.loading;
  HadithCategoryTree? _tree;
  List<Hadith> _recent = const [];
  String _query = '';
  bool _disposed = false;

  LoadStatus get status => _status;
  HadithCategoryTree? get tree => _tree;
  List<Hadith> get recent => _recent;
  String get query => _query;
  bool get isSearching => _query.trim().length >= 2;

  List<CategorySearchResult> get searchResults =>
      isSearching ? (_tree?.search(_query) ?? const []) : const [];

  /// Charge thèmes et récents en parallèle. Les récents restent affichés
  /// même si les thèmes échouent (lecture hors connexion).
  Future<void> load({bool forceRefresh = false}) async {
    _status = LoadStatus.loading;
    _notify();
    final recentFuture = _service.getRecent();
    try {
      _tree = await _service.getCategoryTree(forceRefresh: forceRefresh);
      _status = LoadStatus.ready;
    } on Object {
      _status = LoadStatus.error;
    }
    _recent = await recentFuture;
    _notify();
  }

  /// Recharge les récents (après retour d'une lecture).
  Future<void> refreshRecent() async {
    _recent = await _service.getRecent();
    _notify();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _notify();
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
