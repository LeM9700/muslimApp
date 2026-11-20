import 'package:flutter/material.dart';

import '../../models/hadith_grade.dart';
import '../../utils/app_theme.dart';
import 'grade_badge.dart';

/// Ouvre la fiche « Comprendre les degrés d'authenticité ».
///
/// [current] est mis en évidence pour relier l'explication au hadith lu.
Future<void> showGradeInfoSheet(
  BuildContext context, {
  HadithGrade? current,
  bool reinforced = false,
  String? rawLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Fond opaque : le contenu de l'accueil transparaissait sous le texte.
    backgroundColor: const Color(0xFFFBF8FD),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => GradeInfoContent(
        scrollController: controller,
        current: current,
        reinforced: reinforced,
        rawLabel: rawLabel,
      ),
    ),
  );
}

/// Contenu pédagogique, séparé de la feuille pour pouvoir le tester et le
/// réutiliser (ex : écran Bibliothèque).
class GradeInfoContent extends StatelessWidget {
  const GradeInfoContent({
    super.key,
    this.scrollController,
    this.current,
    this.reinforced = false,
    this.rawLabel,
  });

  final ScrollController? scrollController;
  final HadithGrade? current;
  final bool reinforced;
  final String? rawLabel;

  static const List<_Condition> _conditions = [
    _Condition(
      'Une chaîne continue',
      'Chaque rapporteur a reçu le hadith directement de celui qui le '
          'précède, sans maillon manquant, jusqu’au Prophète ﷺ.',
    ),
    _Condition(
      'Des rapporteurs intègres',
      'Des personnes connues pour leur piété et leur honnêteté '
          '(al-‘adâla).',
    ),
    _Condition(
      'Des rapporteurs précis',
      'Une mémoire ou des écrits fiables, qui transmettent le texte sans '
          'l’altérer (ad-dabt).',
    ),
    _Condition(
      'Aucune contradiction',
      'Le hadith ne contredit pas ce qu’ont rapporté des rapporteurs plus '
          'fiables (absence de shudhûdh).',
    ),
    _Condition(
      'Aucun défaut caché',
      'Après examen de toutes les chaînes, les spécialistes n’y ont trouvé '
          'aucune faille subtile (absence de ‘illa).',
    ),
  ];

