import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';

/// Utilitaires et helpers généraux pour l'application
/// Fonctions réutilisables pour dates, notifications, formatage
class Helpers {
  
  /// Calcule la prochaine instance d'une heure donnée
  /// Utilisé pour programmer les notifications quotidiennes
  /// [hour] : heure en format 24h (ex: 10 pour 10h00, 20 pour 20h00)
  static tz.TZDateTime nextInstanceOfHour(int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );
    
    // Si l'heure est déjà passée aujourd'hui, programmer pour demain
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Formate une date en français (ex: "14 octobre 2025")
  /// Utilisé pour afficher les dates de manière lisible
  static String formatDateFrench(DateTime date) {
    const List<String> months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Formate une heure (ex: "10:30" ou "20:00")
  /// Utilisé pour afficher les horaires de prière
  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Calcule l'angle bearing entre deux points géographiques
  /// Utilisé pour calculer la direction vers la Kaaba depuis position actuelle
  /// Retourne l'angle en degrés (0-360)
  static double calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double pi = 3.14159265359;
    
    // Conversion en radians
    final double startLatRad = startLat * pi / 180;
    final double startLngRad = startLng * pi / 180;
    final double endLatRad = endLat * pi / 180;
    final double endLngRad = endLng * pi / 180;
    
    final double dLng = endLngRad - startLngRad;
    
    final double y = sin(dLng) * cos(endLatRad);
    final double x = cos(startLatRad) * sin(endLatRad) -
        sin(startLatRad) * cos(endLatRad) * cos(dLng);
    
    double bearing = atan2(y, x) * 180 / pi;
    
    // Normaliser entre 0 et 360
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }

  /// Normalise un angle entre 0 et 360 degrés
  /// Utilisé pour les calculs de boussole Qibla
  static double normalizeAngle(double angle) {
    angle = angle % 360;
    if (angle < 0) {
      angle += 360;
    }
    return angle;
  }

  /// Affiche un SnackBar d'erreur avec style cohérent
  /// Utilisé pour notifier les erreurs à l'utilisateur
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Affiche un SnackBar de succès avec style cohérent
  /// Utilisé pour confirmer les actions réussies
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Vérifie si une chaîne contient du texte arabe
  /// Utilisé pour adapter l'affichage selon le contenu
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }


}