import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/models/hadith.dart';
import 'package:muslim_app/models/prayer_data.dart';
import 'package:muslim_app/models/quiz_question.dart';
import 'package:muslim_app/services/firebase_service.dart';
import 'package:muslim_app/services/onboarding_service.dart';
import 'package:muslim_app/services/prayer_service.dart';
import 'package:muslim_app/services/qibla_service.dart';
import 'package:muslim_app/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QiblaService', () {
    test('calculates bearing to Kaaba from Paris', () {
      final bearing = QiblaService.calculateBearingFromCoordinates(
        startLatitude: 48.8566,
        startLongitude: 2.3522,
      );

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
      expect(bearing, closeTo(119, 2));
    });

    test('calculates bearing to Kaaba from New York', () {
      final bearing = QiblaService.calculateBearingFromCoordinates(
        startLatitude: 40.7128,
        startLongitude: -74.0060,
      );

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
      expect(bearing, closeTo(58.5, 2));
    });

    test('normalizes bearing for arbitrary destination', () {
      final bearing = QiblaService.calculateBearingFromCoordinates(
        startLatitude: -33.8688,
        startLongitude: 151.2093,
        endLatitude: 21.4225,
        endLongitude: 39.8262,
      );

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });
  });

  group('Helpers', () {
    test('formats French dates', () {
      expect(
        Helpers.formatDateFrench(DateTime(2025, 10, 14)),
        '14 octobre 2025',
      );
      expect(
        Helpers.formatDateFrench(DateTime(2025, 1, 1)),
        '1 janvier 2025',
      );
      expect(
        Helpers.formatDateFrench(DateTime(2025, 12, 31)),
        '31 décembre 2025',
      );
    });

    test('formats time with two digits', () {
      expect(Helpers.formatTime(const TimeOfDay(hour: 9, minute: 5)), '09:05');
      expect(
          Helpers.formatTime(const TimeOfDay(hour: 13, minute: 30)), '13:30');
      expect(Helpers.formatTime(const TimeOfDay(hour: 0, minute: 0)), '00:00');
    });

    test('detects Arabic text', () {
      expect(Helpers.containsArabic('بسم الله الرحمن الرحيم'), isTrue);
      expect(Helpers.containsArabic('Mixed text مع عربي'), isTrue);
      expect(Helpers.containsArabic('Hello World'), isFalse);
      expect(Helpers.containsArabic('123456'), isFalse);
      expect(Helpers.containsArabic(''), isFalse);
    });
  });

  group('Models', () {
    test('Hadith.fromMap keeps optional API fields', () {
      final createdAt = DateTime(2026, 9, 29);
      final hadith = Hadith.fromMap({
        'id': 'h1',
        'text': 'Actions are by intentions',
        'source': 'Sahih al-Bukhari',
        'reviewed': true,
        'created_at': createdAt,
        'collection': 'bukhari',
        'hadithNumber': '1',
        'grade': 'Sahih',
      });

      expect(hadith.id, 'h1');
      expect(hadith.reviewed, isTrue);
      expect(hadith.createdAt, createdAt);
      expect(hadith.collection, 'bukhari');
      expect(hadith.toFirestore(), containsPair('grade', 'Sahih'));
    });

    test('QuizQuestion supports legacy and seed answer indexes', () {
      final legacy = QuizQuestion.fromFirestore({
        'question': 'How many daily prayers are obligatory?',
        'options': ['3', '4', '5', '6'],
        'answerIndex': 2,
        'explanation': 'There are five daily prayers.',
        'reviewed': true,
      }, 'legacy');

      final seeded = QuizQuestion.fromFirestore({
        'question': 'How many surahs are in the Quran?',
        'options': ['112', '114', '116', '118'],
        'correctIndex': 1,
        'explanation': 'The Quran contains 114 surahs.',
        'reviewed': true,
        'points': 3,
        'tags': ['quran'],
        'language': 'fr',
      }, 'seeded');

      expect(legacy.correctAnswer, '5');
      expect(legacy.isCorrectAnswer(2), isTrue);
      expect(seeded.correctAnswer, '114');
      expect(seeded.points, 3);
      expect(seeded.tags, ['quran']);
    });

    test('PrayerData formats countdowns and empty states', () {
      final empty = PrayerData.empty();
      final data = PrayerData(
        prayerTimes: const {'Fajr': '05:30'},
        nextPrayerName: 'Fajr',
        nextPrayerTime: '05:30',
        timeUntilNext: const Duration(hours: 2, minutes: 7, seconds: 3),
        cityName: 'Paris',
        lastUpdated: DateTime(2026, 9, 29),
      );

      expect(empty.isValid, isFalse);
      expect(empty.formattedCountdown, '--:--:--');
      expect(data.isValid, isTrue);
      expect(data.hasNextPrayer, isTrue);
      expect(data.formattedCountdown, '02:07:03');
      expect(data.readableTimeLeft, 'dans 2h 7min');
    });
  });

  group('PrayerService pure helpers', () {
    test('formats durations for prayer countdown labels', () {
      expect(
          PrayerService.formatDuration(const Duration(minutes: 45)), '45min');
      expect(
        PrayerService.formatDuration(const Duration(hours: 2, minutes: 5)),
        '2h 5min',
      );
    });
  });

  group('OnboardingService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores onboarding completion flags independently', () async {
      expect(await OnboardingService.isHomeOnboardingDone(), isFalse);
      expect(await OnboardingService.isQuranOnboardingDone(), isFalse);
      expect(await OnboardingService.isQuizOnboardingDone(), isFalse);

      await OnboardingService.markHomeDone();
      await OnboardingService.markQuizDone();

      expect(await OnboardingService.isHomeOnboardingDone(), isTrue);
      expect(await OnboardingService.isQuranOnboardingDone(), isFalse);
      expect(await OnboardingService.isQuizOnboardingDone(), isTrue);

      await OnboardingService.resetAll();

      expect(await OnboardingService.isHomeOnboardingDone(), isFalse);
      expect(await OnboardingService.isQuranOnboardingDone(), isFalse);
      expect(await OnboardingService.isQuizOnboardingDone(), isFalse);
    });
  });

  group('FirebaseService fallback mode', () {
    test('returns deterministic counts when Firebase is unavailable', () async {
      expect(FirebaseService.isAvailable, isFalse);
      expect(await FirebaseService.getValidatedHadithsCount(), 42);
      expect(await FirebaseService.getValidatedQuestionsCount(), 156);
    });

    test('returns local quiz fallback when Firebase is unavailable', () async {
      final question = await FirebaseService.getRandomQuizQuestion();
      final questions = await FirebaseService.getMultipleQuestions(3);

      expect(question, isNotNull);
      expect(question!.reviewed, isTrue);
      expect(question.correctAnswer, isNotEmpty);
      expect(questions, hasLength(3));
      expect(questions.every((item) => item.reviewed), isTrue);
    });
  });
}
