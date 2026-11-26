import 'package:flutter/material.dart';

import '../models/prayer_schedule.dart';
import '../screens/adhan_player_screen.dart';
import '../screens/fasting_screen.dart';
import '../screens/sura_detail_screen.dart';
import '../models/friday_reminders.dart';
import 'prayer_notification_planner.dart';

/// Ouvre le bon écran quand l'utilisateur appuie sur une notification.
///
/// Seules les notifications d'adhan ouvrent le lecteur (adhan intégral +
/// dou'a) ; un rappel « dans 15 min » ou une notification simple ouvre
/// juste l'app, sans écran inattendu.
///
/// Les notifications de prière de nuit (`night:…`, voir `NightPayload`)
/// ne sont pas reconnues ici : elles ouvrent simplement l'app. Un rappel
/// de jeûne (`fast:…`) ouvre l'écran « Jeûnes », le rappel al-Kahf
/// (`friday:kahf`) ouvre la sourate 18.
class NotificationRouter {
  /// [navigatorKey] est injecté (celui de `MyApp`) plutôt qu'importé : le
  /// routeur reste indépendant de l'arbre de l'app, donc testable seul.
  NotificationRouter({
    required GlobalKey<NavigatorState> navigatorKey,
    DateTime Function()? clock,
    void Function(NavigatorState navigator, Prayer prayer)? openPlayer,
    void Function(NavigatorState navigator)? openFasting,
    void Function(NavigatorState navigator)? openKahf,
  })  : _navigatorKey = navigatorKey,
        _clock = clock ?? DateTime.now,
        _openPlayer = openPlayer ?? _defaultOpenPlayer,
        _openFasting = openFasting ?? _defaultOpenFasting,
        _openKahf = openKahf ?? _defaultOpenKahf;

  final GlobalKey<NavigatorState> _navigatorKey;
  final DateTime Function() _clock;
  final void Function(NavigatorState navigator, Prayer prayer) _openPlayer;
  final void Function(NavigatorState navigator) _openFasting;
  final void Function(NavigatorState navigator) _openKahf;

  /// Un même appui peut arriver deux fois (callback + détails de lancement
  /// sur certains appareils) : on ignore le doublon proche.
  static const Duration dedupWindow = Duration(seconds: 3);

  String? _lastPayload;
  DateTime? _lastAt;

  /// Retourne vrai si un écran a été ouvert.
  bool handle(String? rawPayload) {
    final prayer = NotificationPayload.decode(rawPayload);
    final fast = FastPayload.decode(rawPayload);
    final kahf = FridayPayload.decode(rawPayload)?.reminder == FridayReminder.kahf;
    final opensPlayer = prayer != null && prayer.mode.playsAdhan;
    if (!opensPlayer && fast == null && !kahf) return false;

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
    if (opensPlayer) {
      _openPlayer(navigator, prayer.prayer);
    } else if (kahf) {
      _openKahf(navigator);
    } else {
      _openFasting(navigator);
    }
    return true;
  }

  static void _defaultOpenKahf(NavigatorState navigator) {
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const SuraDetailScreen(suraId: '18', suraName: 'Al-Kahf'),
    ));
  }

  static void _defaultOpenFasting(NavigatorState navigator) {
    navigator.push(MaterialPageRoute<void>(builder: (_) => const FastingScreen()));
  }

  static void _defaultOpenPlayer(NavigatorState navigator, Prayer prayer) {
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => AdhanPlayerScreen(prayer: prayer),
    ));
  }
}
