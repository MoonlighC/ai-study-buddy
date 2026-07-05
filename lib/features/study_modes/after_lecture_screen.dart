import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/study_time_block.dart';
import '../../mock/mock_ai_service.dart';
import '../../mock/mock_data.dart';

class AfterLectureScreen extends StatefulWidget {
  const AfterLectureScreen({super.key});

  @override
  State<AfterLectureScreen> createState() => _AfterLectureScreenState();
}

class _AfterLectureScreenState extends State<AfterLectureScreen> {
  static const ai = MockAiService();
  String confidence = 'Mostly';

  @override
  Widget build(BuildContext context) {
    final subject = MockData.subjects.first;
    final materials = MockData.materials
        .where((material) => material.subjectId == subject.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('After Lecture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Turn today\'s lecture into a study session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Choose material',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final material in materials)
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(material.title),
                subtitle: Text('${material.createdLabel} - pasted text'),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.upload_file_outlined),
              title: Text('Paste or upload material placeholder'),
              subtitle: Text('Mock only: no file upload is performed.'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How confident do you feel?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in [
                'I understood everything',
                'Mostly',
                'About half',
                'I am completely lost',
              ])
                ChoiceChip(
                  label: Text(option),
                  selected: confidence == option,
                  onSelected: (_) => setState(() => confidence = option),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _TimeEstimate(blocks: ai.studyTimeBlocks()),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.studySessionResult,
              arguments: subject,
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Create study session'),
          ),
        ],
      ),
    );
  }
}

class _TimeEstimate extends StatelessWidget {
  const _TimeEstimate({required this.blocks});

  final List<StudyTimeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estimated study time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final block in blocks)
              Text('${block.label}: ${block.minutes} min'),
          ],
        ),
      ),
    );
  }
}
