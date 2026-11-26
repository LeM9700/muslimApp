/// Moment des adhkar.
enum AdhkarPeriod {
  morning('Matin', 'Adhkar du matin', '20 min après le Fajr'),
  evening('Soir', 'Adhkar du soir', '20 min après l’Asr');

  const AdhkarPeriod(this.label, this.title, this.when);

  final String label;
  final String title;

  /// Moment du rappel (texte des réglages).
  final String when;

  static AdhkarPeriod? fromName(String name) {
    for (final p in AdhkarPeriod.values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Texte d'un dhikr : arabe, phonétique, sens en français.
class AdhkarText {
  final String arabic;
  final String transliteration;
  final String translation;

  const AdhkarText(this.arabic, this.transliteration, this.translation);

  static AdhkarText? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ar = raw['ar'], tr = raw['tr'], fr = raw['fr'];
    if (ar is! String || tr is! String || fr is! String || ar.isEmpty) return null;
    return AdhkarText(ar, tr, fr);
  }
}

/// Un dhikr du matin et/ou du soir.
class AdhkarItem {
  final String id;
  final String title;
  final Set<AdhkarPeriod> periods;

  /// Nombre de répétitions recommandé.
  final int repeat;
  final String reference;
  final AdhkarText text;

  /// Variante du soir (« Amsaynâ… »), sinon le même texte.
  final AdhkarText? evening;

  const AdhkarItem({
    required this.id,
    required this.title,
    required this.periods,
    required this.repeat,
    required this.reference,
    required this.text,
    this.evening,
  });

  AdhkarText textFor(AdhkarPeriod period) =>
      period == AdhkarPeriod.evening ? (evening ?? text) : text;

  /// `null` si l'entrée est incomplète : elle est ignorée, jamais affichée
  /// à moitié (texte religieux).
  static AdhkarItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = AdhkarText.fromJson(raw['text']);
    final periods = {
      for (final p in (raw['periods'] is List ? raw['periods'] as List : const []))
        if (AdhkarPeriod.fromName('$p') != null) AdhkarPeriod.fromName('$p')!,
    };
    final repeat = raw['repeat'];
    if (text == null ||
        periods.isEmpty ||
        repeat is! int ||
        repeat < 1 ||
        raw['id'] is! String ||
        raw['title'] is! String ||
        raw['reference'] is! String) {
      return null;
    }
    return AdhkarItem(
      id: raw['id'] as String,
      title: raw['title'] as String,
      periods: Set.unmodifiable(periods),
      repeat: repeat,
      reference: raw['reference'] as String,
      text: text,
      evening: AdhkarText.fromJson(raw['evening']),
    );
  }
}

/// Recueil d'adhkar chargé depuis `assets/adhkar/adhkar_fr.json`.
class AdhkarBook {
  /// [⚠️ PROD] Faux tant qu'une personne qualifiée n'a pas relu les textes :
  /// bandeau dans l'app, et le CI bloque un build App Store.
  final bool reviewed;
  final String source;
  final List<AdhkarItem> items;

  const AdhkarBook({required this.reviewed, required this.source, required this.items});

  List<AdhkarItem> itemsFor(AdhkarPeriod period) =>
      [for (final i in items) if (i.periods.contains(period)) i];

  static AdhkarBook fromJson(Map<String, dynamic> json) => AdhkarBook(
        reviewed: json['reviewed'] == true,
        source: json['source'] as String? ?? '',
        items: [
          for (final raw in (json['items'] is List ? json['items'] as List : const []))
            if (AdhkarItem.fromJson(raw) case final item?) item,
        ],
      );
}

/// Rappels des adhkar (désactivés par défaut).
class AdhkarSettings {
  final Set<AdhkarPeriod> enabled;

  const AdhkarSettings({this.enabled = const {}});

  /// Après la prière (le temps de la faire).
  static const Duration afterPrayer = Duration(minutes: 20);

  bool get isActive => enabled.isNotEmpty;
  bool has(AdhkarPeriod p) => enabled.contains(p);

  AdhkarSettings toggle(AdhkarPeriod p, bool on) => AdhkarSettings(
      enabled: Set.unmodifiable(on ? {...enabled, p} : ({...enabled}..remove(p))));

  factory AdhkarSettings.fromJson(Object? raw) {
    if (raw is! List) return const AdhkarSettings();
    return AdhkarSettings(enabled: Set.unmodifiable({
      for (final p in raw)
        if (AdhkarPeriod.fromName('$p') != null) AdhkarPeriod.fromName('$p')!,
    }));
  }

  List<String> toJson() =>
      [for (final p in AdhkarPeriod.values) if (enabled.contains(p)) p.name];
}
