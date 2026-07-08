import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/study_time_block.dart';
import '../../mock/mock_ai_service.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

class AfterLectureScreen extends StatefulWidget {
  const AfterLectureScreen({super.key});

  @override
  State<AfterLectureScreen> createState() => _AfterLectureScreenState();
}

class _AfterLectureScreenState extends State<AfterLectureScreen> {
  static const ai = MockAiService();
  LectureConfidence confidence = LectureConfidence.mostly;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subject = state.subjects.firstOrNull;
    final materials = subject == null ? [] : state.materialsFor(subject.id);
    final previewBlocks = _blocksFor(confidence);

    return Scaffold(
      appBar: AppBar(
        title: const Text('After Lecture'),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
          Text(
            'Turn today\'s lecture into a study session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Start from pasted material and choose how confident you feel.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (subject == null) ...[
            const SectionCard(
              icon: Icons.folder_open_outlined,
              title: 'No subjects yet',
              subtitle:
                  'Create a subject before starting an after-lecture session.',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_outlined),
                title: Text('Subjects will appear here after sync.'),
              ),
            ),
          ] else ...[
            SectionCard(
              icon: Icons.article_outlined,
              title: 'Choose material',
              subtitle: 'Using the first subject for this scenario.',
              child: Column(
                children: [
                  if (materials.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.article_outlined),
                      title: Text('No materials yet'),
                      subtitle: Text(
                        'You can still create a subject-based session.',
                      ),
                    )
                  else
                    for (final material in materials)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.article_outlined),
                        title: Text(material.title),
                        subtitle: Text(
                          '${material.createdLabel} - pasted text',
                        ),
                        trailing: const Icon(Icons.check_circle_outline),
                      ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.post_add_outlined),
                    title: Text('Add pasted text from a subject page'),
                    subtitle: Text('Uploads and files come later.'),
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
                    LectureConfidence.understoodEverything,
                    LectureConfidence.mostly,
                    LectureConfidence.aboutHalf,
                    LectureConfidence.completelyLost,
                  ])
                    ChoiceChip(
                      label: Text(option.label),
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
                  for (final block in previewBlocks)
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
              onPressed: () {
                AppStateScope.read(context).createStudySession(
                  subject: subject,
                  confidence: confidence,
                  materialId: materials.firstOrNull?.id,
                );
                Navigator.pushNamed(
                  context,
                  AppRoutes.studySessionResult,
                  arguments: subject,
                );
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Create study session'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  List<StudyTimeBlock> _blocksFor(LectureConfidence confidence) {
    return switch (confidence) {
      LectureConfidence.understoodEverything => const [
        StudyTimeBlock(label: 'Summary', minutes: 3),
        StudyTimeBlock(label: 'Flashcards', minutes: 5),
        StudyTimeBlock(label: 'Quiz', minutes: 4),
      ],
      LectureConfidence.mostly => ai.studyTimeBlocks(),
      LectureConfidence.aboutHalf => const [
        StudyTimeBlock(label: 'Summary', minutes: 6),
        StudyTimeBlock(label: 'Flashcards', minutes: 14),
        StudyTimeBlock(label: 'Quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 8),
      ],
      LectureConfidence.completelyLost => const [
        StudyTimeBlock(label: 'Simple explanation', minutes: 10),
        StudyTimeBlock(label: 'Guided flashcards', minutes: 15),
        StudyTimeBlock(label: 'Quick quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 10),
      ],
    }.toList();
  }
}
