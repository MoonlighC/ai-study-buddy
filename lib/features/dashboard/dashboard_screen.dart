import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/quiz_attempt.dart';
import '../../core/models/weak_topic.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final recentSubjects = state.subjects.take(3).toList();
    final recentMaterials = state.materials.take(4).toList();
    final focusTopics = state.cumulativeWeakTopics.take(3).toList();
    final latestAttempt = state.latestQuizAttempt;

    return ResponsiveAppScaffold(
      title: 'AI Study Buddy',
      subtitle: 'Your calm place to learn',
      activeRoute: AppRoutes.dashboard,
      body: SingleChildScrollView(
        key: const ValueKey('home-scroll-view'),
        child: ResponsiveContent(
          width: ResponsiveContentWidth.wide,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 820;
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(
                    subjectCount: state.subjects.length,
                    hasMaterials: state.materials.isNotEmpty,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeading(
                    title: 'Recent materials',
                    actionLabel: 'View subjects',
                    onAction: () =>
                        Navigator.pushNamed(context, AppRoutes.subjects),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GlassSurface(
                    child: recentMaterials.isEmpty
                        ? const EmptyState(
                            title: 'No materials yet',
                            message:
                                'Open a subject and add your first study material.',
                            icon: Icons.article_outlined,
                          )
                        : Column(
                            children: [
                              for (
                                var index = 0;
                                index < recentMaterials.length;
                                index++
                              )
                                _MaterialRow(
                                  material: recentMaterials[index],
                                  subjectName: state
                                      .subjectFor(
                                        recentMaterials[index].subjectId,
                                      )
                                      .name,
                                  showDivider:
                                      index != recentMaterials.length - 1,
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeading(title: 'Your subjects'),
                  const SizedBox(height: AppSpacing.sm),
                  if (recentSubjects.isEmpty)
                    const GlassCard(
                      child: EmptyState(
                        title: 'Create your first subject',
                        message:
                            'Subjects keep materials and study tools together.',
                        icon: Icons.folder_open_outlined,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final subject in recentSubjects)
                          SizedBox(
                            width: twoColumns ? 220 : constraints.maxWidth,
                            child: GlassButton(
                              label: subject.name,
                              icon: Icons.folder_outlined,
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.subjectDetail,
                                arguments: subject,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );

              final side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LatestProgress(attempt: latestAttempt, state: state),
                  const SizedBox(height: AppSpacing.lg),
                  _FocusTopics(topics: focusTopics, state: state),
                  const SizedBox(height: AppSpacing.lg),
                  const _QuickActions(),
                ],
              );

              if (!twoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    const SizedBox(height: AppSpacing.xl),
                    side,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: main),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(flex: 5, child: side),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.subjectCount, required this.hasMaterials});

  final int subjectCount;
  final bool hasMaterials;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('home-hero'),
    depth: GlassDepth.prominent,
    padding: EdgeInsets.all(
      AppResponsive.prominentSurfacePaddingFor(
        MediaQuery.sizeOf(context).width,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassStatusChip(
          label: 'Study workspace',
          icon: Icons.menu_book_outlined,
          color: AppColors.secondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Ready for your next study step?',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hasMaterials
              ? 'Continue with a recent material or choose a focused study action.'
              : 'Add study material to a subject, then build summaries, flashcards, and quizzes.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              key: const ValueKey('home-open-subjects'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.subjects),
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(
                subjectCount == 0 ? 'Create a subject' : 'Open subjects',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.afterLecture),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('After Lecture'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.subjectName,
    required this.showDivider,
  });

  final StudyMaterial material;
  final String subjectName;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => AppListRow(
    title: Text(material.title),
    subtitle: Text('$subjectName · ${material.createdLabel}'),
    leading: Icon(
      _iconFor(material.kind),
      color: Theme.of(context).colorScheme.primary,
    ),
    trailing: const Icon(Icons.chevron_right),
    showDivider: showDivider,
    onTap: () => Navigator.pushNamed(
      context,
      AppRoutes.materialDetail,
      arguments: material,
    ),
  );

  IconData _iconFor(MaterialKind kind) => switch (kind) {
    MaterialKind.pdf => Icons.picture_as_pdf_outlined,
    MaterialKind.image => Icons.image_outlined,
    MaterialKind.pastedText => Icons.article_outlined,
  };
}

class _LatestProgress extends StatelessWidget {
  const _LatestProgress({required this.attempt, required this.state});

  final QuizAttempt? attempt;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final latest = attempt;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Latest progress'),
          const SizedBox(height: AppSpacing.md),
          if (latest == null)
            const EmptyState(
              title: 'No quiz attempts yet',
              message: 'Complete a quiz to see your latest result.',
              icon: Icons.quiz_outlined,
            )
          else ...[
            Text(
              '${latest.score.round()}%',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${latest.correctQuestions} of ${latest.totalQuestions} correct',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.subjectFor(latest.subjectId).name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusTopics extends StatelessWidget {
  const _FocusTopics({required this.topics, required this.state});

  final List<CumulativeWeakTopic> topics;
  final AppState state;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Focus topics'),
        const SizedBox(height: AppSpacing.sm),
        if (topics.isEmpty)
          const Text('Complete quizzes to reveal topics worth revisiting.')
        else
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_outlined, size: AppIconSizes.control),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.topic,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${state.subjectFor(topic.subjectId).name} · ${topic.missCount} ${topic.missCount == 1 ? 'miss' : 'misses'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: 'Quick actions'),
        const SizedBox(height: AppSpacing.sm),
        GlassButton(
          label: 'Prepare for Exam',
          icon: Icons.event_available_outlined,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.examPrep),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          label: 'Continue Studying',
          icon: Icons.play_circle_outline,
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.continueStudying),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xxs,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}
