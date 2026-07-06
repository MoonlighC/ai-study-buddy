import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

class StudySessionResultScreen extends StatelessWidget {
  const StudySessionResultScreen({required this.subject, super.key});

  final Subject subject;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final latest = state.latestStudySession;
    final session = latest != null && latest.subjectId == subject.id
        ? latest
        : null;
    final quizScore = session?.quizScorePercent ?? ai.quizScoreFor(subject);
    final weakTopics = session?.weakTopics ?? ai.weakTopicsFor(subject);
    final flashcards = session?.flashcards ?? state.flashcardsFor(subject.id);
    final timeBlocks = session?.studyTimeBlocks ?? ai.studyTimeBlocks();
    final quiz = session?.quizQuestion ?? ai.quizFor(subject).first;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Session')),
      body: AppPage(
        children: [
          Text(subject.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Mock study session generated from your material.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.quiz_outlined,
                  label: 'Quiz score',
                  value: '$quizScore%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.schedule_outlined,
                  label: 'Study time',
                  value:
                      '${timeBlocks.fold<int>(0, (total, block) => total + block.minutes)} min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.summarize_outlined,
            title: 'Summary',
            child: Text(session?.summary ?? ai.summaryFor(subject)),
          ),
          SectionCard(
            icon: Icons.schedule_outlined,
            title: 'Estimated study time',
            child: Column(
              children: [
                for (final block in timeBlocks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(block.label),
                    trailing: Text('${block.minutes} min'),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.style_outlined,
            title: 'Flashcards',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final card in flashcards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${card.front} Topic: ${card.topic}'),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.quiz_outlined,
            title: 'Quick quiz',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.question),
                const SizedBox(height: 8),
                for (final option in quiz.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      onPressed: session == null
                          ? null
                          : () => state.answerQuiz(
                              sessionId: session.id,
                              answer: option,
                            ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_answerLabel(session, option)),
                      ),
                    ),
                  ),
                Text(
                  session?.feedback ??
                      'Quiz score: $quizScore%. Choose an answer to update this local session.',
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.warning_amber_outlined,
            title: 'Weak topics',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final topic in weakTopics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${topic.title}: ${topic.reason}'),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.lightbulb_outline,
            title: 'Mistake explanation',
            child: Text(ai.mistakeExplanationFor(subject)),
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Review weak topics'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.flashcards,
              arguments: subject,
            ),
            icon: const Icon(Icons.style_outlined),
            label: const Text('Generate more flashcards'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.aiTeacher,
              arguments: subject,
            ),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('Ask AI Teacher'),
          ),
        ],
      ),
    );
  }

  String _answerLabel(StudySession? session, String option) {
    if (session?.selectedAnswer != option) {
      return option;
    }
    final isCorrect = session?.answeredCorrectly == true;
    return isCorrect ? '$option - correct' : '$option - incorrect';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
