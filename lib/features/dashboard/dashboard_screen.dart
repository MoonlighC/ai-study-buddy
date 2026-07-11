import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/quiz_attempt.dart';
import '../../core/models/weak_topic.dart';
import '../../l10n/l10n_extensions.dart';
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
    final l10n = context.l10n;

    return ResponsiveAppScaffold(
      title: l10n.appTitle,
      subtitle: l10n.homeSubtitle,
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
                    title: l10n.homeRecentMaterials,
                    actionLabel: l10n.homeViewSubjects,
                    onAction: () =>
                        Navigator.pushNamed(context, AppRoutes.subjects),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GlassSurface(
                    child: recentMaterials.isEmpty
                        ? EmptyState(
                            title: l10n.homeNoMaterialsTitle,
                            message: l10n.homeNoMaterialsMessage,
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
                  _SectionHeading(title: l10n.homeYourSubjects),
                  const SizedBox(height: AppSpacing.sm),
                  if (recentSubjects.isEmpty)
                    GlassCard(
                      child: EmptyState(
                        title: l10n.homeCreateFirstSubject,
                        message: l10n.homeCreateFirstSubjectMessage,
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
        GlassStatusChip(
          label: context.l10n.homeStudyWorkspace,
          icon: Icons.menu_book_outlined,
          color: AppColors.secondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.homeHeroTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hasMaterials
              ? context.l10n.homeHeroWithMaterials
              : context.l10n.homeHeroWithoutMaterials,
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
                subjectCount == 0
                    ? context.l10n.homeCreateSubject
                    : context.l10n.homeOpenSubjects,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.afterLecture),
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(context.l10n.homeAfterLecture),
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
          _SectionHeading(title: context.l10n.homeLatestProgress),
          const SizedBox(height: AppSpacing.md),
          if (latest == null)
            EmptyState(
              title: context.l10n.homeNoQuizAttemptsTitle,
              message: context.l10n.homeNoQuizAttemptsMessage,
              icon: Icons.quiz_outlined,
            )
          else ...[
            Text(
              '${latest.score.round()}%',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.l10n.homeCorrectCount(
                latest.correctQuestions,
                latest.totalQuestions,
              ),
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
        _SectionHeading(title: context.l10n.homeFocusTopics),
        const SizedBox(height: AppSpacing.sm),
        if (topics.isEmpty)
          Text(context.l10n.homeFocusTopicsEmpty)
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
                          context.l10n.homeMissesWithSubject(
                            state.subjectFor(topic.subjectId).name,
                            topic.missCount,
                          ),
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
        _SectionHeading(title: context.l10n.homeQuickActions),
        const SizedBox(height: AppSpacing.sm),
        GlassButton(
          label: context.l10n.homePrepareForExam,
          icon: Icons.event_available_outlined,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.examPrep),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          label: context.l10n.homeContinueStudying,
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
