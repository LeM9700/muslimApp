import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// =============================================================================
// Widgets Lottie — Q10 : animations contextuelles
// Toutes les animations sont des assets locaux (pas de réseau).
// =============================================================================

/// Rings émeraude pulsants — affiché pendant l'heure de prière.
///
/// Boucle indéfinie. Stopper en le retirant du tree.
/// [⚡ PERF] Ne pas superposer avec d'autres BackdropFilter.
class PrayerGlowAnimation extends StatelessWidget {
  /// Taille du conteneur carré (défaut 200).
  final double size;

  const PrayerGlowAnimation({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/lottie/prayer_glow.json',
        repeat: true,
        fit: BoxFit.contain,
        // Lottie 3.x : delegates = null → décode sur l'isolate Flutter par défaut
      ),
    );
  }
}

/// Cercle émeraude + sparkles dorés — joue une fois quand la Qibla est trouvée.
///
/// [onComplete] appelé à la fin de l'animation (use it to hide the widget).
class QiblaFoundAnimation extends StatefulWidget {
  final double size;

  /// Callback déclenché quand l'animation est terminée.
  final VoidCallback? onComplete;

  const QiblaFoundAnimation({
    super.key,
    this.size = 200,
    this.onComplete,
  });

  @override
  State<QiblaFoundAnimation> createState() => _QiblaFoundAnimationState();
}

class _QiblaFoundAnimationState extends State<QiblaFoundAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Durée synchro avec op/fr du JSON : 72 frames / 60 fps = 1.2s
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward().whenComplete(() {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        'assets/lottie/qibla_found.json',
        controller: _controller,
        repeat: false,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Burst émeraude/cuivre de 6 points — réponse correcte au quiz.
///
/// Joue une fois (0.9s = 54 frames / 60fps).
/// [onComplete] facultatif, appelé à la fin.
class QuizCorrectAnimation extends StatefulWidget {
  final double size;
  final VoidCallback? onComplete;

  const QuizCorrectAnimation({
    super.key,
    this.size = 200,
    this.onComplete,
  });

  @override
  State<QuizCorrectAnimation> createState() => _QuizCorrectAnimationState();
}

class _QuizCorrectAnimationState extends State<QuizCorrectAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 54 frames / 60 fps = 0.9s — correspond au TweenSequence existant
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward().whenComplete(() {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        'assets/lottie/quiz_correct.json',
        controller: _controller,
        repeat: false,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Affiche la Lottie quiz_correct centrée sur un widget existant.
///
/// Usage : overlay dans un Stack, au-dessus du bouton de réponse.
/// Se retire automatiquement après [onComplete].
///
/// ```dart
/// Stack(children: [
///   AnswerButton(...),
///   if (_showBurst)
///     const Positioned.fill(
///       child: QuizCorrectBurst(onComplete: () => setState(() => _showBurst = false)),
///     ),
/// ])
/// ```
class QuizCorrectBurst extends StatelessWidget {
  final VoidCallback? onComplete;

  const QuizCorrectBurst({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: QuizCorrectAnimation(
          size: 240,
          onComplete: onComplete,
        ),
      ),
    );
  }
}
