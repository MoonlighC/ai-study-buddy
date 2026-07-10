import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../auth/auth_controller.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final latestAttempt = state.latestQuizAttempt;
    final isSupabase =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Attempts completed'),
              trailing: Text('${state.quizAttempts.length}'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Focus topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Miss counts are cumulative quiz history, not a mastery score.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (state.isLoadingCumulativeWeakTopics)
            const Card(
              child: ListTile(
                leading: CircularProgressIndicator(strokeWidth: 2),
                title: Text('Loading focus topics'),
              ),
            )
          else if (state.weakTopicSyncErrorMessage != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(state.weakTopicSyncErrorMessage!),
                trailing: TextButton(
                  onPressed: () => state.loadCumulativeWeakTopicsFor(
                    AuthScope.read(context).user,
                  ),
                  child: const Text('Retry'),
                ),
              ),
            )
          else if (state.cumulativeWeakTopics.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text(
                  'Complete quizzes to discover topics that need more practice.',
                ),
              ),
            )
          else
            for (final topic in state.cumulativeWeakTopics)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(topic.topic),
                  subtitle: Text(_subjectName(state, topic.subjectId)),
                  trailing: Text(
                    topic.missCount == 1
                        ? '1 miss'
                        : '${topic.missCount} misses',
                  ),
                ),
              ),
          if (!isSupabase) ...[
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
            Text(
              'Study history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            const Card(
              child: ListTile(
                leading: Icon(Icons.local_fire_department_outlined),
                title: Text('Streak placeholder'),
                subtitle: Text('3 study days this week'),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  String _subjectName(AppState state, String subjectId) {
    for (final subject in state.subjects) {
      if (subject.id == subjectId) return subject.name;
    }
    return 'Subject unavailable';
  }
}
