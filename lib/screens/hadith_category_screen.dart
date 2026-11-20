import 'package:flutter/material.dart';

import '../controllers/category_hadiths_controller.dart';
import '../models/hadith_category.dart';
import '../models/hadith_category_tree.dart';
import '../models/hadith_page.dart';
import '../services/hadith_library_service.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/hadith/theme_visuals.dart';
import 'hadith_detail_screen.dart';

/// Un thème de la Bibliothèque, à n'importe quel niveau.
///
/// Le même écran sert pour les 4 niveaux de l'arborescence : la liste montre
/// tous les hadiths du thème (sous-thèmes inclus) et les puces permettent
/// d'affiner. L'utilisateur n'est jamais obligé de descendre 4 niveaux pour
/// commencer à lire.
class HadithCategoryScreen extends StatefulWidget {
  const HadithCategoryScreen({
    super.key,
    required this.category,
    this.service,
  });

  final HadithCategory category;
  final HadithLibraryService? service;

  static Future<void> open(
    BuildContext context,
    HadithCategory category, {
    HadithLibraryService? service,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HadithCategoryScreen(
          category: category,
          service: service,
        ),
      ),
    );
  }

  @override
  State<HadithCategoryScreen> createState() => _HadithCategoryScreenState();
}

class _HadithCategoryScreenState extends State<HadithCategoryScreen> {
  late final HadithLibraryService _service =
      widget.service ?? HadithLibraryService.instance;
  late final CategoryHadithsController _controller =
      CategoryHadithsController(categoryId: widget.category.id, service: _service);
  final ScrollController _scrollController = ScrollController();

  HadithCategoryTree? _tree;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.loadFirstPage();
    // L'arbre est déjà en mémoire (écran précédent) : appel instantané.
    _service.getCategoryTree().then((tree) {
      if (mounted) setState(() => _tree = tree);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Précharge la page suivante avant d'atteindre le bas : le défilement
  /// reste fluide sans bouton « Voir plus ».
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 600 &&
        !_controller.hasError) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final ancestors = _tree?.ancestorsOf(category.id) ?? const [];
    final subthemes = _tree?.childrenOf(category.id) ?? const [];
    final visual = ThemeVisual.forRoot(
      ancestors.isNotEmpty ? ancestors.first.id : category.id,
    );

    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Pas de titre dans la barre : les intitulés font jusqu'à 80
        // caractères et y seraient tronqués. Le titre complet est porté par
        // l'en-tête (principe du « grand titre » iOS).
        appBar: AppBar(surfaceTintColor: Colors.transparent),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => RefreshIndicator(
              onRefresh: _controller.loadFirstPage,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      category: category,
                      ancestors: ancestors,
                      visual: visual,
                    ),
                  ),
                  if (subthemes.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _SubthemeChips(
                        subthemes: subthemes,
                        onSelected: (c) => HadithCategoryScreen.open(
                          context,
                          c,
                          service: _service,
                        ),
                      ),
                    ),
                  ..._buildList(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildList(BuildContext context) {
    final c = _controller;
    if (c.isInitial && c.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ListError(
            message: 'Impossible de charger les hadiths de ce thème.',
            onRetry: c.loadFirstPage,
          ),
        ),
      ];
    }
    if (c.isInitial) {
      return [const SliverToBoxAdapter(child: _ListSkeleton())];
    }
    if (c.items.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('Aucun hadith dans ce thème pour l’instant.')),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Semantics(
            header: true,
            child: Text(
              'Hadiths',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: c.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _HadithRow(
            summary: c.items[i],
            onTap: () => HadithDetailScreen.openById(
              context,
              hadithId: c.items[i].id,
              previewTitle: c.items[i].title,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _buildFooter(context)),
    ];
  }

  Widget _buildFooter(BuildContext context) {
    final c = _controller;
    if (c.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _ListError(
          message: 'La suite n’a pas pu être chargée.',
          onRetry: c.loadMore,
          compact: true,
        ),
      );
    }
    if (c.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Text(
        'Vous avez parcouru les ${formatHadithCount(c.items.length)} '
        'de ce thème.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.ancestors,
    required this.visual,
  });

  final HadithCategory category;
  final List<HadithCategory> ancestors;
  final ThemeVisual visual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trail = ancestors.map((c) => c.title).join(' › ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ThemeIconBadge(visual: visual, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trail.isNotEmpty) ...[
                  Text(
                    trail,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    category.title,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatHadithCount(category.hadithCount),
                  style: textTheme.bodyMedium?.copyWith(
                    color: visual.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sous-thèmes en puces défilantes : compact (ne repousse pas la liste
/// hors de l'écran) et lisible d'un coup d'œil.
class _SubthemeChips extends StatelessWidget {
  const _SubthemeChips({required this.subthemes, required this.onSelected});

  final List<HadithCategory> subthemes;
  final ValueChanged<HadithCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Semantics(
            header: true,
            child: Text(
              'Affiner par sous-thème',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: subthemes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = subthemes[i];
              return ActionChip(
                onPressed: () => onSelected(c),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: Colors.white.withValues(alpha: 0.75),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.95)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                label: Text(
                  '${c.title} · ${c.hadithCount}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                tooltip: '${c.title}, ${formatHadithCount(c.hadithCount)}',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HadithRow extends StatelessWidget {
  const _HadithRow({required this.summary, required this.onTap});

  final HadithSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: summary.title,
      hint: 'Ouvre le hadith et son explication',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!compact) ...[
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
          ],
          Text(message, textAlign: TextAlign.center, style: textTheme.bodyLarge),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement des hadiths',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  height: 76,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
