import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: const [AppTopActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          for (final topic in MockData.weakTopics)
            Card(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(topic.title),
                subtitle: Text(topic.reason),
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
