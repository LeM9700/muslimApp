import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/quiz_stats_service.dart';
import '../models/quiz_question.dart';
import '../models/quiz_stats.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/lottie_animations.dart';
import '../utils/hero_tags.dart';

/// Modes d'affichage de l'écran quiz
enum QuizScreenMode {
  dashboard, // Tableau de bord avec statistiques
  difficulty, // Sélection de difficulté
  loading, // Chargement des questions
  playing, // Quiz en cours
  results, // Résultats du quiz
}

/// Écran de quiz amélioré avec statistiques et niveaux de difficulté
/// Affiche dashboard, sélection de difficulté, et quiz interactif
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizStats? _stats;
  bool _isLoadingStats = true;

  // État du quiz
  List<QuizQuestion> _dailyQuestions = [];
  int _currentQuestionIndex = 0;
  QuizDifficulty? _selectedDifficulty;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  bool _showExplanation = false;
  int _currentScore = 0;
  int _correctAnswersCount = 0;
  bool _isLoadingQuestions = false;

  // Mode d'affichage
  QuizScreenMode _currentMode = QuizScreenMode.dashboard;

  // [Genjutsu] Feedback animation sur réponse soumise
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Charge les statistiques de l'utilisateur
  Future<void> _loadStats() async {
    try {
      final stats = await QuizStatsService.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  /// Démarre un nouveau quiz avec la difficulté sélectionnée
  Future<void> _startQuiz(QuizDifficulty difficulty) async {
    setState(() {
      _selectedDifficulty = difficulty;
      _isLoadingQuestions = true;
      _currentMode = QuizScreenMode.loading;
    });

    try {
      // Charger 5 questions filtrées par difficulté
      final questions = await FirebaseService.getMultipleQuestions(
        5,
        difficulty: difficulty.dataKey,
      );

      if (mounted) {
        if (questions.isNotEmpty) {
          setState(() {
            _dailyQuestions = questions;
            _currentQuestionIndex = 0;
            _currentScore = 0;
            _correctAnswersCount = 0;
            _selectedOptionIndex = null;
            _hasAnswered = false;
            _showExplanation = false;
            _isLoadingQuestions = false;
            _currentMode = QuizScreenMode.playing;
          });
        } else {
          setState(() {
            _isLoadingQuestions = false;
            _currentMode = QuizScreenMode.dashboard;
          });
          _showError('Aucune question disponible');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuestions = false;
          _currentMode = QuizScreenMode.dashboard;
        });
        _showError('Erreur de chargement: $e');
      }
    }
  }

  /// Sélectionne une réponse
  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    setState(() {
      _selectedOptionIndex = index;
    });
  }

  /// Valide la réponse et affiche l'explication
  void _submitAnswer() {
    if (_selectedOptionIndex == null || _hasAnswered) return;

    final question = _dailyQuestions[_currentQuestionIndex];
    final isCorrect = question.isCorrectAnswer(_selectedOptionIndex!);

    if (isCorrect) {
      _correctAnswersCount++;
      _currentScore += _selectedDifficulty!.pointMultiplier;
    }

    setState(() {
      _hasAnswered = true;
      _showExplanation = true;
      _showFeedback = true;
      _lastAnswerCorrect = isCorrect;
    });
  }

  /// Passe à la question suivante ou termine le quiz
  void _nextQuestion() {
    if (_currentQuestionIndex < _dailyQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _hasAnswered = false;
        _showExplanation = false;
      });
    } else {
      _finishQuiz();
    }
  }

  /// Termine le quiz et sauvegarde les résultats
  Future<void> _finishQuiz() async {
    try {
      // Mettre à jour les statistiques
      final updatedStats = await QuizStatsService.updateAfterQuiz(
        difficulty: _selectedDifficulty!.key,
        score: _currentScore,
        totalQuestions: _dailyQuestions.length,
        correctAnswers: _correctAnswersCount,
      );

      setState(() {
        _stats = updatedStats;
        _currentMode = QuizScreenMode.results;
      });
    } catch (e) {
      _showError('Erreur sauvegarde: $e');
    }
  }

  /// Retourne au dashboard
  void _backToDashboard() {
    setState(() {
      _currentMode = QuizScreenMode.dashboard;
      _dailyQuestions.clear();
      _currentQuestionIndex = 0;
      _selectedDifficulty = null;
      _currentScore = 0;
      _correctAnswersCount = 0;
    });
  }

  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            // [Genjutsu] Overlay feedback bonne/mauvaise réponse
            if (_showFeedback)
              _QuizFeedbackOverlay(
                isCorrect: _lastAnswerCorrect,
                onComplete: () => setState(() => _showFeedback = false),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit l'AppBar selon le mode actuel
  PreferredSizeWidget _buildAppBar() {
    String title;
    List<Widget> actions = [];

    switch (_currentMode) {
      case QuizScreenMode.dashboard:
        title = 'Quiz Islamique';
        actions = [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Actualiser',
          ),
        ];
        break;
      case QuizScreenMode.difficulty:
        title = 'Choisir la difficulté';
        break;
      case QuizScreenMode.loading:
        title = 'Chargement...';
        break;
      case QuizScreenMode.playing:
        title =
            'Question ${_currentQuestionIndex + 1}/${_dailyQuestions.length}';
        actions = [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _backToDashboard,
            tooltip: 'Abandonner',
          ),
        ];
        break;
      case QuizScreenMode.results:
        title = 'Résultats';
        break;
    }

    return AppBar(
      title: Text(title),
      actions: actions,
      automaticallyImplyLeading: _currentMode != QuizScreenMode.dashboard,
      leading: _currentMode != QuizScreenMode.dashboard
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _backToDashboard,
            )
          : null,
    );
  }

  /// Construit le corps selon le mode actuel
  Widget _buildBody() {
    switch (_currentMode) {
      case QuizScreenMode.dashboard:
        return _buildDashboard();
      case QuizScreenMode.difficulty:
        return _buildDifficultySelection();
      case QuizScreenMode.loading:
        return _buildLoadingScreen();
      case QuizScreenMode.playing:
        return _buildQuizScreen();
      case QuizScreenMode.results:
        return _buildResultsScreen();
    }
  }

  /// Construit le tableau de bord avec statistiques
  Widget _buildDashboard() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats!;
    final canQuiz = stats.canDoQuizToday;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Titre de bienvenue
          Text(
            canQuiz
                ? 'Quiz du jour disponible !'
                : 'Quiz déjà terminé aujourd\'hui',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: canQuiz ? AppColors.emerald : AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 24),

          // Statistiques principales
          _buildMainStatsCard(stats),

          const SizedBox(height: 16),

          // Progression et rang
          _buildProgressCard(stats),

          const SizedBox(height: 16),

          // Bouton principal
          if (canQuiz) ...[
            _buildStartQuizButton(),
            const SizedBox(height: 16),
          ],

          // Statistiques détaillées
          _buildDetailedStats(stats),
        ],
      ),
    );
  }

  /// Construit la card des statistiques principales
  Widget _buildMainStatsCard(QuizStats stats) {
    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Hero(
                  tag: HeroTags.quizIcon,
                  child: const Icon(Icons.quiz_outlined,
                      color: AppColors.emerald, size: 28),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.emoji_events,
                    color: AppColors.warning, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Vos Statistiques',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Quiz terminés',
                    '${stats.totalQuizzesCompleted}',
                    Icons.quiz_outlined,
                    AppColors.emerald,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Points totaux',
                    '${stats.totalPoints}',
                    Icons.stars_rounded,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Moyenne/quiz',
                    '${stats.averageScore.toStringAsFixed(1)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Précision',
                    '${stats.accuracyPercentage.toStringAsFixed(1)}%',
                    Icons.my_location,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construit un élément de statistique
  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Construit la card de progression
  Widget _buildProgressCard(QuizStats stats) {
    final rank = QuizStatsService.getRank(stats.totalPoints);
    final nextRank = QuizStatsService.getNextRank(stats.totalPoints);
    final pointsToNext =
        QuizStatsService.getPointsToNextRank(stats.totalPoints);

    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Rang: $rank',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (pointsToNext > 0) ...[
              const SizedBox(height: 16),
              Text(
                '$pointsToNext points pour devenir $nextRank',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pointsToNext > 0
                    ? 1 - (pointsToNext / (pointsToNext + 50))
                    : 1,
                backgroundColor: AppColors.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ],
            if (stats.currentStreak > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Série actuelle: ${stats.currentStreak} jour(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit le bouton pour commencer le quiz
  Widget _buildStartQuizButton() {
    return Container(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentMode = QuizScreenMode.difficulty;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 28),
            const SizedBox(width: 12),
            Text(
              'Commencer le Quiz du Jour',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit les statistiques détaillées
  Widget _buildDetailedStats(QuizStats stats) {
    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Statistiques par Difficulté',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...QuizDifficulty.values.map((difficulty) {
              final points = stats.difficultyStats[difficulty.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(difficulty.icon, color: difficulty.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        difficulty.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '$points pts',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: difficulty.color,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Construit l'écran de sélection de difficulté
  Widget _buildDifficultySelection() {
    final suggestedDifficulty = QuizDifficultyExtension.fromString(
        _stats?.suggestedDifficulty ?? 'novice');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Choisissez votre niveau',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Difficulté suggérée: ${suggestedDifficulty.label}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          ...QuizDifficulty.values.map((difficulty) {
            final isRecommended = difficulty == suggestedDifficulty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LiquidGlassCard(
                child: InkWell(
                  onTap: () => _startQuiz(difficulty),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          difficulty.icon,
                          color: difficulty.color,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    difficulty.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (isRecommended) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.green, width: 1),
                                      ),
                                      child: Text(
                                        'Recommandé',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                difficulty.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${difficulty.pointMultiplier} point${difficulty.pointMultiplier > 1 ? 's' : ''} par bonne réponse',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: difficulty.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Construit l'écran de chargement
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Préparation des questions...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Niveau: ${_selectedDifficulty?.label}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _selectedDifficulty?.color,
                ),
          ),
        ],
      ),
    );
  }

  /// Construit l'écran de quiz en cours
  Widget _buildQuizScreen() {
    if (_dailyQuestions.isEmpty) return const SizedBox();

    final question = _dailyQuestions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _dailyQuestions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Barre de progression
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Difficulté: ${_selectedDifficulty!.label}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _selectedDifficulty!.color,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    'Score: $_currentScore pts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.glassBorder,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_selectedDifficulty!.color),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Question
          LiquidGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question ${_currentQuestionIndex + 1}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.question,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Options de réponse
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return _buildAnswerOption(index, option, question);
          }),

          const SizedBox(height: 24),

          // Bouton de validation
          if (!_hasAnswered && _selectedOptionIndex != null)
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDifficulty!.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Valider ma réponse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Résultat et explication
          if (_showExplanation) ...[
            const SizedBox(height: 24),
            _buildExplanationCard(question),
          ],

          // Bouton question suivante
          if (_hasAnswered) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < _dailyQuestions.length - 1
                      ? 'Question suivante'
                      : 'Terminer le quiz',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Construit une option de réponse
  Widget _buildAnswerOption(int index, String option, QuizQuestion question) {
    final isSelected = _selectedOptionIndex == index;
    final isCorrect = _hasAnswered && index == question.answerIndex;
    final isWrong = _hasAnswered && isSelected && !isCorrect;

    Color? borderColor;
    Color? backgroundColor;

    if (_hasAnswered) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
      } else if (isWrong) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
      }
    } else if (isSelected) {
      borderColor = _selectedDifficulty!.color;
      backgroundColor = _selectedDifficulty!.color.withOpacity(0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlassCard(
        child: InkWell(
          onTap: () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(12),
              color: backgroundColor,
            ),
            child: Row(
              children: [
                // Indicateur de sélection/résultat
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor ?? AppColors.glassBorder,
                      width: 2,
                    ),
                    color: isSelected || isCorrect
                        ? (borderColor ?? _selectedDifficulty!.color)
                        : null,
                  ),
                  child: (isSelected || isCorrect)
                      ? Icon(
                          isCorrect ? Icons.check : Icons.circle,
                          size: 16,
                          color: AppColors.textPrimary,
                        )
                      : null,
                ),

                const SizedBox(width: 16),

                // Texte de l'option
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      color: isWrong ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construit la card d'explication
  Widget _buildExplanationCard(QuizQuestion question) {
    final isCorrect = _selectedOptionIndex == question.answerIndex;

    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résultat
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect ? 'Bonne réponse !' : 'Réponse incorrecte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isCorrect
                        ? '+${_selectedDifficulty!.pointMultiplier} pts'
                        : '+0 pts',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (!isCorrect) ...[
              const SizedBox(height: 12),
              Text(
                'La bonne réponse était : ${question.correctAnswer}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Explication
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Explication :',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                question.explanation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit l'écran de résultats
  Widget _buildResultsScreen() {
    final accuracy = (_correctAnswersCount / _dailyQuestions.length) * 100;
    final isGoodScore = accuracy >= 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Icône de résultat
          Icon(
            isGoodScore ? Icons.emoji_events : Icons.sentiment_satisfied,
            size: 80,
            color: isGoodScore ? AppColors.warning : AppColors.emerald,
          ),

          const SizedBox(height: 24),

          // Titre de félicitations
          Text(
            isGoodScore ? 'Excellent travail !' : 'Bon effort !',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isGoodScore ? AppColors.warning : AppColors.emerald,
                ),
          ),

          const SizedBox(height: 32),

          // Résultats principaux
          LiquidGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Résultats du Quiz',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultItem(
                          'Score',
                          '$_currentScore',
                          Icons.stars,
                          AppColors.warning,
                        ),
                      ),
                      Expanded(
                        child: _buildResultItem(
                          'Bonnes réponses',
                          '$_correctAnswersCount/${_dailyQuestions.length}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultItem(
                          'Précision',
                          '${accuracy.toStringAsFixed(1)}%',
                          Icons.my_location,
                          Colors.purple,
                        ),
                      ),
                      Expanded(
                        child: _buildResultItem(
                          'Difficulté',
                          _selectedDifficulty!.label,
                          _selectedDifficulty!.icon,
                          _selectedDifficulty!.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Message d'encouragement
          LiquidGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    _getEncouragementMessage(accuracy),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Bouton retour
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _backToDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Retour au tableau de bord',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un élément de résultat
  Widget _buildResultItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Obtient un message d'encouragement selon le score
  String _getEncouragementMessage(double accuracy) {
    if (accuracy >= 90) {
      return 'Parfait ! Vous maîtrisez parfaitement le sujet. Essayez un niveau plus difficile demain !';
    } else if (accuracy >= 80) {
      return 'Très bien ! Vous avez une excellente compréhension. Continuez sur cette lancée !';
    } else if (accuracy >= 60) {
      return 'Bon travail ! Vous progressez bien. Quelques révisions et vous serez au top !';
    } else if (accuracy >= 40) {
      return 'C\'est un début ! Ne vous découragez pas, la persévérance est la clé du succès.';
    } else {
      return 'Ne vous inquiétez pas ! Chaque quiz est une opportunité d\'apprendre. Revenez demain !';
    }
  }
}

// =============================================================================
// [Genjutsu] _QuizFeedbackOverlay — moment-pivot : bonne ou mauvaise réponse
// Animation : scale bounce + glow + fade out en 900ms
// =============================================================================

class _QuizFeedbackOverlay extends StatefulWidget {
  final bool isCorrect;
  final VoidCallback onComplete;

  const _QuizFeedbackOverlay(
      {required this.isCorrect, required this.onComplete});

  @override
  State<_QuizFeedbackOverlay> createState() => _QuizFeedbackOverlayState();
}

class _QuizFeedbackOverlayState extends State<_QuizFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Scale : 0 → 1.25 → 1.0 → 0
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.25)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.25, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
    ]).animate(_ctrl);

    // Opacity : visible → fade out au dernier tiers
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.72, 1.0)),
    );

    // Glow pulse
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)),
    );

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isCorrect ? AppColors.emerald : AppColors.error;
    final icon = widget.isCorrect ? Icons.check_rounded : Icons.close_rounded;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // ── Lottie burst (bonne réponse uniquement) ───────────────────────
            if (widget.isCorrect) const Center(child: QuizCorrectBurst()),

            // ── Scale bounce + glow existant ──────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Opacity(
                opacity: _opacity.value,
                child: Center(
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.12),
                        border: Border.all(color: color, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.35 * _glow.value),
                            blurRadius: 30 * _glow.value,
                            spreadRadius: 6 * _glow.value,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 60),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
