/// Catégorie thématique de HadeethEnc (ex : « Le dogme », « Les vertus »).
///
/// Les catégories racines ([parentId] nul) regroupent leurs
/// sous-catégories : [hadithCount] inclut les hadiths des sous-catégories.
class HadithCategory {
  final String id;
  final String title;
  final int hadithCount;
  final String? parentId;

  const HadithCategory({
    required this.id,
    required this.title,
    required this.hadithCount,
    this.parentId,
  });

  bool get isRoot => parentId == null;

  /// Parse une entrée de `/categories/roots` ou `/categories/list`.
  /// L'API renvoie les nombres sous forme de chaînes.
  factory HadithCategory.fromJson(Map<String, dynamic> json) {
    return HadithCategory(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      hadithCount: int.tryParse('${json['hadeeths_count'] ?? 0}') ?? 0,
      parentId: json['parent_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hadeeths_count': hadithCount,
        'parent_id': parentId,
      };
}
