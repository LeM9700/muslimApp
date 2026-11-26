import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Frontière avec la feuille de partage du système (remplaçable en test).
abstract class ShareGateway {
  /// Ouvre la feuille de partage avec [text] et, si fournie, une image PNG.
  Future<void> share({
    required String text,
    required String subject,
    Uint8List? image,
    Rect? origin,
  });
}

/// Implémentation réelle avec `share_plus`.
class SharePlusGateway implements ShareGateway {
  @override
  Future<void> share({
    required String text,
    required String subject,
    Uint8List? image,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: subject,
      files: image == null
          ? null
          : [XFile.fromData(image, mimeType: 'image/png', name: 'deen.png')],
      // [⚠️ PROD] Obligatoire sur iPad : sans point d'ancrage, la feuille
      // de partage (popover) fait planter l'app.
      sharePositionOrigin: origin,
    ));
    debugPrint('Partage : ${image == null ? 'texte' : 'texte + image'}');
  }
}
