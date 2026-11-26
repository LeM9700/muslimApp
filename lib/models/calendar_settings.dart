/// Calendrier dans lequel le croyant préfère lire les dates.
enum DateCalendar {
  gregorian('Grégorien'),
  hijri('Hégirien');

  const DateCalendar(this.label);

  final String label;

  static DateCalendar? fromName(String name) {
    for (final c in DateCalendar.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// Préférences de calendrier, valables pour toute l'app.
class CalendarSettings {
  /// Calendrier affiché en premier (l'autre reste visible en second).
  final DateCalendar primary;

  /// Décalage en jours par rapport au calendrier Umm al-Qura, pour
  /// suivre l'annonce locale (observation de la lune) : +1 = les mois
  /// commencent un jour plus tard. Appliqué partout, Tarawih compris.
  final int hijriAdjustment;

  const CalendarSettings({
    this.primary = DateCalendar.gregorian,
    this.hijriAdjustment = 0,
  });

  static const List<int> adjustmentChoices = [-2, -1, 0, 1, 2];

  CalendarSettings copyWith({DateCalendar? primary, int? hijriAdjustment}) =>
      CalendarSettings(
        primary: primary ?? this.primary,
        hijriAdjustment: hijriAdjustment ?? this.hijriAdjustment,
      );

  /// [🔒 SÉCURITÉ] Lecture défensive : valeur inconnue → défaut.
  factory CalendarSettings.fromJson(Object? raw) {
    if (raw is! Map) return const CalendarSettings();
    final adjustment = raw['hijriAdjustment'];
    return CalendarSettings(
      primary: DateCalendar.fromName('${raw['primary']}') ?? DateCalendar.gregorian,
      hijriAdjustment:
          adjustmentChoices.contains(adjustment) ? adjustment as int : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'primary': primary.name,
        'hijriAdjustment': hijriAdjustment,
      };
}
