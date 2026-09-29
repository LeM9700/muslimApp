import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/app_theme.dart';

// =============================================================================
// FloatingGlassNavBar — navbar glass iridescente pour fond clair
// Indicateur d'onglet : barre spring qui glisse entre les items
// =============================================================================

class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    IconData? activeIcon,
    required this.label,
  }) : activeIcon = activeIcon ?? icon;
}

class FloatingGlassNavBar extends StatefulWidget {
  final int selectedIndex;
  final void Function(int) onItemTapped;
  final List<FloatingNavItem> items;

  const FloatingGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  });

  @override
  State<FloatingGlassNavBar> createState() => _FloatingGlassNavBarState();
}

class _FloatingGlassNavBarState extends State<FloatingGlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _entryAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _entryAnim,
        builder: (context, child) => Transform.scale(
          scale: _entryAnim.value,
          child: child,
        ),
        child: SizedBox(
          height: 76,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  // Glass clair sur fond pastel
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.55),
                      Colors.white.withOpacity(0.40),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.60),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.iridStart.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        constraints.maxWidth / widget.items.length;
                    return Stack(
                      children: [
                        // ── Indicateur spring glissant ──────────────────
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.elasticOut,
                          left: widget.selectedIndex * itemWidth +
                              (itemWidth - 36) / 2,
                          bottom: 8,
                          child: Container(
                            width: 36,
                            height: 3.5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.emerald,
                                  AppColors.copper,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Items ────────────────────────────────────────
                        Row(
                          children: widget.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isSelected = index == widget.selectedIndex;
                            return _NavItem(
                              item: item,
                              isSelected: isSelected,
                              onTap: () => widget.onItemTapped(index),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final FloatingNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _ripple.forward().then((_) => _ripple.reset());
          widget.onTap();
        },
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 4),

              // Icône avec badge de sélection animé
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                transform: Matrix4.identity()
                  ..scale(widget.isSelected ? 1.18 : 1.0)
                  ..translate(0.0, widget.isSelected ? -2.0 : 0.0),
                child: Icon(
                  widget.isSelected
                      ? widget.item.activeIcon
                      : widget.item.icon,
                  color: widget.isSelected
                      ? AppColors.emerald
                      : AppColors.textMuted,
                  size: 24,
                ),
              ),

              const SizedBox(height: 3),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                style: TextStyle(
                  color: widget.isSelected
                      ? AppColors.emerald
                      : AppColors.textMuted,
                  fontSize: widget.isSelected ? 11.5 : 10.5,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                child: Text(widget.item.label),
              ),

              // Espace pour l'indicateur en bas
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// GlassFloatingActionButton
// =============================================================================

class GlassFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  const GlassFloatingActionButton({
    super.key,
    this.onPressed,
    required this.child,
    this.tooltip,
  });

  @override
  State<GlassFloatingActionButton> createState() =>
      _GlassFloatingActionButtonState();
}

class _GlassFloatingActionButtonState extends State<GlassFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 110,
      right: 24,
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.emerald, AppColors.copper],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(child: widget.child),
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
