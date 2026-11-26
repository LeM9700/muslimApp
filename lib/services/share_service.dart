import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../models/hadith.dart';
import '../widgets/share/hadith_share_card.dart';
import '../widgets/share/quiz_score_share_card.dart';
import 'share_content.dart';
import 'share_gateway.dart';

/// Rend une carte (widget) en image PNG, hors écran.
abstract class ShareImageRenderer {
  Future<Uint8List> render(Widget card, {BuildContext? context});
}

/// Implémentation avec le paquet `screenshot`.
class ScreenshotRenderer implements ShareImageRenderer {
  /// Taille logique des cartes ; ×3 → 1080 × 1350 (format portrait des
  /// réseaux sociaux).
  static const Size cardSize = Size(360, 450);

  @override
  Future<Uint8List> render(Widget card, {BuildContext? context}) =>
      ScreenshotController().captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(size: cardSize),
          child: Directionality(textDirection: TextDirection.ltr, child: card),
        ),
        context: context,
        pixelRatio: 3,
        targetSize: cardSize,
        delay: const Duration(milliseconds: 50),
      );
}

/// Partage un hadith ou un score : texte toujours, image en plus si le
/// rendu réussit.
class ShareService {
  ShareService({ShareGateway? gateway, ShareImageRenderer? renderer})
      : _gateway = gateway ?? SharePlusGateway(),
        _renderer = renderer ?? ScreenshotRenderer();

  final ShareGateway _gateway;
  final ShareImageRenderer _renderer;

  Future<void> shareHadith(Hadith hadith, {Rect? origin, BuildContext? context}) {
    final message = ShareContent.hadith(hadith);
    return _share(message, HadithShareCard(hadith: hadith), origin, context);
  }

  Future<void> shareQuizScore({
    required int correct,
    required int total,
    String? level,
    Rect? origin,
    BuildContext? context,
  }) {
    final message = ShareContent.quizScore(correct: correct, total: total, level: level);
    return _share(
      message,
      QuizScoreShareCard(correct: correct, total: total, level: level),
      origin,
      context,
    );
  }

  /// [⚠️ PROD] Si l'image échoue (mémoire, rendu), on partage quand même
  /// le texte : le geste de l'utilisateur ne doit jamais rester sans effet.
  Future<void> _share(
    ShareMessage message,
    Widget card,
    Rect? origin,
    BuildContext? context,
  ) async {
    Uint8List? image;
    try {
      image = await _renderer.render(card, context: context);
    } on Object catch (e) {
      debugPrint('Partage : image impossible ($e), texte seul');
    }
    await _gateway.share(
      text: message.text,
      subject: message.subject,
      image: image,
      origin: origin,
    );
  }

  /// Zone du bouton à l'écran : point d'ancrage de la feuille sur iPad.
  static Rect? originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
