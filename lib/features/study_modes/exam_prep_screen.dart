import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../mock/mock_data.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Prepare for an exam',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('Choose subject', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in MockData.subjects)
                ChoiceChip(
                  label: Text(subject.name),
                  selected: selectedSubject.id == subject.id,
                  onSelected: (_) => setState(() => selectedSubject = subject),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
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
          const SizedBox(height: 12),
          Text(
            'Selected materials',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final material in materials)
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(material.title),
                subtitle: Text(
                  '${material.createdLabel} - included in mock plan',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up_outlined),
              title: Text('${selectedSubject.name} knowledge score'),
              subtitle: LinearProgressIndicator(
                value: score.scorePercent / 100,
              ),
              trailing: Text('${score.scorePercent}%'),
            ),
          ),
          const SizedBox(height: 12),
          Text('Weak topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final topic in weakTopics)
            Card(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(topic.title),
                subtitle: Text(topic.reason),
              ),
            ),
          const SizedBox(height: 12),
          _PlanSection(plan: plan),
          const SizedBox(height: 16),
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

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.plan});

  final List<String> plan;

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
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily preparation plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    );
  }
}
