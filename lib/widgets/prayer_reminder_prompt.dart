import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/prayer_settings_repository.dart';
import '../screens/notification_settings_screen.dart';
import '../services/prayer_notification_service.dart';
import '../utils/app_theme.dart';

/// Invitation à activer les rappels de prière, sous le compte à rebours.
///
/// Explique l'intérêt AVANT la demande système : iOS ne pose la question
/// qu'une fois, un refus réflexe serait définitif. Masquée dès que les
/// rappels sont actifs ou que l'utilisateur choisit « Plus tard ».
class PrayerReminderPrompt extends StatefulWidget {
  const PrayerReminderPrompt({super.key, this.service, this.store});

  final PrayerNotificationService? service;
  final PrayerSettingsRepository? store;

  @override
  State<PrayerReminderPrompt> createState() => _PrayerReminderPromptState();
}

class _PrayerReminderPromptState extends State<PrayerReminderPrompt> {
  late final PrayerNotificationService _service =
      widget.service ?? PrayerNotificationService.instance;
  late final PrayerSettingsRepository _store =
      widget.store ?? PrayerSettingsRepository();

  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decideVisibility();
  }

  Future<void> _decideVisibility() async {
    final settings = await _store.readSettings();
    final dismissed = await _store.isPromptDismissed();
    if (mounted) {
      setState(() => _visible = !settings.prayersEnabled && !dismissed);
    }
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final outcome = await _service.enablePrayers();
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);

    switch (outcome) {
      case EnableOutcome.enabled:
        setState(() => _visible = false);
        messenger.showSnackBar(SnackBar(
          content: const Text('Rappels de prière activés'),
          action: SnackBarAction(
            label: 'Personnaliser',
            onPressed: () => NotificationSettingsScreen.open(context),
          ),
        ));
      case EnableOutcome.permissionDenied:
        messenger.showSnackBar(const SnackBar(
          content: Text('Notifications refusées : autorisez-les dans les '
              'Réglages pour recevoir les rappels.'),
          action: SnackBarAction(
            label: 'Réglages',
            onPressed: Geolocator.openAppSettings,
          ),
        ));
      case EnableOutcome.noLocation:
        // Sans position, pas d'horaires : l'écran de réglages l'explique.
        await NotificationSettingsScreen.open(context);
        await _decideVisibility();
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    await _store.dismissPrompt();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emeraldDark.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.emeraldDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ne manquez plus une prière',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recevez une notification à l’heure de chaque '
                        'prière, selon votre ville.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Plus tard'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _enable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldDark,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Activer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
