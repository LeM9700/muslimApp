import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget de boussole Qibla avec vraie orientation magnétique
/// Affiche une boussole avec flèche pointant vers la Kaaba
class QiblaCompass extends StatelessWidget {
  final double qiblaBearing;  // Direction vers la Qibla en degrés
  final double currentHeading; // Orientation magnétique actuelle

  const QiblaCompass({
    super.key,
    required this.qiblaBearing,
    required this.currentHeading,
  });

  @override
  Widget build(BuildContext context) {
    // Calcul de l'angle de la flèche Qibla relative à l'orientation actuelle
    final qiblaAngle = qiblaBearing - currentHeading;
    
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle de fond avec graduations
          _buildCompassRing(),
          
          // Points cardinaux
          _buildCardinalPoints(),
          
          // Flèche pointant vers la Qibla
          _buildQiblaArrow(qiblaAngle),
          
          // Indicateur Nord
          _buildNorthIndicator(),
          
          // Centre de la boussole
          _buildCenter(),
        ],
      ),
    );
  }

  /// Construit l'anneau de la boussole avec graduations
  Widget _buildCompassRing() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white30,
          width: 2,
        ),
      ),
      child: CustomPaint(
        painter: CompassRingPainter(),
      ),
    );
  }

  /// Construit les points cardinaux (N, S, E, W)
  Widget _buildCardinalPoints() {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          // Nord
          _buildCardinalText('N', 0),
          // Est
          _buildCardinalText('E', 90),
          // Sud
          _buildCardinalText('S', 180),
          // Ouest
          _buildCardinalText('W', 270),
        ],
      ),
    );
  }

  /// Construit un texte de point cardinal à une position donnée
  Widget _buildCardinalText(String text, double angle) {
    return Transform.rotate(
      angle: -currentHeading * (math.pi / 180),
      child: Transform.translate(
        offset: Offset(
          math.sin(angle * math.pi / 180) * 120,
          -math.cos(angle * math.pi / 180) * 120,
        ),
        child: Transform.rotate(
          angle: currentHeading * (math.pi / 180),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: text == 'N' ? Colors.red.shade300 : Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construit la flèche pointant vers la Qibla
  Widget _buildQiblaArrow(double angle) {
    return Transform.rotate(
      angle: angle * (math.pi / 180),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Flèche vers la Qibla
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Pointe de la flèche
          CustomPaint(
            size: Size(20, 20),
            painter: ArrowHeadPainter(color: Colors.green.shade400),
          ),
          
          // Espace pour équilibrer
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// Construit l'indicateur de direction Nord
  Widget _buildNorthIndicator() {
    return Transform.rotate(
      angle: -currentHeading * (math.pi / 180),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit le centre de la boussole
  Widget _buildCenter() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black26, width: 1),
      ),
    );
  }
}

/// Painter pour l'anneau de la boussole avec graduations
class CompassRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;
    
    // Dessiner les graduations (tous les 10 degrés)
    for (int i = 0; i < 36; i++) {
      final angle = i * 10 * (math.pi / 180);
      final isMainGraduation = i % 3 == 0; // Tous les 30 degrés
      
      final startRadius = isMainGraduation ? radius - 20 : radius - 10;
      final endRadius = radius - 5;
      
      final startPoint = Offset(
        center.dx + startRadius * math.cos(angle - math.pi / 2),
        center.dy + startRadius * math.sin(angle - math.pi / 2),
      );
      
      final endPoint = Offset(
        center.dx + endRadius * math.cos(angle - math.pi / 2),
        center.dy + endRadius * math.sin(angle - math.pi / 2),
      );
      
      paint.strokeWidth = isMainGraduation ? 2 : 1;
      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Painter pour la pointe de flèche
class ArrowHeadPainter extends CustomPainter {
  final Color color;
  
  const ArrowHeadPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(size.width / 2, 0) // Point haut
      ..lineTo(0, size.height) // Point bas gauche
      ..lineTo(size.width, size.height) // Point bas droit
      ..close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}