/// Rappels du vendredi.
enum FridayReminder {
  kahf('Sourate al-Kahf', 'Le vendredi à 9 h'),
  jumua('Prière du vendredi', '45 min avant le Dhuhr');

  const FridayReminder(this.label, this.when);

  final String label;
  final String when;

  static FridayReminder? fromName(String name) {
    for (final r in FridayReminder.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// Réglages des rappels du vendredi (tous désactivés par défaut).
class FridaySettings {
  final Set<FridayReminder> enabled;

  const FridaySettings({this.enabled = const {}});

  /// Heure locale du rappel al-Kahf.
  static const int kahfHour = 9;

  /// Avance du rappel de la Jumu‘a sur le Dhuhr (ghusl, trajet).
  static const Duration jumuaLead = Duration(minutes: 45);

  bool get isActive => enabled.isNotEmpty;
  bool has(FridayReminder r) => enabled.contains(r);

  FridaySettings toggle(FridayReminder r, bool on) => FridaySettings(
      enabled: Set.unmodifiable(on ? {...enabled, r} : ({...enabled}..remove(r))));

  /// [⚠️ PROD] Absent (réglages ≤ v1.4.0) → aucun rappel.
  factory FridaySettings.fromJson(Object? raw) {
    if (raw is! List) return const FridaySettings();
    return FridaySettings(enabled: Set.unmodifiable({
      for (final r in raw)
        if (FridayReminder.fromName('$r') != null) FridayReminder.fromName('$r')!,
    }));
  }

  List<String> toJson() =>
      [for (final r in FridayReminder.values) if (enabled.contains(r)) r.name];
}
