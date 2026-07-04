import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../mock/mock_data.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subjects = MockData.subjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Workspace'),
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
          Text('Subjects', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create folders for lecture notes, summaries, quizzes, and exam prep.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final subject in subjects)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(subject.colorValue),
                  child: Text(
                    subject.name.characters.first,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(subject.name),
                subtitle: Text(subject.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.subjectDetail,
                  arguments: subject,
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create subject placeholder'),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ModeButton(
                icon: Icons.auto_stories_outlined,
                label: 'After Lecture',
                route: AppRoutes.afterLecture,
              ),
              _ModeButton(
                icon: Icons.event_available_outlined,
                label: 'Exam Prep',
                route: AppRoutes.examPrep,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
