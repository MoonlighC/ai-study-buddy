import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../mock/mock_data.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  static const ai = MockAiService();
  late Subject selectedSubject = MockData.subjects.first;

  @override
  Widget build(BuildContext context) {
    final materials = MockData.materials
        .where((material) => material.subjectId == selectedSubject.id)
        .toList();
    final score = MockData.knowledgeScores.firstWhere(
      (item) => item.subjectId == selectedSubject.id,
    );
    final weakTopics = ai.weakTopicsFor(selectedSubject);
    final plan = ai.examPlanFor(selectedSubject);

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Prep')),
      body: AppPage(
        children: [
          Text(
            'Prepare for an exam',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Create a local mock plan from a subject, materials, and weak topics.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.folder_outlined,
            title: 'Choose subject',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in MockData.subjects)
                  ChoiceChip(
                    label: Text(subject.name),
                    selected: selectedSubject.id == subject.id,
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
                for (final material in materials)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(material.title),
                    subtitle: Text(
                      '${material.createdLabel} - included in mock plan',
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.trending_up_outlined,
            title: '${selectedSubject.name} knowledge score',
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
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.studySessionResult,
              arguments: selectedSubject,
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Create study session'),
          ),
        ],
      ),
    );
  }
}
