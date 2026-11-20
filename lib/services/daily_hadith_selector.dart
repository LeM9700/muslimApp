import '../models/hadith_category.dart';

/// Position d'un hadith dans une catégorie (position à partir de 1).
class HadithSlot {
  final String categoryId;
  final int position;

  const HadithSlot(this.categoryId, this.position);

  @override
  bool operator ==(Object other) =>
      other is HadithSlot &&
      other.categoryId == categoryId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(categoryId, position);

  @override
  String toString() => 'HadithSlot($categoryId, $position)';
}

/// Choix déterministe du hadith du jour, sans état ni réseau.
///
/// Tous les utilisateurs voient le même hadith à une date donnée (on peut
/// en parler entre proches). On parcourt l'ensemble des hadiths avec un pas
/// premier avec le total : aucune répétition avant d'avoir tout vu, et les
/// catégories sont mélangées au lieu d'être lues dans l'ordre.
class DailyHadithSelector {
  const DailyHadithSelector._();

  /// Pas de départ (nombre premier) : assez grand pour sauter d'une
  /// catégorie à l'autre d'un jour sur l'autre.
  static const int _baseStride = 1543;

  /// Clé de date locale AAAA-MM-JJ, utilisée aussi par le cache.
  static String dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Nombre de jours depuis l'époque Unix pour la date locale de [date].
  /// Calculé en UTC pour ne pas être faussé par les changements d'heure.
  static int dayNumber(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(1970))
          .inDays;

  /// Index global (0 ≤ index < [total]) du hadith pour [date].
  static int indexForDate(DateTime date, int total) {
    if (total <= 0) throw ArgumentError.value(total, 'total', 'doit être > 0');
    final stride = strideFor(total);
    return (dayNumber(date) * stride) % total;
  }

  /// Premier pas ≥ [_baseStride] premier avec [total] : garantit que
  /// `jour * pas mod total` visite tous les index avant de boucler.
  static int strideFor(int total) {
    var stride = _baseStride;
    while (_gcd(stride, total) != 1) {
      stride++;
    }
    return stride;
  }

  /// Convertit un index global en (catégorie, position) en cumulant les
  /// nombres de hadiths des catégories, triées par identifiant pour que le
  /// résultat ne dépende pas de l'ordre renvoyé par l'API.
  static HadithSlot slotForIndex(List<HadithCategory> roots, int index) {
    final sorted = roots.where((c) => c.hadithCount > 0).toList()
      ..sort((a, b) =>
          (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));
    var remaining = index;
    for (final category in sorted) {
      if (remaining < category.hadithCount) {
        return HadithSlot(category.id, remaining + 1);
      }
      remaining -= category.hadithCount;
    }
    throw RangeError.index(index, roots, 'index');
  }

  static int totalCount(List<HadithCategory> roots) =>
      roots.fold(0, (sum, c) => sum + (c.hadithCount > 0 ? c.hadithCount : 0));

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a.abs();
  }
}
