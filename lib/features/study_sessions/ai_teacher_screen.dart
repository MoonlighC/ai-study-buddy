import 'package:flutter/material.dart';

import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/study_components.dart';

class AiTeacherScreen extends StatefulWidget {
  const AiTeacherScreen({required this.subject, super.key});

  final Subject subject;

  @override
  State<AiTeacherScreen> createState() => _AiTeacherScreenState();
}

class _AiTeacherScreenState extends State<AiTeacherScreen> {
  static const ai = MockAiService();
  String selectedPrompt = 'Explain simpler';

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;

    return ResponsiveAppScaffold(
      title: 'AI Teacher',
      showBack: true,
      showNavigation: false,
      subjectColor: Color(subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            const GlassStatusChip(
              label: 'Local mock coaching · Prototype',
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 12),
            StudyModeCard(
              title: subject.name,
              subtitle: 'Canned local responses; no live AI connection.',
              child: Text(
                'Choose a coaching style. The response below stays entirely local and uses mock text.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            StudyModeCard(
              icon: Icons.tune_outlined,
              title: 'Coach prompt',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in [
                    'Explain simpler',
                    'Give another example',
                    'Ask a question',
                  ])
                    ChoiceChip(
                      label: Text(prompt),
                      selected: selectedPrompt == prompt,
                      onSelected: (_) =>
                          setState(() => selectedPrompt = prompt),
                    ),
                ],
              ),
            ),
            StudyModeCard(
              icon: Icons.psychology_alt_outlined,
              title: 'Prototype answer',
              subtitle: selectedPrompt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ai.aiTeacherAnswerFor(subject)),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_promptFollowUp(selectedPrompt)),
                    ),
                  ),
                ],
              ),
            ),
            StudyModeCard(
              icon: Icons.chat_bubble_outline,
              title: 'Try next',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => selectedPrompt = 'Give another example'),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Show another mock example'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => selectedPrompt = 'Ask a question'),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Quiz me on this'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _promptFollowUp(String prompt) {
    return switch (prompt) {
      'Give another example' =>
        'Example: connect the main idea to a familiar lecture note, then restate it in your own words.',
      'Ask a question' =>
        'Question: what is the first clue you would look for to recognize this topic on a quiz?',
      _ =>
        'Simpler version: focus on the cause, the key term, and one example before adding details.',
    };
  }
}
