import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../flashcards/flashcards_screen.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';

class GeneratedOutputsScreen extends StatelessWidget {
  const GeneratedOutputsScreen({required this.subject, super.key});

  final Subject subject;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    final quiz = ai.quizFor(subject);
    final plan = ai.examPlanFor(subject);

    final hasContent =
        ai.summaryFor(subject).trim().isNotEmpty ||
        quiz.isNotEmpty ||
        plan.isNotEmpty;
    return ResponsiveAppScaffold(
      title: context.l10n.generatedPreviewTitle,
      subtitle: context.l10n.generatedPreviewSubtitle(subject.name),
      showBack: true,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          key: const ValueKey('generated-outputs-scroll-view'),
          children: [
            GlassStatusChip(
              label: context.l10n.generatedPreviewTitle,
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 16),
            if (!hasContent)
              EmptyState(
                icon: Icons.auto_awesome_outlined,
                title: context.l10n.generatedPreviewEmptyTitle,
                message: context.l10n.generatedPreviewEmptyMessage,
              )
            else ...[
              Text(
                subject.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _OutputSection(
                icon: Icons.summarize_outlined,
                title: context.l10n.studySummary,
                child: Text(ai.summaryFor(subject)),
              ),
              _OutputSection(
                icon: Icons.style_outlined,
                title: context.l10n.flashcardsTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.generatedCountPreview(5)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.flashcards,
                        arguments: FlashcardsRouteArgs(subject: subject),
                      ),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(context.l10n.generatedOpenFlashcards),
                    ),
                  ],
                ),
              ),
              _OutputSection(
                icon: Icons.quiz_outlined,
                title: context.l10n.sessionQuickQuiz,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quiz.first.question),
                    const SizedBox(height: 8),
                    for (final option in quiz.first.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(option)),
                          ],
                        ),
                      ),
                    Text(
                      context.l10n.generatedExplainMistake(
                        quiz.first.explanation,
                      ),
                    ),
                  ],
                ),
              ),
              _OutputSection(
                icon: Icons.calendar_month_outlined,
                title: context.l10n.generatedExamPlan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final item in plan) Text(item)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
