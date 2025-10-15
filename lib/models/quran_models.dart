/// Modèles pour l'API Quran Foundation v4
/// https://api.quran.com/api/v4

/// Modèle pour un verset avec texte arabe, traduction FR et audio
class Verse {
  final int id;
  final int verseNumber;
  final String textUthmani;        // arabe (uthmani)
  final String? translationText;   // texte français
  final String? audioUrl;          // URL audio (si demandé)
  final String? verseKey;          // ex: "1:1" (sourate:verset)

  Verse({
    required this.id,
    required this.verseNumber,
    required this.textUthmani,
    this.translationText,
    this.audioUrl,
    this.verseKey,
  });

  /// Parse depuis l'API Quran Foundation v4
  /// API format: "verse_key", "text_uthmani", "translations"[0]["text"], "audio":{"url":...}
  factory Verse.fromApi(Map<String, dynamic> json) {
    final translations = (json['translations'] as List?) ?? const [];
    final firstTr = translations.isNotEmpty ? translations.first : null;

    final audio = json['audio'];
    
    return Verse(
      id: json['id'] as int? ?? 0,
      verseNumber: json['verse_number'] as int? ?? 0,
      textUthmani: json['text_uthmani'] as String? ?? '',
      translationText: firstTr != null ? (firstTr['text'] as String?) : null,
      audioUrl: (audio != null) ? (audio['url'] as String?) : null,
      verseKey: json['verse_key'] as String?,
    );
  }

  /// Pour debugging
  @override
  String toString() {
    return 'Verse(id: $id, verseNumber: $verseNumber, verseKey: $verseKey)';
  }
}

/// Métadonnées d'une sourate depuis l'API
class ChapterInfo {
  final int number;
  final String nameAr;         // nom arabe
  final String? nameSimple;    // nom simple (latin)
  final String? nameComplex;   // nom complexe
  final int ayahCount;         // nombre de versets
  final String? revelationPlace; // Meccan/Medinan
  final int? revelationOrder;   // ordre de révélation

  ChapterInfo({
    required this.number,
    required this.nameAr,
    this.nameSimple,
    this.nameComplex,
    required this.ayahCount,
    this.revelationPlace,
    this.revelationOrder,
  });

  /// Parse depuis l'API chapters endpoint
  factory ChapterInfo.fromApi(Map<String, dynamic> json) {
    return ChapterInfo(
      number: json['id'] as int? ?? 0,
      nameAr: json['name_arabic'] as String? ?? '',
      nameSimple: json['name_simple'] as String?,
      nameComplex: json['name_complex'] as String?,
      ayahCount: json['verses_count'] as int? ?? 0,
      revelationPlace: json['revelation_place'] as String?,
      revelationOrder: json['revelation_order'] as int?,
    );
  }

  /// Nom d'affichage prioritaire
  String get displayName => nameSimple ?? nameComplex ?? nameAr;

  @override
  String toString() {
    return 'ChapterInfo(number: $number, nameAr: $nameAr, ayahCount: $ayahCount)';
  }
}

/// Métadonnées d'un récitateur pour l'audio
class Reciter {
  final int id;
  final String name;
  final String? style;         // ex: "Murattal", "Mujawwad"
  final String? translatedName;

  Reciter({
    required this.id,
    required this.name,
    this.style,
    this.translatedName,
  });

  factory Reciter.fromApi(Map<String, dynamic> json) {
    return Reciter(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      style: json['style'] as String?,
      translatedName: json['translated_name'] != null 
          ? (json['translated_name']['name'] as String?)
          : null,
    );
  }
}

/// Métadonnées d'une traduction
class Translation {
  final int id;
  final String name;
  final String? authorName;
  final String languageName;

  Translation({
    required this.id,
    required this.name,
    this.authorName,
    required this.languageName,
  });

  factory Translation.fromApi(Map<String, dynamic> json) {
    return Translation(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      authorName: json['author_name'] as String?,
      languageName: json['language_name'] as String? ?? '',
    );
  }
}