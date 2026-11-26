import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Frontière avec le widget d'écran verrouillé (extension WidgetKit).
///
/// Remplaçable par un faux en test, comme `NotificationGateway`.
abstract class PrayerWidgetGateway {
  /// Publie la chronologie (JSON) et demande à iOS de redessiner.
  Future<void> publish(String timelineJson);

  /// Efface les données : le widget affiche « Activez-le dans Deen ».
  Future<void> clear();
}

/// Implémentation iOS : canal vers `PrayerWidgetBridge.swift`, qui écrit
/// dans l'App Group partagé avec l'extension puis recharge les widgets.
///
/// Choisi plutôt que le paquet `home_widget` : deux appels suffisent, et
/// ce paquet impose iOS 14 alors que l'app accepte encore iOS 13.
class MethodChannelPrayerWidgetGateway implements PrayerWidgetGateway {
  MethodChannelPrayerWidgetGateway({MethodChannel? channel, bool? isIos})
      : _channel = channel ?? const MethodChannel(channelName),
        _isIos = isIos ?? (!kIsWeb && Platform.isIOS);

  static const String channelName = 'deen/prayer_widget';

  final MethodChannel _channel;
  final bool _isIos;

  @override
  Future<void> publish(String timelineJson) =>
      _invoke('publish', {'timeline': timelineJson});

  @override
  Future<void> clear() => _invoke('clear');

  /// [⚠️ PROD] Le widget est un bonus : une erreur native ne doit jamais
  /// empêcher la programmation des notifications qui suit.
  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!_isIos) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Build sans l'extension (ou iOS < 14) : rien à faire.
    } on PlatformException catch (e) {
      debugPrint('Widget écran verrouillé : $method impossible (${e.code})');
    }
  }
}
