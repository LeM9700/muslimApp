import '../models/prayer_schedule.dart';

/// Nuit allant du Maghrib du jour J au Fajr du jour J+1 (instants UTC).
class NightWindow {
  final DateTime maghrib;
  final DateTime fajrNext;

  const NightWindow({required this.maghrib, required this.fajrNext});

  Duration get length => fajrNext.difference(maghrib);

  /// Début du dernier tiers : `fajr(J+1) − (fajr(J+1) − maghrib(J)) / 3`.
  ///
  /// Nuit mesurée du Maghrib au Fajr (avis majoritaire pour le qiyam).
  /// Aladhan (`Lastthird`, mode « Standard ») la mesure du coucher au
  /// lever du soleil : son heure tombe 45 à 65 min plus tard à Paris.
  DateTime get lastThirdStart =>
      fajrNext.subtract(Duration(microseconds: length.inMicroseconds ~/ 3));
}

/// Heure retenue pour le rappel du dernier tiers.
class LastThirdTime {
  /// Instant de la notification.
  final DateTime at;

  /// Vrai si le garde-fou a avancé l'heure à `Fajr − marge` : le dernier
  /// tiers est alors déjà entamé au moment de la notification (le texte
  /// le dit, plutôt que « commence »).
  final bool clampedByMargin;

  const LastThirdTime(this.at, {required this.clampedByMargin});
}

/// Calculs de la prière de nuit : fonctions pures, sans plugin ni horloge.
class NightPrayerCalculator {
  const NightPrayerCalculator._();

  /// Nuit du jour [day], ou `null` si [next] n'est pas le lendemain civil
  /// de [day] (fin du calendrier, jour rejeté par le parseur) ou si les
  /// horaires sont incohérents. On ne devine jamais un Fajr manquant.
  static NightWindow? nightOf(PrayerDay day, PrayerDay? next) {
    if (next == null || !_isNextDay(day.dateKey, next.dateKey)) return null;
    final maghrib = day.times[Prayer.maghrib];
    final fajrNext = next.times[Prayer.fajr];
    if (maghrib == null || fajrNext == null || !fajrNext.isAfter(maghrib)) {
      return null;
    }
    return NightWindow(maghrib: maghrib, fajrNext: fajrNext);
  }

  /// Heure du rappel du dernier tiers, avec garde-fou : au plus tard
  /// [fajrMarginMinutes] avant le Fajr (0 = sans garde-fou).
  ///
  /// `null` si la nuit est trop courte pour respecter la marge (hautes
  /// latitudes en été) : mieux vaut aucune notification qu'une heure
  /// absurde, avant le Maghrib.
  static LastThirdTime? lastThird(NightWindow night, {int fajrMarginMinutes = 0}) {
    final natural = night.lastThirdStart;
    if (fajrMarginMinutes <= 0) {
      return LastThirdTime(natural, clampedByMargin: false);
    }
    final latest = night.fajrNext.subtract(Duration(minutes: fajrMarginMinutes));
    if (!latest.isAfter(night.maghrib)) return null;
    return natural.isAfter(latest)
        ? LastThirdTime(latest, clampedByMargin: true)
        : LastThirdTime(natural, clampedByMargin: false);
  }

  /// Vrai si la soirée de [day] est une nuit de Ramadan.
  ///
  /// Le jour hégirien commence au Maghrib : la nuit de J appartient au
  /// jour hégirien de J+1. La 1re nuit de Tarawih est donc la veille du
  /// 1er jeûne, et la veille de l'Aïd n'en est pas une. Sans lendemain
  /// connu ou sans mois hégirien, on répond `false`.
  static bool isRamadanNight(PrayerDay day, PrayerDay? next) {
    if (next == null || !_isNextDay(day.dateKey, next.dateKey)) return false;
    return next.hijriMonth == PrayerDay.ramadan;
  }

  static bool _isNextDay(String dateKey, String nextKey) {
    final d = DateTime.tryParse(dateKey);
    final n = DateTime.tryParse(nextKey);
    if (d == null || n == null) return false;
    // Dates civiles en UTC : aucun effet des changements d'heure.
    final expected = DateTime.utc(d.year, d.month, d.day + 1);
    return DateTime.utc(n.year, n.month, n.day) == expected;
  }
}
