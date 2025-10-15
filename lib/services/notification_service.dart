import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/helpers.dart';

/// Service de configuration des notifications locales quotidiennes
/// Hadith à 10h et Quiz à 20h selon les spécifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  /// Initialise et programme les notifications quotidiennes
  /// À appeler au démarrage de l'application
  static Future<void> setupDailyNotifications() async {
    try {
      // Annuler les notifications existantes
      await _notifications.cancelAll();
      
      // Programmer hadith quotidien à 10h
      await _scheduleHadithNotification();
      
      // Programmer quiz quotidien à 20h  
      await _scheduleQuizNotification();
      
      print('Notifications quotidiennes programmées avec succès');
    } catch (e) {
      print('Erreur lors de la programmation des notifications: $e');
    }
  }

  /// Programme la notification de hadith quotidien à 10h00
  /// Utilise le canal 'hadith_channel' configuré dans main.dart
  static Future<void> _scheduleHadithNotification() async {
    await _notifications.zonedSchedule(
      1, // ID unique pour hadith
      '📜 Hadith du jour',
      'Découvrez votre hadith quotidien',
      Helpers.nextInstanceOfHour(10),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hadith_channel',
          'Hadith du jour',
          channelDescription: 'Notifications pour le hadith quotidien à 10h',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF0A1E32), // Couleur du thème
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'hadith_category',
          threadIdentifier: 'hadith_thread',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Répéter quotidiennement
      payload: 'hadith_daily',
    );
  }

  /// Programme la notification de quiz quotidien à 20h00
  /// Utilise le canal 'quiz_channel' configuré dans main.dart
  static Future<void> _scheduleQuizNotification() async {
    await _notifications.zonedSchedule(
      2, // ID unique pour quiz
      '❓ Quiz du jour',
      'Testez vos connaissances islamiques',
      Helpers.nextInstanceOfHour(20),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quiz_channel',
          'Quiz du jour',
          channelDescription: 'Notifications pour le quiz quotidien à 20h',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF0A1E32), // Couleur du thème
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'quiz_category',
          threadIdentifier: 'quiz_thread',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Répéter quotidiennement
      payload: 'quiz_daily',
    );
  }

  /// Vérifie et demande les permissions de notification
  /// Retourne true si accordées, false sinon
  static Future<bool> requestNotificationPermissions() async {
    try {
      final androidImplementation = 
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final result = await androidImplementation.requestNotificationsPermission();
        return result ?? false;
      }

      final iosImplementation = 
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        final result = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return result ?? false;
      }

      return true; // Par défaut si pas d'implémentation spécifique
    } catch (e) {
      print('Erreur lors de la demande de permissions: $e');
      return false;
    }
  }

  /// Annule toutes les notifications programmées
  /// Utilisé pour désactiver les notifications depuis les paramètres
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('Toutes les notifications ont été annulées');
    } catch (e) {
      print('Erreur lors de l\'annulation des notifications: $e');
    }
  }

  /// Affiche une notification immédiate (pour tests)
  /// Utilisé uniquement en développement
  static Future<void> showTestNotification() async {
    try {
      await _notifications.show(
        999, // ID de test
        '🔔 Test Notification',
        'Les notifications fonctionnent correctement !',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Channel',
            channelDescription: 'Canal de test pour les notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      print('Erreur lors du test de notification: $e');
    }
  }

  /// Récupère la liste des notifications en attente
  /// Utilisé pour debugger et vérifier la programmation
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('Erreur lors de la récupération des notifications: $e');
      return [];
    }
  }

  /// Gère les actions quand l'utilisateur tape sur une notification
  /// Navigation vers l'écran approprié selon le payload
  static void handleNotificationTap(String? payload) {
    if (payload == null) return;

    // TODO: Utiliser le navigatorKey de app.dart pour la navigation
    switch (payload) {
      case 'hadith_daily':
        // Navigation vers home (hadith card)
        print('Navigation vers hadith du jour');
        break;
      case 'quiz_daily':
        // Navigation vers quiz screen
        print('Navigation vers quiz du jour');
        break;
      default:
        print('Payload de notification non géré: $payload');
    }
  }
}