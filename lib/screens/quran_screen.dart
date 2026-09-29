import 'package:flutter/material.dart';
import '../models/quran_models.dart';
import '../services/quran_api_service.dart';
import '../widgets/glass_widgets.dart';
import '../utils/app_theme.dart';
import '../screens/sura_detail_screen.dart';
import '../utils/hero_tags.dart';

/// Écran de liste des sourates du Coran avec API Quran Foundation v4
/// Charge les sourates depuis l'API et permet la navigation vers le détail
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranApiService _api = QuranApiService();
  List<ChapterInfo> _chapters = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChapters();
    // Test pour trouver la bonne traduction française
    _api.findFrenchTranslation();
  }

  /// Charge la liste des sourates depuis l'API Quran Foundation
  Future<void> _loadChapters() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final chapters = await _api.getAllChapters();

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement chapitres: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement: $e';
        });
      }
    }
  }

  /// Filtre les sourates selon la requête de recherche
  List<ChapterInfo> get _filteredChapters {
    if (_searchQuery.isEmpty) {
      return _chapters;
    }
    
    return _chapters.where((chapter) {
      final nameSimple = chapter.nameSimple?.toLowerCase() ?? '';
      final nameComplex = chapter.nameComplex?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return nameSimple.contains(query) || 
             nameComplex.contains(query) ||
             chapter.number.toString().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête avec titre et recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: HeroTags.quranIcon,
                        child: const Icon(
                          Icons.menu_book_outlined,
                          size: 32,
                          color: AppColors.copper,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Coran',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_chapters.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_chapters.length} sourates disponibles',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Barre de recherche
                  GlassContainer(
                    borderRadius: 12,
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une sourate...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textMuted),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Corps principal
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
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
              'Chargement des sourates...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_chapters.isEmpty) {
      return _buildEmptyState();
    }

    return _buildChaptersList();
  }

  /// Affiche l'état d'erreur avec possibilité de réessayer
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChapters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche l'état vide quand aucune sourate n'est trouvée
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Aucune sourate trouvée pour "$_searchQuery"'
                  : 'Aucune sourate disponible',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: const Text('Effacer la recherche'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit la liste des sourates avec pull-to-refresh
  Widget _buildChaptersList() {
    final filteredChapters = _filteredChapters;
    
    return RefreshIndicator(
      onRefresh: _loadChapters,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredChapters.length,
        itemBuilder: (context, index) {
          final chapter = filteredChapters[index];
          return _buildChapterCard(chapter);
        },
      ),
    );
  }

  /// Construit une card pour une sourate
  Widget _buildChapterCard(ChapterInfo chapter) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 12,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        
        // Numéro de la sourate
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.emerald, AppColors.copper],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${chapter.number}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ),
        
        // Nom et détails
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            if (chapter.nameAr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                chapter.nameAr,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontFamily: 'Arabic',
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
        
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${chapter.ayahCount} versets',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                chapter.revelationPlace?.toLowerCase() == 'mecca' 
                    ? Icons.location_city 
                    : Icons.location_on,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                chapter.revelationPlace?.toLowerCase() == 'mecca' ? 'Mecquoise' : 'Médinoise',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // Flèche de navigation
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textMuted,
        ),
        
        // Navigation vers le détail
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => SuraDetailScreen(
                suraId: chapter.number.toString(),
                suraName: chapter.displayName,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}