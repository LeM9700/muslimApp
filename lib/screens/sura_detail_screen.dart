import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';
import '../services/quran_api_service.dart';
import '../widgets/glass_widgets.dart';
import '../utils/app_theme.dart';

// =============================================================================
// SuraDetailScreen — lecture d'une sourate
// Feature Q12 : bouton "Play Sourate" → queue audio continue (tous les versets)
// =============================================================================

class SuraDetailScreen extends StatefulWidget {
  final String suraId;
  final String? suraName;

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

  // État audio verset individuel
  int? _currentPlayingVerse;
  bool _isPlaying = false;

  // [Q12] État Play Sourate (queue continue)
  bool _isPlayingSurah = false;
  int _surahQueueIndex = 0;

  // Clés SharedPreferences
  static const String _keyLastSuraId   = 'last_sura_id';
  static const String _keyLastSuraName = 'last_sura_name';
  static const String _keyLastAyah     = 'last_ayah';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _setupAudioListeners();
  }

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------

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
      setState(() { _loading = true; _errorMessage = null; });
      final results = await Future.wait([
        _api.getChapterMeta(chapterNumber),
        _api.getVersesByChapter(chapterNumber: chapterNumber, page: 1, perPage: 50),
      ]);
      if (mounted) {
        setState(() {
          _meta   = results[0] as ChapterInfo;
          _verses = results[1] as List<Verse>;
          _loading = false;
          _page    = 1;
          _hasMore = (_verses.length == 50);
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement sourate: $e');
      if (mounted) {
        setState(() { _loading = false; _errorMessage = 'Erreur de chargement: $e'; });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    final chapterNumber = int.tryParse(widget.suraId);
    if (chapterNumber == null) return;
    try {
      final nextPage  = _page + 1;
      final moreVerses = await _api.getVersesByChapter(
        chapterNumber: chapterNumber, page: nextPage, perPage: 50,
      );
      if (mounted) {
        setState(() {
          _verses.addAll(moreVerses);
          _page    = nextPage;
          _hasMore = (moreVerses.length == 50);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Audio — verset individuel
  // ---------------------------------------------------------------------------

  void _setupAudioListeners() {
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_isPlayingSurah) {
        // [Q12] Avance au verset suivant dans la queue
        final playable = _verses.where((v) => v.audioUrl != null).toList();
        _playQueueFrom(_surahQueueIndex + 1, playable);
      } else {
        setState(() { _currentPlayingVerse = null; _isPlaying = false; });
      }
    });

    _player.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() { _isPlaying = state == PlayerState.playing; });
      }
    });
  }

  Future<void> _playVerse(Verse verse) async {
    if (verse.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio non disponible pour ce verset')),
      );
      return;
    }
    try {
      if (_currentPlayingVerse == verse.verseNumber && _isPlaying) {
        await _player.stop();
        return;
      }
      // Arrêt Play Sourate si actif
      if (_isPlayingSurah) setState(() => _isPlayingSurah = false);

      await _player.stop();
      await _player.play(UrlSource(verse.audioUrl!));
      setState(() => _currentPlayingVerse = verse.verseNumber);
      await _saveProgress(verse.verseNumber);
    } catch (e) {
      debugPrint('❌ Erreur lecture audio: $e');
    }
  }

  Future<void> _stopAudio() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _currentPlayingVerse = null;
        _isPlaying           = false;
        _isPlayingSurah      = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // [Q12] Play Sourate — queue audio continue
  // ---------------------------------------------------------------------------

  /// Lance ou arrête la lecture complète de la sourate verset par verset.
  Future<void> _playSurah() async {
    if (_isPlayingSurah) {
      await _stopAudio();
      return;
    }
    final playable = _verses.where((v) => v.audioUrl != null).toList();
    if (playable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun audio disponible pour cette sourate')),
      );
      return;
    }
    setState(() { _isPlayingSurah = true; _surahQueueIndex = 0; });
    await _playQueueFrom(0, playable);
  }

  /// Joue le verset à [index] dans [verses], puis avance automatiquement.
  Future<void> _playQueueFrom(int index, List<Verse> verses) async {
    if (!mounted || !_isPlayingSurah || index >= verses.length) {
      if (mounted) {
        setState(() { _isPlayingSurah = false; _currentPlayingVerse = null; });
      }
      return;
    }
    final verse = verses[index];
    try {
      await _player.stop();
      await _player.play(UrlSource(verse.audioUrl!));
      setState(() {
        _currentPlayingVerse = verse.verseNumber;
        _surahQueueIndex     = index;
      });
      await _saveProgress(verse.verseNumber);
    } catch (e) {
      // Verset audio défaillant → passe au suivant
      await _playQueueFrom(index + 1, verses);
    }
  }

  // ---------------------------------------------------------------------------
  // Persistance
  // ---------------------------------------------------------------------------

  Future<void> _saveProgress(int ayahNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSuraId,   widget.suraId);
      await prefs.setString(_keyLastSuraName, _meta?.displayName ?? 'Sourate ${widget.suraId}');
      await prefs.setInt(_keyLastAyah,        ayahNumber);
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde progrès: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Écran poussé hors de MainNavigation : il doit fournir son propre fond,
    // sinon le Scaffold transparent s'affiche sur du noir (texte illisible).
    return AnimatedGlassBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          _meta?.displayName ?? widget.suraName ?? 'Sourate ${widget.suraId}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // [Q12] Bouton "Play Sourate"
          if (_verses.any((v) => v.audioUrl != null))
            _PlaySurahButton(
              isPlaying: _isPlayingSurah,
              onPressed: _playSurah,
            ),
          // Arrêt si lecture individuelle
          if (_isPlaying && !_isPlayingSurah)
            IconButton(
              icon: const Icon(Icons.stop_rounded, color: AppColors.error),
              onPressed: _stopAudio,
              tooltip: 'Arrêter',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChapterInfo,
          ),
        ],
      ),
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _verses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.emerald),
            SizedBox(height: 16),
            Text('Chargement des versets...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadAll, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _verses.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _verses.length) return _buildLoadMoreButton();
        return _buildVerseCard(_verses[index]);
      },
    );
  }

  Widget _buildVerseCard(Verse verse) {
    final isCurrentlyPlaying = _currentPlayingVerse == verse.verseNumber && _isPlaying;
    final isInQueue = _isPlayingSurah && _currentPlayingVerse == verse.verseNumber;

    final isActive = _currentPlayingVerse == verse.verseNumber;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      borderRadius: 18,
      // Fond plus opaque que glassLight pour la lisibilité du texte long
      color: Colors.white.withOpacity(0.72),
      border: Border.all(
        color: isActive
            ? (isInQueue ? AppColors.copper : AppColors.emerald)
            : Colors.white.withOpacity(0.6),
        width: isActive ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header verset
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                // Badge numéro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isInQueue ? AppColors.copper : AppColors.emerald).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${verse.verseNumber}',
                    style: TextStyle(
                      color: isInQueue ? AppColors.copper : AppColors.emerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                // Bouton audio verset individuel
                if (verse.audioUrl != null)
                  IconButton(
                    icon: Icon(
                      isCurrentlyPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: isCurrentlyPlaying ? AppColors.error : AppColors.emerald,
                    ),
                    onPressed: () => _playVerse(verse),
                    tooltip: isCurrentlyPlaying ? 'Arrêter' : 'Écouter',
                  ),
              ],
            ),
          ),

          // Texte arabe
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Text(
              verse.textUthmani,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTheme.getArabicTextStyle(fontSize: 26)
                  .copyWith(height: 2.0),
            ),
          ),

          // Traduction française
          if (verse.translationText != null)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.06),
                border: Border(
                  top: BorderSide(color: AppColors.textMuted.withOpacity(0.2)),
                ),
              ),
              child: Text(
                verse.translationText!,
                style: AppTheme.getFrenchTranslationStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ).copyWith(fontStyle: FontStyle.normal, height: 1.55),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _loadMore,
          icon: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.expand_more_rounded),
          label: const Text('Charger plus de versets'),
        ),
      ),
    );
  }

  void _showChapterInfo() {
    if (_meta == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LiquidGlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_meta!.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Nom arabe', _meta!.nameAr),
              _infoRow('Versets', '${_meta!.ayahCount}'),
              if (_meta!.revelationPlace != null)
                _infoRow('Révélation', _meta!.revelationPlace!),
              const Divider(height: 24, color: AppColors.glassBorder),
              const Text(
                'Texte & API : Quran Foundation / Quran.com (v4)\nTraduction : Muhammad Hamidullah',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer', style: TextStyle(color: AppColors.emerald)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label : ', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
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

// =============================================================================
// Widget bouton Play Sourate — avec animation spring
// =============================================================================

class _PlaySurahButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlaySurahButton({required this.isPlaying, required this.onPressed});

  @override
  State<_PlaySurahButton> createState() => _PlaySurahButtonState();
}

class _PlaySurahButtonState extends State<_PlaySurahButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.isPlaying) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PlaySurahButton old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isPlaying && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.isPlaying
                ? LinearGradient(colors: [
                    AppColors.copper.withOpacity(0.8 + 0.2 * _pulse.value),
                    AppColors.copperLight,
                  ])
                : const LinearGradient(colors: [AppColors.emerald, AppColors.emeraldLight]),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isPlaying ? 'Arrêter' : 'Play Sourate',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
