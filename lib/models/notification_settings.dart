import 'adhan_mode.dart';
import 'night_prayer_settings.dart';
import 'prayer_schedule.dart';

/// Réglages des notifications, modifiables par l'utilisateur.
///
/// Les rappels de prière sont désactivés par défaut : l'utilisateur les
/// active lui-même (c'est aussi à ce moment qu'iOS demande l'autorisation).
class NotificationSettings {
  final bool prayersEnabled;

  /// Comportement de chaque prière (adhan, notification, silencieux, aucun).
  Map<Prayer, AdhanMode> get modes => _modes ?? defaultPreset.modes;

  /// Rappel supplémentaire avant l'heure (0 = uniquement à l'heure).
  final int reminderMinutes;

  /// Méthode de calcul ; `null` = automatique.
  final int? methodId;

  final bool hadithDaily;
  final bool quizDaily;

  /// Prière de nuit (désactivée par défaut, indépendante de [prayersEnabled]).
  final NightPrayerSettings night;

  /// Chronologie des prières sur l'écran verrouillé (widget iOS).
  /// Désactivée par défaut ; ne demande pas l'autorisation de notifier.
  final bool lockScreenWidget;

  const NotificationSettings({
    this.prayersEnabled = false,
    Map<Prayer, AdhanMode>? modes,
    this.reminderMinutes = 0,
    this.methodId,
    this.hadithDaily = true,
    this.quizDaily = true,
    this.night = const NightPrayerSettings(),
    this.lockScreenWidget = false,
  }) : _modes = modes;

  // Champ privé + getter : permet un constructeur `const` avec un profil
  // par défaut (une Map ne peut pas être une valeur par défaut calculée).
  final Map<Prayer, AdhanMode>? _modes;

  static const List<int> reminderChoices = [0, 10, 15, 30];

  /// Nouvel utilisateur : profil « Équilibré ».
  static const AdhanPreset defaultPreset = AdhanPreset.balanced;

  /// Mode d'une prière (une prière absente de la map est désactivée).
  AdhanMode modeOf(Prayer prayer) => modes[prayer] ?? AdhanMode.off;

  /// Prières pour lesquelles une notification est envoyée.
  Set<Prayer> get prayers =>
      {for (final p in Prayer.values) if (modeOf(p) != AdhanMode.off) p};

  NotificationSettings copyWith({
    bool? prayersEnabled,
    Map<Prayer, AdhanMode>? modes,
    int? reminderMinutes,
    int? Function()? methodId,
    bool? hadithDaily,
    bool? quizDaily,
    NightPrayerSettings? night,
    bool? lockScreenWidget,
  }) {
    return NotificationSettings(
      prayersEnabled: prayersEnabled ?? this.prayersEnabled,
      modes: Map.unmodifiable(modes ?? this.modes),
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      methodId: methodId != null ? methodId() : this.methodId,
      hadithDaily: hadithDaily ?? this.hadithDaily,
      quizDaily: quizDaily ?? this.quizDaily,
      night: night ?? this.night,
      lockScreenWidget: lockScreenWidget ?? this.lockScreenWidget,
    );
  }

  /// Les notifications de prière (5 prières ou prière de nuit) ont besoin
  /// du calendrier et de la position.
  bool get needsCalendar => prayersEnabled || night.isActive || lockScreenWidget;

  /// Change le mode d'une seule prière.
  NotificationSettings withMode(Prayer prayer, AdhanMode mode) =>
      copyWith(modes: {...modes, prayer: mode});

  /// [⚠️ PROD] Migration v1.2.0 → v1.3.0 : l'ancien format stockait un
  /// ensemble `prayers`. Une prière cochée devient « Notification » (le
  /// comportement qu'avait l'utilisateur), une prière décochée « Désactivé ».
  /// On ne bascule jamais un utilisateur existant sur l'adhan sans son accord.
  ///
  /// [⚠️ PROD] v1.3.0 → v1.4.0 : les clés `night` et `lockScreenWidget`
  /// sont absentes des réglages existants : tout reste désactivé.
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final reminder = json['reminderMinutes'] as int? ?? 0;
    return NotificationSettings(
      prayersEnabled: json['prayersEnabled'] as bool? ?? false,
      modes: _readModes(json),
      reminderMinutes: reminderChoices.contains(reminder) ? reminder : 0,
      methodId: json['methodId'] as int?,
      hadithDaily: json['hadithDaily'] as bool? ?? true,
      quizDaily: json['quizDaily'] as bool? ?? true,
      night: NightPrayerSettings.fromJson(json['night']),
      lockScreenWidget: json['lockScreenWidget'] == true,
    );
  }

  static Map<Prayer, AdhanMode>? _readModes(Map<String, dynamic> json) {
    final raw = json['modes'];
    if (raw is Map) {
      return Map.unmodifiable({
        for (final p in Prayer.values)
          p: AdhanMode.fromName('${raw[p.name]}') ?? AdhanMode.off,
      });
    }
    final legacy = json['prayers'];
    if (legacy is List) {
      final names = legacy.map((e) => '$e').toSet();
      return Map.unmodifiable({
        for (final p in Prayer.values)
          p: names.contains(p.name) ? AdhanMode.notification : AdhanMode.off,
      });
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'prayersEnabled': prayersEnabled,
        'modes': {for (final p in Prayer.values) p.name: modeOf(p).name},
        'reminderMinutes': reminderMinutes,
        'methodId': methodId,
        'hadithDaily': hadithDaily,
        'quizDaily': quizDaily,
        'night': night.toJson(),
        'lockScreenWidget': lockScreenWidget,
      };
}
