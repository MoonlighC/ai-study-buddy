import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';

class ContinueStudyingScreen extends StatelessWidget {
  const ContinueStudyingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final latest = state.latestStudySession;
    final weakTopics =
        latest?.weakTopics ?? state.weakTopicsFor(state.subjects.first.id);
    final dueFlashcards = state.dueFlashcards;
    final subject = latest == null
        ? state.subjects.first
        : state.subjects.firstWhere(
            (item) => item.id == latest.subjectId,
            orElse: () => state.subjects.first,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Continue Studying'),
        actions: const [AppTopActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Today\'s recommended session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: Text('${subject.name} review'),
              subtitle: Text(
                latest?.summary ??
                    'Read the summary, study flashcards, then retake the quick quiz.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('Due flashcards'),
              subtitle: Text(
                '${dueFlashcards.length} ${subject.name} cards are ready for review.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Last quiz score'),
              subtitle: Text(
                latest?.quizScorePercent == null
                    ? '${subject.name} quick quiz: not answered yet'
                    : '${subject.name} quick quiz: ${latest!.quizScorePercent}%',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Weak topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final topic in weakTopics)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(topic.title),
                subtitle: Text(topic.reason),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
