import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

/// Écran de profil utilisateur avec statistiques et paramètres
/// Affiche des informations sur l'utilisation de l'application
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _lastSuraName;
  int? _lastAyah;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// Charge les données du profil utilisateur
  /// Statistiques d'utilisation et préférences sauvegardées
  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Charger les statistiques depuis Firestore
      final hadithCount = await FirebaseService.getValidatedHadithsCount();
      final quizCount = await FirebaseService.getValidatedQuestionsCount();
      
      // Charger les données locales
      final prefs = await SharedPreferences.getInstance();
      final lastSura = prefs.getString('last_sura_name');
      final lastAyah = prefs.getInt('last_ayah');
      
      // Calculer les statistiques locales
      final readingSessions = prefs.getInt('reading_sessions') ?? 0;
      final quizAnswered = prefs.getInt('quiz_answered') ?? 0;
      final correctAnswers = prefs.getInt('correct_answers') ?? 0;
      
      if (mounted) {
        setState(() {
          _stats = {
            'hadith_count': hadithCount,
            'quiz_count': quizCount,
            'reading_sessions': readingSessions,
            'quiz_answered': quizAnswered,
            'correct_answers': correctAnswers,
          };
          _lastSuraName = lastSura;
          _lastAyah = lastAyah;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Erreur de chargement: $e');
      }
    }
  }

  /// Efface toutes les données utilisateur
  /// Confirmation requise avant suppression
  Future<void> _clearAllUserData() async {
    final confirm = await _showConfirmDialog(
      'Effacer toutes les données',
      'Cette action supprimera définitivement :\n'
      '• Votre progression de lecture\n'
      '• Vos statistiques de quiz\n'
      '• Toutes vos préférences\n\n'
      'Continuer ?',
    );
    
    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (mounted) {
          setState(() {
            _stats.clear();
            _lastSuraName = null;
            _lastAyah = null;
          });
          _showSnackBar('Toutes les données ont été effacées');
        }
      } catch (e) {
        _showSnackBar('Erreur lors de l\'effacement: $e');
      }
    }
  }

  /// Affiche une boîte de dialogue de confirmation
  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  /// Affiche un SnackBar avec un message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _isLoading ? _buildLoadingState() : _buildProfileContent(),
    );
  }

  /// Construit l'état de chargement
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Construit le contenu principal du profil
  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du profil
          _buildProfileHeader(),
          
          const SizedBox(height: 24),
          
          // Statistiques d'utilisation
          _buildStatisticsSection(),
          
          const SizedBox(height: 24),
          
          // Progression de lecture
          _buildReadingProgressSection(),
          
          const SizedBox(height: 24),
          
          // Paramètres et actions
          _buildSettingsSection(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Construit l'en-tête du profil
  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.person,
                size: 48,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Titre
            Text(
              'Utilisateur Muslim App',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Membre depuis l\'installation',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la section des statistiques
  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        
        const SizedBox(height: 16),
        
        // Grille de statistiques
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              'Hadiths disponibles',
              '${_stats['hadith_count'] ?? 0}',
              Icons.auto_stories,
              Colors.green,
            ),
            _buildStatCard(
              'Questions disponibles',
              '${_stats['quiz_count'] ?? 0}',
              Icons.quiz,
              Colors.blue,
            ),
            _buildStatCard(
              'Quiz répondus',
              '${_stats['quiz_answered'] ?? 0}',
              Icons.check_circle,
              Colors.orange,
            ),
            _buildStatCard(
              'Bonnes réponses',
              '${_stats['correct_answers'] ?? 0}',
              Icons.star,
              Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  /// Construit une card de statistique
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            
            const SizedBox(height: 12),
            
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la section de progression de lecture
  Widget _buildReadingProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progression de lecture',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: ListTile(
            leading: Icon(
              Icons.bookmark_outline,
              color: Colors.white70,
            ),
            title: Text(
              _lastSuraName ?? 'Aucune lecture en cours',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: _lastAyah != null 
                ? Text('Dernier verset lu: $_lastAyah')
                : const Text('Commencez votre lecture du Coran'),
            trailing: _lastSuraName != null 
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('last_sura_id');
                      await prefs.remove('last_sura_name');
                      await prefs.remove('last_ayah');
                      setState(() {
                        _lastSuraName = null;
                        _lastAyah = null;
                      });
                      _showSnackBar('Progression effacée');
                    },
                    tooltip: 'Effacer la progression',
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// Construit la section des paramètres
  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paramètres',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        
        const SizedBox(height: 16),
        
        // Actions de paramètres
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.refresh, color: Colors.white70),
                title: const Text('Actualiser les données'),
                subtitle: const Text('Recharger les statistiques'),
                onTap: _loadProfileData,
              ),
              
              const Divider(height: 1),
              
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade300),
                title: Text(
                  'Effacer toutes les données',
                  style: TextStyle(color: Colors.red.shade300),
                ),
                subtitle: const Text('Supprime définitivement toutes vos données'),
                onTap: _clearAllUserData,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Informations sur l'application
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Muslim App v1.0.0\n'
                  'MVP open-source pour la communauté musulmane\n\n'
                  'Cette application respecte votre vie privée :\n'
                  '• Aucune donnée personnelle collectée\n'
                  '• Stockage local uniquement\n'
                  '• Contenu validé par des experts',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}