import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/hadith_api_service.dart';
import '../services/local_content_service.dart';
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

  /// Charge le hadith du jour depuis l'API Sunnah.com (ou Firestore fallback)
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

  /// Charge un nouveau hadith aléatoire depuis l'API (bouton refresh)
  Future<void> _loadRandomHadith() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // API random (pas le cache), sinon un autre hadith Nawawi embarqué
      final hadith = await HadithApiService.getRandomHadith() ??
          await LocalContentService.getRandomHadith(
            excludeId: _currentHadith?.id,
          );
      
      if (mounted) {
        setState(() {
          _currentHadith = hadith;
          _isLoading = false;
          if (hadith == null) {
            _errorMessage = 'Impossible de charger un hadith';
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
                      color: AppColors.textSecondary,
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
                    onPressed: _loadRandomHadith,
                    tooltip: 'Nouveau hadith aléatoire',
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
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 16),
        Text(
          'Aucun hadith disponible pour aujourd\'hui',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Revenez plus tard ou actualisez',
          style: TextStyle(
            color: AppColors.textMuted,
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
            color: AppColors.glassLight,
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
        
        // Source et grade du hadith
        Row(
          children: [
            Icon(
              Icons.source_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hadith.source,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            // Badge de grade (Sahih, Hasan, etc.)
            if (hadith.grade != null && hadith.grade!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _gradeColor(hadith.grade!).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _gradeColor(hadith.grade!).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  hadith.grade!,
                  style: TextStyle(
                    fontSize: 10,
                    color: _gradeColor(hadith.grade!),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Couleur associée au grade d'authenticité du hadith
  Color _gradeColor(String grade) {
    final g = grade.toLowerCase();
    if (g.contains('sahih')) return AppColors.emeraldLight;
    if (g.contains('hasan')) return AppColors.warning;
    if (g.contains('da\'if') || g.contains('daif')) return AppColors.copperLight;
    return AppColors.textMuted;
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