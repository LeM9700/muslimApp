import 'package:flutter/material.dart';

import '../../models/hadith_grade.dart';
import '../../utils/app_theme.dart';
import 'grade_info_sheet.dart';

/// Apparence associée à chaque degré : couleur ET icône, pour que
/// l'information ne repose jamais sur la couleur seule (daltonisme).
class HadithGradeStyle {
  final Color foreground;
  final IconData icon;

  const HadithGradeStyle(this.foreground, this.icon);

  Color get background => foreground.withValues(alpha: 0.10);
  Color get border => foreground.withValues(alpha: 0.35);

  static HadithGradeStyle of(HadithGrade grade) {
    switch (grade) {
      case HadithGrade.sahih:
        return const HadithGradeStyle(AppColors.emeraldDark, Icons.verified);
      case HadithGrade.hasan:
        return const HadithGradeStyle(
          AppColors.amberDark,
          Icons.check_circle_outline,
        );
      case HadithGrade.daif:
        return const HadithGradeStyle(
          AppColors.redDark,
          Icons.report_gmailerrorred,
        );
      case HadithGrade.unknown:
        return const HadithGradeStyle(
          AppColors.textSecondary,
          Icons.help_outline,
        );
    }
  }
}

/// Badge du degré d'authenticité. Un appui ouvre l'explication des degrés.
///
/// Zone tactile ≥ 48 dp (guidelines Material / Apple HIG 44 pt) même si le
/// badge visuel est plus petit.
class GradeBadge extends StatelessWidget {
  const GradeBadge({
    super.key,
    required this.grade,
    this.reinforced = false,
    this.rawLabel,
  });

  final HadithGrade grade;

  /// Degré obtenu grâce à d'autres chaînes (« li-ghayrihi »).
  final bool reinforced;

  /// Jugement brut de la source, mis en avant dans la fiche explicative.
  final String? rawLabel;

  @override
  Widget build(BuildContext context) {
    if (grade == HadithGrade.unknown) return const SizedBox.shrink();
    final style = HadithGradeStyle.of(grade);

    return Semantics(
      button: true,
      label: 'Degré d’authenticité : ${grade.label}. '
          'Touchez pour comprendre les degrés.',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showGradeInfoSheet(
            context,
            current: grade,
            reinforced: reinforced,
            rawLabel: rawLabel,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 16, color: style.foreground),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        reinforced
                            ? '${grade.label} (renforcé)'
                            : grade.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: style.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: style.foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
