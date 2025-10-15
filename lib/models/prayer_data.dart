/// Modèle pour les données complètes de prière
/// Contient horaires, prochaine prière, countdown et position
class PrayerData {
  final Map<String, String> prayerTimes;
  final String? nextPrayerName;
  final String? nextPrayerTime;
  final Duration? timeUntilNext;
  final String cityName;
  final double? latitude;
  final double? longitude;
  final DateTime lastUpdated;

  PrayerData({
    required this.prayerTimes,
    this.nextPrayerName,
    this.nextPrayerTime,
    this.timeUntilNext,
    required this.cityName,
    this.latitude,
    this.longitude,
    required this.lastUpdated,
  });

  /// Crée une instance avec données par défaut
  factory PrayerData.empty() {
    return PrayerData(
      prayerTimes: {},
      cityName: 'Chargement...',
      lastUpdated: DateTime.now(),
    );
  }

  /// Vérifie si les données sont valides (pas vides)
  bool get isValid => prayerTimes.isNotEmpty;

  /// Vérifie si on a une prochaine prière
  bool get hasNextPrayer => nextPrayerName != null && nextPrayerTime != null;

  /// Formate le compte à rebours en HH:MM:SS
  String get formattedCountdown {
    if (timeUntilNext == null) return '--:--:--';
    
    final hours = timeUntilNext!.inHours;
    final minutes = timeUntilNext!.inMinutes.remainder(60);
    final seconds = timeUntilNext!.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  /// Formate le temps restant en texte lisible
  String get readableTimeLeft {
    if (timeUntilNext == null) return 'Calcul...';
    
    final hours = timeUntilNext!.inHours;
    final minutes = timeUntilNext!.inMinutes.remainder(60);
    
    if (hours > 0) {
      return 'dans ${hours}h ${minutes}min';
    } else if (minutes > 0) {
      return 'dans ${minutes}min';
    } else {
      return 'maintenant';
    }
  }

  @override
  String toString() {
    return 'PrayerData(city: $cityName, nextPrayer: $nextPrayerName, timeLeft: $readableTimeLeft)';
  }
}

/// Noms des prières en français pour l'affichage
class PrayerNames {
  static const Map<String, String> french = {
    'Fajr': 'Fajr',
    'Dhuhr': 'Dhuhr', 
    'Asr': 'Asr',
    'Maghrib': 'Maghrib',
    'Isha': 'Isha',
  };

  static const Map<String, String> arabic = {
    'Fajr': 'الفجر',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر', 
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  static String getFrenchName(String englishName) {
    return french[englishName] ?? englishName;
  }

  static String getArabicName(String englishName) {
    return arabic[englishName] ?? englishName;
  }
}