import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../utils/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import '../services/qibla_service.dart';
import '../utils/hero_tags.dart';
import '../widgets/qibla_compass.dart';
import '../widgets/lottie_animations.dart';

/// Écran de boussole Qibla avec calibrage et informations
/// Affiche une vraie boussole pointant vers la Kaaba avec géolocalisation
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaBearing;
  double? _currentHeading;
  double? _distanceToKaaba;
  bool _isLoading = true;
  String? _errorMessage;
  LocationPermission? _locationPermission;
  bool _isLocationServiceEnabled = false;

  // ── Animation Lottie (Q10) ────────────────────────────────────────────────
  /// Vrai quand la boussole est alignée avec la Qibla (±5°).
  bool _showQiblaFound = false;
  /// Garde en mémoire l'état précédent pour éviter de re-déclencher.
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _initializeQibla();
  }

  /// Initialise la boussole Qibla
  /// Vérifie les permissions et calcule la direction
  Future<void> _initializeQibla() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Vérifier si le service de localisation est activé
      _isLocationServiceEnabled = await QiblaService.isLocationServiceEnabled();
      if (!_isLocationServiceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Le service de géolocalisation est désactivé.\nVeuillez l\'activer dans les paramètres.';
        });
        return;
      }

      // Vérifier les permissions
      _locationPermission = await QiblaService.getLocationPermissionStatus();
      if (_locationPermission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Permission de géolocalisation refusée définitivement.\nVeuillez l\'autoriser dans les paramètres de l\'application.';
        });
        return;
      }

      if (_locationPermission == LocationPermission.denied) {
        _locationPermission = await QiblaService.requestLocationPermission();
        if (_locationPermission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Permission de géolocalisation requise pour fonctionner.';
          });
          return;
        }
      }

      // Calculer la direction vers la Qibla
      final bearing = await QiblaService.calculateQiblaBearing();
      final distance = await QiblaService.calculateDistanceToKaaba();

      if (bearing != null) {
        setState(() {
          _qiblaBearing = bearing;
          _distanceToKaaba = distance;
          _isLoading = false;
        });

        // Écouter la boussole
        _listenToCompass();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Impossible de calculer la direction de la Qibla.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur d\'initialisation: $e';
      });
    }
  }

  /// Écoute les événements de la boussole
  /// Met à jour l'orientation en temps réel
  void _listenToCompass() {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted || event.heading == null) return;
      final heading = event.heading!;

      // Détection alignement Qibla : différence angulaire ≤ 5°
      if (_qiblaBearing != null) {
        final diff = ((heading - _qiblaBearing!) % 360 + 360) % 360;
        final aligned = diff <= 5 || diff >= 355;

        if (aligned && !_wasAligned) {
          // Front sur l'alignement : déclenche l'animation une seule fois
          setState(() {
            _showQiblaFound = true;
            _wasAligned = true;
          });
        } else if (!aligned) {
          _wasAligned = false;
        }
      }

      setState(() {
        _currentHeading = heading;
      });
    });
  }

  /// Demande les permissions de géolocalisation
  /// Utilisé par le bouton "Autoriser" en cas de refus
  Future<void> _requestPermissions() async {
    final permission = await QiblaService.requestLocationPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _initializeQibla();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direction de la Qibla'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initializeQibla,
              tooltip: 'Actualiser',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Construit le corps de l'écran selon l'état actuel
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Calcul de la direction...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return _buildCompassView();
  }

  /// Affiche l'état d'erreur avec actions possibles
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _locationPermission == LocationPermission.deniedForever
                  ? Icons.location_disabled
                  : Icons.location_off,
              size: 64,
              color: Colors.red.shade300,
            ),
            
            const SizedBox(height: 24),
            
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Boutons d'action selon le type d'erreur
            if (_locationPermission == LocationPermission.denied) ...[
              ElevatedButton(
                onPressed: _requestPermissions,
                child: const Text('Autoriser la géolocalisation'),
              ),
            ] else if (!_isLocationServiceEnabled) ...[
              ElevatedButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                child: const Text('Ouvrir les paramètres'),
              ),
            ] else if (_locationPermission == LocationPermission.deniedForever) ...[
              ElevatedButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                child: const Text('Ouvrir les paramètres de l\'app'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _initializeQibla,
                child: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit la vue de la boussole avec informations
  Widget _buildCompassView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Informations sur la position
          _buildLocationInfo(),
          
          const SizedBox(height: 24),
          
          // Boussole principale
          _buildMainCompass(),
          
          const SizedBox(height: 24),
          
          // Instructions et conseils
          _buildInstructions(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Construit la section d'informations sur la localisation
  Widget _buildLocationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Informations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Direction en degrés
            if (_qiblaBearing != null)
              _buildInfoRow(
                'Direction de la Qibla',
                '${_qiblaBearing!.toStringAsFixed(1)}°',
                Icons.explore,
              ),
            
            // Distance vers la Kaaba
            if (_distanceToKaaba != null)
              _buildInfoRow(
                'Distance vers la Kaaba',
                '${_distanceToKaaba!.toStringAsFixed(0)} km',
                Icons.straighten,
              ),
            
            // Orientation actuelle
            if (_currentHeading != null)
              _buildInfoRow(
                'Orientation actuelle',
                '${_currentHeading!.toStringAsFixed(1)}°',
                Icons.compass_calibration,
              ),
          ],
        ),
      ),
    );
  }

  /// Construit une ligne d'information
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la boussole principale
  Widget _buildMainCompass() {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Boussole Hero ──────────────────────────────────────────────────
          Hero(
        tag: HeroTags.qiblaCompass,
        // [⚡ PERF] flightShuttleBuilder désactive BackdropFilter pendant le vol
        // pour éviter un rendu double des blurs (source + destination).
        flightShuttleBuilder: (_, animation, __, ___, ____) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Opacity(
              opacity: animation.value,
              child: child,
            ),
            child: QiblaCompass(
              qiblaBearing: _qiblaBearing ?? 0,
              currentHeading: _currentHeading ?? 0,
            ),
          );
        },
        child: QiblaCompass(
          qiblaBearing: _qiblaBearing ?? 0,
          currentHeading: _currentHeading ?? 0,
        ),
      ),

          // ── Lottie "Qibla trouvée" ─────────────────────────────────────────
          if (_showQiblaFound)
            IgnorePointer(
              child: QiblaFoundAnimation(
                size: 300,
                onComplete: () {
                  if (mounted) setState(() => _showQiblaFound = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Construit la section d'instructions et conseils
  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conseils d\'utilisation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildInstructionItem(
              '1. Tenez votre téléphone à plat',
              'Pour une meilleure précision de la boussole',
            ),
            
            _buildInstructionItem(
              '2. Éloignez-vous des objets métalliques',
              'Évitez les interférences magnétiques',
            ),
            
            _buildInstructionItem(
              '3. Calibrez votre boussole si nécessaire',
              'Effectuez des mouvements en 8 avec votre téléphone',
            ),
            
            _buildInstructionItem(
              '4. La flèche verte indique la Qibla',
              'Orientez-vous dans cette direction pour prier',
            ),
          ],
        ),
      ),
    );
  }

  /// Construit un élément d'instruction
  Widget _buildInstructionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}