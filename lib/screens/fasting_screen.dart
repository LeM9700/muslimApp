import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/fasting_controller.dart';
import '../models/fasting.dart';
import '../models/shawwal_progress.dart';
import '../services/calendar_preferences.dart';
import '../services/hijri_converter.dart';
import '../services/prayer_notification_service.dart';
import '../utils/app_theme.dart';
import '../utils/relative_days.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/settings_panel.dart';

/// Jeûnes surérogatoires : prochaines dates et rappels la veille.
class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key, this.service, this.calendar, this.clock});

  /// Injectables pour les tests.
  final PrayerNotificationService? service;
  final CalendarPreferences? calendar;
  final DateTime Function()? clock;

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FastingScreen()),
      );

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  late final FastingController _controller = FastingController(
    service: widget.service,
    calendar: widget.calendar,
    clock: widget.clock,
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
          title: const Text('Jeûnes'),
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final upcoming = _controller.upcoming;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_controller.inShawwal) ...[
                    _buildShawwal(context),
                    const SizedBox(height: 16),
                  ],
                  _buildReminders(context),
                  const SizedBox(height: 16),
                  SettingsPanel(
                    title: 'Prochains jeûnes',
                    icon: Icons.event_note_outlined,
                    children: [
                      if (upcoming.isEmpty)
                        const InlineNote(
                          icon: Icons.info_outline,
                          text: 'Aucun jeûne dans les 3 prochains mois.',
                        ),
                      for (final day in upcoming) _FastTile(day: day, controller: _controller),
                      const InlineNote(
                        icon: Icons.info_outline,
                        text: 'Dates selon le calendrier Umm al-Qura et votre '
                            'ajustement (Notifications → Calendrier). Les jours '
                            'où le jeûne est interdit (Aïd, Tachriq) ne sont '
                            'jamais proposés.',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShawwal(BuildContext context) {
    final progress = _controller.shawwal;
    final days = _controller.shawwalDays;
    final busy = _controller.isBusy;
    final textTheme = Theme.of(context).textTheme;
    return SettingsPanel(
      title: '6 jours de Chawwal',
      icon: Icons.task_alt_outlined,
      children: [
        Row(
          children: [
            Text('${progress.count.clamp(0, 99)} / ${ShawwalProgress.goal}',
                key: const ValueKey('shawwal-count'),
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: (progress.count / ShawwalProgress.goal).clamp(0.0, 1.0),
                color: AppColors.emeraldDark,
                backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (days.isEmpty)
          const InlineNote(
            icon: Icons.celebration_outlined,
            text: 'Aïd moubarak ! Le jeûne commence demain : cochez ici '
                'chaque jour jeûné.',
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in days)
                FilterChip(
                  key: ValueKey('shawwal-${day.day}-${day.month}'),
                  label: Text(_shawwalLabel(day)),
                  selected: _controller.isShawwalFasted(day),
                  onSelected: busy ? null : (_) => _controller.toggleShawwal(day),
                ),
            ],
          ),
        if (progress.isComplete)
          const InlineNote(
            icon: Icons.check_circle_outline,
            text: 'Les 6 jours sont faits, qu’Allah les accepte. Plus de '
                'rappel de Chawwal cette année.',
          )
        else
          const InlineNote(
            icon: Icons.info_outline,
            text: 'Cochez les jours jeûnés (consécutifs ou non). Les jours '
                'à rattraper du Ramadan ne sont pas comptés ici.',
          ),
      ],
    );
  }

  String _shawwalLabel(DateTime day) {
    final h = HijriConverter.fromCivil(day,
        adjustment: _controller.calendar.hijriAdjustment);
    return h == null ? '${day.day}/${day.month}' : '${h.day} Chawwal';
  }

  Widget _buildReminders(BuildContext context) {
    final fasting = _controller.fasting;
    final busy = _controller.isBusy;
    return SettingsPanel(
      title: 'Rappels',
      icon: Icons.notifications_none_rounded,
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('fasting-switch'),
          contentPadding: EdgeInsets.zero,
          value: fasting.enabled,
          onChanged: busy ? null : _controller.setEnabled,
          title: const Text('Me rappeler la veille'),
          subtitle: const Text('30 min après l’Isha : intention et sahour'),
        ),
        if (_controller.notice == FastingNotice.noLocation)
          const InlineNote(
            icon: Icons.location_off_outlined,
            text: 'Activez la localisation ou choisissez une ville depuis '
                'l’accueil : l’heure du rappel suit celle de l’Isha.',
          ),
        if (_controller.notice == FastingNotice.permissionDenied) ...[
          const InlineNote(
            icon: Icons.notifications_off_outlined,
            text: 'Les notifications sont désactivées pour Deen : '
                'autorisez-les dans les Réglages du téléphone.',
          ),
          const TextButton(
            onPressed: Geolocator.openAppSettings,
            child: Text('Ouvrir les Réglages'),
          ),
        ],
        if (fasting.enabled) ...[
          const Divider(height: 16),
          for (final kind in FastKind.values)
            CheckboxListTile.adaptive(
              key: ValueKey('fasting-kind-${kind.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: fasting.kinds.contains(kind),
              onChanged: busy ? null : (on) => _controller.setKind(kind, on ?? false),
              title: Text(kind.label),
              subtitle: Text(kind.when),
            ),
        ],
      ],
    );
  }
}

class _FastTile extends StatelessWidget {
  const _FastTile({required this.day, required this.controller});

  final FastDay day;
  final FastingController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labels = DateLabels.of(day.date, controller.calendar);
    final reminded = controller.isReminded(day);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        reminded ? Icons.notifications_active_outlined : Icons.event_outlined,
        color: reminded ? AppColors.emeraldDark : AppColors.textSecondary,
      ),
      title: Text(day.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${labels.primary}'
        '${labels.secondary.isEmpty ? '' : '\n${labels.secondary}'}\n'
        '${day.mainKind.reference}',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      isThreeLine: true,
      trailing: Text(
        relativeDays(controller.today, day.date),
        style: textTheme.labelMedium?.copyWith(color: AppColors.copper),
      ),
    );
  }
}
