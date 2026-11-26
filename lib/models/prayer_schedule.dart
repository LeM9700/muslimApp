/// Les 5 prières quotidiennes, dans l'ordre chronologique.
enum Prayer {
  fajr('Fajr', 'Fajr'),
  dhuhr('Dhuhr', 'Dhuhr'),
  asr('Asr', 'Asr'),
  maghrib('Maghrib', 'Maghrib'),
  isha('Isha', 'Isha');

  const Prayer(this.apiKey, this.label);

  /// Clé du champ dans les réponses Aladhan.
  final String apiKey;

  /// Nom affiché (translittération usuelle en français).
  final String label;

  static Prayer? fromName(String name) {
    for (final p in Prayer.values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Horaires d'une journée, en instants absolus.
///
/// Les heures viennent d'Aladhan au format ISO 8601 avec décalage
/// (« 2026-11-20T06:53:00+01:00 ») : ce sont des instants sans ambiguïté,
/// indépendants du fuseau de l'appareil et des changements d'heure.
class PrayerDay {
  /// Date civile au lieu des horaires (AAAA-MM-JJ).
  final String dateKey;

  /// Instants UTC de chaque prière.
  final Map<Prayer, DateTime> times;

  /// Mois hégirien de la journée (9 = Ramadan), tel que calculé par
  /// Aladhan. `null` pour un calendrier mis en cache avant la v1.4.0 :
  /// le mois est alors inconnu, jamais deviné.
  final int? hijriMonth;

  const PrayerDay({required this.dateKey, required this.times, this.hijriMonth});

  /// Numéro du mois de Ramadan dans le calendrier hégirien.
  static const int ramadan = 9;

  factory PrayerDay.fromJson(Map<String, dynamic> json) {
    final raw = json['times'] as Map<String, dynamic>? ?? const {};
    return PrayerDay(
      dateKey: json['date'] as String? ?? '',
      times: {
        for (final entry in raw.entries)
          if (Prayer.fromName(entry.key) != null &&
              DateTime.tryParse('${entry.value}') != null)
            Prayer.fromName(entry.key)!: DateTime.parse('${entry.value}').toUtc(),
      },
      hijriMonth: json['hijriMonth'] is int ? json['hijriMonth'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'times': {
          for (final e in times.entries) e.key.name: e.value.toIso8601String(),
        },
        if (hijriMonth != null) 'hijriMonth': hijriMonth,
      };
}

/// Position utilisée pour calculer les horaires des notifications.
///
/// Enregistrée parce que les notifications sont programmées plusieurs jours
/// à l'avance : elles doivent suivre la ville choisie, pas une position GPS
/// relue à chaque ouverture.
class PrayerLocation {
  final double latitude;
  final double longitude;
  final String cityName;

  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.cityName,
  });

  /// Clé de cache : ~1 km de précision suffit pour des horaires à la minute.
  String get cacheKey =>
      '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';

  factory PrayerLocation.fromJson(Map<String, dynamic> json) => PrayerLocation(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        cityName: json['city'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'city': cityName,
      };
}

/// Méthode de calcul des horaires (paramètre `method` d'Aladhan).
class CalculationMethod {
  /// `null` : Aladhan choisit l'autorité la plus proche de la position
  /// (UOIF pour la France, Umm al-Qura pour l'Arabie…).
  final int? id;
  final String label;

  const CalculationMethod(this.id, this.label);

  static const auto = CalculationMethod(null, 'Automatique (selon la position)');

  /// Méthodes proposées : les plus utilisées par un public francophone.
  static const List<CalculationMethod> choices = [
    auto,
    CalculationMethod(12, 'UOIF (France)'),
    CalculationMethod(3, 'Ligue islamique mondiale'),
    CalculationMethod(21, 'Maroc'),
    CalculationMethod(19, 'Algérie'),
    CalculationMethod(18, 'Tunisie'),
    CalculationMethod(13, 'Turquie (Diyanet)'),
    CalculationMethod(5, 'Égypte'),
    CalculationMethod(4, 'Umm al-Qura (La Mecque)'),
    CalculationMethod(2, 'ISNA (Amérique du Nord)'),
  ];

  static CalculationMethod fromId(int? id) =>
      choices.firstWhere((m) => m.id == id, orElse: () => auto);
}
