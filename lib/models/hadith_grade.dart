/// Degré d'authenticité d'un hadith, normalisé quelle que soit la source.
///
/// Les sources expriment le degré en texte libre (« Authentique »,
/// « An-Nawawî a dit : Hadith bon », « Sahih »…). On le ramène à une
/// échelle fixe pour pouvoir l'afficher de façon cohérente et l'expliquer.
enum HadithGrade {
  /// Sahîh : remplit les cinq conditions d'authenticité.
  sahih,

  /// Hasan : mêmes conditions, précision d'un rapporteur un peu moindre.
  hasan,

  /// Da'îf : au moins une condition manque.
  daif,

  /// Degré absent ou non reconnu : on n'affiche pas de badge.
  unknown;

  /// Libellé français affiché dans le badge.
  String get label {
    switch (this) {
      case HadithGrade.sahih:
        return 'Authentique';
      case HadithGrade.hasan:
        return 'Bon';
      case HadithGrade.daif:
        return 'Faible';
      case HadithGrade.unknown:
        return 'Non précisé';
    }
  }

  /// Terme arabe translittéré, utilisé par les savants.
  String get arabicTerm {
    switch (this) {
      case HadithGrade.sahih:
        return 'Sahîh';
      case HadithGrade.hasan:
        return 'Hasan';
      case HadithGrade.daif:
        return "Da'îf";
      case HadithGrade.unknown:
        return '';
    }
  }

  /// Normalise un degré à partir des libellés bruts d'une source.
  ///
  /// Le libellé arabe ([arabic]) est prioritaire : il utilise un vocabulaire
  /// technique stable (صحيح / حسن / ضعيف), alors que les traductions varient.
  /// « حسن صحيح » (hasan sahîh) est rangé dans [sahih].
  static HadithGrade fromLabels({String? arabic, String? label}) {
    final ar = arabic ?? '';
    if (ar.contains('ضعيف') || ar.contains('موضوع')) return HadithGrade.daif;
    if (ar.contains('صحيح')) return HadithGrade.sahih;
    if (ar.contains('حسن')) return HadithGrade.hasan;

    final fr = (label ?? '').toLowerCase();
    if (fr.isEmpty) return HadithGrade.unknown;
    if (fr.contains('faible') ||
        fr.contains('daif') ||
        fr.contains("da'if") ||
        fr.contains('da`if') ||
        fr.contains('forgé')) {
      return HadithGrade.daif;
    }
    if (fr.contains('authentique') || fr.contains('sahih')) {
      return HadithGrade.sahih;
    }
    if (fr.contains('bon') || fr.contains('hasan')) return HadithGrade.hasan;
    return HadithGrade.unknown;
  }

  /// Vrai si le hadith atteint son degré grâce à d'autres chaînes qui le
  /// renforcent (« li-ghayrihi »), plutôt que par sa seule chaîne.
  static bool isReinforced({String? arabic, String? label}) {
    final fr = (label ?? '').toLowerCase();
    return (arabic ?? '').contains('لغيره') ||
        fr.contains('autres voies') ||
        fr.contains('autres chaînes') ||
        fr.contains('li ghayrihi') ||
        fr.contains('li-ghayrihi');
  }
}
