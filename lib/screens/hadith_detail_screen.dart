import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hadith.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/hadith/grade_badge.dart';

/// Lecture complète d'un hadith : texte arabe, traduction, explication,
/// enseignements et source.
///
/// Écran plutôt que bottom sheet : les explications dépassent souvent
/// 2 000 caractères, un écran plein offre une lecture confortable, un
/// retour natif (geste iOS / bouton Android) et garde la place pour des
/// actions futures (partage, favoris).
class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({
    super.key,
    required this.hadith,
    this.focusExplanation = false,
  });

  final Hadith hadith;

  /// Fait défiler directement jusqu'à l'explication : l'utilisateur qui a
  /// touché « Lire l'explication » ne doit pas avoir à la chercher.
  final bool focusExplanation;

  /// Ouvre l'écran avec la transition standard de la plateforme.
  static Future<void> open(
    BuildContext context,
    Hadith hadith, {
    bool focusExplanation = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HadithDetailScreen(
          hadith: hadith,
          focusExplanation: focusExplanation,
        ),
      ),
    );
  }

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  final GlobalKey _explanationKey = GlobalKey();

  Hadith get hadith => widget.hadith;

  @override
  void initState() {
    super.initState();
    if (widget.focusExplanation && hadith.hasExplanation) {
      // Après la transition d'entrée, pour que le défilement soit visible
      // et compris (on voit qu'on « arrive » à l'explication).
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final target = _explanationKey.currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = hadith.title?.trim() ?? '';
    // Le titre HadeethEnc reprend parfois le début du texte : on ne
    // l'affiche que s'il apporte une information distincte et courte.
    final showTitle = title.isNotEmpty &&
        title.length <= 140 &&
        !hadith.displayText.startsWith(title);

    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: const Text('Hadith'),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copier le hadith',
              onPressed: () => _copy(context),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (showTitle) ...[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  GradeBadge(
                    grade: hadith.gradeLevel,
                    reinforced: hadith.isGradeReinforced,
                    rawLabel: hadith.grade,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Section(
                title: 'Traduction',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hadith.narratorIntro != null) ...[
                      Text(
                        hadith.narratorIntro!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(
                      hadith.displayText,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (hadith.textArabic != null)
                _ArabicSection(text: hadith.textArabic!),
              if (hadith.explanation?.isNotEmpty ?? false)
                _Section(
                  key: _explanationKey,
                  title: 'Explication',
                  icon: Icons.lightbulb_outline,
                  child: SelectableText(
                    hadith.explanation!,
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              if (hadith.hints.isNotEmpty)
                _Section(
                  // Ancre de secours si l'explication est vide.
                  key: (hadith.explanation?.isEmpty ?? true)
                      ? _explanationKey
                      : null,
                  title: 'Enseignements à retenir',
                  icon: Icons.checklist_rounded,
                  child: Column(
                    children: [
                      for (final hint in hadith.hints) _Bullet(hint),
                    ],
                  ),
                ),
              if (hadith.source.isNotEmpty)
                _Section(
                  title: 'Source',
                  icon: Icons.menu_book_outlined,
                  child: Text(hadith.source, style: textTheme.bodyMedium),
                ),
              const SizedBox(height: 8),
              Text(
                _creditFor(hadith.provider),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln(hadith.displayText)
      ..writeln()
      ..write(hadith.source);
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hadith copié')),
    );
  }

  static String _creditFor(HadithProvider provider) {
    switch (provider) {
      case HadithProvider.hadeethEnc:
        return 'Traduction et explication : Encyclopédie des hadiths '
            'traduits (HadeethEnc.com)';
      case HadithProvider.nawawiLocal:
        return 'Les 40 hadiths de l’imam An-Nawawî';
      case HadithProvider.sunnah:
        return 'Source : Sunnah.com';
      case HadithProvider.other:
        return '';
    }
  }
}

/// Bloc de contenu. Fond blanc quasi opaque plutôt que verre flouté :
/// meilleur contraste pour la lecture longue, et pas de BackdropFilter
/// multiplié dans une liste ([⚡ PERF]).
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.copper),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Texte arabe repliable : précieux mais long (souvent aussi long que la
/// traduction). Replié par défaut pour garder l'explication accessible.
class _ArabicSection extends StatelessWidget {
  const _ArabicSection({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Theme(
        // Retire les séparateurs par défaut de l'ExpansionTile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.translate, color: AppColors.copper),
          title: Text(
            'Texte arabe',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  text,
                  textAlign: TextAlign.right,
                  style: AppTheme.getArabicTextStyle(fontSize: 21),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.emeraldDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
