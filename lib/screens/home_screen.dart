import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/prayer_times_card.dart';
import '../widgets/hadith_card.dart';
import '../widgets/mini_qibla.dart';
import '../widgets/quiz_card.dart';
import '../widgets/resume_reading_card.dart';
import '../widgets/next_prayer_countdown.dart';
import '../widgets/city_search_widget.dart';
import '../routes/app_routes.dart';
import '../services/prayer_service.dart';
import '../services/firebase_hadith_service.dart';
import '../services/firebase_quiz_service.dart';
import '../models/hadith.dart';
import '../models/quiz_question.dart';
import '../models/prayer_data.dart';

/// Écran d'accueil - Dashboard principal de l'application
/// Affiche un aperçu de tous les services: prières, hadith, qibla, quiz, lecture
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerData? _prayerData;
  bool _isLoadingPrayers = true;
  Timer? _refreshTimer;
  
  // Données Firebase
  Hadith? _dailyHadith;
  QuizQuestion? _dailyQuiz;
  bool _isLoadingHadith = true;
  bool _isLoadingQuiz = true;

  @override
  void initState() {
    super.initState();
    _loadPrayerData();
    _loadDailyHadith();
    _loadDailyQuiz();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Auto-actualisation toutes les minutes pour le compte à rebours
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _loadPrayerData();
      }
    });
  }
  
  /// Charge le hadith du jour depuis Firebase
  Future<void> _loadDailyHadith() async {
    try {
      final hadithService = FirebaseHadithService();
      final hadith = await hadithService.getDailyHadith();
      if (mounted && hadith != null) {
        setState(() {
          _dailyHadith = hadith;
          _isLoadingHadith = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHadith = false;
        });
      }
    }
  }
  
  /// Charge le quiz du jour depuis Firebase
  Future<void> _loadDailyQuiz() async {
    try {
      final quizService = FirebaseQuizService();
      final question = await quizService.getDailyQuestion();
      if (mounted && question != null) {
        setState(() {
          _dailyQuiz = question;
          _isLoadingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuiz = false;
        });
      }
    }
  }

  /// Charge les données complètes de prière (horaires + prochaine prière + countdown)
  Future<void> _loadPrayerData() async {
    try {
      final prayerData = await PrayerService.getCompletePrayerData();
      if (mounted) {
        setState(() {
          _prayerData = prayerData;
          _isLoadingPrayers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrayers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement des horaires: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Charge les données par ville (recherche manuelle)
  void _loadPrayerDataForCity(String cityName) {
    _loadPrayerDataForCityAsync(cityName);
  }

  Future<void> _loadPrayerDataForCityAsync(String cityName) async {
    setState(() {
      _isLoadingPrayers = true;
    });

    try {
      final prayerData = await PrayerService.getCompletePrayerData(cityName: cityName);
      if (mounted) {
        setState(() {
          _prayerData = prayerData;
          _isLoadingPrayers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrayers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur pour la ville $cityName: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPrayerData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100), // Espace pour navbar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message de bienvenue avec titre
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _buildWelcomeSection(),
                ),
                
                const SizedBox(height: 16),
                
                // Compte à rebours prochaine prière (widget principal)
                NextPrayerCountdown(
                  prayerData: _prayerData,
                  onRefresh: _loadPrayerData,
                ),
                
                // Widget de recherche de ville
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CitySearchWidget(
                    onCitySelected: _loadPrayerDataForCity,
                    currentCity: _prayerData?.cityName,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Horaires de prière complets
                      _buildPrayerTimesSection(),
                      
                      const SizedBox(height: 16),
                      
                      // Hadith du jour
                      const HadithCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Quiz du jour
                      const QuizCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Section navigation rapide
                      _buildQuickNavigationSection(),
                      
                      const SizedBox(height: 16),
                      
                      // Reprendre la lecture
                      const ResumeReadingCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Section de bienvenue avec date du jour
  /// Affiche un message personnalisé selon l'heure
  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting;
    if (hour < 12) {
      greeting = 'Bonjour';
    } else if (hour < 18) {
      greeting = 'Bon après-midi';
    } else {
      greeting = 'Bonsoir';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de l'app
        Text(
          'Muslim App',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w300,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(now),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  /// Section des horaires de prière avec loading state
  /// Utilise PrayerTimesCard pour l'affichage
  Widget _buildPrayerTimesSection() {
    if (_isLoadingPrayers || _prayerData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return PrayerTimesCard(prayerTimes: _prayerData!.prayerTimes);
  }

  /// Section de navigation rapide vers Qibla et Coran
  /// Boutons larges avec icônes pour accès facile
  Widget _buildQuickNavigationSection() {
    return Row(
      children: [
        // Bouton Qibla avec mini-boussole
        Expanded(
          child: Card(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.qibla);
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    MiniQiblaCompass(),
                    SizedBox(height: 8),
                    Text(
                      'Qibla',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Bouton Coran
        Expanded(
          child: Card(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.quran);
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Coran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Formate la date en français (ex: "14 octobre 2025")
  /// Utilisé dans la section de bienvenue
  String _formatDate(DateTime date) {
    const List<String> months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}