import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/study_session.dart';
import '../../core/models/study_time_block.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';

class AfterLectureScreen extends StatefulWidget {
  const AfterLectureScreen({super.key});
  @override
  State<AfterLectureScreen> createState() => _AfterLectureScreenState();
}

class _AfterLectureScreenState extends State<AfterLectureScreen> {
  static const ai = MockAiService();
  LectureConfidence confidence = LectureConfidence.mostly;
  Subject? selectedSubject;
  StudyMaterial? selectedMaterial;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;
    final subject =
        selectedSubject != null &&
            subjects.any((s) => s.id == selectedSubject!.id)
        ? selectedSubject
        : null;
    final materials = subject == null
        ? <StudyMaterial>[]
        : state.materialsFor(subject.id);
    final material =
        selectedMaterial != null &&
            materials.any((m) => m.id == selectedMaterial!.id)
        ? selectedMaterial
        : null;
    return ResponsiveAppScaffold(
      title: 'After Lecture',
      showBack: true,
      showNavigation: false,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            const GlassStatusChip(
              label: 'Local prototype guidance',
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 12),
            if (subjects.isEmpty)
              EmptyState(
                title: 'No subjects yet',
                message:
                    'Create a subject before starting an after-lecture session.',
                icon: Icons.folder_open_outlined,
                action: FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.subjects),
                  child: const Text('Open Subjects'),
                ),
              )
            else ...[
              StudyModeCard(
                title: 'Choose a subject',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in subjects)
                      ChoiceChip(
                        label: Text(item.name),
                        selected: subject?.id == item.id,
                        onSelected: (_) => setState(() {
                          selectedSubject = item;
                          selectedMaterial = null;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (subject == null)
                const GlassCard(
                  child: EmptyState(
                    title: 'Select a subject',
                    message: 'Choose the lecture subject to continue.',
                    icon: Icons.touch_app_outlined,
                  ),
                )
              else if (materials.isEmpty)
                const GlassCard(
                  child: EmptyState(
                    title: 'No materials available',
                    message:
                        'Add a usable material before creating this study session.',
                    icon: Icons.article_outlined,
                  ),
                )
              else
                StudyModeCard(
                  title: 'Choose material',
                  child: Column(
                    children: [
                      for (final item in materials)
                        ListTile(
                          leading: Icon(
                            material?.id == item.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(item.title),
                          subtitle: Text(item.createdLabel),
                          selected: material?.id == item.id,
                          onTap: () => setState(() => selectedMaterial = item),
                        ),
                    ],
                  ),
                ),
              if (material != null) ...[
                const SizedBox(height: 12),
                StudyModeCard(
                  title: 'How confident do you feel?',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in LectureConfidence.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: confidence == option,
                          onSelected: (_) =>
                              setState(() => confidence = option),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StudyModeCard(
                  title: 'Prototype study schedule',
                  subtitle:
                      'Estimated locally; this is not tracked study time.',
                  child: Column(
                    children: [
                      for (final block in _blocksFor(confidence))
                        ListTile(
                          title: Text(block.label),
                          trailing: Text('${block.minutes} min'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    state.createStudySession(
                      subject: subject!,
                      confidence: confidence,
                      materialId: material.id,
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
          ],
        ),
      ),
    );
  }

  List<StudyTimeBlock> _blocksFor(LectureConfidence value) => switch (value) {
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
