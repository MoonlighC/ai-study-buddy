import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../mock/mock_ai_service.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

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
      body: AppPage(
        children: [
          Text(
            'Turn today\'s lecture into a study session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Start from local mock material and choose how confident you feel.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.article_outlined,
            title: 'Choose material',
            subtitle: 'Using the first mock subject for this scenario.',
            child: Column(
              children: [
                for (final material in materials)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(material.title),
                    subtitle: Text('${material.createdLabel} - pasted text'),
                    trailing: const Icon(Icons.check_circle_outline),
                  ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Paste or upload material placeholder'),
                  subtitle: Text('Mock only: no file upload is performed.'),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.sentiment_satisfied_outlined,
            title: 'How confident do you feel?',
            child: Wrap(
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
          ),
          SectionCard(
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
