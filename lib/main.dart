import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/firebase_service.dart';
import 'services/firebase_data_seeder.dart';
import 'services/notification_gateway.dart';
import 'services/notification_router.dart';
import 'services/prayer_notification_service.dart';
import 'app.dart';

/// Point d'entrée principal de l'application
/// Initialise Firebase et les notifications locales avant de lancer l'app
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Ouvre le lecteur d'adhan quand on appuie sur une notification.
final NotificationRouter _notificationRouter =
    NotificationRouter(navigatorKey: MyApp.navigatorKey);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase avec gestion d'erreur
  await FirebaseService.initialize();

  // Lancer le seeding en arrière-plan (NE PAS await)
  if (kDebugMode && FirebaseService.isAvailable) {
    FirebaseDataSeeder.seedAllData().catchError((Object e) {
      print('Seeding background error: $e');
    });
  }

  // Initialisation des notifications locales
  try {
    await _initializeNotifications();
    print('✅ Notifications initialisées');
  } catch (e) {
    print('⚠️ Erreur notifications: $e');
  }

  // Fuseau horaire réel de l'appareil : sans lui, tz.local reste en UTC
  // et le rappel « 10 h » tombait à 11 h (hiver) ou 12 h (été) en France.
  await _initializeTimeZone();

  runApp(const MyApp());
  WidgetsBinding.instance
      .addPostFrameCallback((_) => unawaited(_handleLaunchFromNotification()));

  // Après runApp : la reprogrammation peut appeler le réseau (calendrier
  // Aladhan) et ne doit jamais retarder l'affichage de l'app.
  unawaited(PrayerNotificationService.instance.reschedule(force: true));
  _lifecycleListener = AppLifecycleListener(
    // Retour au premier plan : prolonge la fenêtre de rappels (limite iOS
    // de 64 notifications programmées). Limité à une fois / 30 min.
    onResume: () => unawaited(PrayerNotificationService.instance.reschedule()),
  );
}

/// Gardé en référence pour toute la durée de vie de l'app.
// ignore: unused_element
AppLifecycleListener? _lifecycleListener;

Future<void> _initializeTimeZone() async {
  tz_data.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } on Object catch (e) {
    // Identifiant inconnu de la base tz : les rappels de prière restent
    // justes (instants absolus) ; seuls hadith/quiz seraient décalés.
    debugPrint('Fuseau horaire indisponible, UTC utilisé : $e');
  }
}

/// Configure les notifications locales pour Android et iOS.
Future<void> _initializeNotifications() async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // App ouverte ou en arrière-plan : appui sur la notification.
    onDidReceiveNotificationResponse: (response) {
      if (response.actionId == LocalNotificationGateway.stopAdhanActionId) {
        return; // « Arrêter » : la notification (et le son) est déjà coupée.
      }
      _notificationRouter.handle(response.payload);
    },
  );

  await _createNotificationChannels();
  // Canaux de prière (un par son) + sons iOS dans Library/Sounds.
  await PrayerNotificationService.instance.prepare();
}

/// [⚠️ PROD] App tuée puis lancée par un appui sur la notification :
/// `onDidReceiveNotificationResponse` n'est pas appelé dans ce cas, il faut
/// lire le lancement explicitement, une fois le navigateur monté.
Future<void> _handleLaunchFromNotification() async {
  try {
    final details =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      _notificationRouter.handle(details!.notificationResponse?.payload);
    }
  } on Object catch (e) {
    debugPrint('Lancement depuis une notification illisible ($e)');
  }
}

/// Canaux des rappels quotidiens (hadith 10 h, quiz 20 h). Les canaux de
/// prière sont créés par le gateway (voir AdhanSoundResolver).
Future<void> _createNotificationChannels() async {
  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    'hadith_channel',
    'Hadith du jour',
    description: 'Notifications pour le hadith quotidien à 10h',
    importance: Importance.defaultImportance,
  ));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    'quiz_channel',
    'Quiz du jour',
    description: 'Notifications pour le quiz quotidien à 20h',
    importance: Importance.defaultImportance,
  ));
}
