import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

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
    final score = MockData.knowledgeScores.firstWhere(
      (item) => item.subjectId == effectiveSubject?.id,
      orElse: () => MockData.knowledgeScores.first,
    );
    final weakTopics = effectiveSubject == null
        ? []
        : ai.weakTopicsFor(effectiveSubject);
    final plan = effectiveSubject == null
        ? []
        : ai.examPlanFor(effectiveSubject);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Prep'),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
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
            const SectionCard(
              icon: Icons.folder_open_outlined,
              title: 'No subjects yet',
              subtitle: 'Create a subject before preparing an exam plan.',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_outlined),
                title: Text('Subjects will appear here after sync.'),
              ),
            ),
          ] else ...[
            SectionCard(
              icon: Icons.folder_outlined,
              title: 'Choose subject',
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
            SectionCard(
              icon: Icons.event_outlined,
              title: 'Exam date',
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Exam date',
                  hintText: 'Mock date: 2 weeks from now',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date placeholder',
                    onPressed: () {},
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
            ),
            SectionCard(
              icon: Icons.article_outlined,
              title: 'Selected materials',
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
            SectionCard(
              icon: Icons.trending_up_outlined,
              title: '${effectiveSubject.name} knowledge score',
              trailing: Text('${score.scorePercent}%'),
              child: LinearProgressIndicator(value: score.scorePercent / 100),
            ),
            SectionCard(
              icon: Icons.flag_outlined,
              title: 'Weak topics',
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
            SectionCard(
              icon: Icons.calendar_month_outlined,
              title: 'Daily preparation plan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in plan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(item),
                    ),
                  const SizedBox(height: 6),
                  const Text('Recommended: flashcards first, then quick quiz.'),
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
      bottomNavigationBar: const AppBottomNav(),
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
