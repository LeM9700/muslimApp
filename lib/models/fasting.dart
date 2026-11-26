import 'hijri_date.dart';

/// Jeûnes surérogatoires et dates clés rappelés par l'app.
///
/// L'ordre est celui de la priorité d'affichage quand plusieurs motifs
/// tombent le même jour (ex. un jour blanc qui est aussi un jeudi).
enum FastKind {
  ramadanStart(
    'Début du Ramadan',
    'La veille du premier jour de jeûne.',
    'Celui qui jeûne le Ramadan avec foi et espérance voit ses péchés '
        'passés pardonnés.',
    'Bukhari 38',
  ),
  arafat(
    'Jour d’Arafat',
    '9 Dhou al-hijja.',
    'Son jeûne expie les péchés de l’année passée et de l’année à venir.',
    'Muslim 1162',
  ),
  ashura(
    'Tasu‘a et Achoura',
    '9 et 10 Mouharram.',
    'Le jeûne d’Achoura expie les péchés de l’année passée ; le Prophète ﷺ '
        'voulait y joindre le 9.',
    'Muslim 1162, 1134',
  ),
  shawwal(
    '6 jours de Chawwal',
    'À partir du 2 Chawwal, rappel aussi à mi-mois.',
    'Jeûner le Ramadan puis six jours de Chawwal équivaut au jeûne de toute '
        'l’année.',
    'Muslim 1164',
  ),
  whiteDays(
    'Jours blancs',
    '13, 14 et 15 de chaque mois hégirien.',
    'Le Prophète ﷺ recommandait de jeûner les 13, 14 et 15 du mois.',
    'Tirmidhi 761',
  ),
  mondayThursday(
    'Lundi et jeudi',
    'Chaque semaine.',
    'Les œuvres sont présentées le lundi et le jeudi : le Prophète ﷺ aimait '
        'qu’elles le soient alors qu’il jeûnait.',
    'Tirmidhi 747',
  );

  const FastKind(this.label, this.when, this.virtue, this.reference);

  final String label;

  /// Quand tombe ce jeûne (texte court pour les réglages).
  final String when;

  /// Mérite, d'après le hadith cité.
  final String virtue;
  final String reference;

  static FastKind? fromName(String name) {
    for (final k in FastKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Un jour de jeûne (date civile) et ses motifs.
class FastDay {
  /// Journée civile (seuls l'année, le mois et le jour comptent).
  final DateTime date;
  final HijriDate hijri;

  /// Motifs du jour, du plus important au moins important.
  final List<FastKind> kinds;

  const FastDay({required this.date, required this.hijri, required this.kinds});

  FastKind get mainKind => kinds.first;

  /// « Jour d’Arafat », « Achoura », « Tasu‘a », « Jour blanc », « Lundi »…
  String get title => switch (mainKind) {
        FastKind.ramadanStart => '1er jour du Ramadan',
        FastKind.arafat => 'Jour d’Arafat',
        FastKind.ashura => hijri.day == 9 ? 'Tasu‘a' : 'Achoura',
        FastKind.shawwal => hijri.day == 2
            ? 'Début des 6 jours de Chawwal'
            : '6 jours de Chawwal : mi-mois',
        FastKind.whiteDays => 'Jour blanc',
        FastKind.mondayThursday => date.weekday == DateTime.monday ? 'Lundi' : 'Jeudi',
      };
}

/// Réglages des rappels de jeûne, imbriqués dans `NotificationSettings`.
class FastingSettings {
  /// Rappels activés (désactivés par défaut : demande l'autorisation).
  final bool enabled;

  /// Jeûnes rappelés. Par défaut tous sauf lundi et jeudi (2 rappels par
  /// semaine : risque de lassitude, l'utilisateur les active lui-même).
  final Set<FastKind> kinds;

  const FastingSettings({this.enabled = false, this.kinds = defaultKinds});

  static const Set<FastKind> defaultKinds = {
    FastKind.ramadanStart,
    FastKind.arafat,
    FastKind.ashura,
    FastKind.shawwal,
    FastKind.whiteDays,
  };

  /// Décalage du rappel après l'Isha, la veille.
  static const Duration reminderAfterIsha = Duration(minutes: 30);

  bool get isActive => enabled && kinds.isNotEmpty;

  FastingSettings copyWith({bool? enabled, Set<FastKind>? kinds}) =>
      FastingSettings(
        enabled: enabled ?? this.enabled,
        kinds: Set.unmodifiable(kinds ?? this.kinds),
      );

  FastingSettings toggle(FastKind kind, bool on) => copyWith(
      kinds: on ? {...kinds, kind} : ({...kinds}..remove(kind)));

  /// [⚠️ PROD] Absent (réglages ≤ v1.4.0) → désactivé ; types inconnus
  /// (version future) ignorés.
  factory FastingSettings.fromJson(Object? raw) {
    if (raw is! Map) return const FastingSettings();
    final list = raw['kinds'];
    return FastingSettings(
      enabled: raw['enabled'] == true,
      kinds: list is List
          ? Set.unmodifiable({
              for (final k in list)
                if (FastKind.fromName('$k') != null) FastKind.fromName('$k')!,
            })
          : defaultKinds,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'kinds': [for (final k in FastKind.values) if (kinds.contains(k)) k.name],
      };
}
