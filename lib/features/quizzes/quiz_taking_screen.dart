import 'package:flutter/material.dart';

import '../../core/models/material.dart';
import '../../core/models/quiz.dart';
import '../../core/models/quiz_question.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

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

  @override
  Widget build(BuildContext context) {
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
              onReview: () => setState(() {
                _index = 0;
                _isComplete = false;
              }),
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
                  : () => setState(() {
                      if (_index == questions.length - 1) {
                        _isComplete = true;
                      } else {
                        _index += 1;
                      }
                    }),
            ),
        ],
      ),
    );
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
    required this.onReview,
  });

  final List<QuizQuestion> questions;
  final Map<String, String> answers;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final correctCount = questions
        .where((question) => answers[question.id] == question.correctAnswer)
        .length;
    final percent = ((correctCount / questions.length) * 100).round();

    return SectionCard(
      icon: Icons.emoji_events_outlined,
      title: 'Result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$correctCount / ${questions.length} correct',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('Score: $percent%'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Review answers'),
          ),
        ],
      ),
    );
  }
}
