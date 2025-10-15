import 'package:flutter/material.dart';
import 'dart:ui';

/// Widgets personnalisés pour l'effet glassmorphism moderne
/// Utilise backdrop filter et gradients pour un rendu liquide

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
    Key? key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 10,
    this.color = const Color(0x40FFFFFF),
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
  }) : super(key: key);

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
            padding: padding ?? EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
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

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final List<Color>? gradientColors;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 25,
    this.gradientColors,
    this.padding,
    this.margin,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultGradient = [
      const Color(0x30FFFFFF),
      const Color(0x10FFFFFF),
      const Color(0x05FFFFFF),
    ];

    return Container(
      margin: margin ?? EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: padding ?? EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors ?? defaultGradient,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double size;
  final double borderRadius;

  const FloatingGlassButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.size = 56,
    this.borderRadius = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
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

class AnimatedGlassBackground extends StatefulWidget {
  final Widget child;
  
  const AnimatedGlassBackground({Key? key, required this.child}) : super(key: key);

  @override
  _AnimatedGlassBackgroundState createState() => _AnimatedGlassBackgroundState();
}

class _AnimatedGlassBackgroundState extends State<AnimatedGlassBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
        // Gradient de fond animé
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [
                    0.0,
                    _animation.value * 0.5,
                    _animation.value,
                    1.0,
                  ],
                  colors: [
                    Color(0xFF0A1E32),
                    Color(0xFF1A2F47),
                    Color(0xFF2A3F57),
                    Color(0xFF0A1E32),
                  ],
                ),
              ),
            );
          },
        ),
        // Bulles flottantes
        ...List.generate(5, (index) => _buildFloatingBubble(index)),
        // Contenu principal
        widget.child,
      ],
    );
  }

  Widget _buildFloatingBubble(int index) {
    final delays = [0.0, 0.2, 0.4, 0.6, 0.8];
    final sizes = [80.0, 120.0, 60.0, 100.0, 90.0];
    final positions = [
      {'top': 100.0, 'left': 50.0},
      {'top': 300.0, 'right': 30.0},
      {'bottom': 200.0, 'left': 30.0},
      {'top': 150.0, 'right': 100.0},
      {'bottom': 100.0, 'right': 200.0},
    ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = (_animation.value + delays[index]) % 1.0;
        final opacity = (1 - progress) * 0.3;
        
        return Positioned(
          top: positions[index]['top'],
          bottom: positions[index]['bottom'],
          left: positions[index]['left'],
          right: positions[index]['right'],
          child: Transform.translate(
            offset: Offset(0, -progress * 50),
            child: Container(
              width: sizes[index],
              height: sizes[index],
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(opacity),
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