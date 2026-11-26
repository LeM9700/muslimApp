import '../models/dhikr.dart';

/// Ce qui vient de se passer après un appui (sert au retour haptique).
enum TasbihEvent {
  /// Simple compte.
  counted,

  /// Objectif de la formule atteint (mode simple : un tour de plus).
  targetReached,

  /// Étape d'un enchaînement terminée, la suivante commence.
  stepDone,

  /// Enchaînement complet (ex. les 100 après la prière).
  sequenceDone,
}

/// Compteur de dhikr, pur et testable (aucune dépendance Flutter).
///
/// - Mode simple : une formule, un objectif (33, 99, 100) ou sans limite ;
///   l'objectif atteint, l'appui suivant commence un nouveau tour.
/// - Mode enchaînement : les étapes se suivent automatiquement ; à la fin,
///   l'appui suivant recommence au début.
class TasbihCounter {
  TasbihCounter(List<TasbihStep> steps)
      : assert(steps.isNotEmpty),
        steps = List.unmodifiable(steps);

  /// Une seule formule ; [target] 0 = sans limite.
  factory TasbihCounter.single(Dhikr dhikr, int target) =>
      TasbihCounter([TasbihStep(dhikr, target)]);

  factory TasbihCounter.afterPrayer() => TasbihCounter(afterPrayerSequence);

  final List<TasbihStep> steps;

  int _step = 0;
  int _count = 0;
  int _rounds = 0;
  bool _finished = false;

  bool get isSequence => steps.length > 1;
  TasbihStep get current => steps[_step];
  int get stepIndex => _step;
  int get count => _count;

  /// Tours complets (mode simple) ou enchaînements complets.
  int get rounds => _rounds;

  /// Progression de l'étape (0 à 1), `null` sans objectif.
  double? get progress =>
      current.target <= 0 ? null : (_count / current.target).clamp(0.0, 1.0);

  TasbihEvent tap() {
    // Après un objectif ou une fin d'enchaînement : on repart.
    if (_finished) {
      _finished = false;
      _step = 0;
      _count = 0;
    } else if (current.target > 0 && _count >= current.target) {
      _step++;
      _count = 0;
    }

    _count++;
    if (current.target <= 0 || _count < current.target) return TasbihEvent.counted;

    final last = _step == steps.length - 1;
    if (!last) return TasbihEvent.stepDone;
    _rounds++;
    _finished = true;
    return isSequence ? TasbihEvent.sequenceDone : TasbihEvent.targetReached;
  }

  void reset() {
    _step = 0;
    _count = 0;
    _finished = false;
  }
}
