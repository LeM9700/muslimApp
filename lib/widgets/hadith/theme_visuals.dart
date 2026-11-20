import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Identité visuelle d'un thème racine HadeethEnc : une icône qui évoque
/// le contenu et une teinte pour repérer le thème d'un coup d'œil.
/// Les sous-thèmes héritent de l'identité de leur racine.
class ThemeVisual {
  final IconData icon;
  final Color color;

  const ThemeVisual(this.icon, this.color);

  /// Identifiants stables des 7 racines de HadeethEnc.
  static ThemeVisual forRoot(String? rootId) {
    switch (rootId) {
      case '1': // Le Noble Coran et ses sciences
        return const ThemeVisual(Icons.menu_book_outlined, AppColors.copper);
      case '2': // Le hadith et ses sciences
        return const ThemeVisual(Icons.library_books_outlined, Color(0xFF6D5BA8));
      case '3': // Le dogme
        return const ThemeVisual(Icons.auto_awesome_outlined, Color(0xFF3B6FB6));
      case '4': // La jurisprudence et son fondement
        return const ThemeVisual(Icons.balance_outlined, AppColors.emeraldDark);
      case '5': // Les vertus et les convenances
        return const ThemeVisual(Icons.volunteer_activism_outlined, Color(0xFFB4436C));
      case '6': // La prédication
        return const ThemeVisual(Icons.campaign_outlined, AppColors.amberDark);
      case '7': // La biographie et l'histoire
        return const ThemeVisual(Icons.history_edu_outlined, Color(0xFF7A5230));
      default:
        return const ThemeVisual(Icons.bookmark_border, AppColors.textSecondary);
    }
  }
}

/// Pastille d'icône de thème (décorative : exclue de la lecture d'écran,
/// le titre du thème porte l'information).
class ThemeIconBadge extends StatelessWidget {
  const ThemeIconBadge({super.key, required this.visual, this.size = 44});

  final ThemeVisual visual;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: visual.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(visual.icon, color: visual.color, size: size * 0.52),
      ),
    );
  }
}

/// « 1 hadith » / « 527 hadiths » avec séparateur de milliers français.
String formatHadithCount(int count) {
  final digits = count.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer ${count > 1 ? 'hadiths' : 'hadith'}';
}
