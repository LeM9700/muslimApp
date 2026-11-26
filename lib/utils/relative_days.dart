/// « Aujourd’hui », « Demain », « Dans 3 jours » entre deux dates civiles.
String relativeDays(DateTime today, DateTime date) {
  final a = DateTime.utc(today.year, today.month, today.day);
  final b = DateTime.utc(date.year, date.month, date.day);
  final days = b.difference(a).inDays;
  return switch (days) {
    0 => 'Aujourd’hui',
    1 => 'Demain',
    _ when days < 0 => 'Passé',
    _ => 'Dans $days jours',
  };
}
