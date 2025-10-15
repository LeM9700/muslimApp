import 'package:geolocator/geolocator.dart';
import 'dart:math';

/// Service pour calculer la direction vers la Qibla (Kaaba)
/// Utilise la géolocalisation pour déterminer la position et calculer l'angle
class QiblaService {
  // Coordonnées de la Kaaba (Mecca, Arabie Saoudite)
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Calcule l'angle (bearing) vers la Qibla depuis la position actuelle
  /// Retourne l'angle en degrés (0-360) ou null si erreur
  static Future<double?> calculateQiblaBearing() async {
    try {
      // Vérifier les permissions de géolocalisation
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Obtenir la position actuelle
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Calculer le bearing vers la Kaaba
      return _calculateBearing(
        position.latitude,
        position.longitude,
        kaabaLatitude,
        kaabaLongitude,
      );
    } catch (e) {
      print('Erreur lors du calcul de la Qibla: $e');
      return null;
    }
  }

  /// Vérifie si la géolocalisation est activée sur l'appareil
  /// Retourne true si le service de localisation est disponible
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Obtient le statut des permissions de géolocalisation
  /// Utile pour afficher des messages appropriés à l'utilisateur
  static Future<LocationPermission> getLocationPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Demande les permissions de géolocalisation
  /// Retourne le nouveau statut après demande
  static Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Calcule l'angle bearing entre deux points géographiques
  /// Formule de navigation sphérique pour calculer la direction
  static double _calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Conversion degrés vers radians
    final double startLatRad = _degreesToRadians(startLat);
    final double startLngRad = _degreesToRadians(startLng);
    final double endLatRad = _degreesToRadians(endLat);
    final double endLngRad = _degreesToRadians(endLng);

    final double dLng = endLngRad - startLngRad;

    final double y = sin(dLng) * cos(endLatRad);
    final double x = cos(startLatRad) * sin(endLatRad) -
        sin(startLatRad) * cos(endLatRad) * cos(dLng);

    double bearing = atan2(y, x);

    // Conversion radians vers degrés et normalisation 0-360
    bearing = _radiansToDegrees(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  /// Convertit les degrés en radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Convertit les radians en degrés
  static double _radiansToDegrees(double radians) {
    return radians * 180 / pi;
  }

  /// Calcule la distance vers la Kaaba en kilomètres
  /// Utilisé pour information additionnelle dans l'interface
  static Future<double?> calculateDistanceToKaaba() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();
      
      return Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        kaabaLatitude,
        kaabaLongitude,
      ) / 1000; // Conversion mètres vers kilomètres
    } catch (e) {
      print('Erreur lors du calcul de la distance: $e');
      return null;
    }
  }

  /// Stream pour écouter les changements de position
  /// Utile pour mettre à jour la boussole en temps réel
  static Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Mise à jour tous les 10 mètres
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}