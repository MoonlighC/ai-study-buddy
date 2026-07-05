import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

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
      body: AppPage(
        children: [
          _HomeHeader(sessionCount: history.length),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.bolt_outlined,
            title: 'What do you want to do today?',
            subtitle: 'Pick a mock study flow and keep moving.',
            child: Column(
              children: [
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
                  subtitle:
                      'Resume today\'s session, flashcards, and weak topics.',
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
              ],
            ),
          ),
          SectionCard(
            icon: Icons.insights_outlined,
            title: 'Knowledge score summary',
            subtitle: 'Your strongest and weakest mock subjects.',
            child: Column(
              children: [
                for (final score in scores)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScoreRow(
                      label: score.subjectName,
                      percent: score.scorePercent,
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.history_outlined,
            title: 'Recent study sessions',
            subtitle: 'Local mock activity from your study history.',
            child: Column(
              children: [
                for (final entry in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('${entry.label}: ${entry.subjectName}'),
                    subtitle: Text(
                      '${entry.activitySummary}, quiz ${entry.quizScorePercent}%',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.sessionCount});

  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi there',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: colorScheme.onPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your coach has a study path ready for today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(label: '$sessionCount recent sessions'),
                const _StatusPill(label: 'Mock-only data'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colorScheme.onPrimary),
        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE1E5EA)),
        ),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$percent%', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percent / 100),
      ],
    );
  }
}
