import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/dhikr.dart';
import '../repositories/tasbih_repository.dart';
import '../services/tasbih_counter.dart';

/// État et actions de l'écran Tasbih.
class TasbihController extends ChangeNotifier {
  TasbihController({
    TasbihRepository? store,
    DateTime Function()? clock,
    void Function(TasbihEvent event)? haptic,
    this.saveDelay = const Duration(seconds: 2),
  })  : _store = store ?? TasbihRepository(),
        _clock = clock ?? DateTime.now,
        _haptic = haptic ?? _defaultHaptic;

  final TasbihRepository _store;
  final DateTime Function() _clock;
  final void Function(TasbihEvent) _haptic;

  /// [⚡ PERF] Le total est écrit au plus une fois par [saveDelay] (et à
  /// la fermeture), pas à chaque appui.
  final Duration saveDelay;

  static const List<int> targets = [33, 99, 100, 0];

  TasbihCounter _counter = TasbihCounter.single(Dhikr.subhanAllah, 33);
  Dhikr _dhikr = Dhikr.subhanAllah;
  int _target = 33;
  bool _afterPrayer = false;
  int _todayTotal = 0;
  String _todayKey = '';
  TasbihEvent? _lastEvent;
  Timer? _saveTimer;
  bool _disposed = false;

  TasbihCounter get counter => _counter;
  Dhikr get dhikr => _counter.current.dhikr;
  int get target => _target;
  bool get afterPrayer => _afterPrayer;
  int get todayTotal => _todayTotal;
  TasbihEvent? get lastEvent => _lastEvent;

  Future<void> load() async {
    _todayKey = _keyOf(_clock());
    _todayTotal = await _store.readTotal(_todayKey);
    _notify();
  }

  void tap() {
    final key = _keyOf(_clock());
    if (key != _todayKey) {
      // Minuit passé pendant la séance : nouveau jour, nouveau total.
      _todayKey = key;
      _todayTotal = 0;
    }
    _lastEvent = _counter.tap();
    _todayTotal++;
    _haptic(_lastEvent!);
    _scheduleSave();
    _notify();
  }

  void reset() {
    _counter.reset();
    _lastEvent = null;
    _notify();
  }

  void selectDhikr(Dhikr dhikr) {
    _dhikr = dhikr;
    _afterPrayer = false;
    _rebuild();
  }

  void selectTarget(int target) {
    _target = target;
    _afterPrayer = false;
    _rebuild();
  }

  /// Enchaînement 33/33/33 + 1 après la prière (Muslim 597).
  void setAfterPrayer(bool on) {
    _afterPrayer = on;
    _rebuild();
  }

  void _rebuild() {
    _counter = _afterPrayer
        ? TasbihCounter.afterPrayer()
        : TasbihCounter.single(_dhikr, _target);
    _lastEvent = null;
    _notify();
  }

  void _scheduleSave() {
    _saveTimer ??= Timer(saveDelay, () {
      _saveTimer = null;
      _store.writeTotal(_todayKey, _todayTotal);
    });
  }

  /// Écrit le total immédiatement (fermeture de l'écran).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_todayKey.isNotEmpty) await _store.writeTotal(_todayKey, _todayTotal);
  }

  static String _keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static void _defaultHaptic(TasbihEvent event) {
    switch (event) {
      case TasbihEvent.counted:
        HapticFeedback.selectionClick();
      case TasbihEvent.stepDone:
        HapticFeedback.mediumImpact();
      case TasbihEvent.targetReached:
      case TasbihEvent.sequenceDone:
        HapticFeedback.heavyImpact();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    flush();
    super.dispose();
  }
}
