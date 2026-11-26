import 'package:flutter/material.dart';

import '../../services/share_content.dart';
import '../../utils/app_theme.dart';
import 'share_card_frame.dart';

/// Image partagée d'un score au quiz.
class QuizScoreShareCard extends StatelessWidget {
  const QuizScoreShareCard({
    super.key,
    required this.correct,
    required this.total,
    this.level,
  });

  final int correct;
  final int total;
  final String? level;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : correct / total;
    return ShareCardFrame(
      icon: Icons.emoji_events_outlined,
      label: 'Quiz du jour',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$correct/$total',
            key: const ValueKey('share-quiz-score'),
            style: const TextStyle(
                fontSize: 72, fontWeight: FontWeight.w800, color: AppColors.emeraldDark),
          ),
          if (level != null && level!.isNotEmpty)
            Text('Niveau $level',
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: AppColors.emerald,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            ShareContent.quizInvitation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text('À toi de jouer !',
              style: TextStyle(fontSize: 15, color: AppColors.copper)),
        ],
      ),
    );
  }
}
