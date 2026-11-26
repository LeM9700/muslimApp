/// Formule de dhikr : texte arabe, phonétique et sens en français.
class Dhikr {
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;

  const Dhikr(this.id, this.arabic, this.transliteration, this.translation);

  static const subhanAllah = Dhikr('subhan', 'سُبْحَانَ اللَّهِ',
      'Subhâna-Llâh', 'Gloire à Allah');
  static const alhamdulillah = Dhikr('hamd', 'الْحَمْدُ لِلَّهِ',
      'Al-hamdu li-Llâh', 'Louange à Allah');
  static const allahuAkbar = Dhikr('takbir', 'اللَّهُ أَكْبَرُ',
      'Allâhu akbar', 'Allah est le plus grand');
  static const laIlaha = Dhikr('tahlil', 'لَا إِلَٰهَ إِلَّا اللَّهُ',
      'Lâ ilâha illa-Llâh', 'Nulle divinité digne d’adoration sauf Allah');
  static const astaghfirullah = Dhikr('istighfar', 'أَسْتَغْفِرُ اللَّهَ',
      'Astaghfiru-Llâh', 'Je demande pardon à Allah');

  /// Formule qui complète la centaine après la prière (Muslim 597).
  static const tahlilComplete = Dhikr(
    'tahlil_complet',
    'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ '
        'الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    'Lâ ilâha illa-Llâhu wahdahu lâ sharîka lah, lahul-mulku wa lahul-hamd, '
        'wa huwa ‘alâ kulli shay’in qadîr',
    'Nulle divinité sauf Allah, Seul, sans associé. À Lui la royauté, à Lui '
        'la louange, et Il est capable de toute chose.',
  );

  /// Formules proposées au choix.
  static const List<Dhikr> choices = [
    subhanAllah,
    alhamdulillah,
    allahuAkbar,
    laIlaha,
    astaghfirullah,
  ];
}

/// Une étape : une formule à répéter [target] fois (0 = sans limite).
class TasbihStep {
  final Dhikr dhikr;
  final int target;

  const TasbihStep(this.dhikr, this.target);
}

/// Enchaînement après la prière : 33 + 33 + 33 + 1 = 100 (Muslim 597).
const List<TasbihStep> afterPrayerSequence = [
  TasbihStep(Dhikr.subhanAllah, 33),
  TasbihStep(Dhikr.alhamdulillah, 33),
  TasbihStep(Dhikr.allahuAkbar, 33),
  TasbihStep(Dhikr.tahlilComplete, 1),
];
