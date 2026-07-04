import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';

class GeneratedOutputsScreen extends StatelessWidget {
  const GeneratedOutputsScreen({required this.subject, super.key});

  final Subject subject;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    final quiz = ai.quizFor(subject);
    final plan = ai.examPlanFor(subject);

    return Scaffold(
      appBar: AppBar(title: const Text('Mock AI outputs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(subject.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _OutputSection(
            icon: Icons.summarize_outlined,
            title: 'Summary',
            child: Text(ai.summaryFor(subject)),
          ),
          _OutputSection(
            icon: Icons.style_outlined,
            title: 'Flashcards',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose generation count'),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: Text('5'), selected: true),
                    ChoiceChip(label: Text('10'), selected: false),
                    ChoiceChip(label: Text('20'), selected: false),
                    ChoiceChip(label: Text('Custom'), selected: false),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.flashcards,
                    arguments: subject,
                  ),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Open flashcards'),
                ),
              ],
            ),
          ),
          _OutputSection(
            icon: Icons.quiz_outlined,
            title: 'Quick quiz',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.first.question),
                const SizedBox(height: 8),
                for (final option in quiz.first.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      onPressed: () {},
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(option),
                      ),
                    ),
                  ),
                Text('Explain mistake: ${quiz.first.explanation}'),
              ],
            ),
          ),
          _OutputSection(
            icon: Icons.calendar_month_outlined,
            title: 'Exam preparation plan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final item in plan) Text(item)],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({
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
