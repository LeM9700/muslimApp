import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/prayer_data.dart';

/// Service complet pour les horaires de prière
/// Utilise l'API Aladhan pour des calculs précis
/// Inclut géolocalisation et recherche de ville
class PrayerService {
  static const String _baseUrl = 'https://api.aladhan.com/v1';
  static final http.Client _client = http.Client();
  
  // Cache pour éviter trop d'appels API
  static Map<String, dynamic>? _cachedData;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);
  
  /// Récupère la position actuelle de l'utilisateur
  static Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Services de localisation désactivés');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Permission de localisation refusée');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission de localisation refusée définitivement');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
      return null;
    }
  }
  
  /// Récupère les horaires de prière via l'API Aladhan
  static Future<Map<String, String>> _fetchPrayerTimes(double latitude, double longitude) async {
    try {
      // Vérifier le cache
      if (_cachedData != null && _cacheTime != null) {
        if (DateTime.now().difference(_cacheTime!).inHours < _cacheDuration.inHours) {
          return _parsePrayerTimes(_cachedData!);
        }
      }
      
      final today = DateTime.now();
      final url = '$_baseUrl/timings/${today.day}-${today.month}-${today.year}?latitude=$latitude&longitude=$longitude&method=2';
      
      print('🕒 API Prayer Request: $url');
      
      final response = await _client.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Erreur API Aladhan: ${response.statusCode}');
      }
      
      final data = json.decode(response.body);
      
      if (data['code'] != 200) {
        throw Exception('Erreur API: ${data['status']}');
      }
      
      // Mettre en cache
      _cachedData = data as Map<String, dynamic>;
      _cacheTime = DateTime.now();
      
      print('✅ Horaires de prière récupérés avec succès');
      return _parsePrayerTimes(data);
    } catch (e) {
      print('❌ Erreur API Aladhan: $e');
      return _getDefaultPrayerTimes();
    }
  }
  
  /// Parse les horaires depuis la réponse API
  static Map<String, String> _parsePrayerTimes(Map<String, dynamic> data) {
    final timings = data['data']['timings'] as Map<String, dynamic>;
    
    return {
      'Fajr': _formatTime(timings['Fajr'] as String),
      'Dhuhr': _formatTime(timings['Dhuhr'] as String),
      'Asr': _formatTime(timings['Asr'] as String),
      'Maghrib': _formatTime(timings['Maghrib'] as String),
      'Isha': _formatTime(timings['Isha'] as String),
    };
  }
  
  /// Formate l'heure (supprime timezone si présente)
  static String _formatTime(String time) {
    // L'API retourne parfois "13:15 (CET)" - on garde juste l'heure
    return time.split(' ')[0];
  }
  
  /// Horaires par défaut en cas d'échec
  static Map<String, String> _getDefaultPrayerTimes() {
    return {
      'Fajr': '05:30',
      'Dhuhr': '13:15',
      'Asr': '16:45',
      'Maghrib': '19:20',
      'Isha': '21:00',
    };
  }
  
  /// Recherche les horaires de prière par nom de ville
  static Future<Map<String, String>> getPrayerTimesByCity(String cityName) async {
    try {
      // Obtenir les coordonnées de la ville
      List<Location> locations = await locationFromAddress(cityName);
      if (locations.isEmpty) {
        throw Exception('Ville non trouvée: $cityName');
      }
      
      final location = locations.first;
      print('📍 Coordonnées pour $cityName: ${location.latitude}, ${location.longitude}');
      
      return await _fetchPrayerTimes(location.latitude, location.longitude);
    } catch (e) {
      print('❌ Erreur recherche ville $cityName: $e');
      return _getDefaultPrayerTimes();
    }
  }
  
  /// Récupère toutes les données de prière complètes
  /// Position automatique ou coordonnées spécifiques
  static Future<PrayerData> getCompletePrayerData({
    double? latitude,
    double? longitude,
    String? cityName,
  }) async {
    try {
      late Map<String, String> prayerTimes;
      late String finalCityName;
      double? finalLat = latitude;
      double? finalLng = longitude;
      
      if (cityName != null) {
        // Recherche par ville
        prayerTimes = await getPrayerTimesByCity(cityName);
        finalCityName = cityName;
        
        // Obtenir les coordonnées pour le cache
        try {
          List<Location> locations = await locationFromAddress(cityName);
          if (locations.isNotEmpty) {
            finalLat = locations.first.latitude;
            finalLng = locations.first.longitude;
          }
        } catch (e) {
          // Ignore - on garde juste le nom de ville
        }
      } else {
        // Position automatique
        prayerTimes = await getTodayPrayerTimes(
          latitude: latitude, 
          longitude: longitude
        );
        finalCityName = await getCurrentCityName();
      }
      
      // Calculer la prochaine prière
      final nextPrayer = await getNextPrayer(
        latitude: finalLat,
        longitude: finalLng,
      );
      
      // Calculer le temps restant
      final timeUntil = await getTimeUntilNextPrayer(
        latitude: finalLat,
        longitude: finalLng,
      );
      
      return PrayerData(
        prayerTimes: prayerTimes,
        nextPrayerName: nextPrayer?['name'],
        nextPrayerTime: nextPrayer?['time'],
        timeUntilNext: timeUntil,
        cityName: finalCityName,
        latitude: finalLat,
        longitude: finalLng,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('❌ Erreur récupération données complètes: $e');
      
      return PrayerData(
        prayerTimes: _getDefaultPrayerTimes(),
        cityName: 'Erreur de localisation',
        lastUpdated: DateTime.now(),
      );
    }
  }
  
  /// Récupère des informations sur la ville actuelle
  static Future<String> getCurrentCityName() async {
    try {
      final position = await _getCurrentPosition();
      if (position == null) return 'Position inconnue';
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.locality ?? placemark.administrativeArea ?? 'Ville inconnue';
      }
      
      return 'Position inconnue';
    } catch (e) {
      print('❌ Erreur récupération nom ville: $e');
      return 'Position inconnue';
    }
  }
  
  /// Récupère les horaires de prière pour aujourd'hui
  /// Utilise la géolocalisation automatique ou les coordonnées fournies
  static Future<Map<String, String>> getTodayPrayerTimes({
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Utiliser les coordonnées fournies ou obtenir la position actuelle
      Position? position;
      if (latitude != null && longitude != null) {
        position = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      } else {
        position = await _getCurrentPosition();
      }
      
      if (position == null) {
        // Position par défaut (Paris) si géolocalisation échoue
        position = Position(
          latitude: 48.8566,
          longitude: 2.3522,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      
      return await _fetchPrayerTimes(position.latitude, position.longitude);
    } catch (e) {
      print('❌ Erreur récupération horaires de prière: $e');
      // Retourner des horaires par défaut en cas d'erreur
      return _getDefaultPrayerTimes();
    }
  }

  /// Récupère les horaires pour une date spécifique
  /// [date] : date pour laquelle récupérer les horaires
  static Future<Map<String, String>> getPrayerTimesForDate(
    DateTime date, {
    double? latitude,
    double? longitude,
  }) async {
    // Simulation d'un appel API
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    // TODO: Calculer les horaires réels selon la date et position
    return getTodayPrayerTimes(latitude: latitude, longitude: longitude);
  }

  /// Calcule la prochaine prière à partir de l'heure actuelle
  /// Retourne le nom de la prière et l'heure
  static Future<Map<String, String>?> getNextPrayer({
    double? latitude,
    double? longitude,
  }) async {
    final prayerTimes = await getTodayPrayerTimes(
      latitude: latitude,
      longitude: longitude,
    );
    
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Parcourir les prières dans l'ordre chronologique
    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    for (final prayer in prayerOrder) {
      final prayerTime = prayerTimes[prayer]!;
      if (currentTime.compareTo(prayerTime) < 0) {
        return {
          'name': prayer,
          'time': prayerTime,
        };
      }
    }
    
    // Si toutes les prières sont passées, retourner Fajr du lendemain
    final tomorrowPrayerTimes = await getPrayerTimesForDate(
      now.add(const Duration(days: 1)),
      latitude: latitude,
      longitude: longitude,
    );
    
    return {
      'name': 'Fajr',
      'time': tomorrowPrayerTimes['Fajr']!,
    };
  }

  /// Calcule le temps restant avant la prochaine prière
  /// Retourne une durée ou null si erreur
  static Future<Duration?> getTimeUntilNextPrayer({
    double? latitude,
    double? longitude,
  }) async {
    final nextPrayer = await getNextPrayer(
      latitude: latitude,
      longitude: longitude,
    );
    
    if (nextPrayer == null) return null;
    
    final now = DateTime.now();
    final prayerTimeParts = nextPrayer['time']!.split(':');
    final prayerHour = int.parse(prayerTimeParts[0]);
    final prayerMinute = int.parse(prayerTimeParts[1]);
    
    DateTime prayerDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      prayerHour,
      prayerMinute,
    );
    
    // Si l'heure est déjà passée aujourd'hui, c'est pour demain
    if (prayerDateTime.isBefore(now)) {
      prayerDateTime = prayerDateTime.add(const Duration(days: 1));
    }
    
    return prayerDateTime.difference(now);
  }

  /// Formate une durée en texte lisible (ex: "2h 30min")
  /// Utilisé pour afficher le temps restant avant la prochaine prière
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  /// Vérifie si c'est l'heure d'une prière (à ±5 minutes près)
  /// Utilisé pour déclencher des notifications ou alertes
  static Future<String?> getCurrentPrayerTime({
    double? latitude,
    double? longitude,
  }) async {
    final prayerTimes = await getTodayPrayerTimes(
      latitude: latitude,
      longitude: longitude,
    );
    
    final now = DateTime.now();
    
    for (final entry in prayerTimes.entries) {
      final prayerTimeParts = entry.value.split(':');
      final prayerHour = int.parse(prayerTimeParts[0]);
      final prayerMinute = int.parse(prayerTimeParts[1]);
      
      final prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        prayerHour,
        prayerMinute,
      );
      
      final difference = now.difference(prayerDateTime).abs();
      
      // Si on est à moins de 5 minutes de l'heure de prière
      if (difference.inMinutes <= 5) {
        return entry.key;
      }
    }
    
    return null;
  }
}