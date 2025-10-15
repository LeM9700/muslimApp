import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes/app_routes.dart';

/// Widget pour reprendre la dernière lecture du Coran
/// Lit les données de SharedPreferences: last_sura_id, last_sura_name, last_ayah
class ResumeReadingCard extends StatefulWidget {
  const ResumeReadingCard({super.key});

  @override
  State<ResumeReadingCard> createState() => _ResumeReadingCardState();
}

class _ResumeReadingCardState extends State<ResumeReadingCard> {
  String? _lastSuraId;
  String? _lastSuraName;
  int? _lastAyah;
  bool _isLoading = true;
  bool _hasResumeData = false;

  // Clés SharedPreferences documentées
  static const String _keyLastSuraId = 'last_sura_id';      // String: ID Firestore de la dernière sourate
  static const String _keyLastSuraName = 'last_sura_name';  // String: Nom de la dernière sourate
  static const String _keyLastAyah = 'last_ayah';           // int: Numéro du dernier verset lu

  @override
  void initState() {
    super.initState();
    _loadResumeData();
  }

  /// Charge les données de reprise depuis SharedPreferences
  /// Récupère la dernière sourate et le dernier verset consultés
  Future<void> _loadResumeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final suraId = prefs.getString(_keyLastSuraId);
      final suraName = prefs.getString(_keyLastSuraName);
      final ayah = prefs.getInt(_keyLastAyah);
      
      if (mounted) {
        setState(() {
          _lastSuraId = suraId;
          _lastSuraName = suraName;
          _lastAyah = ayah;
          _hasResumeData = suraId != null && suraName != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasResumeData = false;
        });
      }
    }
  }

  /// Efface les données de reprise
  /// Utilisé quand l'utilisateur veut commencer une nouvelle lecture
  Future<void> _clearResumeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSuraId);
      await prefs.remove(_keyLastSuraName);
      await prefs.remove(_keyLastAyah);
      
      if (mounted) {
        setState(() {
          _lastSuraId = null;
          _lastSuraName = null;
          _lastAyah = null;
          _hasResumeData = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historique de lecture effacé'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Erreur silencieuse pour cette action non critique
      print('Erreur lors de l\'effacement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!_hasResumeData) {
      return _buildNoResumeData();
    }

    return _buildResumeCard();
  }

  /// Affiche l'état quand aucune donnée de reprise n'existe
  /// Invite à commencer la lecture du Coran
  Widget _buildNoResumeData() {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.quran);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lecture du Coran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Commencez votre lecture du Coran',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.quran);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Commencer'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche la card de reprise avec les dernières données de lecture
  /// Permet de reprendre où l'utilisateur s'était arrêté
  Widget _buildResumeCard() {
    return Card(
      child: InkWell(
        onTap: () {
          AppRoutes.navigateToSura(context, _lastSuraId!, _lastSuraName!);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec bouton d'effacement
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reprendre la lecture',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _clearResumeData,
                    tooltip: 'Effacer l\'historique',
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Informations de reprise
              Text(
                _lastSuraName!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 8),
              
              if (_lastAyah != null)
                Text(
                  'Verset ${_lastAyah}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Bouton de reprise
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      AppRoutes.navigateToSura(context, _lastSuraId!, _lastSuraName!);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuer'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}