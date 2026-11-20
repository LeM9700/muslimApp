import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/notification_settings_controller.dart';
import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import '../services/prayer_notification_service.dart';
import '../utils/app_theme.dart';
import '../utils/french_dates.dart';
import '../widgets/glass_widgets.dart';

/// Réglages des notifications : rappels de prière, hadith et quiz.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, this.service});

  /// Injectable pour les tests.
  final PrayerNotificationService? service;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  late final NotificationSettingsController _controller =
      NotificationSettingsController(service: widget.service);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onNotice);
    _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onNotice);
    _controller.dispose();
    super.dispose();
  }

  /// Retour depuis les Réglages iOS : l'autorisation a pu changer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.load();
  }

  void _onNotice() {
    if (_controller.notice != SettingsNotice.testSent) return;
    _controller.clearNotice();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification de test envoyée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: const Text('Notifications'),
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_controller.permissionMissing) ...[
                    const _PermissionBanner(),
                    const SizedBox(height: 12),
                  ],
                  _buildPrayerSection(context),
                  const SizedBox(height: 16),
                  _buildDailySection(context),
                  const SizedBox(height: 20),
                  _buildTestButton(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerSection(BuildContext context) {
    final status = _controller.status!;
    final settings = status.settings;
    final busy = _controller.isBusy;
    final city = status.location?.cityName ?? '';
    final textTheme = Theme.of(context).textTheme;

    return _Panel(
      title: 'Heures de prière',
      icon: Icons.mosque_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.prayersEnabled,
          onChanged: busy ? null : _controller.setPrayersEnabled,
          title: const Text('Notification à chaque prière'),
          subtitle: Text(
            status.location == null
                ? 'Position inconnue : activez la localisation ou '
                    'choisissez une ville sur l’accueil'
                : city.isEmpty
                    ? 'Horaires de votre position'
                    : 'Horaires de $city',
          ),
        ),
        if (_controller.notice == SettingsNotice.noLocation)
          const _InlineMessage(
            icon: Icons.location_off_outlined,
            text: 'Activez la localisation ou choisissez une ville depuis '
                'l’accueil : les horaires en dépendent.',
          ),
        if (settings.prayersEnabled) ...[
          const Divider(height: 20),
          for (final prayer in Prayer.values)
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.prayers.contains(prayer),
              onChanged: busy
                  ? null
                  : (v) => _controller.togglePrayer(prayer, v ?? false),
              title: Text(prayer.label),
              secondary: Text(
                status.today?.times[prayer] == null
                    ? '--:--'
                    : FrenchDates.time(status.today!.times[prayer]!),
                style: textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const Divider(height: 20),
          Text('Me prévenir aussi avant', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final m in NotificationSettings.reminderChoices)
                  ButtonSegment(
                    value: m,
                    label: Text(m == 0 ? 'Non' : '$m min'),
                  ),
              ],
              selected: {settings.reminderMinutes},
              onSelectionChanged:
                  busy ? null : (s) => _controller.setReminder(s.first),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Méthode de calcul'),
            subtitle: Text(_methodSubtitle(status)),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => _pickMethod(context, settings.methodId),
          ),
          _CoverageNote(status: status),
        ],
      ],
    );
  }

  String _methodSubtitle(NotificationStatus status) {
    final method = CalculationMethod.fromId(status.settings.methodId);
    if (method.id != null) return method.label;
    return status.methodName.isEmpty
        ? 'Automatique'
        : 'Automatique · ${status.methodName}';
  }

  Widget _buildDailySection(BuildContext context) {
    final settings = _controller.settings;
    final busy = _controller.isBusy;
    return _Panel(
      title: 'Rappels quotidiens',
      icon: Icons.notifications_none_rounded,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.hadithDaily,
          onChanged: busy ? null : _controller.setHadithDaily,
          title: const Text('Hadith du jour'),
          subtitle: const Text('Chaque jour à 10 h'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.quizDaily,
          onChanged: busy ? null : _controller.setQuizDaily,
          title: const Text('Quiz du jour'),
          subtitle: const Text('Chaque jour à 20 h'),
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    final hasPermission = _controller.status?.hasPermission ?? false;
    return OutlinedButton.icon(
      onPressed:
          hasPermission && !_controller.isBusy ? _controller.sendTest : null,
      icon: const Icon(Icons.notifications_active_outlined),
      label: const Text('Envoyer une notification de test'),
    );
  }

  Future<void> _pickMethod(BuildContext context, int? current) async {
    final picked = await showModalBottomSheet<CalculationMethod>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBF8FD),
      builder: (context) => _MethodPicker(current: current),
    );
    if (picked != null) await _controller.setMethod(picked.id);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (et non Container décoré) : les ListTile y dessinent leur
    // effet d'appui ; sur un fond décoré, l'appui n'avait aucun retour.
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, color: AppColors.copper, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CoverageNote extends StatelessWidget {
  const _CoverageNote({required this.status});
  final NotificationStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.calendarUnavailable) {
      return const _InlineMessage(
        icon: Icons.cloud_off_outlined,
        text: 'Horaires indisponibles hors connexion. Les rappels seront '
            'programmés dès que Deen pourra se connecter.',
      );
    }
    final until = status.coveredUntil;
    if (until == null || !status.hasPermission) return const SizedBox.shrink();
    return _InlineMessage(
      icon: Icons.event_available_outlined,
      text: 'Rappels programmés jusqu’au ${FrenchDates.dayMonth(until)}. '
          'Ils se prolongent automatiquement à chaque ouverture de Deen.',
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Autorisation refusée : seul l'utilisateur peut la rétablir dans les
/// Réglages (iOS ne réaffiche jamais la demande). On l'y emmène.
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amberDark.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.amberDark.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_off_outlined,
                    color: AppColors.amberDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les notifications sont désactivées pour Deen',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.amberDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Autorisez-les dans les Réglages de votre téléphone pour '
              'recevoir les rappels.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: Geolocator.openAppSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Ouvrir les Réglages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({required this.current});
  final int? current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Text('Méthode de calcul', style: textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            'Les autorités fixent l’angle du soleil pour Fajr et Isha : '
            'les horaires peuvent varier de quelques minutes. En cas de '
            'doute, suivez votre mosquée.',
            style: textTheme.bodyMedium,
          ),
        ),
        for (final method in CalculationMethod.choices)
          ListTile(
            title: Text(method.label),
            leading: Icon(
              method.id == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: method.id == current
                  ? AppColors.emeraldDark
                  : AppColors.textSecondary,
            ),
            selected: method.id == current,
            onTap: () => Navigator.of(context).pop(method),
          ),
      ],
    );
  }
}
