import 'package:flutter/material.dart';

import '../../models/hadith.dart';
import '../../models/hadith_grade.dart';
import '../../utils/app_theme.dart';
import 'share_card_frame.dart';

/// Image partagée d'un hadith.
class HadithShareCard extends StatelessWidget {
  const HadithShareCard({super.key, required this.hadith});

  final Hadith hadith;

  /// Au-delà, l'image montre le début et renvoie au message (qui contient
  /// toujours le texte intégral) : jamais de hadith coupé sans le dire.
  static const int maxChars = 420;

  /// Texte affiché sur l'image et indicateur de coupure.
  static (String, bool) excerpt(String text) {
    final clean = text.trim();
    if (clean.length <= maxChars) return (clean, false);
    var cut = clean.lastIndexOf(' ', maxChars);
    if (cut < maxChars ~/ 2) cut = maxChars;
    return ('${clean.substring(0, cut).trimRight()}…', true);
  }

  static double fontSizeFor(String text) => text.length < 160
      ? 21
      : text.length < 300
          ? 17.5
          : 15;

  @override
  Widget build(BuildContext context) {
    final (text, truncated) = excerpt(hadith.displayText);
    final grade = hadith.gradeLevel;
    return ShareCardFrame(
      icon: Icons.auto_stories_outlined,
      label: 'Hadith',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '« $text »',
              key: const ValueKey('share-hadith-text'),
              overflow: TextOverflow.fade,
              style: TextStyle(fontSize: fontSizeFor(text), height: 1.45),
            ),
          ),
          if (truncated)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Suite dans le message',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 10),
          Text(
            [
              if (hadith.source.trim().isNotEmpty) hadith.source.trim(),
              if (grade != HadithGrade.unknown) grade.label,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
