import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final latestAttempt = state.latestQuizAttempt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: const [AppTopActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Latest quiz', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (state.isLoadingQuizAttempts)
            const Card(
              child: ListTile(
                leading: CircularProgressIndicator(strokeWidth: 2),
                title: Text('Loading quiz results'),
              ),
            )
          else if (latestAttempt == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.quiz_outlined),
                title: Text('Complete a quiz to see results here.'),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text('Score: ${latestAttempt.score.round()}%'),
                subtitle: Text(
                  '${latestAttempt.correctQuestions} / ${latestAttempt.totalQuestions} correct',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Knowledge scores',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final score in MockData.knowledgeScores)
            Card(
              child: ListTile(
                title: Text(score.subjectName),
                subtitle: LinearProgressIndicator(
                  value: score.scorePercent / 100,
                ),
                trailing: Text('${score.scorePercent}%'),
              ),
            ),
          const SizedBox(height: 16),
          Text('Study history', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final entry in MockData.studyHistory)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text('${entry.label}: ${entry.subjectName}'),
                subtitle: Text(
                  '${entry.activitySummary}, quiz ${entry.quizScorePercent}%',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Weak topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (latestAttempt == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text('No quiz weak topics yet'),
                subtitle: Text('Missed quiz topics will appear here.'),
              ),
            )
          else if (latestAttempt.weakTopicsSnapshot.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('No missed topics in your latest quiz'),
              ),
            )
          else
            for (final topic in latestAttempt.weakTopicsSnapshot)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(topic.topic),
                  subtitle: Text(
                    topic.missCount == 1
                        ? 'Missed once in the latest quiz'
                        : 'Missed ${topic.missCount} times in the latest quiz',
                  ),
                ),
              ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.local_fire_department_outlined),
              title: Text('Streak placeholder'),
              subtitle: Text('3 study days this week'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
