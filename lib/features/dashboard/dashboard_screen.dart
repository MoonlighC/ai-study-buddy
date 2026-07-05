import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../mock/mock_data.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scores = MockData.knowledgeScores;
    final history = MockData.studyHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Buddy'),
        actions: [
          IconButton(
            tooltip: 'Favorites',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(
            tooltip: 'Usage limits',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.usage),
            icon: const Icon(Icons.speed_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hi there', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'What do you want to do today?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _ScenarioCard(
            icon: Icons.auto_stories_outlined,
            title: 'After Lecture',
            subtitle: 'Check understanding from notes you just studied.',
            route: AppRoutes.afterLecture,
          ),
          _ScenarioCard(
            icon: Icons.event_available_outlined,
            title: 'Prepare for Exam',
            subtitle: 'Build a mock plan from a subject and exam date.',
            route: AppRoutes.examPrep,
          ),
          _ScenarioCard(
            icon: Icons.play_circle_outline,
            title: 'Continue Studying',
            subtitle: 'Resume today\'s session, flashcards, and weak topics.',
            route: AppRoutes.continueStudying,
          ),
          _ScenarioCard(
            icon: Icons.folder_outlined,
            title: 'Subjects',
            subtitle: 'Open folders, materials, and Phase 1 study tools.',
            route: AppRoutes.subjects,
          ),
          _ScenarioCard(
            icon: Icons.trending_up_outlined,
            title: 'Progress',
            subtitle: 'Review knowledge scores, history, and streaks.',
            route: AppRoutes.progress,
          ),
          const SizedBox(height: 12),
          Text(
            'Knowledge score summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final score in scores)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(score.subjectName),
              subtitle: LinearProgressIndicator(
                value: score.scorePercent / 100,
              ),
              trailing: Text('${score.scorePercent}%'),
            ),
          const SizedBox(height: 16),
          Text(
            'Recent study sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final entry in history)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text('${entry.label}: ${entry.subjectName}'),
                subtitle: Text(
                  '${entry.activitySummary}, quiz ${entry.quizScorePercent}%',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
