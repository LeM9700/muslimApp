import 'package:flutter/material.dart';

import '../models/prayer_schedule.dart';
import '../screens/adhan_player_screen.dart';
import 'prayer_notification_planner.dart';

/// Ouvre le bon écran quand l'utilisateur appuie sur une notification.
///
/// Seules les notifications d'adhan ouvrent le lecteur (adhan intégral +
/// dou'a) ; un rappel « dans 15 min » ou une notification simple ouvre
/// juste l'app, sans écran inattendu.
///
/// Les notifications de prière de nuit (`night:…`, voir `NightPayload`)
/// ne sont pas reconnues ici : elles ouvrent simplement l'app.
class NotificationRouter {
  /// [navigatorKey] est injecté (celui de `MyApp`) plutôt qu'importé : le
  /// routeur reste indépendant de l'arbre de l'app, donc testable seul.
  NotificationRouter({
    required GlobalKey<NavigatorState> navigatorKey,
    DateTime Function()? clock,
    void Function(NavigatorState navigator, Prayer prayer)? openPlayer,
  })  : _navigatorKey = navigatorKey,
        _clock = clock ?? DateTime.now,
        _openPlayer = openPlayer ?? _defaultOpenPlayer;

  final GlobalKey<NavigatorState> _navigatorKey;
  final DateTime Function() _clock;
  final void Function(NavigatorState navigator, Prayer prayer) _openPlayer;

  /// Un même appui peut arriver deux fois (callback + détails de lancement
  /// sur certains appareils) : on ignore le doublon proche.
  static const Duration dedupWindow = Duration(seconds: 3);

  String? _lastPayload;
  DateTime? _lastAt;

  /// Retourne vrai si un écran a été ouvert.
  bool handle(String? rawPayload) {
    final payload = NotificationPayload.decode(rawPayload);
    if (payload == null || !payload.mode.playsAdhan) return false;

    final now = _clock();
    if (rawPayload == _lastPayload &&
        _lastAt != null &&
        now.difference(_lastAt!) < dedupWindow) {
      return false;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return false;

    _lastPayload = rawPayload;
    _lastAt = now;
    _openPlayer(navigator, payload.prayer);
    return true;
  }

  static void _defaultOpenPlayer(NavigatorState navigator, Prayer prayer) {
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => AdhanPlayerScreen(prayer: prayer),
    ));
  }
}
