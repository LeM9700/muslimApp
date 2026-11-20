/// Formats de date en français, sans dépendre de l'initialisation des
/// données de locale d'`intl` (qui échoue silencieusement si oubliée).
class FrenchDates {
  const FrenchDates._();

  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// « 06:53 » dans le fuseau de l'appareil.
  static String time(DateTime instant) {
    final local = instant.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  /// « mardi 1er décembre » dans le fuseau de l'appareil.
  static String dayMonth(DateTime instant) {
    final local = instant.toLocal();
    final day = local.day == 1 ? '1er' : '${local.day}';
    return '${_weekdays[local.weekday - 1]} $day ${_months[local.month - 1]}';
  }
}
