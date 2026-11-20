/// Entrée légère d'une liste de hadiths (sans texte complet ni degré :
/// l'endpoint de liste HadeethEnc ne renvoie que l'identifiant et le titre).
class HadithSummary {
  /// Identifiant HadeethEnc brut (ex : « 66511 »).
  final String id;

  /// Titre : en général les paroles prophétiques clés.
  final String title;

  const HadithSummary({required this.id, required this.title});

  /// Identifiant du [Hadith] complet correspondant.
  String get hadithId => 'henc_$id';

  factory HadithSummary.fromJson(Map<String, dynamic> json) => HadithSummary(
        id: json['id'].toString(),
        title: cleanTitle(json['title'] as String? ?? ''),
      );

  /// Certains titres HadeethEnc sont des extraits coupés en milieu de
  /// phrase (« ! Dis-moi… ») : on retire la ponctuation orpheline du début.
  static String cleanTitle(String raw) => raw
      .replaceAll('\r', '')
      .trim()
      .replaceFirst(RegExp(r'^[!?.,;:»)\]"\s]+'), '')
      .trim();
}

/// Une page de résultats paginés.
class HadithPage {
  final List<HadithSummary> items;
  final int page;
  final int lastPage;
  final int totalItems;

  const HadithPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.totalItems,
  });

  bool get hasMore => page < lastPage;

  /// Parse `/hadeeths/list` : les nombres de `meta` arrivent tantôt en
  /// chaîne, tantôt en entier.
  factory HadithPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    int asInt(Object? v) => int.tryParse('${v ?? 0}') ?? 0;
    return HadithPage(
      items: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HadithSummary.fromJson)
          .where((h) => h.title.isNotEmpty)
          .toList(growable: false),
      page: asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']),
      totalItems: asInt(meta['total_items']),
    );
  }
}
