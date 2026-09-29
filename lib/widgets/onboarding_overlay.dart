import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// =============================================================================
// Onboarding progressif — Q11 : tooltips contextuels premier lancement
// Design : spotlight sur le widget cible + glass bubble iridescent
// =============================================================================

/// Un step d'onboarding : pointe vers un GlobalKey sur l'écran.
class OnboardingStep {
  /// Clé du widget cible (pour récupérer sa position via RenderBox).
  final GlobalKey targetKey;

  /// Titre court du tooltip (max ~30 chars).
  final String title;

  /// Description contextuelle (max ~80 chars).
  final String description;

  /// Icône affichée dans la bulle.
  final IconData icon;

  /// Padding autour du spotlight (agrandit la zone illuminée).
  final double spotlightPadding;

  /// Rayon du spotlight (0 = rect, >0 = rounded).
  final double spotlightRadius;

  const OnboardingStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.spotlightPadding = 12.0,
    this.spotlightRadius = 16.0,
  });
}

/// Overlay d'onboarding progressif.
/// Affiche un spotlight + bulle glass au-dessus de toute l'UI.
///
/// Usage :
/// ```dart
/// OnboardingOverlay.show(
///   context,
///   steps: steps,
///   onComplete: () => OnboardingService.markHomeDone(),
/// );
/// ```
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  /// Lance l'overlay onboarding par-dessus le contexte courant.
  static Future<void> show({
    required BuildContext context,
    required List<OnboardingStep> steps,
    required VoidCallback onComplete,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => OnboardingOverlay(
          steps: steps,
          onComplete: onComplete,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Rect? _targetRect;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    // Délai pour laisser le build se terminer avant de lire les positions.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep(0));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showStep(int index) {
    if (!mounted) return;
    final step = widget.steps[index];
    final rect = _getRectForKey(step.targetKey);
    setState(() {
      _currentStep = index;
      _targetRect = rect;
    });
    _animController
      ..reset()
      ..forward();
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _showStep(_currentStep + 1);
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    widget.onComplete();
    if (mounted) Navigator.of(context).pop();
  }

  /// Récupère le Rect absolu du widget via son GlobalKey.
  Rect? _getRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final target = _targetRect;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Scrim avec trou ─────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _next, // Tap n'importe où → avance
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, __) => CustomPaint(
                  painter: _SpotlightPainter(
                    targetRect: target != null
                        ? target.inflate(step.spotlightPadding)
                        : null,
                    borderRadius: step.spotlightRadius,
                    opacity: _fadeAnim.value,
                  ),
                ),
              ),
            ),
          ),

          // ── Bulle glass ─────────────────────────────────────────────────
          if (target != null)
            _buildBubble(context, step, target),

          // ── Bouton Passer ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    backgroundColor: AppColors.glassMedium,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  child: Text(
                    '${_currentStep + 1}/${widget.steps.length}  Passer',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    OnboardingStep step,
    Rect target,
  ) {
    final screenSize = MediaQuery.of(context).size;
    const bubbleWidth = 280.0;
    const bubbleMaxHeight = 160.0;
    const arrowSize = 10.0;
    const gap = 16.0;

    // Position bulle : au-dessus ou en-dessous selon l'espace disponible
    final spaceBelow = screenSize.height - target.bottom;
    final showAbove = spaceBelow < bubbleMaxHeight + gap + arrowSize + 40;

    final bubbleTop = showAbove
        ? target.top - bubbleMaxHeight - arrowSize - gap
        : target.bottom + arrowSize + gap;

    // Centrer horizontalement par rapport à la cible, clamp dans l'écran
    double bubbleLeft = target.center.dx - bubbleWidth / 2;
    bubbleLeft = bubbleLeft.clamp(12.0, screenSize.width - bubbleWidth - 12);

    final isLast = _currentStep == widget.steps.length - 1;

    return Positioned(
      top: bubbleTop,
      left: bubbleLeft,
      width: bubbleWidth,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _next,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xCCFFFFFF), // blanc 80%
                        Color(0xAAF8F0FF), // lavande légère
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.iridStart.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icône + titre
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.emerald, AppColors.copper],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(step.icon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Description
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // CTA + indicateurs
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Points de progression
                          Row(
                            children: List.generate(
                              widget.steps.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                width: i == _currentStep ? 20 : 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: i == _currentStep
                                      ? const LinearGradient(
                                          colors: [AppColors.emerald, AppColors.copper],
                                        )
                                      : null,
                                  color: i == _currentStep
                                      ? null
                                      : AppColors.textMuted.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),

                          // Bouton suivant
                          GestureDetector(
                            onTap: _next,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.emerald, AppColors.copper],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isLast ? 'Terminé ✓' : 'Suivant →',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Painter — scrim sombre avec trou transparent sur la cible
// =============================================================================

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;
  final double opacity;

  const _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = Colors.black.withOpacity(0.65 * opacity);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, scrimPaint);
      return;
    }

    // Dessine le scrim avec un trou via saveLayer + BlendMode.clear
    canvas.saveLayer(Offset.zero & size, Paint());

    // Fond sombre
    canvas.drawRect(Offset.zero & size, scrimPaint);

    // Trou transparent autour de la cible
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect!,
        Radius.circular(borderRadius),
      ),
      Paint()..blendMode = BlendMode.clear,
    );

    // Halo iridescent autour du trou
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect!.inflate(2),
        Radius.circular(borderRadius + 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB39DDB).withOpacity(0.7 * opacity), // iridStart
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect ||
      old.opacity != opacity;
}
