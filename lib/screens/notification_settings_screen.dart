import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/notification_settings_controller.dart';
import '../models/adhan_mode.dart';
import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import '../services/adhan_audio.dart';
import '../services/prayer_notification_service.dart';
import '../utils/app_theme.dart';
import '../utils/french_dates.dart';
import '../widgets/glass_widgets.dart';

/// Réglages des notifications : rappels de prière, hadith et quiz.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, this.service, this.preview});

  /// Injectables pour les tests.
  final PrayerNotificationService? service;
  final AdhanPlayback? preview;

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
      NotificationSettingsController(
          service: widget.service, preview: widget.preview);

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
    if (state == AppLifecycleState.paused) _controller.stopPreview();
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
                  if (AdhanAudioCatalog.isTestAudio) ...[
                    // [⚠️ PROD] Visible par les testeurs : un build TestFlight
                    // peut être soumis à l'App Store en deux clics.
                    const _InlineMessage(
                      icon: Icons.science_outlined,
                      text: 'Build de test : l’audio de l’adhan n’est pas '
                          'publiable. Ne pas soumettre ce build à l’App Store.',
                    ),
                    const SizedBox(height: 8),
                  ],
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
          _PresetSelector(
            active: _controller.activePreset,
            onSelected: busy ? null : _controller.applyPreset,
          ),
          const SizedBox(height: 4),
          for (final prayer in Prayer.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !busy,
              title: Text(prayer.label),
              subtitle: Text(
                status.today?.times[prayer] == null
                    ? '--:--'
                    : FrenchDates.time(status.today!.times[prayer]!),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              trailing: _ModeChip(mode: settings.modeOf(prayer)),
              onTap: () => _pickMode(context, prayer, settings.modeOf(prayer)),
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

  Future<void> _pickMode(
    BuildContext context,
    Prayer prayer,
    AdhanMode current,
  ) async {
    final picked = await showModalBottomSheet<_ModeChoice>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBF8FD),
      builder: (context) => _ModePicker(
        prayer: prayer,
        current: current,
        controller: _controller,
      ),
    );
    await _controller.stopPreview();
    if (picked == null) return;
    if (picked.applyToAll) {
      await _controller.setModeForAll(picked.mode);
    } else if (picked.mode != current) {
      await _controller.setMode(prayer, picked.mode);
    }
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

IconData _iconFor(AdhanMode mode) => switch (mode) {
      AdhanMode.off => Icons.notifications_off_outlined,
      AdhanMode.silent => Icons.notifications_paused_outlined,
      AdhanMode.notification => Icons.notifications_outlined,
      AdhanMode.adhanShort => Icons.campaign_outlined,
      AdhanMode.adhanFull => Icons.mosque_outlined,
    };

/// Profils en un appui ; « Personnalisé » s'affiche dès qu'une prière
/// s'écarte du profil.
class _PresetSelector extends StatelessWidget {
  const _PresetSelector({required this.active, required this.onSelected});

  final AdhanPreset? active;
  final ValueChanged<AdhanPreset>? onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profil', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in AdhanPreset.values)
              ChoiceChip(
                label: Text(preset.label),
                selected: active == preset,
                onSelected:
                    onSelected == null ? null : (_) => onSelected!(preset),
              ),
            if (active == null)
              const ChoiceChip(
                label: Text('Personnalisé'),
                selected: true,
                onSelected: null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          active?.description ??
              'Réglé prière par prière. Touchez une prière pour la modifier.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final AdhanMode mode;

  @override
  Widget build(BuildContext context) {
    final off = mode == AdhanMode.off;
    final color = off
        ? AppColors.textSecondary
        : mode.playsAdhan
            ? AppColors.emeraldDark
            : AppColors.copper;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_iconFor(mode), size: 20, color: color),
        const SizedBox(width: 6),
        Text(mode.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ],
    );
  }
}

class _ModeChoice {
  final AdhanMode mode;
  final bool applyToAll;
  const _ModeChoice(this.mode, {required this.applyToAll});
}

/// Choix du mode d'une prière, avec écoute des sons d'adhan.
class _ModePicker extends StatefulWidget {
  const _ModePicker({
    required this.prayer,
    required this.current,
    required this.controller,
  });

  final Prayer prayer;
  final AdhanMode current;
  final NotificationSettingsController controller;

  @override
  State<_ModePicker> createState() => _ModePickerState();
}

class _ModePickerState extends State<_ModePicker> {
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(widget.prayer.label, style: textTheme.titleLarge),
          ),
          for (final mode in AdhanMode.values)
            ListTile(
              leading: Icon(
                _iconFor(mode),
                color: mode == widget.current
                    ? AppColors.emeraldDark
                    : AppColors.textSecondary,
              ),
              title: Text(mode.label),
              subtitle: Text(mode.description),
              selected: mode == widget.current,
              trailing: AdhanAudioCatalog.previewFor(mode) == null
                  ? (mode == widget.current
                      ? const Icon(Icons.check, color: AppColors.emeraldDark)
                      : null)
                  : IconButton(
                      tooltip: widget.controller.previewing == mode
                          ? 'Arrêter l’écoute'
                          : 'Écouter',
                      icon: Icon(widget.controller.previewing == mode
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline),
                      onPressed: () => widget.controller.togglePreview(mode),
                    ),
              onTap: () => Navigator.of(context)
                  .pop(_ModeChoice(mode, applyToAll: _applyToAll)),
            ),
          CheckboxListTile.adaptive(
            value: _applyToAll,
            onChanged: (v) => setState(() => _applyToAll = v ?? false),
            title: const Text('Appliquer à toutes les prières'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_isAdhanOnIos(context))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Sur iPhone, l’adhan suit le bouton silencieux du téléphone.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  bool _isAdhanOnIos(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;
}
