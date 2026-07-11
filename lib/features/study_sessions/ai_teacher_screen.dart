import 'package:flutter/material.dart';

import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../l10n/l10n_extensions.dart';
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
  _CoachPrompt selectedPrompt = _CoachPrompt.simple;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;

    return ResponsiveAppScaffold(
      title: context.l10n.aiTeacherTitle,
      showBack: true,
      showNavigation: false,
      subjectColor: Color(subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            GlassStatusChip(
              label: context.l10n.aiTeacherStatus,
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 12),
            StudyModeCard(
              title: subject.name,
              subtitle: context.l10n.aiTeacherNoLive,
              child: Text(
                context.l10n.aiTeacherHelp,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            StudyModeCard(
              icon: Icons.tune_outlined,
              title: context.l10n.aiTeacherPrompt,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in _CoachPrompt.values)
                    ChoiceChip(
                      label: Text(_promptLabel(context, prompt)),
                      selected: selectedPrompt == prompt,
                      onSelected: (_) =>
                          setState(() => selectedPrompt = prompt),
                    ),
                ],
              ),
            ),
            StudyModeCard(
              icon: Icons.psychology_alt_outlined,
              title: context.l10n.aiTeacherAnswer,
              subtitle: _promptLabel(context, selectedPrompt),
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
              title: context.l10n.aiTeacherTryNext,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => selectedPrompt = _CoachPrompt.example),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text(context.l10n.aiTeacherAnotherExample),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => selectedPrompt = _CoachPrompt.question),
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(context.l10n.aiTeacherQuizMe),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _promptLabel(BuildContext context, _CoachPrompt prompt) => switch (prompt) {
    _CoachPrompt.simple => context.l10n.aiTeacherPromptSimple,
    _CoachPrompt.example => context.l10n.aiTeacherPromptExample,
    _CoachPrompt.question => context.l10n.aiTeacherPromptQuestion,
  };

  String _promptFollowUp(_CoachPrompt prompt) {
    return switch (prompt) {
      _CoachPrompt.example =>
        'Example: connect the main idea to a familiar lecture note, then restate it in your own words.',
      _CoachPrompt.question =>
        'Question: what is the first clue you would look for to recognize this topic on a quiz?',
      _ =>
        'Simpler version: focus on the cause, the key term, and one example before adding details.',
    };
  }
}

enum _CoachPrompt { simple, example, question }
