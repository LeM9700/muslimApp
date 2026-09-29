import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../utils/hero_tags.dart';
import '../widgets/prayer_times_card.dart';
import '../widgets/hadith_card.dart';
import '../widgets/mini_qibla.dart';
import '../widgets/quiz_card.dart';
import '../widgets/resume_reading_card.dart';
import '../widgets/next_prayer_countdown.dart';
import '../widgets/city_search_widget.dart';
import '../widgets/onboarding_overlay.dart';
import '../widgets/glass_widgets.dart';
import '../routes/app_routes.dart';
import '../services/prayer_service.dart';
import '../services/firebase_service.dart';
import '../services/onboarding_service.dart';
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
  bool _isRequestingPrayerLocation = false;
  bool _isPrayerLocationServiceEnabled = true;
  LocationPermission? _prayerLocationPermission;
  Timer? _refreshTimer;

  // Données Firebase
  Hadith? _dailyHadith;
  QuizQuestion? _dailyQuiz;
  bool _isLoadingHadith = true;
  bool _isLoadingQuiz = true;

  // ── Onboarding (Q11) — GlobalKeys sur les éléments cibles ────────────────
  final GlobalKey _keyPrayerCountdown = GlobalKey();
  final GlobalKey _keyHadithCard = GlobalKey();
  final GlobalKey _keyQuizCard = GlobalKey();
  final GlobalKey _keyQiblaNav = GlobalKey();
  final GlobalKey _keyQuranNav = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPrayerData();
    _loadDailyHadith();
    _loadDailyQuiz();
    _startAutoRefresh();
    // Déclenche l'onboarding après le premier rendu complet
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  /// Vérifie si l'onboarding home doit s'afficher (premier lancement).
  Future<void> _maybeShowOnboarding() async {
    final done = await OnboardingService.isHomeOnboardingDone();
    if (done || !mounted) return;

    final steps = [
      OnboardingStep(
        targetKey: _keyPrayerCountdown,
        icon: Icons.access_time_rounded,
        title: 'Prochaine prière',
        description:
            'Le compte à rebours se met à jour en temps réel selon votre position.',
      ),
      OnboardingStep(
        targetKey: _keyHadithCard,
        icon: Icons.auto_stories_outlined,
        title: 'Hadith du jour',
        description:
            'Un hadith authentique sélectionné chaque jour. Appuyez sur ↺ pour en découvrir un autre.',
      ),
      OnboardingStep(
        targetKey: _keyQuizCard,
        icon: Icons.quiz_outlined,
        title: 'Quiz islamique',
        description:
            'Testez vos connaissances avec un quiz quotidien. Trois niveaux disponibles.',
        spotlightPadding: 8,
      ),
      OnboardingStep(
        targetKey: _keyQiblaNav,
        icon: Icons.explore_outlined,
        title: 'Direction Qibla',
        description:
            'Boussole précise pointant vers la Kaaba, calibrée avec votre position GPS.',
        spotlightPadding: 8,
        spotlightRadius: 12,
      ),
      OnboardingStep(
        targetKey: _keyQuranNav,
        icon: Icons.menu_book_outlined,
        title: 'Coran',
        description:
            'Lisez et écoutez les 114 sourates. Votre progression est sauvegardée automatiquement.',
        spotlightPadding: 8,
        spotlightRadius: 12,
      ),
    ];

    await OnboardingOverlay.show(
      context: context,
      steps: steps,
      onComplete: OnboardingService.markHomeDone,
    );
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
      final hadith = await FirebaseService.getHadithOfTheDay();
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
      final question = await FirebaseService.getRandomQuizQuestion();
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final prayerData = await PrayerService.getCompletePrayerData();
      if (mounted) {
        setState(() {
          _isPrayerLocationServiceEnabled = serviceEnabled;
          _prayerLocationPermission = permission;
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
      final prayerData =
          await PrayerService.getCompletePrayerData(cityName: cityName);
      if (mounted) {
        setState(() {
          _prayerLocationPermission = null;
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

  Future<void> _enablePrayerLocation() async {
    if (_isRequestingPrayerLocation) return;

    setState(() {
      _isRequestingPrayerLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _loadPrayerData();
        return;
      }

      if (mounted) {
        setState(() {
          _prayerLocationPermission = permission;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPrayerLocation = false;
        });
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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding:
                const EdgeInsets.fromLTRB(0, 0, 0, 100), // Espace pour navbar
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
                KeyedSubtree(
                  key: _keyPrayerCountdown,
                  child: NextPrayerCountdown(
                    prayerData: _prayerData,
                    onRefresh: _loadPrayerData,
                  ),
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
                      KeyedSubtree(
                        key: _keyHadithCard,
                        child: const HadithCard(),
                      ),

                      const SizedBox(height: 16),

                      // Quiz du jour
                      KeyedSubtree(
                        key: _keyQuizCard,
                        child: const QuizCard(),
                      ),

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
          'Sakina',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(now),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
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

    return Column(
      children: [
        if (_shouldShowPrayerLocationCta) _buildPrayerLocationCta(),
        PrayerTimesCard(prayerTimes: _prayerData!.prayerTimes),
      ],
    );
  }

  bool get _shouldShowPrayerLocationCta {
    final permission = _prayerLocationPermission;
    final usingFallbackLocation =
        _prayerData?.latitude == null && _prayerData?.longitude == null;

    return usingFallbackLocation &&
        (!_isPrayerLocationServiceEnabled ||
            permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever);
  }

  Widget _buildPrayerLocationCta() {
    final serviceDisabled = !_isPrayerLocationServiceEnabled;
    final deniedForever =
        _prayerLocationPermission == LocationPermission.deniedForever;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 18,
        blur: 10,
        padding: const EdgeInsets.all(16),
        color: AppColors.glassMedium,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.near_me_rounded,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Horaires precis',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serviceDisabled
                        ? "Activez le service de localisation de l'iPhone pour calculer vos horaires locaux."
                        : deniedForever
                            ? 'Autorisez la position dans les reglages pour calculer vos horaires locaux.'
                            : 'Activez votre position pour afficher les horaires de priere de votre ville.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _isRequestingPrayerLocation
                          ? null
                          : _enablePrayerLocation,
                      icon: _isRequestingPrayerLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              deniedForever
                                  ? Icons.settings_rounded
                                  : serviceDisabled
                                      ? Icons.settings_rounded
                                      : Icons.location_on_rounded,
                              size: 18,
                            ),
                      label: Text(
                        deniedForever
                            ? 'Ouvrir les reglages'
                            : serviceDisabled
                                ? 'Ouvrir les reglages'
                                : 'Activer la position',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section de navigation rapide vers Qibla et Coran
  /// Boutons larges avec icônes pour accès facile
  Widget _buildQuickNavigationSection() {
    return Row(
      children: [
        // Bouton Qibla avec mini-boussole
        Expanded(
          child: Card(
            key: _keyQiblaNav,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.qibla);
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Hero(
                      tag: HeroTags.qiblaCompass,
                      child: MiniQiblaCompass(),
                    ),
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
            key: _keyQuranNav,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.quran);
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Hero(
                      tag: HeroTags.quranIcon,
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 48,
                        color: AppColors.copper,
                      ),
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
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
