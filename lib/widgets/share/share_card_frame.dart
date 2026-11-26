import 'package:flutter/material.dart';

import '../../config/share_config.dart';
import '../../utils/app_theme.dart';

/// Cadre commun des images partagées : fond aux couleurs de Deen, titre,
/// contenu, signature. Taille fixe 360 × 450 (rendue en ×3).
class ShareCardFrame extends StatelessWidget {
  const ShareCardFrame({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 450,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundStart,
              AppColors.backgroundMid,
              AppColors.backgroundEnd,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              decoration: TextDecoration.none,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.copper, size: 22),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.copper)),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(child: child),
                Container(height: 1, color: AppColors.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text(ShareConfig.appName,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.emeraldDark)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('La prière, le Coran, les hadiths',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
