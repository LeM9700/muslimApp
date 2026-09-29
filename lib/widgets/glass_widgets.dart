import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/app_theme.dart';

// =============================================================================
// Widgets glassmorphism iridescent CLAIR
// Design DNA : fond pastel peach/lavande/rose + frosted glass cards
// [⚡ PERF] BackdropFilter est coûteux. Max 5-6 simultanés à l'écran.
// =============================================================================

/// Conteneur glass générique — frosted glass sur fond lumineux.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color color;
  final Border? border;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 12,
    this.color = AppColors.glassLight,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.2,
                  ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.15),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Card glass avec bordure iridescente (violet → rose → bleu).
/// Utiliser pour les cards principales de l'écran d'accueil.
/// Paramètre [heroTag] active un Hero widget pour shared element transitions.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final List<Color>? gradientColors;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool iridescent;
  final String? heroTag;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.gradientColors,
    this.padding,
    this.margin,
    this.onTap,
    this.iridescent = true,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ??
                  [
                    Colors.white.withOpacity(0.40),
                    Colors.white.withOpacity(0.22),
                  ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.38),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.iridStart.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(-4, -4),
              ),
              BoxShadow(
                color: AppColors.iridEnd.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(4, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    // Bordure iridescente (gradient 1.2px autour du clip)
    if (iridescent) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.iridStart,
              AppColors.iridMid,
              AppColors.iridEnd,
            ],
          ),
        ),
        padding: const EdgeInsets.all(1.2),
        child: card,
      );
    }

    // Shared element transition
    if (heroTag != null) {
      card = Hero(tag: heroTag!, child: card);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return Container(margin: margin ?? const EdgeInsets.all(0), child: card);
  }
}

/// Bouton glass flottant (icône)
class FloatingGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double size;
  final double borderRadius;

  const FloatingGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.size = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.2,
              ),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.15),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IridescentBackground — fond gradient animé pastel (peach → lavande → rose)
// Remplace AnimatedGlassBackground (dark) dans MainNavigation
// =============================================================================

class AnimatedGlassBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGlassBackground({super.key, required this.child});

  @override
  State<AnimatedGlassBackground> createState() =>
      _AnimatedGlassBackgroundState();
}

class _AnimatedGlassBackgroundState extends State<AnimatedGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient de fond iridescent animé
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Color.lerp(
                      AppColors.backgroundStart,
                      AppColors.backgroundEnd,
                      _animation.value,
                    )!,
                    Color.lerp(
                      AppColors.backgroundMid,
                      AppColors.backgroundStart,
                      _animation.value,
                    )!,
                    Color.lerp(
                      AppColors.backgroundEnd,
                      AppColors.backgroundMid,
                      _animation.value,
                    )!,
                  ],
                ),
              ),
            );
          },
        ),

        // Orbes lumineux flottants (ambiance éthérée)
        ...List.generate(5, _buildFloatingOrb),

        // Contenu principal
        widget.child,
      ],
    );
  }

  Widget _buildFloatingOrb(int index) {
    final delays  = [0.0, 0.2, 0.4, 0.6, 0.8];
    final sizes   = [120.0, 160.0, 90.0, 140.0, 110.0];
    final colors  = [
      AppColors.iridStart.withOpacity(0.18),
      AppColors.iridMid.withOpacity(0.14),
      AppColors.emerald.withOpacity(0.10),
      AppColors.iridEnd.withOpacity(0.16),
      AppColors.copper.withOpacity(0.10),
    ];
    final positions = [
      const {'top': 60.0,  'left': 30.0},
      const {'top': 300.0, 'right': 20.0},
      const {'bottom': 180.0, 'left': 20.0},
      const {'top': 130.0, 'right': 80.0},
      const {'bottom': 80.0, 'right': 160.0},
    ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = (_animation.value + delays[index]) % 1.0;
        return Positioned(
          top: positions[index]['top'],
          bottom: positions[index]['bottom'],
          left: positions[index]['left'],
          right: positions[index]['right'],
          child: Transform.translate(
            offset: Offset(0, -progress * 40),
            child: Container(
              width: sizes[index],
              height: sizes[index],
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[index],
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
