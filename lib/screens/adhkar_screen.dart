import 'package:flutter/material.dart';

import '../controllers/adhkar_controller.dart';
import '../models/adhkar.dart';
import '../repositories/adhkar_repository.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/settings_panel.dart';

/// Adhkar du matin et du soir, avec compteur par dhikr.
class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({
    super.key,
    this.initialPeriod,
    this.repository,
    this.clock,
    this.haptic,
  });

  final AdhkarPeriod? initialPeriod;

  /// Injectables pour les tests.
  final AdhkarRepository? repository;
  final DateTime Function()? clock;
  final void Function(bool completed)? haptic;

  static Future<void> open(BuildContext context, {AdhkarPeriod? period}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AdhkarScreen(initialPeriod: period),
      ));

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final AdhkarController _controller = AdhkarController(
    repository: widget.repository,
    initialPeriod: widget.initialPeriod,
    clock: widget.clock,
    haptic: widget.haptic,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: const Text('Adhkar'),
          actions: [
            IconButton(
              tooltip: 'Tout remettre à zéro',
              icon: const Icon(Icons.restart_alt),
              onPressed: _controller.reset,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_controller.failed) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: InlineNote(
                    icon: Icons.error_outline,
                    text: 'Impossible de lire les adhkar. Réinstallez l’app '
                        'si le problème persiste.',
                  ),
                );
              }
              final book = _controller.book!;
              final items = _controller.items;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AdhkarPeriod>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in AdhkarPeriod.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_controller.period},
                      onSelectionChanged: (s) => _controller.setPeriod(s.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_controller.doneCount} / ${items.length} terminés',
                    key: const ValueKey('adhkar-progress'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.emeraldDark),
                  ),
                  if (!book.reviewed)
                    // [⚠️ PROD] Retiré quand `reviewed` passe à true dans le
                    // JSON, après relecture par une personne qualifiée.
                    const InlineNote(
                      icon: Icons.rate_review_outlined,
                      text: 'Textes en cours de relecture par une personne '
                          'qualifiée.',
                    ),
                  for (final item in items)
                    _DhikrCard(
                      item: item,
                      period: _controller.period,
                      count: _controller.countOf(item),
                      onTap: () => _controller.tap(item),
                    ),
                  InlineNote(icon: Icons.menu_book_outlined, text: book.source),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.item,
    required this.period,
    required this.count,
    required this.onTap,
  });

  final AdhkarItem item;
  final AdhkarPeriod period;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final text = item.textFor(period);
    final done = count >= item.repeat;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white.withValues(alpha: done ? 0.55 : 0.8),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('adhkar-${item.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    _Counter(count: count, repeat: item.repeat),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  text.arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: textTheme.titleLarge?.copyWith(height: 1.9),
                ),
                const SizedBox(height: 8),
                Text(text.transliteration,
                    style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
                Text(text.translation, style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(item.reference,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.repeat});

  final int count;
  final int repeat;

  @override
  Widget build(BuildContext context) {
    final done = count >= repeat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (done ? AppColors.emerald : AppColors.copper).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) const Icon(Icons.check, size: 16, color: AppColors.emeraldDark),
          Text(
            done ? ' $repeat×' : '$count / $repeat',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: done ? AppColors.emeraldDark : AppColors.copper,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
