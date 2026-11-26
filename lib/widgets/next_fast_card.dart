import 'package:flutter/material.dart';

import '../models/fasting.dart';
import '../repositories/prayer_settings_repository.dart';
import '../screens/fasting_screen.dart';
import '../services/calendar_preferences.dart';
import '../services/fast_calendar.dart';
import '../services/hijri_converter.dart';
import '../utils/app_theme.dart';
import '../utils/relative_days.dart';
import 'glass_widgets.dart';

/// Carte « Prochain jeûne » de l'accueil ; ouvre l'écran « Jeûnes ».
///
/// Suit les types de jeûne choisis par le croyant (par défaut sans lundi
/// ni jeudi, sinon la carte annoncerait presque toujours « Lundi ») et
/// l'ajustement du calendrier hégirien. Hors connexion : calcul local.
class NextFastCard extends StatefulWidget {
  const NextFastCard({super.key, this.preferences, this.store, this.clock, this.onOpen});

  /// Injectables pour les tests.
  final CalendarPreferences? preferences;
  final PrayerSettingsRepository? store;
  final DateTime Function()? clock;
  final VoidCallback? onOpen;

  @override
  State<NextFastCard> createState() => _NextFastCardState();
}

class _NextFastCardState extends State<NextFastCard> {
  late final CalendarPreferences _prefs =
      widget.preferences ?? CalendarPreferences.instance;
  Set<FastKind> _kinds = FastingSettings.defaultKinds;

  @override
  void initState() {
    super.initState();
    _prefs.load();
    _loadKinds();
  }

  Future<void> _loadKinds() async {
    final settings = await (widget.store ?? PrayerSettingsRepository()).readSettings();
    if (mounted) setState(() => _kinds = settings.fasting.kinds);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) {
        final now = (widget.clock ?? DateTime.now)();
        final today = DateTime(now.year, now.month, now.day);
        final next = FastCalendar.next(today,
            adjustment: _prefs.settings.hijriAdjustment,
            kinds: _kinds.isEmpty ? null : _kinds);
        if (next == null) return const SizedBox.shrink();
        final labels = DateLabels.of(next.date, _prefs.settings);
        return LiquidGlassCard(
          onTap: widget.onOpen ?? () => _open(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.nightlight_outlined, color: AppColors.copper, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prochain jeûne',
                        style: textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    Text(next.title,
                        style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(labels.primary,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(relativeDays(today, next.date),
                  style: textTheme.labelLarge?.copyWith(color: AppColors.copper)),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context) async {
    await FastingScreen.open(context);
    _loadKinds(); // les types ont pu changer dans l'écran
  }
}
