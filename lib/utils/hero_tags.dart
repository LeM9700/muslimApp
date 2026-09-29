/// Constantes de tags Hero pour les shared element transitions.
/// Toujours utiliser ces constantes — jamais de strings inline.
/// [⚠️ PROD] Un tag Hero dupliqué dans le même arbre cause un crash.
class HeroTags {
  HeroTags._();

  /// Mini boussole Qibla (home) → QiblaCompass (qibla screen)
  static const String qiblaCompass = 'hero_qibla_compass';

  /// Icône Coran (home quick nav) → Header Quran screen
  static const String quranIcon = 'hero_quran_icon';

  /// Icône Quiz (QuizCard home) → Header Quiz screen dashboard
  static const String quizIcon = 'hero_quiz_icon';

  /// Icône bookmark (ResumeReadingCard) → Header SuraDetail
  static const String bookmarkIcon = 'hero_bookmark_icon';
}
