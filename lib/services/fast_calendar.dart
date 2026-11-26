import '../models/fasting.dart';
import '../models/hijri_date.dart';
import 'hijri_converter.dart';

/// Calcule les jours de jeûne surérogatoire : pur, sans réseau.
///
/// Règles appliquées d'office :
/// - jamais de jeûne les jours interdits : Aïd al-Fitr (1 Chawwal), Aïd
///   al-Adha (10 Dhou al-hijja) et jours de Tachriq (11-13 Dhou al-hijja),
///   même s'ils tombent un lundi, un jeudi ou un « 13 » ;
/// - pendant le Ramadan, seul le 1er jour est signalé (le jeûne est déjà
///   obligatoire : pas de rappel lundi/jeudi ni jours blancs) ;
/// - les dates suivent l'ajustement hégirien choisi par le croyant.
class FastCalendar {
  const FastCalendar._();

  static const int _ramadan = 9;
  static const int _shawwal = 10;
  static const int _dhulHijja = 12;
  static const int _muharram = 1;

  /// Vrai si jeûner ce jour est interdit.
  static bool isForbidden(HijriDate h) =>
      (h.month == _shawwal && h.day == 1) ||
      (h.month == _dhulHijja && h.day >= 10 && h.day <= 13);

  /// Jeûne de la journée civile [date], ou `null`. [kinds] `null` = tous.
  static FastDay? on(
    DateTime date, {
    int adjustment = 0,
    Set<FastKind>? kinds,
  }) {
    final civil = DateTime(date.year, date.month, date.day);
    final h = HijriConverter.fromCivil(civil, adjustment: adjustment);
    if (h == null || isForbidden(h)) return null;

    final found = <FastKind>[
      if (h.month == _ramadan && h.day == 1) FastKind.ramadanStart,
      if (h.month == _dhulHijja && h.day == 9) FastKind.arafat,
      if (h.month == _muharram && (h.day == 9 || h.day == 10)) FastKind.ashura,
      if (h.month == _shawwal && (h.day == 2 || h.day == 15)) FastKind.shawwal,
      if (h.month != _ramadan && h.day >= 13 && h.day <= 15) FastKind.whiteDays,
      if (h.month != _ramadan &&
          (civil.weekday == DateTime.monday || civil.weekday == DateTime.thursday))
        FastKind.mondayThursday,
    ].where((k) => kinds == null || kinds.contains(k)).toList();

    return found.isEmpty ? null : FastDay(date: civil, hijri: h, kinds: found);
  }

  /// Jeûnes des [days] journées à partir de [from] (inclus), dans l'ordre.
  static List<FastDay> upcoming(
    DateTime from, {
    int days = 90,
    int adjustment = 0,
    Set<FastKind>? kinds,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    return [
      for (var i = 0; i < days; i++)
        if (on(DateTime(start.year, start.month, start.day + i),
                adjustment: adjustment, kinds: kinds)
            case final day?)
          day,
    ];
  }

  /// Prochain jeûne à partir de [from], dans l'année qui vient.
  static FastDay? next(
    DateTime from, {
    int adjustment = 0,
    Set<FastKind>? kinds,
  }) {
    final list = upcoming(from, days: 400, adjustment: adjustment, kinds: kinds);
    return list.isEmpty ? null : list.first;
  }
}
