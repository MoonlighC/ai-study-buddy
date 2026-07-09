import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/material.dart';
import '../../core/models/quiz.dart';
import '../../core/models/quiz_attempt.dart';
import '../../core/models/quiz_question.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';
import '../auth/auth_controller.dart';

class QuizTakingArgs {
  const QuizTakingArgs({
    required this.subject,
    required this.material,
    required this.quiz,
  });

  final Subject subject;
  final StudyMaterial material;
  final Quiz quiz;
}

class QuizTakingScreen extends StatefulWidget {
  const QuizTakingScreen({required this.args, super.key});

  final QuizTakingArgs args;

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final Map<String, String> _answers = {};
  int _index = 0;
  bool _isComplete = false;
  bool _isCompleting = false;
  DateTime _startedAt = DateTime.now().toUtc();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final questions = widget.args.quiz.questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const AppPage(
          children: [
            SectionCard(
              icon: Icons.quiz_outlined,
              title: 'Quiz',
              child: Text('No questions available.'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: AppPage(
        children: [
          Text(
            widget.args.quiz.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            widget.args.material.title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_isComplete)
            _ResultView(
              questions: questions,
              answers: _answers,
              attempt: state.latestQuizCompletion,
              isSaving: state.isSavingQuizAttempt || _isCompleting,
              warningMessage: state.quizAttemptSyncErrorMessage,
              onReviewMaterial: () => Navigator.pop(context),
              onRetry: _retry,
            )
          else
            _QuestionView(
              question: questions[_index],
              questionNumber: _index + 1,
              totalQuestions: questions.length,
              selectedAnswer: _answers[questions[_index].id],
              onAnswer: (answer) =>
                  setState(() => _answers[questions[_index].id] = answer),
              onNext: _answers[questions[_index].id] == null
                  ? null
                  : () {
                      if (_index == questions.length - 1) {
                        _completeQuiz();
                        return;
                      }
                      setState(() => _index += 1);
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _completeQuiz() async {
    if (_isCompleting) return;
    setState(() {
      _isComplete = true;
      _isCompleting = true;
    });
    final saved = await AppStateScope.read(context).completeQuizFor(
      AuthScope.read(context).user,
      quiz: widget.args.quiz,
      selectedAnswers: _answers,
      startedAt: _startedAt,
    );
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (!saved) {
      final message =
          AppStateScope.read(context).quizAttemptSyncErrorMessage ??
          'Could not save this quiz attempt.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _retry() {
    setState(() {
      _answers.clear();
      _index = 0;
      _isComplete = false;
      _isCompleting = false;
      _startedAt = DateTime.now().toUtc();
    });
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedAnswer,
    required this.onAnswer,
    required this.onNext,
  });

  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswer;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAnswer;
    final hasAnswer = selected != null;
    final isCorrect = selected == question.correctAnswer;

    return SectionCard(
      icon: Icons.quiz_outlined,
      title: '$questionNumber / $totalQuestions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: hasAnswer ? null : () => onAnswer(option),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_optionLabel(option)),
                ),
              ),
            ),
          if (hasAnswer) ...[
            const SizedBox(height: 4),
            Text(isCorrect ? 'Correct' : 'Incorrect'),
            const SizedBox(height: 4),
            Text(question.explanation),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onNext,
            child: Text(
              questionNumber == totalQuestions ? 'Show score' : 'Next',
            ),
          ),
        ],
      ),
    );
  }

  String _optionLabel(String option) {
    if (selectedAnswer == null) {
      return option;
    }
    if (option == question.correctAnswer) {
      return '$option - correct';
    }
    if (option == selectedAnswer) {
      return '$option - incorrect';
    }
    return option;
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.questions,
    required this.answers,
    required this.attempt,
    required this.isSaving,
    required this.warningMessage,
    required this.onReviewMaterial,
    required this.onRetry,
  });

  final List<QuizQuestion> questions;
  final Map<String, String> answers;
  final QuizAttempt? attempt;
  final bool isSaving;
  final String? warningMessage;
  final VoidCallback onReviewMaterial;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final result = attempt;
    final correctCount =
        result?.correctQuestions ??
        questions
            .where((question) => answers[question.id] == question.correctAnswer)
            .length;
    final percent =
        result?.score.round() ??
        ((correctCount / questions.length) * 100).round();
    final weakTopics = result?.weakTopicsSnapshot ?? _weakTopics();

    return SectionCard(
      icon: Icons.emoji_events_outlined,
      title: 'Result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Score: $percent%',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('$correctCount / ${questions.length} correct'),
          const SizedBox(height: 16),
          Text('Missed topics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (weakTopics.isEmpty)
            const Text('No missed topics. Great work!')
          else
            for (final topic in weakTopics)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  topic.missCount > 1
                      ? '${topic.topic} (${topic.missCount} misses)'
                      : topic.topic,
                ),
              ),
          if (isSaving) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            const Text('Saving quiz attempt…'),
          ],
          if (!isSaving && warningMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              warningMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onReviewMaterial,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Review material'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onRetry,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Retry quiz'),
          ),
        ],
      ),
    );
  }

  List<QuizWeakTopicSnapshot> _weakTopics() {
    final counts = <String, int>{};
    for (final question in questions) {
      if (answers[question.id] == question.correctAnswer) continue;
      final topic = question.topic.trim();
      if (topic.isEmpty) continue;
      counts.update(topic, (count) => count + 1, ifAbsent: () => 1);
    }
    return [
      for (final entry in counts.entries)
        QuizWeakTopicSnapshot(topic: entry.key, missCount: entry.value),
    ];
  }
}
