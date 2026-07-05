import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';

class StudySessionResultScreen extends StatelessWidget {
  const StudySessionResultScreen({required this.subject, super.key});

  final Subject subject;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    final quizScore = ai.quizScoreFor(subject);
    final weakTopics = ai.weakTopicsFor(subject);
    final flashcards = ai.flashcardsFor(subject);

    return Scaffold(
      appBar: AppBar(title: const Text('Study Session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(subject.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _SessionSection(
            icon: Icons.summarize_outlined,
            title: 'Summary',
            child: Text(ai.summaryFor(subject)),
          ),
          _SessionSection(
            icon: Icons.schedule_outlined,
            title: 'Estimated study time',
            child: Column(
              children: [
                for (final block in ai.studyTimeBlocks())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(block.label),
                    trailing: Text('${block.minutes} min'),
                  ),
              ],
            ),
          ),
          _SessionSection(
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
          _SessionSection(
            icon: Icons.quiz_outlined,
            title: 'Quick quiz',
            child: Text('Quiz score: $quizScore%'),
          ),
          _SessionSection(
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
          _SessionSection(
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
}

class _SessionSection extends StatelessWidget {
  const _SessionSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
