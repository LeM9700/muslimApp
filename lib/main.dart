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
import 'services/prayer_notification_service.dart';
import 'app.dart';

/// Point d'entrée principal de l'application
/// Initialise Firebase et les notifications locales avant de lancer l'app
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

/// Configure les notifications locales pour Android et iOS
/// Prépare les canaux de notification pour hadiths et quiz
Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // TODO: Navigation vers écran approprié selon le type de notification
      debugPrint('Notification reçue: ${response.payload}');
    },
  );

  // Création des canaux de notification Android
  await _createNotificationChannels();
}

/// Crée les canaux de notification pour Android
/// Un canal pour les hadiths (10h) et un pour les quiz (20h)
Future<void> _createNotificationChannels() async {
  const AndroidNotificationChannel hadithChannel = AndroidNotificationChannel(
    'hadith_channel',
    'Hadith du jour',
    description: 'Notifications pour le hadith quotidien à 10h',
    importance: Importance.defaultImportance,
  );

  const AndroidNotificationChannel quizChannel = AndroidNotificationChannel(
    'quiz_channel',
    'Quiz du jour',
    description: 'Notifications pour le quiz quotidien à 20h',
    importance: Importance.defaultImportance,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(hadithChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(quizChannel);

  const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
    LocalNotificationGateway.prayerChannelId,
    LocalNotificationGateway.prayerChannelName,
    description: 'Notification à l’heure de chaque prière',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(prayerChannel);
}
