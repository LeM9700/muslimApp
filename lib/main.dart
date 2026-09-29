import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/firebase_service.dart';
import 'services/firebase_data_seeder.dart';
import 'services/notification_service.dart';
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

  // Initialisation des fuseaux horaires pour les notifications
  try {
    tz.initializeTimeZones();
    print('✅ Timezones initialisées');
  } catch (e) {
    print('⚠️ Erreur timezones: $e');
  }

  // Programmer les notifications quotidiennes (hadith 10h, quiz 20h)
  try {
    final notificationsEnabled =
        await NotificationService.areNotificationsEnabled();
    if (notificationsEnabled) {
      await NotificationService.setupDailyNotifications();
      print('✅ Notifications quotidiennes programmées');
    } else {
      print('⚠️ Permissions notifications refusées');
    }
  } catch (e) {
    print('⚠️ Erreur setup notifications: $e');
  }

  runApp(const MyApp());
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
}
