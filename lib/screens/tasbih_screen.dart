import 'package:flutter/material.dart';

import '../controllers/tasbih_controller.dart';
import '../models/dhikr.dart';
import '../repositories/tasbih_repository.dart';
import '../services/tasbih_counter.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';

/// Compteur de dhikr : appuyer n'importe où dans la zone du compteur.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key, this.store, this.clock, this.haptic});

  /// Injectables pour les tests.
  final TasbihRepository? store;
  final DateTime Function()? clock;
  final void Function(TasbihEvent event)? haptic;

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const TasbihScreen()));

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  late final TasbihController _controller = TasbihController(
    store: widget.store,
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
    final textTheme = Theme.of(context).textTheme;
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: const Text('Tasbih'),
          actions: [
            IconButton(
              tooltip: 'Remettre à zéro',
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
              final counter = _controller.counter;
              final dhikr = _controller.dhikr;
              return Column(
                children: [
                  _buildOptions(context),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Compter : ${dhikr.transliteration}, '
                          '${counter.count}',
                      child: GestureDetector(
                        key: const ValueKey('tasbih-tap'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _controller.tap,
                        // Petits écrans (iPhone SE) : le contenu se réduit
                        // plutôt que de déborder ; la zone d'appui reste entière.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width - 48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(dhikr.arabic,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: textTheme.headlineSmall?.copyWith(
                                          color: AppColors.textPrimary,
                                          height: 1.6)),
                                  const SizedBox(height: 6),
                                  Text(dhikr.transliteration,
                                      textAlign: TextAlign.center,
                                      style: textTheme.titleMedium?.copyWith(
                                          fontStyle: FontStyle.italic)),
                                  Text(dhikr.translation,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 24),
                                  _CounterRing(counter: counter),
                                  const SizedBox(height: 16),
                                  Text(_statusText(counter),
                                      key: const ValueKey('tasbih-status'),
                                      style: textTheme.titleSmall?.copyWith(
                                          color: AppColors.emeraldDark)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Aujourd’hui : ${_controller.todayTotal}',
                      key: const ValueKey('tasbih-total'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    final afterPrayer = _controller.afterPrayer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: afterPrayer,
            onChanged: _controller.setAfterPrayer,
            title: const Text('Après la prière'),
            subtitle: const Text('33 + 33 + 33, puis la formule qui complète '
                'la centaine (Muslim 597)'),
          ),
          if (!afterPrayer) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in Dhikr.choices)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(d.transliteration),
                        selected: _controller.dhikr.id == d.id,
                        onSelected: (_) => _controller.selectDhikr(d),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final t in TasbihController.targets)
                    ButtonSegment(value: t, label: Text(t == 0 ? '∞' : '$t')),
                ],
                selected: {_controller.target},
                onSelectionChanged: (s) => _controller.selectTarget(s.first),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(TasbihCounter counter) {
    final event = _controller.lastEvent;
    if (event == TasbihEvent.sequenceDone)
      return 'Les 100 sont faits, qu’Allah les accepte';
    if (event == TasbihEvent.targetReached)
      return 'Objectif atteint · tour ${counter.rounds}';
    if (counter.isSequence) {
      return 'Étape ${counter.stepIndex + 1} / ${counter.steps.length}';
    }
    return counter.current.target == 0 ? 'Sans limite' : 'Touchez pour compter';
  }
}

class _CounterRing extends StatelessWidget {
  const _CounterRing({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    final target = counter.current.target;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: counter.progress ?? 0,
              strokeWidth: 10,
              color: AppColors.emerald,
              backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${counter.count}',
                  key: const ValueKey('tasbih-count'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              if (target > 0)
                Text('/ $target',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
