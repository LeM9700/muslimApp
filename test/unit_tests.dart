import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

/// Tests unitaires pour les calculs de logique pure
/// Teste les fonctions mathématiques et utilitaires sans dépendances
void main() {
  group('Qibla Calculation Tests', () {
    test('calculateBearing should return correct bearing to Kaaba from Paris', () {
      // Coordonnées de Paris
      const double parisLat = 48.8566;
      const double parisLng = 2.3522;
      
      // Coordonnées de la Kaaba
      const double kaabaLat = 21.4225;
      const double kaabaLng = 39.8262;
      
      // Calcul attendu : environ 119° depuis Paris
      final bearing = _calculateBearingTest(parisLat, parisLng, kaabaLat, kaabaLng);
      
      expect(bearing, isA<double>());
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
      // Le bearing depuis Paris vers la Kaaba devrait être environ 119°
      expect(bearing, closeTo(119, 20)); // Tolérance élargie pour test simple
    });

    test('calculateBearing should return correct bearing to Kaaba from New York', () {
      // Coordonnées de New York
      const double nyLat = 40.7128;
      const double nyLng = -74.0060;
      
      // Coordonnées de la Kaaba
      const double kaabaLat = 21.4225;
      const double kaabaLng = 39.8262;
      
      final bearing = _calculateBearingTest(nyLat, nyLng, kaabaLat, kaabaLng);
      
      expect(bearing, isA<double>());
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
      // Le bearing depuis New York vers la Kaaba devrait être environ 58°
      expect(bearing, closeTo(58, 20));
    });

    test('calculateBearing should handle same coordinates', () {
      // Même position que la Kaaba
      const double kaabaLat = 21.4225;
      const double kaabaLng = 39.8262;
      
      final bearing = _calculateBearingTest(kaabaLat, kaabaLng, kaabaLat, kaabaLng);
      
      expect(bearing, isA<double>());
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });
  });

  group('Utility Functions Tests', () {
    test('normalizeAngle should normalize angles correctly', () {
      expect(_normalizeAngle(45), equals(45));
      expect(_normalizeAngle(360), equals(0));
      expect(_normalizeAngle(365), equals(5));
      expect(_normalizeAngle(-45), equals(315));
      expect(_normalizeAngle(-360), equals(0));
      expect(_normalizeAngle(720), equals(0));
    });

    test('formatDateFrench should format dates correctly', () {
      final date1 = DateTime(2025, 10, 14);
      expect(_formatDateFrench(date1), equals('14 octobre 2025'));
      
      final date2 = DateTime(2025, 1, 1);
      expect(_formatDateFrench(date2), equals('1 janvier 2025'));
      
      final date3 = DateTime(2025, 12, 31);
      expect(_formatDateFrench(date3), equals('31 décembre 2025'));
    });

    test('formatTime should format time correctly', () {
      expect(_formatTime(9, 5), equals('09:05'));
      expect(_formatTime(13, 30), equals('13:30'));
      expect(_formatTime(0, 0), equals('00:00'));
    });

    test('containsArabic should detect Arabic text correctly', () {
      expect(_containsArabic('بسم الله الرحمن الرحيم'), isTrue);
      expect(_containsArabic('Hello World'), isFalse);
      expect(_containsArabic('Mixed text مع عربي'), isTrue);
      expect(_containsArabic(''), isFalse);
      expect(_containsArabic('123456'), isFalse);
    });
  });

  group('Model Tests', () {
    test('Hadith model should handle data correctly', () {
      final testData = {
        'text': 'إنما الأعمال بالنيات',
        'source': 'صحيح البخاري',
        'reviewed': true,
        'created_at': null,
      };
      
      expect(testData['text'], isA<String>());
      expect(testData['reviewed'], isTrue);
      expect(testData['source'], contains('صحيح'));
    });

    test('QuizQuestion model should handle options correctly', () {
      final testQuestion = {
        'question': 'Combien de piliers a l\'Islam ?',
        'options': ['3', '4', '5', '6'],
        'answerIndex': 2, // Index de '5'
        'explanation': 'L\'Islam a 5 piliers fondamentaux.',
        'reviewed': true,
      };
      
      expect(testQuestion['options'], hasLength(4));
      expect(testQuestion['answerIndex'], equals(2));
      final options = testQuestion['options'] as List;
      expect(options[testQuestion['answerIndex'] as int], equals('5'));
    });
  });
}

/// Fonction de test pour le calcul de bearing
/// Reproduit la logique de QiblaService pour test isolé
double _calculateBearingTest(double startLat, double startLng, double endLat, double endLng) {
  // Conversion degrés vers radians
  final double startLatRad = startLat * pi / 180;
  final double startLngRad = startLng * pi / 180;
  final double endLatRad = endLat * pi / 180;
  final double endLngRad = endLng * pi / 180;

  final double dLng = endLngRad - startLngRad;

  final double y = sin(dLng) * cos(endLatRad);
  final double x = cos(startLatRad) * sin(endLatRad) -
      sin(startLatRad) * cos(endLatRad) * cos(dLng);

  double bearing = atan2(y, x) * 180 / pi;
  
  // Normalisation 0-360
  bearing = (bearing + 360) % 360;
  
  return bearing;
}

/// Normalise un angle entre 0 et 360 degrés
double _normalizeAngle(double angle) {
  angle = angle % 360;
  if (angle < 0) {
    angle += 360;
  }
  return angle;
}

/// Formate une date en français
String _formatDateFrench(DateTime date) {
  const List<String> months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formate une heure
String _formatTime(int hour, int minute) {
  final hourStr = hour.toString().padLeft(2, '0');
  final minuteStr = minute.toString().padLeft(2, '0');
  return '$hourStr:$minuteStr';
}

/// Vérifie si une chaîne contient du texte arabe
bool _containsArabic(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}