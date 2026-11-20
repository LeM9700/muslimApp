import 'package:flutter/material.dart';

import '../models/hadith.dart';
import '../screens/hadith_detail_screen.dart';
import '../services/hadith_service.dart';
import '../utils/app_theme.dart';
import 'glass_widgets.dart';
import 'hadith/grade_badge.dart';

/// Carte « Hadith du jour » de l'accueil.
///
/// Aperçu volontairement court (6 lignes) : la carte donne envie, l'écran
/// de détail porte la lecture complète et l'explication.
class HadithCard extends StatefulWidget {
  const HadithCard({super.key, this.service});

  /// Injectable pour les tests ; par défaut le service réel.
  final HadithService? service;

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  late final HadithService _service = widget.service ?? HadithService();

  HadithResult? _result;
  bool _isLoading = true;
  bool _isDaily = true;

  /// Jeton de requête : ignore une réponse arrivée après un clic plus récent.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadDaily();
  }

  Future<void> _loadDaily() =>
      _load(() => _service.getHadithOfTheDay(), isDaily: true);

  Future<void> _loadAnother() => _load(
        () => _service.getAnotherHadith(excludeId: _result?.hadith.id),
        isDaily: false,
      );

  Future<void> _load(
    Future<HadithResult> Function() fetch, {
    required bool isDaily,
  }) async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    final result = await fetch();
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _result = result;
      _isDaily = isDaily;
      _isLoading = false;
    });
  }

  void _openDetail({bool focusExplanation = false}) {
    final hadith = _result?.hadith;
    if (hadith == null) return;
    HadithDetailScreen.open(
      context,
      hadith,
      focusExplanation: focusExplanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isLoading || _result == null
                ? const _HadithSkeleton(key: ValueKey('skeleton'))
                : _buildContent(context, _result!),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.auto_stories_outlined,
          color: AppColors.copper,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              _isDaily ? 'Hadith du jour' : 'Autre hadith',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        if (!_isDaily)
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Revenir au hadith du jour',
            onPressed: _isLoading ? null : _loadDaily,
          ),
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          tooltip: 'Afficher un autre hadith',
          onPressed: _isLoading ? null : _loadAnother,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, HadithResult result) {
    final hadith = result.hadith;
    final textTheme = Theme.of(context).textTheme;
    final showOfflineNote =
        result.isFallback && hadith.provider == HadithProvider.nawawiLocal;

    return Column(
      key: ValueKey(hadith.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Texte : toucher le texte ouvre aussi le détail (cible large).
        Semantics(
          button: true,
          hint: 'Ouvre le hadith complet',
          child: InkWell(
            onTap: _openDetail,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.copper, width: 3),
                ),
              ),
              child: Text(
                hadith.displayText,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
        if (hadith.source.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hadith.source,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (showOfflineNote)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hors connexion : hadith tiré des 40 hadiths de Nawawi.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                _openDetail(focusExplanation: hadith.hasExplanation),
            icon: Icon(
              hadith.hasExplanation
                  ? Icons.lightbulb_outline
                  : Icons.chrome_reader_mode_outlined,
              size: 20,
            ),
            label: Text(
              hadith.hasExplanation
                  ? 'Lire l’explication complète'
                  : 'Lire le hadith en entier',
            ),
          ),
        ),
      ],
    );
  }
}

/// Squelette de chargement : garde la hauteur de la carte stable
/// (pas de saut de mise en page quand le hadith arrive).
class _HadithSkeleton extends StatelessWidget {
  const _HadithSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, {double height = 14}) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        );

    return Semantics(
      label: 'Chargement du hadith',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(1),
            bar(0.95),
            bar(0.9),
            bar(0.6),
            const SizedBox(height: 6),
            bar(0.35, height: 26),
            const SizedBox(height: 8),
            bar(1, height: 48),
          ],
        ),
      ),
    );
  }
}
