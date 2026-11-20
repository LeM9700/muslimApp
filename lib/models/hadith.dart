import 'hadith_grade.dart';

/// Origine d'un hadith, pour savoir quoi créditer et quoi afficher.
enum HadithProvider {
  /// Encyclopédie des hadiths traduits (hadeethenc.com) : traduction,
  /// degré, explication et enseignements relus.
  hadeethEnc,

  /// API Sunnah.com (utilisée seulement si elle fournit le français).
  sunnah,

  /// Les 42 hadiths Nawawi embarqués / seedés dans Firestore.
  nawawiLocal,

  /// Origine inconnue (anciens documents Firestore, mocks).
  other;

  static HadithProvider fromName(String? name) => HadithProvider.values
      .firstWhere((p) => p.name == name, orElse: () => HadithProvider.other);
}

/// Modèle d'un hadith, quelle que soit sa source.
///
/// [text] reste le texte complet historique (arabe + traduction) pour la
/// compatibilité Firestore. Les champs détaillés ([translation],
/// [textArabic], [explanation]…) sont renseignés quand la source les fournit.
class Hadith {
  final String id;
  final String text;
  final String source;
  final bool reviewed;
  final DateTime? createdAt;

  /// Champs additionnels provenant de l'API Sunnah.com
  final String? collection; // ex: "bukhari", "muslim"
  final String? hadithNumber; // ex: "1", "6018"

  /// Degré brut tel que donné par la source (ex : « Authentique »,
  /// « An-Nawawî a dit : Hadith bon »).
  final String? grade;

  /// Degré brut en arabe, plus fiable pour la normalisation.
  final String? gradeArabic;

  /// Titre court (souvent les paroles prophétiques clés).
  final String? title;

  /// Traduction française du hadith, sans la chaîne d'introduction.
  final String? translation;

  /// Introduction du rapporteur (« D'après Abû Hurayra… a dit : »).
  final String? narratorIntro;

  /// Texte arabe complet.
  final String? textArabic;

  /// Explication complète du hadith.
  final String? explanation;

  /// Enseignements à retenir.
  final List<String> hints;

  final HadithProvider provider;

  const Hadith({
    required this.id,
    required this.text,
    required this.source,
    required this.reviewed,
    this.createdAt,
    this.collection,
    this.hadithNumber,
    this.grade,
    this.gradeArabic,
    this.title,
    this.translation,
    this.narratorIntro,
    this.textArabic,
    this.explanation,
    this.hints = const [],
    this.provider = HadithProvider.other,
  });

  /// Degré normalisé, prêt à être affiché et expliqué.
  HadithGrade get gradeLevel =>
      HadithGrade.fromLabels(arabic: gradeArabic, label: grade);

  /// Vrai si le degré vient du renforcement par d'autres chaînes.
  bool get isGradeReinforced =>
      HadithGrade.isReinforced(arabic: gradeArabic, label: grade);

  /// Texte à afficher en priorité : la traduction française si elle existe.
  String get displayText {
    final t = translation;
    return (t != null && t.isNotEmpty) ? t : text;
  }

  bool get hasExplanation =>
      (explanation?.isNotEmpty ?? false) || hints.isNotEmpty;

  /// Crée un Hadith depuis un document Firestore
  /// Utilise les champs : text, source, reviewed, created_at
  factory Hadith.fromFirestore(Map<String, dynamic> data, String id) {
    return Hadith.fromMap({...data, 'id': id});
  }

  /// Crée un Hadith depuis une Map (avec id inclus).
  /// Sert aussi à relire le cache local (voir [toMap]).
  factory Hadith.fromMap(Map<String, dynamic> data) {
    final createdAt = data['created_at'];
    return Hadith(
      id: data['id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? '',
      reviewed: data['reviewed'] as bool? ?? false,
      createdAt: switch (createdAt) {
        DateTime d => d,
        String s => DateTime.tryParse(s),
        null => null,
        // Timestamp Firestore (évite d'importer cloud_firestore dans le modèle)
        _ => (createdAt as dynamic).toDate() as DateTime?,
      },
      collection: data['collection'] as String?,
      hadithNumber: data['hadithNumber'] as String?,
      grade: data['grade'] as String?,
      gradeArabic: data['gradeArabic'] as String?,
      title: data['title'] as String?,
      translation: data['translation'] as String?,
      narratorIntro: data['narratorIntro'] as String?,
      textArabic: data['textArabic'] as String?,
      explanation: data['explanation'] as String?,
      hints: (data['hints'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      provider: HadithProvider.fromName(data['provider'] as String?),
    );
  }

  /// Sérialisation complète (JSON-compatible) pour le cache local.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'source': source,
      'reviewed': reviewed,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (collection != null) 'collection': collection,
      if (hadithNumber != null) 'hadithNumber': hadithNumber,
      if (grade != null) 'grade': grade,
      if (gradeArabic != null) 'gradeArabic': gradeArabic,
      if (title != null) 'title': title,
      if (translation != null) 'translation': translation,
      if (narratorIntro != null) 'narratorIntro': narratorIntro,
      if (textArabic != null) 'textArabic': textArabic,
      if (explanation != null) 'explanation': explanation,
      if (hints.isNotEmpty) 'hints': hints,
      'provider': provider.name,
    };
  }

  /// Convertit le Hadith en Map pour Firestore
  /// Utilisé si besoin d'écriture (admin uniquement)
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'source': source,
      'reviewed': reviewed,
      'created_at': createdAt,
      if (collection != null) 'collection': collection,
      if (hadithNumber != null) 'hadithNumber': hadithNumber,
      if (grade != null) 'grade': grade,
    };
  }

  /// Copie le hadith avec modifications optionnelles
  Hadith copyWith({
    String? id,
    String? text,
    String? source,
    bool? reviewed,
    DateTime? createdAt,
    String? collection,
    String? hadithNumber,
    String? grade,
  }) {
    return Hadith(
      id: id ?? this.id,
      text: text ?? this.text,
      source: source ?? this.source,
      reviewed: reviewed ?? this.reviewed,
      createdAt: createdAt ?? this.createdAt,
      collection: collection ?? this.collection,
      hadithNumber: hadithNumber ?? this.hadithNumber,
      grade: grade ?? this.grade,
      gradeArabic: gradeArabic,
      title: title,
      translation: translation,
      narratorIntro: narratorIntro,
      textArabic: textArabic,
      explanation: explanation,
      hints: hints,
      provider: provider,
    );
  }

  @override
  String toString() {
    return 'Hadith(id: $id, text: ${text.substring(0, text.length.clamp(0, 50))}..., source: $source, reviewed: $reviewed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hadith && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
