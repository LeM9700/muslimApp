import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Panneau de réglages (fond blanc translucide, titre et icône).
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (et non Container décoré) : les ListTile y dessinent leur
    // effet d'appui ; sur un fond décoré, l'appui n'avait aucun retour.
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, color: AppColors.copper, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Message court sous un réglage (information, avertissement).
class InlineNote extends StatelessWidget {
  const InlineNote({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
