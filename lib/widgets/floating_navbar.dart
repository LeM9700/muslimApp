import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

/// Navbar flottante moderne avec effet glassmorphism
/// Animation liquide et design premium
class FloatingGlassNavBar extends StatefulWidget {
  final int selectedIndex;
  final void Function(int) onItemTapped;
  final List<FloatingNavItem> items;

  const FloatingGlassNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  }) : super(key: key);

  @override
  _FloatingGlassNavBarState createState() => _FloatingGlassNavBarState();
}

class _FloatingGlassNavBarState extends State<FloatingGlassNavBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    _rippleController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: Container(
              height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widget.items.asMap().entries.map((entry) {
                        int index = entry.key;
                        FloatingNavItem item = entry.value;
                        bool isSelected = index == widget.selectedIndex;
                        
                        return _buildNavItem(item, index, isSelected);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(FloatingNavItem item, int index, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _rippleController.forward().then((_) {
            _rippleController.reset();
          });
          widget.onItemTapped(index);
        },
        child: Container(
          height: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Effet de ripple animé
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return Container(
                    width: 50 * _rippleController.value,
                    height: 50 * _rippleController.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(
                        0.3 * (1 - _rippleController.value),
                      ),
                    ),
                  );
                },
              ),
              // Indicateur de sélection liquide
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isSelected ? 50 : 0,
                height: isSelected ? 50 : 0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(isSelected ? 0.3 : 0),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Icône avec animation
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    transform: Matrix4.identity()
                      ..scale(isSelected ? 1.2 : 1.0)
                      ..translate(0.0, isSelected ? -2.0 : 0.0),
                    child: Icon(
                      item.icon,
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.6),
                      size: 24,
                    ),
                  ),
                  SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 300),
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.6),
                      fontSize: isSelected ? 12 : 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  final IconData icon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.label,
  });
}

/// Bouton d'action flottant avec effet glassmorphism
class GlassFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  const GlassFloatingActionButton({
    Key? key,
    this.onPressed,
    required this.child,
    this.tooltip,
  }) : super(key: key);

  @override
  _GlassFloatingActionButtonState createState() => _GlassFloatingActionButtonState();
}

class _GlassFloatingActionButtonState extends State<GlassFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: math.pi / 12,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120,
      right: 30,
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.4),
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}