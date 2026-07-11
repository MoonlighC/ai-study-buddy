import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  static const ai = MockAiService();
  Subject? selectedSubject;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;
    final effectiveSubject = _selectedSubjectFrom(subjects);
    final materials = effectiveSubject == null
        ? []
        : state.materialsFor(effectiveSubject.id);
    final weakTopics = effectiveSubject == null
        ? []
        : ai.weakTopicsFor(effectiveSubject);
    final plan = effectiveSubject == null
        ? []
        : ai.examPlanFor(effectiveSubject);

    return ResponsiveAppScaffold(
      title: 'Exam Prep',
      showBack: true,
      showNavigation: false,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            const GlassStatusChip(
              label: 'Local prototype plan',
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              'Prepare for an exam',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Create a local study plan from a subject, materials, and weak topics.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (effectiveSubject == null) ...[
              EmptyState(
                title: 'No subjects yet',
                message: 'Create a subject before preparing an exam plan.',
                icon: Icons.folder_open_outlined,
                action: FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.subjects),
                  child: const Text('Open Subjects'),
                ),
              ),
            ] else ...[
              StudyModeCard(
                title: 'Choose subject',
                icon: Icons.folder_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in subjects)
                      ChoiceChip(
                        label: Text(subject.name),
                        selected: effectiveSubject.id == subject.id,
                        onSelected: (_) =>
                            setState(() => selectedSubject = subject),
                      ),
                  ],
                ),
              ),
              StudyModeCard(
                title: 'Exam date preview',
                icon: Icons.event_outlined,
                subtitle: 'Date selection is not available in this prototype.',
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Exam date',
                    hintText: 'Mock date: 2 weeks from now',
                    enabled: false,
                    suffixIcon: IconButton(
                      tooltip: 'Date selection unavailable',
                      onPressed: null,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ),
              StudyModeCard(
                title: 'Selected materials preview',
                icon: Icons.article_outlined,
                child: Column(
                  children: [
                    if (materials.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.article_outlined),
                        title: Text('No materials yet'),
                        subtitle: Text(
                          'The plan can still start from the selected subject.',
                        ),
                      )
                    else
                      for (final material in materials)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.article_outlined),
                          title: Text(material.title),
                          subtitle: Text(
                            '${material.createdLabel} - included in plan',
                          ),
                        ),
                  ],
                ),
              ),
              StudyModeCard(
                title: 'Preview focus topics',
                icon: Icons.flag_outlined,
                subtitle:
                    'Locally generated prototype guidance; not a mastery score.',
                child: Column(
                  children: [
                    for (final topic in weakTopics)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(topic.title),
                        subtitle: Text(topic.reason),
                      ),
                  ],
                ),
              ),
              StudyModeCard(
                title: 'Preview preparation plan',
                icon: Icons.calendar_month_outlined,
                subtitle: 'Locally generated prototype guidance.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in plan)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(item),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'Recommended: flashcards first, then quick quiz.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  AppStateScope.read(context).createStudySession(
                    subject: effectiveSubject,
                    confidence: LectureConfidence.mostly,
                    materialId: materials.firstOrNull?.id,
                  );
                  Navigator.pushNamed(
                    context,
                    AppRoutes.studySessionResult,
                    arguments: effectiveSubject,
                  );
                },
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Create study session'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Subject? _selectedSubjectFrom(List<Subject> subjects) {
    final current = selectedSubject;
    if (current != null && subjects.any((item) => item.id == current.id)) {
      return current;
    }
    return subjects.firstOrNull;
  }
}
