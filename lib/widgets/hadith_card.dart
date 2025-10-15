import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/hadith.dart';
import '../utils/app_theme.dart';
import 'glass_widgets.dart';

/// Widget pour afficher le hadith du jour depuis Firestore
/// Charge automatiquement un hadith validé (reviewed == true)
class HadithCard extends StatefulWidget {
  const HadithCard({super.key});

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  Hadith? _currentHadith;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDailyHadith();
  }

  /// Charge le hadith du jour depuis Firestore
  /// Affiche un état de chargement puis le hadith ou une erreur
  Future<void> _loadDailyHadith() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final hadith = await FirebaseService.getHadithOfTheDay();
      
      if (mounted) {
        setState(() {
          _currentHadith = hadith;
          _isLoading = false;
          if (hadith == null) {
            _errorMessage = 'Aucun hadith disponible';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec icône et bouton refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hadith du jour',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadDailyHadith,
                    tooltip: 'Actualiser',
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Contenu du hadith
            _buildHadithContent(),
          ],
        ),
      ),
    );
  }

  /// Construit le contenu du hadith selon l'état actuel
  /// Gère les états: chargement, erreur, hadith affiché
  Widget _buildHadithContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_currentHadith == null) {
      return _buildEmptyState();
    }

    return _buildHadithDisplay();
  }

  /// Affiche l'état d'erreur avec possibilité de réessayer
  /// Bouton retry pour recharger le hadith
  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red.shade300),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadDailyHadith,
          child: const Text('Réessayer'),
        ),
      ],
    );
  }

  /// Affiche l'état vide quand aucun hadith n'est disponible
  /// Message informatif avec suggestion
  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.book_outlined,
          size: 48,
          color: Colors.white30,
        ),
        const SizedBox(height: 16),
        Text(
          'Aucun hadith disponible pour aujourd\'hui',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Revenez plus tard ou actualisez',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Affiche le hadith avec son texte et sa source
  /// Utilise le style arabe si le texte contient de l'arabe
  Widget _buildHadithDisplay() {
    final hadith = _currentHadith!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Texte du hadith
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.gradientStart,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hadith.text,
            style: _isArabicText(hadith.text)
                ? AppTheme.getArabicTextStyle(fontSize: 20)
                : Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            textAlign: _isArabicText(hadith.text) 
                ? TextAlign.right 
                : TextAlign.left,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Source du hadith
        Row(
          children: [
            Icon(
              Icons.source_outlined,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hadith.source,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Détermine si le texte contient principalement de l'arabe
  /// Utilisé pour choisir le style d'affichage approprié
  bool _isArabicText(String text) {
    // Regex pour détecter les caractères arabes
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    final arabicMatches = arabicRegex.allMatches(text).length;
    final totalChars = text.replaceAll(RegExp(r'\s'), '').length;
    
    // Si plus de 30% des caractères sont arabes, considérer comme texte arabe
    return totalChars > 0 && (arabicMatches / totalChars) > 0.3;
  }
}