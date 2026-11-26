import '../config/share_config.dart';
import '../models/hadith.dart';
import '../models/hadith_grade.dart';

/// Texte prêt à partager.
class ShareMessage {
  final String text;

  /// Objet (utilisé par les e-mails).
  final String subject;

  const ShareMessage(this.text, this.subject);
}

/// Construit les messages partagés : pur, testable, sans plugin.
class ShareContent {
  const ShareContent._();

  /// Phrase d'invitation du score (demandée pour faire connaître l'app).
  static const String quizInvitation =
      'Concurrençons-nous dans la science qu’Allah nous a offerte !';

  /// Le hadith en entier (jamais tronqué : texte religieux), sa source,
  /// son degré s'il est connu, puis la signature.
  static ShareMessage hadith(Hadith hadith, {String? url = ShareConfig.appStoreUrl}) {
    final grade = hadith.gradeLevel;
    final source = [
      if (hadith.source.trim().isNotEmpty) hadith.source.trim(),
      if (grade != HadithGrade.unknown) grade.label,
    ].join(' · ');
    final text = StringBuffer()
      ..writeln('« ${hadith.displayText.trim()} »')
      ..writeln(source.isEmpty ? '' : '($source)')
      ..writeln()
      ..write(ShareConfig.signature(url: url));
    return ShareMessage(
      text.toString().replaceAll('\n\n\n', '\n\n'),
      'Un hadith partagé depuis ${ShareConfig.appName}',
    );
  }

  /// « J’ai obtenu 8/10 au quiz de Deen (niveau Intermédiaire). … »
  static ShareMessage quizScore({
    required int correct,
    required int total,
    String? level,
    String? url = ShareConfig.appStoreUrl,
  }) {
    final levelText = level == null || level.isEmpty ? '' : ' (niveau $level)';
    return ShareMessage(
      'J’ai obtenu $correct/$total au quiz de ${ShareConfig.appName}'
      '$levelText. $quizInvitation À toi de jouer !\n\n'
      '${ShareConfig.signature(url: url)}',
      'Mon score au quiz de ${ShareConfig.appName}',
    );
  }
}
