import 'package:hijri/hijri_calendar.dart';

import '../models/calendar_settings.dart';
import '../models/hijri_date.dart';
import '../utils/french_dates.dart';

/// Conversion grégorien → hégire, hors connexion.
///
/// Source : tables officielles Umm al-Qura (paquet `hijri`, 1356 à
/// 1500 AH, soit ~1937 à 2077), identiques jour pour jour au calendrier
/// UAQ d'Aladhan (vérifié sur 2026–2027). Le décalage de
/// [CalendarSettings.hijriAdjustment] permet de suivre l'annonce locale.
///
/// Pur : on n'utilise que les champs numériques du paquet, jamais ses
/// noms de mois (état global `HijriCalendar.language`).
class HijriConverter {
  const HijriConverter._();

  /// Date hégirienne de la journée civile [civilDate] (seuls l'année, le
  /// mois et le jour comptent), ou `null` hors de la table.
  ///
  /// Convention des calendriers usuels : c'est la date de la journée.
  /// Le jour hégirien commence en réalité au Maghrib la veille (voir
  /// `NightPrayerCalculator.hijriOfNight`).
  static HijriDate? fromCivil(DateTime civilDate, {int adjustment = 0}) {
    final shifted = DateTime.utc(
        civilDate.year, civilDate.month, civilDate.day - adjustment);
    try {
      final h = HijriCalendar.fromDate(shifted);
      if (h.hMonth < 1 || h.hMonth > 12 || h.hDay < 1 || h.hDay > 30) {
        return null;
      }
      return HijriDate(h.hYear, h.hMonth, h.hDay);
    } on Object {
      return null;
    }
  }

  /// Date d'une clé civile « AAAA-MM-JJ » (celle de `PrayerDay.dateKey`).
  static HijriDate? fromDateKey(String dateKey, {int adjustment = 0}) {
    final parsed = DateTime.tryParse(dateKey);
    return parsed == null ? null : fromCivil(parsed, adjustment: adjustment);
  }
}

/// Libellés de date selon la préférence du croyant.
class DateLabels {
  /// Calendrier préféré, affiché en premier.
  final String primary;

  /// L'autre calendrier (vide si la date hégirienne est hors table).
  final String secondary;

  const DateLabels(this.primary, this.secondary);

  /// Pour la journée civile [civilDate] : « jeudi 26 novembre 2026 » et
  /// « 5 Joumada ath-thania 1448 », dans l'ordre choisi.
  factory DateLabels.of(DateTime civilDate, CalendarSettings settings) {
    final gregorian = FrenchDates.fullDate(civilDate);
    final hijri = HijriConverter.fromCivil(civilDate,
            adjustment: settings.hijriAdjustment)
        ?.label;
    if (hijri == null) return DateLabels(gregorian, '');
    return settings.primary == DateCalendar.hijri
        ? DateLabels(hijri, gregorian)
        : DateLabels(gregorian, hijri);
  }

  /// Date courte pour une phrase (« jusqu’au … ») dans le calendrier
  /// préféré : « mardi 1er décembre » ou « 21 Joumada al-oula 1448 ».
  static String inSentence(DateTime instant, CalendarSettings settings) {
    if (settings.primary == DateCalendar.hijri) {
      final local = instant.toLocal();
      final h = HijriConverter.fromCivil(local,
          adjustment: settings.hijriAdjustment);
      if (h != null) return h.label;
    }
    return FrenchDates.dayMonth(instant);
  }
}
