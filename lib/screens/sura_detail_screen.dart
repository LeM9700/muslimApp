import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';
import '../services/quran_api_service.dart';
import '../widgets/glass_widgets.dart';
import '../utils/app_theme.dart';

/// Écran de lecture d'une sourate avec API Quran Foundation v4
/// Affiche les versets en arabe + traduction FR + audio à la volée
class SuraDetailScreen extends StatefulWidget {
  final String suraId; // string mais on va caster en int pour l'API
  final String? suraName; // optionnel car on peut le récupérer via API

  const SuraDetailScreen({
    super.key,
    required this.suraId,
    this.suraName,
  });

  @override
  State<SuraDetailScreen> createState() => _SuraDetailScreenState();
}

class _SuraDetailScreenState extends State<SuraDetailScreen> {
  final QuranApiService _api = QuranApiService();
  final AudioPlayer _player = AudioPlayer();

  ChapterInfo? _meta;
  List<Verse> _verses = [];
  int _page = 1;
  bool _loading = true;
  bool _hasMore = true;
  String? _errorMessage;
  int? _currentPlayingVerse;
  bool _isPlaying = false;

  // Clés SharedPreferences pour le bookmarking
  static const String _keyLastSuraId = 'last_sura_id';
  static const String _keyLastSuraName = 'last_sura_name';
  static const String _keyLastAyah = 'last_ayah';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _setupAudioPlayerListeners();
  }

  /// Charge les métadonnées et versets depuis l'API Quran Foundation
  Future<void> _loadAll() async {
    final chapterNumber = int.tryParse(widget.suraId);
    if (chapterNumber == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'ID de sourate invalide: ${widget.suraId}';
      });
      return;
    }

    try {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      // Charge métadonnées et première page en parallèle
      final results = await Future.wait([
        _api.getChapterMeta(chapterNumber),
        _api.getVersesByChapter(chapterNumber: chapterNumber, page: 1, perPage: 50),
      ]);

      final meta = results[0] as ChapterInfo;
      final verses = results[1] as List<Verse>;

      if (mounted) {
        setState(() {
          _meta = meta;
          _verses = verses;
          _loading = false;
          _page = 1;
          _hasMore = verses.length == 50; // Si 50 versets → peut-être plus
        });
      }
    } catch (e) {
      print('❌ Erreur chargement sourate: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Erreur de chargement: $e';
        });
      }
    }
  }

  /// Charge plus de versets (pagination)
  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;

    final chapterNumber = int.tryParse(widget.suraId);
    if (chapterNumber == null) return;

    try {
      final nextPage = _page + 1;
      final moreVerses = await _api.getVersesByChapter(
        chapterNumber: chapterNumber, 
        page: nextPage, 
        perPage: 50,
      );

      if (mounted) {
        setState(() {
          _verses.addAll(moreVerses);
          _page = nextPage;
          _hasMore = moreVerses.length == 50;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement page suivante: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e')),
        );
      }
    }
  }

  /// Configuration des listeners pour le player audio
  void _setupAudioPlayerListeners() {
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _currentPlayingVerse = null;
          _isPlaying = false;
        });
      }
    });

    _player.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  /// Lecture audio d'un verset avec gestion de l'état
  Future<void> _playVerse(Verse verse) async {
    if (verse.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio non disponible pour ce verset')),
      );
      return;
    }

    try {
      // Arrêt si déjà en lecture
      if (_currentPlayingVerse == verse.verseNumber && _isPlaying) {
        await _player.stop();
        return;
      }

      // Nouvelle lecture  
      await _player.stop();
      await _player.play(UrlSource(verse.audioUrl!));
      
      setState(() {
        _currentPlayingVerse = verse.verseNumber;
      });

      // Sauvegarde progrès de lecture
      await _saveReadingProgress(verse.verseNumber);
    } catch (e) {
      print('❌ Erreur lecture audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lecture: $e')),
      );
    }
  }

  /// Arrêt de la lecture audio
  Future<void> _stopAudio() async {
    try {
      await _player.stop();
      setState(() {
        _currentPlayingVerse = null;
        _isPlaying = false;
      });
    } catch (e) {
      print('❌ Erreur arrêt audio: $e');
    }
  }

  /// Sauvegarde la position de lecture pour reprise
  Future<void> _saveReadingProgress(int ayahNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSuraId, widget.suraId);
      await prefs.setString(_keyLastSuraName, _meta?.displayName ?? 'Sourate ${widget.suraId}');
      await prefs.setInt(_keyLastAyah, ayahNumber);
      
      print('✅ Progrès sauvé: Sourate ${widget.suraId}, Verset $ayahNumber');
    } catch (e) {
      print('❌ Erreur sauvegarde progrès: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: Text(
          _meta?.displayName ?? widget.suraName ?? 'Sourate ${widget.suraId}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChapterInfo,
          ),
          if (_isPlaying)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopAudio,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _verses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentBlue),
            SizedBox(height: 16),
            Text(
              'Chargement des versets...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verses.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Bouton "Charger plus" à la fin
        if (index == _verses.length) {
          return _buildLoadMoreButton();
        }

        final verse = _verses[index];
        return _buildVerseCard(verse, index);
      },
    );
  }

  Widget _buildVerseCard(Verse verse, int index) {
    final isCurrentlyPlaying = _currentPlayingVerse == verse.verseNumber && _isPlaying;
    
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header avec numéro de verset + bouton audio
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${verse.verseNumber}',
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (verse.audioUrl != null)
                  IconButton(
                    icon: Icon(
                      isCurrentlyPlaying ? Icons.stop : Icons.play_arrow,
                      color: isCurrentlyPlaying ? Colors.red.shade400 : AppTheme.accentBlue,
                    ),
                    onPressed: () => _playVerse(verse),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Texte arabe
            Text(
              verse.textUthmani,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFamily: 'NotoNaskhArabic', // TODO: Ajouter police arabe
                height: 1.8,
              ),
            ),
            
            // Traduction française
            if (verse.translationText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  verse.translationText!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: _loading ? null : _loadMore,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Charger plus de versets'),
        ),
      ),
    );
  }

  void _showChapterInfo() {
    if (_meta == null) return;
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        title: Text(
          _meta!.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nom arabe: ${_meta!.nameAr}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Nombre de versets: ${_meta!.ayahCount}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (_meta!.revelationPlace != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lieu de révélation: ${_meta!.revelationPlace}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Attribution:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Texte & API : Quran Foundation / Quran.com (v4)\nTraduction française : Muhammad Hamidullah',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: AppTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _api.dispose();
    super.dispose();
  }
}