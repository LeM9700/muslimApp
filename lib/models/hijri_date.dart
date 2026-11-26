/// Date du calendrier de l'hégire (année, mois 1 à 12, jour 1 à 30).
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate(this.year, this.month, this.day);

  /// Numéro du mois de Ramadan.
  static const int ramadan = 9;

  bool get isRamadan => month == ramadan;

  /// Translittérations françaises usuelles.
  static const List<String> monthNames = [
    'Mouharram',
    'Safar',
    'Rabi‘ al-awwal',
    'Rabi‘ ath-thani',
    'Joumada al-oula',
    'Joumada ath-thania',
    'Rajab',
    'Cha‘bane',
    'Ramadan',
    'Chawwal',
    'Dhou al-qi‘da',
    'Dhou al-hijja',
  ];

  String get monthName => monthNames[month - 1];

  /// « 12 Ramadan 1447 » (« 1er » pour le premier jour, comme en français).
  String get label => '${day == 1 ? '1er' : '$day'} $monthName $year';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day AH';
}
