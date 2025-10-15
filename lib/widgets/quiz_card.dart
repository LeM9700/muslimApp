import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/quiz_question.dart';
import '../routes/app_routes.dart';

/// Widget pour afficher un aperçu du quiz du jour
/// Charge une question depuis Firestore et permet d'aller vers l'écran complet
class QuizCard extends StatefulWidget {
  const QuizCard({super.key});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  QuizQuestion? _currentQuestion;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDailyQuestion();
  }

  /// Charge la question du jour depuis Firestore
  /// Affiche un état de chargement puis la question ou une erreur
  Future<void> _loadDailyQuestion() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final question = await FirebaseService.getRandomQuizQuestion();
      
      if (mounted) {
        setState(() {
          _currentQuestion = question;
          _isLoading = false;
          if (question == null) {
            _errorMessage = 'Aucune question disponible';
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
    return Card(
      child: InkWell(
        onTap: _currentQuestion != null ? () {
          Navigator.pushNamed(context, AppRoutes.quiz);
        } : null,
        borderRadius: BorderRadius.circular(12),
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
                        Icons.quiz_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quiz du jour',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadDailyQuestion,
                      tooltip: 'Actualiser',
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Contenu du quiz
              _buildQuizContent(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit le contenu du quiz selon l'état actuel
  /// Gère les états: chargement, erreur, question affichée
  Widget _buildQuizContent() {
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

    if (_currentQuestion == null) {
      return _buildEmptyState();
    }

    return _buildQuestionPreview();
  }

  /// Affiche l'état d'erreur avec possibilité de réessayer
  /// Bouton retry pour recharger la question
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
          onPressed: _loadDailyQuestion,
          child: const Text('Réessayer'),
        ),
      ],
    );
  }

  /// Affiche l'état vide quand aucune question n'est disponible
  /// Message informatif avec suggestion
  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.quiz,
          size: 48,
          color: Colors.white30,
        ),
        const SizedBox(height: 16),
        Text(
          'Aucune question disponible pour aujourd\'hui',
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

  /// Affiche un aperçu de la question avec CTA
  /// Montre la question tronquée et invite à cliquer pour le quiz complet
  Widget _buildQuestionPreview() {
    final question = _currentQuestion!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question tronquée
        Text(
          _truncateQuestion(question.question),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 16),
        
        // Indicateur nombre d'options
        Row(
          children: [
            Icon(
              Icons.format_list_bulleted,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              '${question.options.length} réponses possibles',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Bouton CTA
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.quiz);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Commencer le quiz'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tronque la question si elle est trop longue
  /// Limite à 100 caractères pour l'aperçu
  String _truncateQuestion(String question) {
    const maxLength = 100;
    if (question.length <= maxLength) {
      return question;
    }
    
    return '${question.substring(0, maxLength)}...';
  }
}