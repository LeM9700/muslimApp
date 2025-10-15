import 'package:flutter/material.dart';
import '../services/qibla_service.dart';

/// Widget miniature de boussole Qibla pour le dashboard
/// Affiche l'angle vers la Qibla avec un CTA vers l'écran complet
class MiniQiblaCompass extends StatefulWidget {
  const MiniQiblaCompass({super.key});

  @override
  State<MiniQiblaCompass> createState() => _MiniQiblaCompassState();
}

class _MiniQiblaCompassState extends State<MiniQiblaCompass> {
  double? _qiblaAngle;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculateQiblaDirection();
  }

  /// Calcule la direction vers la Qibla
  /// Affiche l'angle ou un message d'erreur si permissions refusées
  Future<void> _calculateQiblaDirection() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final angle = await QiblaService.calculateQiblaBearing();
      
      if (mounted) {
        setState(() {
          _qiblaAngle = angle;
          _isLoading = false;
          if (angle == null) {
            _errorMessage = 'Permission géolocalisation requise';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de calcul';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: _buildCompassContent(),
    );
  }

  /// Construit le contenu de la mini-boussole selon l'état
  /// Gère les états: chargement, erreur, boussole affichée
  Widget _buildCompassContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_errorMessage != null) {
      return Icon(
        Icons.location_disabled,
        size: 48,
        color: Colors.red.shade300,
      );
    }

    if (_qiblaAngle == null) {
      return Icon(
        Icons.compass_calibration,
        size: 48,
        color: Colors.white30,
      );
    }

    return _buildMiniCompass();
  }

  /// Construit la mini-boussole avec indication de direction
  /// Flèche pointant vers la Qibla avec angle affiché
  Widget _buildMiniCompass() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle de fond
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white30,
              width: 2,
            ),
          ),
        ),
        
        // Flèche pointant vers la Qibla
        Transform.rotate(
          angle: _qiblaAngle! * (3.14159 / 180), // Conversion degrés vers radians
          child: Icon(
            Icons.navigation,
            size: 24,
            color: Colors.green.shade400,
          ),
        ),
        
        // Point central
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}