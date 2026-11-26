import 'package:flutter/material.dart';

import '../services/calendar_preferences.dart';
import '../services/hijri_converter.dart';
import '../utils/app_theme.dart';

/// Date du jour dans le calendrier préféré du croyant, l'autre calendrier
/// en dessous (« jeudi 26 novembre 2026 » / « 5 Joumada ath-thania 1448 »).
///
/// Suit [CalendarPreferences] : un changement fait dans l'écran
/// Notifications se voit immédiatement ici.
class TodayDateLabel extends StatefulWidget {
  const TodayDateLabel({super.key, this.preferences, this.clock});

  /// Injectables pour les tests.
  final CalendarPreferences? preferences;
  final DateTime Function()? clock;

  @override
  State<TodayDateLabel> createState() => _TodayDateLabelState();
}

class _TodayDateLabelState extends State<TodayDateLabel> {
  late final CalendarPreferences _prefs =
      widget.preferences ?? CalendarPreferences.instance;

  @override
  void initState() {
    super.initState();
    _prefs.load();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) {
        final labels = DateLabels.of(
            (widget.clock ?? DateTime.now)(), _prefs.settings);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.primary,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            if (labels.secondary.isNotEmpty)
              Text(
                labels.secondary,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
          ],
        );
      },
    );
  }
}
