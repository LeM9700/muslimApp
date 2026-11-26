/// Adapte au lecteur francophone la phonétique du Coran fournie par
/// Quran.com (ressource 57, translittération Tanzil, à l'anglaise).
///
/// Conventions de la source : « AA » note le ‘ayn, « / » la hamza dans un
/// mot, « ee » et « oo » les voyelles longues i et u. La source suit la
/// prononciation réelle (lettres solaires assimilées : « arrahmani »), ce
/// qu'on conserve.
///
/// Exemples : « rabbi alAAalameen » → « rabbi al‘alamîn » ;
/// « yu/minoona » → « yu’minûna ».
class QuranTransliteration {
  const QuranTransliteration._();

  /// Identifiant Quran.com de la phonétique (« Transliteration »).
  static const int resourceId = 57;

  static String toFrench(String raw) {
    return raw
        // Balises éventuelles (la source en contient parfois).
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('AA', '‘')
        .replaceAll('/', '’')
        .replaceAll('ee', 'î')
        .replaceAll('oo', 'û')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
