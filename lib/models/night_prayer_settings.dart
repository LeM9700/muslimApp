import 'adhan_mode.dart';

/// Les notifications de la prière de nuit (qiyam al-layl / tahajjud).
///
/// Volontairement hors de l'enum `Prayer` : les écrans, les profils
/// d'adhan et les tests bouclent sur les 5 prières obligatoires, et la
/// prière de nuit n'a ni adhan ni horaire fourni par Aladhan.
enum NightSlot {
  /// Rappel du soir, quelques heures après l'Isha.
  evening('Rappel du soir'),

  /// Début du dernier tiers de la nuit (hadith de la descente divine).
  lastThird('Dernier tiers de la nuit'),

  /// Soirs de Ramadan : remplace le rappel du soir.
  tarawih('Tarawih (Ramadan)');

  const NightSlot(this.label);

  final String label;

  static NightSlot? fromName(String name) {
    for (final s in NightSlot.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Réglages de la prière de nuit, imbriqués dans `NotificationSettings`.
///
/// Chaque créneau réutilise [AdhanMode] restreint à [allowedModes] :
/// `off` désactive le créneau (même convention que pour les 5 prières),
/// et il n'y a jamais d'adhan la nuit.
class NightPrayerSettings {
  /// Interrupteur général de la section (désactivé par défaut).
  final bool enabled;

  final AdhanMode evening;
  final AdhanMode lastThird;
  final AdhanMode tarawih;

  /// Délai du rappel du soir après l'Isha, en heures.
  final int eveningDelayHours;

  /// Garde-fou : le rappel du dernier tiers tombe au plus tard
  /// N minutes avant le Fajr (0 = pas de garde-fou).
  final int fajrMarginMinutes;

  const NightPrayerSettings({
    this.enabled = false,
    this.evening = AdhanMode.notification,
    this.lastThird = AdhanMode.notification,
    this.tarawih = AdhanMode.notification,
    this.eveningDelayHours = 1,
    this.fajrMarginMinutes = 30,
  });

  static const List<AdhanMode> allowedModes = [
    AdhanMode.off,
    AdhanMode.silent,
    AdhanMode.notification,
  ];
  static const List<int> eveningDelayChoices = [1, 2];
  static const List<int> fajrMarginChoices = [0, 30, 45, 60];

  /// Délai fixe de la notification Tarawih après l'Isha : les mosquées
  /// enchaînent généralement les Tarawih juste après l'Isha.
  static const Duration tarawihDelay = Duration(minutes: 15);

  /// Mode d'un créneau.
  AdhanMode modeOf(NightSlot slot) => switch (slot) {
        NightSlot.evening => evening,
        NightSlot.lastThird => lastThird,
        NightSlot.tarawih => tarawih,
      };

  /// Vrai si au moins un créneau sera programmé.
  bool get isActive =>
      enabled && NightSlot.values.any((s) => modeOf(s) != AdhanMode.off);

  NightPrayerSettings copyWith({
    bool? enabled,
    int? eveningDelayHours,
    int? fajrMarginMinutes,
  }) =>
      NightPrayerSettings(
        enabled: enabled ?? this.enabled,
        evening: evening,
        lastThird: lastThird,
        tarawih: tarawih,
        eveningDelayHours: eveningDelayHours ?? this.eveningDelayHours,
        fajrMarginMinutes: fajrMarginMinutes ?? this.fajrMarginMinutes,
      );

  /// Change le mode d'un créneau (un mode d'adhan devient « Notification »).
  NightPrayerSettings withMode(NightSlot slot, AdhanMode mode) {
    final m = _sanitize(mode);
    return NightPrayerSettings(
      enabled: enabled,
      evening: slot == NightSlot.evening ? m : evening,
      lastThird: slot == NightSlot.lastThird ? m : lastThird,
      tarawih: slot == NightSlot.tarawih ? m : tarawih,
      eveningDelayHours: eveningDelayHours,
      fajrMarginMinutes: fajrMarginMinutes,
    );
  }

  /// [⚠️ PROD] Lecture défensive : toute valeur absente ou inconnue
  /// retombe sur le défaut. Un JSON v1.3.0 (sans clé `night`) donne donc
  /// une prière de nuit désactivée.
  factory NightPrayerSettings.fromJson(Object? raw) {
    if (raw is! Map) return const NightPrayerSettings();
    AdhanMode mode(String key) {
      final value = raw[key];
      if (value == null) return AdhanMode.notification;
      return _sanitize(AdhanMode.fromName('$value') ?? AdhanMode.notification);
    }

    final delay = raw['eveningDelayHours'];
    final margin = raw['fajrMarginMinutes'];
    return NightPrayerSettings(
      enabled: raw['enabled'] == true,
      evening: mode('evening'),
      lastThird: mode('lastThird'),
      tarawih: mode('tarawih'),
      eveningDelayHours: eveningDelayChoices.contains(delay) ? delay as int : 1,
      fajrMarginMinutes: fajrMarginChoices.contains(margin) ? margin as int : 30,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'evening': evening.name,
        'lastThird': lastThird.name,
        'tarawih': tarawih.name,
        'eveningDelayHours': eveningDelayHours,
        'fajrMarginMinutes': fajrMarginMinutes,
      };

  /// Pas d'adhan pour la prière de nuit : on retombe sur une notification.
  static AdhanMode _sanitize(AdhanMode mode) =>
      allowedModes.contains(mode) ? mode : AdhanMode.notification;
}
