import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Widget pour afficher les horaires de prière du jour
/// Reçoit une Map avec les noms des prières et leurs horaires
class PrayerTimesCard extends StatelessWidget {
  final Map<String, String> prayerTimes;

  const PrayerTimesCard({
    super.key,
    required this.prayerTimes,
  });

  @override
  Widget build(BuildContext context) {
    if (prayerTimes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucun horaire disponible',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec icône
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Horaires de prière',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Liste des horaires
            ...prayerTimes.entries.map((entry) => _buildPrayerTimeRow(
              context,
              entry.key,
              entry.value,
            )),
          ],
        ),
      ),
    );
  }

  /// Construit une ligne d'horaire de prière
  /// [prayerName] : nom de la prière (Fajr, Dhuhr, etc.)
  /// [time] : heure au format HH:MM
  Widget _buildPrayerTimeRow(BuildContext context, String prayerName, String time) {
    // Vérifier si c'est la prochaine prière (style différent)
    final isNext = _isNextPrayer(prayerName, time);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _translatePrayerName(prayerName),
            style: TextStyle(
              fontSize: 16,
              color: isNext ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isNext ? AppColors.emerald.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isNext ? Border.all(color: AppColors.emerald, width: 1) : null,
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isNext ? AppColors.emerald : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Traduit le nom des prières en français
  /// Mapping des noms anglais vers français
  String _translatePrayerName(String englishName) {
    switch (englishName) {
      case 'Fajr':
        return 'Fajr';
      case 'Dhuhr':
        return 'Dhuhr';
      case 'Asr':
        return 'Asr';
      case 'Maghrib':
        return 'Maghrib';
      case 'Isha':
        return 'Isha';
      default:
        return englishName;
    }
  }

  /// Détermine si c'est la prochaine prière à venir
  /// Retourne true UNIQUEMENT pour la toute prochaine prière, pas toutes les futures
  bool _isNextPrayer(String prayerName, String time) {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Parcourir les prières dans l'ordre pour trouver LA prochaine
    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final prayer in prayerOrder) {
      final prayerTime = prayerTimes[prayer];
      if (prayerTime != null && currentTime.compareTo(prayerTime) < 0) {
        // C'est la première prière pas encore passée = la prochaine
        return prayer == prayerName;
      }
    }
    
    // Toutes les prières sont passées → la prochaine est Fajr (demain)
    return prayerName == 'Fajr';
  }
}