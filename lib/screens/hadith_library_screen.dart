import 'package:flutter/material.dart';

import '../controllers/hadith_library_controller.dart';
import '../models/hadith.dart';
import '../models/hadith_category.dart';
import '../models/hadith_category_tree.dart';
import '../services/hadith_library_service.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/hadith/grade_info_sheet.dart';
import '../widgets/hadith/theme_visuals.dart';
import 'hadith_category_screen.dart';
import 'hadith_detail_screen.dart';

/// Bibliothèque de hadiths : thèmes racines, recherche de thème et
/// lectures récentes.
class HadithLibraryScreen extends StatefulWidget {
  const HadithLibraryScreen({super.key, this.service});

  /// Injectable pour les tests.
  final HadithLibraryService? service;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HadithLibraryScreen()),
    );
  }

  @override
  State<HadithLibraryScreen> createState() => _HadithLibraryScreenState();
}

class _HadithLibraryScreenState extends State<HadithLibraryScreen> {
  late final HadithLibraryController _controller =
      HadithLibraryController(service: widget.service);
  final TextEditingController _searchController = TextEditingController();

  HadithLibraryService get _service =>
      widget.service ?? HadithLibraryService.instance;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCategory(HadithCategory category) async {
    FocusScope.of(context).unfocus();
    await HadithCategoryScreen.open(context, category, service: _service);
    // Les lectures faites dans le thème apparaissent dans « Lus récemment ».
    await _controller.refreshRecent();
  }

  Future<void> _openRecent(Hadith hadith) async {
    await HadithDetailScreen.open(context, hadith);
    await _controller.refreshRecent();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: const Text('Bibliothèque de hadiths'),
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => GestureDetector(
              // Toucher hors du champ ferme le clavier.
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    sliver: SliverToBoxAdapter(child: _buildSearchField()),
                  ),
                  ..._buildBody(context),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _controller.setQuery,
      textInputAction: TextInputAction.search,
      enabled: _controller.status == LoadStatus.ready,
      decoration: InputDecoration(
        hintText: 'Rechercher un thème : prière, jeûne…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Effacer la recherche',
                onPressed: () {
                  _searchController.clear();
                  _controller.setQuery('');
                },
              ),
        fillColor: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    switch (_controller.status) {
      case LoadStatus.loading:
        return [const SliverToBoxAdapter(child: _ThemesSkeleton())];
      case LoadStatus.error:
        return [
          SliverToBoxAdapter(
            child: _LibraryError(
              onRetry: () => _controller.load(forceRefresh: true),
            ),
          ),
          if (_controller.recent.isNotEmpty) ..._buildRecent(context),
        ];
      case LoadStatus.ready:
        return _controller.isSearching
            ? _buildSearchResults(context)
            : _buildHome(context);
    }
  }

  List<Widget> _buildHome(BuildContext context) {
    final tree = _controller.tree!;
    final textTheme = Theme.of(context).textTheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Text(
            '${formatHadithCount(tree.totalHadithCount)} traduits, '
            'authentifiés et expliqués, classés par thème.',
            style: textTheme.bodyMedium,
          ),
        ),
      ),
      if (_controller.recent.isNotEmpty) ..._buildRecent(context),
      const _SectionHeader('Thèmes'),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: tree.roots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final root = tree.roots[i];
            return _ThemeTile(
              category: root,
              visual: ThemeVisual.forRoot(root.id),
              subthemeCount: tree.childrenOf(root.id).length,
              onTap: () => _openCategory(root),
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: _GradeInfoTile(onTap: () => showGradeInfoSheet(context)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Contenu : Encyclopédie des hadiths traduits (HadeethEnc.com)',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildRecent(BuildContext context) {
    final recent = _controller.recent.take(10).toList();
    return [
      const _SectionHeader('Lus récemment'),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _RecentCard(
              hadith: recent[i],
              onTap: () => _openRecent(recent[i]),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSearchResults(BuildContext context) {
    final results = _controller.searchResults;
    final tree = _controller.tree!;
    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptySearch(query: _controller.query.trim()),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Semantics(
            liveRegion: true,
            child: Text(
              results.length > 1
                  ? '${results.length} thèmes trouvés'
                  : '1 thème trouvé',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final result = results[i];
            return _SearchResultTile(
              result: result,
              visual: ThemeVisual.forRoot(tree.rootOf(result.category.id)?.id),
              onTap: () => _openCategory(result.category),
            );
          },
        ),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Surface de liste : blanc translucide sans BackdropFilter
/// ([⚡ PERF] 7+ cartes floutées dans une liste coûteraient cher au GPU).
BoxDecoration _tileDecoration() => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
    );

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.category,
    required this.visual,
    required this.subthemeCount,
    required this.onTap,
  });

  final HadithCategory category;
  final ThemeVisual visual;
  final int subthemeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      formatHadithCount(category.hadithCount),
      if (subthemeCount > 0)
        '$subthemeCount sous-thème${subthemeCount > 1 ? 's' : ''}',
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${category.title}, $details',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: _tileDecoration(),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ThemeIconBadge(visual: visual),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(details, style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      )),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.visual,
    required this.onTap,
  });

  final CategorySearchResult result;
  final ThemeVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = formatHadithCount(result.category.hadithCount);
    return Semantics(
      button: true,
      label: [
        result.category.title,
        if (result.ancestors.isNotEmpty) 'dans ${result.breadcrumb}',
        count,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: _tileDecoration(),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ThemeIconBadge(visual: visual, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (result.ancestors.isNotEmpty)
                        Text(
                          result.shortBreadcrumb,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Text(
                        result.category.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(count, style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      )),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.hadith, required this.onTap});

  final Hadith hadith;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = (hadith.title?.isNotEmpty ?? false)
        ? hadith.title!
        : hadith.displayText;
    return Semantics(
      button: true,
      label: 'Relire : $text',
      excludeSemantics: true,
      child: SizedBox(
        width: 220,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: _tileDecoration(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: AppColors.copper,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeInfoTile extends StatelessWidget {
  const _GradeInfoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Comprendre les degrés d’authenticité',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.emeraldDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.emeraldDark.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.emeraldDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprendre les degrés d’authenticité',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Authentique, bon, faible : ce que cela signifie',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Aucun thème ne correspond à « $query »',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez un mot plus court ou plus général, par exemple '
              '« prière », « parents » ou « jeûne ».',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 8),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Bibliothèque indisponible hors connexion',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Les thèmes se chargent une première fois avec Internet, '
            'puis restent disponibles.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _ThemesSkeleton extends StatelessWidget {
  const _ThemesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement des thèmes',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          child: Column(
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
