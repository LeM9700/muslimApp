import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/adhkar.dart';
import '../repositories/adhkar_repository.dart';

/// État et actions de l'écran Adhkar.
class AdhkarController extends ChangeNotifier {
  AdhkarController({
    AdhkarRepository? repository,
    AdhkarPeriod? initialPeriod,
    DateTime Function()? clock,
    void Function(bool completed)? haptic,
  })  : _repository = repository ?? AdhkarRepository(),
        _haptic = haptic ?? _defaultHaptic,
        _period = initialPeriod ?? _periodAt((clock ?? DateTime.now)());

  final AdhkarRepository _repository;
  final void Function(bool completed) _haptic;

  AdhkarBook? _book;
  AdhkarPeriod _period;
  bool _failed = false;
  bool _disposed = false;

  /// Répétitions faites par dhikr, pour le moment affiché (séance en cours).
  final Map<String, int> _counts = {};

  bool get isLoading => _book == null && !_failed;
  bool get failed => _failed;
  AdhkarBook? get book => _book;
  AdhkarPeriod get period => _period;
  List<AdhkarItem> get items => _book?.itemsFor(_period) ?? const [];

  int countOf(AdhkarItem item) => _counts[item.id] ?? 0;
  bool isDone(AdhkarItem item) => countOf(item) >= item.repeat;
  int get doneCount => items.where(isDone).length;

  /// Avant 15 h : matin (les adhkar du soir commencent après l'Asr).
  static AdhkarPeriod _periodAt(DateTime now) =>
      now.hour < 15 ? AdhkarPeriod.morning : AdhkarPeriod.evening;

  Future<void> load() async {
    try {
      _book = await _repository.load();
    } on Object catch (e) {
      debugPrint('Adhkar : lecture impossible ($e)');
      _failed = true;
    }
    _notify();
  }

  void setPeriod(AdhkarPeriod period) {
    if (period == _period) return;
    _period = period;
    _counts.clear();
    _notify();
  }

  /// Un appui sur la carte : une répétition de plus (jusqu'au nombre
  /// recommandé, ensuite plus rien).
  void tap(AdhkarItem item) {
    if (isDone(item)) return;
    _counts[item.id] = countOf(item) + 1;
    _haptic(isDone(item));
    _notify();
  }

  void reset() {
    _counts.clear();
    _notify();
  }

  static void _defaultHaptic(bool completed) => completed
      ? HapticFeedback.mediumImpact()
      : HapticFeedback.selectionClick();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