  static const Map<HadithGrade, _GradeExplanation> _grades = {
    HadithGrade.sahih: _GradeExplanation(
      'Remplit les cinq conditions.',
      'C’est le plus haut degré. Les savants s’appuient sur lui pour la '
          'croyance comme pour la pratique.',
    ),
    HadithGrade.hasan: _GradeExplanation(
      'Remplit les cinq conditions, mais la précision d’au moins un '
          'rapporteur est un peu moindre.',
      'Accepté comme preuve par les savants, juste en dessous de '
          'l’authentique.',
    ),
    HadithGrade.daif: _GradeExplanation(
      'Il manque au moins une des conditions (chaîne interrompue, '
          'rapporteur peu fiable…).',
      'La majorité des savants ne s’en servent pas pour établir une règle '
          'religieuse.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final raw = rawLabel?.trim() ?? '';
    final showRaw = raw.isNotEmpty && raw != current?.label;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Comprendre les degrés d’authenticité',
            style: textTheme.headlineMedium?.copyWith(fontSize: 22),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pour s’assurer qu’une parole vient bien du Prophète ﷺ, les '
          'savants du hadith étudient sa chaîne de transmission (isnâd) et '
          'son texte (matn). Le degré résume le résultat de cet examen.',
          style: textTheme.bodyLarge,
        ),
        if (current != null && current != HadithGrade.unknown) ...[
          const SizedBox(height: 16),
          _CurrentGradeBanner(
            grade: current!,
            reinforced: reinforced,
            rawLabel: showRaw ? raw : null,
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('L’échelle des degrés'),
        const SizedBox(height: 12),
        _GradeScale(current: current),
        const SizedBox(height: 16),
        for (final entry in _grades.entries) ...[
          _GradeTile(
            grade: entry.key,
            explanation: entry.value,
            highlighted: entry.key == current,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        const _SectionTitle('Les 5 conditions d’un hadith authentique'),
        const SizedBox(height: 12),
        for (var i = 0; i < _conditions.length; i++)
          _ConditionTile(number: i + 1, condition: _conditions[i]),
        const SizedBox(height: 14),
        const _SectionTitle('Pourquoi l’un est plus authentique que l’autre ?'),
        const SizedBox(height: 8),
        Text(
          'Tout se joue sur la solidité de la transmission. Plus les '
          'rapporteurs sont précis et plus le hadith est rapporté par des '
          'chaînes différentes et indépendantes, plus sa certitude est '
          'grande. Entre un hadith authentique et un hadith bon, la '
          'différence tient souvent à la mémoire d’un seul rapporteur.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        const _Highlight(
          icon: Icons.workspace_premium_outlined,
          title: '« Rapporté par Al-Bukhârî et Muslim »',
          body: 'Lorsque les deux recueils les plus rigoureux rapportent le '
              'même hadith, les savants le placent au sommet de '
              'l’authenticité.',
        ),
        const SizedBox(height: 10),
        const _Highlight(
          icon: Icons.link,
          title: '« Renforcé » par d’autres chaînes',
          body: 'Un hadith un peu faible par une seule chaîne peut être élevé '
              'au degré « bon », voire « authentique », lorsque plusieurs '
              'chaînes indépendantes se confirment (li-ghayrihi).',
        ),
        const SizedBox(height: 20),
        Text(
          'Le degré affiché est celui donné par les savants spécialistes, '
          'tel que rapporté par l’Encyclopédie des hadiths traduits '
          '(HadeethEnc.com).',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Condition {
  final String title;
  final String body;
  const _Condition(this.title, this.body);
}

class _GradeExplanation {
  final String definition;
  final String value;
  const _GradeExplanation(this.definition, this.value);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CurrentGradeBanner extends StatelessWidget {
  const _CurrentGradeBanner({
    required this.grade,
    required this.reinforced,
    this.rawLabel,
  });

  final HadithGrade grade;
  final bool reinforced;
  final String? rawLabel;

  @override
  Widget build(BuildContext context) {
    final style = HadithGradeStyle.of(grade);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ce hadith est jugé « ${grade.label} » '
                  '(${grade.arabicTerm})${reinforced ? ', renforcé par '
                      'd’autres chaînes' : ''}.',
                  style: textTheme.titleMedium?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rawLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Jugement cité : $rawLabel',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Échelle visuelle du plus fort au plus faible.
class _GradeScale extends StatelessWidget {
  const _GradeScale({this.current});
  final HadithGrade? current;

  static const _order = [HadithGrade.sahih, HadithGrade.hasan, HadithGrade.daif];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Échelle : Authentique, plus fort que Bon, plus fort que Faible',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < _order.length; i++) ...[
                Expanded(child: _ScaleStep(grade: _order[i], current: current)),
                if (i < _order.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Plus fort', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('Plus faible', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScaleStep extends StatelessWidget {
  const _ScaleStep({required this.grade, this.current});
  final HadithGrade grade;
  final HadithGrade? current;

  @override
  Widget build(BuildContext context) {
    final style = HadithGradeStyle.of(grade);
    final selected = grade == current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? style.foreground : style.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border, width: selected ? 2 : 1),
      ),
      child: Column(
        children: [
          Icon(
            style.icon,
            size: 18,
            color: selected ? Colors.white : style.foreground,
          ),
          const SizedBox(height: 4),
          Text(
            grade.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : style.foreground,
            ),
          ),
          Text(
            grade.arabicTerm,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: selected ? Colors.white : style.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({
    required this.grade,
    required this.explanation,
    required this.highlighted,
  });

  final HadithGrade grade;
  final _GradeExplanation explanation;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = HadithGradeStyle.of(grade);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? style.background : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? style.foreground : const Color(0x1A1A1A2E),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 18, color: style.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${grade.label} · ${grade.arabicTerm}',
                  style: textTheme.titleMedium?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (highlighted)
                Text(
                  'Ce hadith',
                  style: textTheme.bodySmall?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(explanation.definition, style: textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            explanation.value,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.number, required this.condition});
  final int number;
  final _Condition condition;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.emeraldDark,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(condition.body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.copper),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
