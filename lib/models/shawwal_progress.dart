/// Jours de Chawwal jeûnés pour une année hégirienne donnée.
class ShawwalProgress {
  /// Année hégirienne du Chawwal suivi.
  final int hijriYear;

  /// Journées civiles jeûnées (« AAAA-MM-JJ »).
  final Set<String> days;

  const ShawwalProgress({required this.hijriYear, this.days = const {}});

  /// Objectif : 6 jours (Muslim 1164).
  static const int goal = 6;

  int get count => days.length;
  bool get isComplete => count >= goal;

  ShawwalProgress toggle(String dateKey) => ShawwalProgress(
        hijriYear: hijriYear,
        days: Set.unmodifiable(days.contains(dateKey)
            ? ({...days}..remove(dateKey))
            : {...days, dateKey}),
      );

  /// [🔒 SÉCURITÉ] Lecture défensive : format inattendu → `null`.
  static ShawwalProgress? fromJson(Object? raw) {
    if (raw is! Map || raw['hijriYear'] is! int) return null;
    final list = raw['days'];
    return ShawwalProgress(
      hijriYear: raw['hijriYear'] as int,
      days: Set.unmodifiable({
        if (list is List)
          for (final d in list)
            if (d is String && DateTime.tryParse(d) != null) d,
      }),
    );
  }

  Map<String, dynamic> toJson() => {
        'hijriYear': hijriYear,
        'days': days.toList()..sort(),
      };
}
