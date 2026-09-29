/// Modèle pour un hadith (API Sunnah.com ou Firestore)
/// Représente un hadith avec son texte, sa source et son statut de validation
class Hadith {
  final String id;
  final String text;
  final String source;
  final bool reviewed;
  final DateTime? createdAt;

  /// Champs additionnels provenant de l'API Sunnah.com
  final String? collection;    // ex: "bukhari", "muslim"
  final String? hadithNumber;  // ex: "1", "6018"
  final String? grade;         // ex: "Sahih"

  const Hadith({
    required this.id,
    required this.text,
    required this.source,
    required this.reviewed,
    this.createdAt,
    this.collection,
    this.hadithNumber,
    this.grade,
  });

  /// Crée un Hadith depuis un document Firestore
  /// Utilise les champs : text, source, reviewed, created_at
  factory Hadith.fromFirestore(Map<String, dynamic> data, String id) {
    return Hadith(
      id: id,
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? '',
      reviewed: data['reviewed'] as bool? ?? false,
      createdAt: data['created_at']?.toDate() as DateTime?,
    );
  }

  /// Crée un Hadith depuis une Map (avec id inclus)
  /// Alternative à fromFirestore quand l'id est dans la data
  factory Hadith.fromMap(Map<String, dynamic> data) {
    return Hadith(
      id: data['id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? '',
      reviewed: data['reviewed'] as bool? ?? false,
      createdAt: data['created_at'] != null 
          ? (data['created_at'] is DateTime 
              ? data['created_at'] as DateTime
              : data['created_at'].toDate() as DateTime?)
          : null,
      collection: data['collection'] as String?,
      hadithNumber: data['hadithNumber'] as String?,
      grade: data['grade'] as String?,
    );
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
  /// Utile pour mises à jour locales
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