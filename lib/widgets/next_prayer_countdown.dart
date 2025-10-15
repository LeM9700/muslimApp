import 'dart:async';
import 'package:flutter/material.dart';
import '../models/prayer_data.dart';

/// Widget principal pour afficher la prochaine prière avec compte à rebours
/// Design artistique avec gradient et animations
class NextPrayerCountdown extends StatefulWidget {
  final PrayerData? prayerData;
  final VoidCallback? onRefresh;

  const NextPrayerCountdown({
    super.key,
    this.prayerData,
    this.onRefresh,
  });

  @override
  State<NextPrayerCountdown> createState() => _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends State<NextPrayerCountdown>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  Duration? _timeLeft;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startCountdown();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  void _startCountdown() {
    _updateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    if (widget.prayerData?.timeUntilNext != null) {
      final remaining = widget.prayerData!.timeUntilNext!;
      final elapsed = Duration(
        seconds: DateTime.now().difference(
          DateTime.now().subtract(remaining)
        ).inSeconds,
      );
      
      setState(() {
        _timeLeft = remaining - elapsed;
        if (_timeLeft!.isNegative) {
          _timeLeft = Duration.zero;
          // Actualiser les données si le temps est écoulé
          widget.onRefresh?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayerData = widget.prayerData;
    
    if (prayerData == null || !prayerData.hasNextPrayer) {
      return _buildLoadingCard();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea).withOpacity(0.8),
              const Color(0xFF764ba2).withOpacity(0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(prayerData),
              const SizedBox(height: 20),
              _buildCountdown(),
              const SizedBox(height: 16),
              _buildNextPrayerInfo(prayerData),
              const SizedBox(height: 8),
              _buildLocationInfo(prayerData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.1),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Chargement des horaires de prière...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PrayerData prayerData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Prochaine Prière',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                prayerData.cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          _formatCountdown(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w300,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerInfo(PrayerData prayerData) {
    return Column(
      children: [
        Text(
          PrayerNames.getFrenchName(prayerData.nextPrayerName!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'à ${prayerData.nextPrayerTime}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(PrayerData prayerData) {
    return Text(
      prayerData.readableTimeLeft,
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 14,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  String _formatCountdown() {
    if (_timeLeft == null) {
      return '--:--:--';
    }
    
    final hours = _timeLeft!.inHours;
    final minutes = _timeLeft!.inMinutes.remainder(60);
    final seconds = _timeLeft!.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }
}