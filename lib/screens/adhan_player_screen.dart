import 'package:flutter/material.dart';

import '../controllers/adhan_player_controller.dart';
import '../models/adhan_dua.dart';
import '../models/prayer_schedule.dart';
import '../services/adhan_audio.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_widgets.dart';

/// Écran ouvert par un appui sur une notification d'adhan : l'adhan
/// intégral (la notification n'en joue que 30 s) et la dou'a qui suit.
///
/// Pas de lecture automatique : sur Android, l'appui qui ouvre l'écran vient
/// souvent de quelqu'un qui voulait faire taire l'extrait.
class AdhanPlayerScreen extends StatefulWidget {
  const AdhanPlayerScreen({super.key, required this.prayer, this.playback});

  final Prayer prayer;

  /// Injectable pour les tests.
  final AdhanPlayback? playback;

  @override
  State<AdhanPlayerScreen> createState() => _AdhanPlayerScreenState();
}

class _AdhanPlayerScreenState extends State<AdhanPlayerScreen> {
  late final AdhanPlayerController _controller = AdhanPlayerController(
    prayer: widget.prayer,
    playback: widget.playback,
  );

  @override
  void dispose() {
    _controller.dispose(); // arrête la lecture en quittant l'écran
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
          title: Text('Prière du ${widget.prayer.label}'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _PlayerCard(controller: _controller),
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  Text('Pendant l’appel', style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(AdhanDua.duringAdhan, style: textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  Text('Dou’a après l’adhan', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    AdhanDua.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.getArabicTextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AdhanDua.transliteration,
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AdhanDua.translation,
                    style: AppTheme.getFrenchTranslationStyle(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AdhanDua.source,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.controller});
  final AdhanPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final playing = controller.isPlaying;
    final isFajr = controller.prayer == Prayer.fajr;
    return _Card(
      children: [
        Row(
          children: [
            const Icon(Icons.mosque_outlined, color: AppColors.copper),
            const SizedBox(width: 8),
            Expanded(
              child: Text('C’est l’heure de la prière',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            button: true,
            label: playing ? 'Arrêter l’adhan' : 'Écouter l’adhan complet',
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emeraldDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: controller.toggle,
              icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(playing ? 'Arrêter' : 'Écouter l’adhan complet'),
            ),
          ),
        ),
        if (isFajr) ...[
          const SizedBox(height: 10),
          Text(
            'Au Fajr, le muezzin ajoute « As-salâtu khayrun min an-nawm » '
            '(la prière est meilleure que le sommeil).',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (controller.unavailable) ...[
          const SizedBox(height: 10),
          Text(
            'Enregistrement indisponible.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.redDark),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
