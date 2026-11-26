import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/adhan_mode.dart';
import 'adhan_sound_resolver.dart';
import 'ios_sound_installer.dart';
import 'prayer_notification_planner.dart';

/// Notification quotidienne à heure fixe (hadith, quiz).
class DailyNotification {
  final int id;
  final int hour;
  final String title;
  final String body;
  final String payload;
  final String channelId;
  final String channelName;

  const DailyNotification({
    required this.id,
    required this.hour,
    required this.title,
    required this.body,
    required this.payload,
    required this.channelId,
    required this.channelName,
  });

  static const hadith = DailyNotification(
    id: 1,
    hour: 10,
    title: 'Hadith du jour',
    body: 'Découvrez le hadith du jour et son explication.',
    payload: 'hadith_daily',
    channelId: 'hadith_channel',
    channelName: 'Hadith du jour',
  );

  static const quiz = DailyNotification(
    id: 2,
    hour: 20,
    title: 'Quiz du jour',
    body: 'Testez vos connaissances islamiques.',
    payload: 'quiz_daily',
    channelId: 'quiz_channel',
    channelName: 'Quiz du jour',
  );
}

/// Frontière avec le système de notifications : tout ce qui touche au
/// plugin natif passe par ici (et se remplace par un faux en test).
abstract class NotificationGateway {
  /// Prépare le système : canaux Android (un par son) et sons iOS.
  /// À appeler une fois au démarrage, avant toute programmation.
  Future<void> prepare();

  /// Autorisation déjà accordée (ne déclenche aucune demande).
  Future<bool> hasPermission();

  /// Demande l'autorisation au système (affiche la popup iOS la 1re fois).
  Future<bool> requestPermission();

  Future<void> cancelAll();
  Future<void> scheduleDaily(DailyNotification notification);
  Future<void> schedulePrayer(PlannedNotification notification);
  Future<void> showTest({required String title, required String body});
}

/// Implémentation réelle avec flutter_local_notifications.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    IosSoundInstaller? iosSounds,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _iosSounds = iosSounds ?? IosSoundInstaller();

  final FlutterLocalNotificationsPlugin _plugin;
  final IosSoundInstaller _iosSounds;

  /// Action Android « Arrêter » : annuler la notification coupe le son.
  static const String stopAdhanActionId = 'stop_adhan';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> hasPermission() async {
    try {
      final android = _android;
      if (android != null) return await android.areNotificationsEnabled() ?? false;
      final ios = _ios;
      if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    } on Object catch (e) {
      debugPrint('Notifications : lecture de l’autorisation impossible ($e)');
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _android;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _ios;
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } on Object catch (e) {
      debugPrint('Notifications : demande d’autorisation impossible ($e)');
    }
    return false;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> scheduleDaily(DailyNotification n) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, n.hour);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

    await _zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      at: at,
      details: NotificationDetails(
        android: AndroidNotificationDetails(
          n.channelId,
          n.channelName,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF10B981),
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: n.channelId),
      ),
      payload: n.payload,
      repeatDaily: true,
    );
  }

  @override
  Future<void> prepare() async {
    final android = _android;
    if (android != null) {
      for (final sound in AdhanSoundResolver.all) {
        await android.createNotificationChannel(_channelFor(sound));
      }
    }
    await _iosSounds.install();
  }

  @override
  Future<void> schedulePrayer(PlannedNotification n) async {
    await _zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      // Instant absolu → converti dans le fuseau de l'appareil.
      at: tz.TZDateTime.from(n.when, tz.local),
      details: detailsFor(n.mode),
      payload: n.payload,
    );
  }

  @override
  Future<void> showTest({required String title, required String body}) {
    return _plugin.show(999, title, body, detailsFor(AdhanMode.notification));
  }

  /// Détails de notification d'un mode (exposé pour les tests).
  @visibleForTesting
  static NotificationDetails detailsFor(AdhanMode mode) {
    final sound = AdhanSoundResolver.resolve(mode);
    final raw = sound.androidRawSound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        sound.androidChannelId,
        sound.androidChannelName,
        channelDescription: sound.androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound.playSound,
        enableVibration: sound.playSound,
        sound: raw == null ? null : RawResourceAndroidNotificationSound(raw),
        audioAttributesUsage: sound.useAlarmStream
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        category: sound.useAlarmStream
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF10B981),
        actions: mode.playsAdhan
            ? const [
                AndroidNotificationAction(
                  stopAdhanActionId,
                  'Arrêter',
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: AdhanSoundResolver.notificationChannelId,
        presentSound: sound.playSound,
        sound: sound.iosSound,
        // « Time Sensitive » : passe les résumés programmés et certains
        // modes Concentration. Sans l'entitlement Xcode correspondant,
        // iOS rétrograde simplement en « active » (aucune erreur).
        interruptionLevel: sound.playSound
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  /// [⚠️ PROD] Les attributs d'un canal (son, flux audio, importance) sont
  /// figés à sa création. Créer explicitement les canaux garantit qu'ils
  /// ont les bons attributs dès le premier affichage.
  static AndroidNotificationChannel _channelFor(AdhanSound sound) {
    final raw = sound.androidRawSound;
    return AndroidNotificationChannel(
      sound.androidChannelId,
      sound.androidChannelName,
      description: sound.androidChannelDescription,
      importance: Importance.high,
      playSound: sound.playSound,
      enableVibration: sound.playSound,
      sound: raw == null ? null : RawResourceAndroidNotificationSound(raw),
      audioAttributesUsage: sound.useAlarmStream
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
    );
  }

  /// [⚠️ PROD] Android 14+ peut refuser les alarmes exactes : on retombe
  /// alors sur une alarme inexacte (quelques minutes de décalage possibles)
  /// plutôt que de ne rien programmer.
  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required NotificationDetails details,
    required String payload,
    bool repeatDaily = false,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              repeatDaily ? DateTimeComponents.time : null,
          payload: payload,
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
