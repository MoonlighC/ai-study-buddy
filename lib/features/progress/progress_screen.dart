import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../auth/auth_controller.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final latest = state.latestQuizAttempt;
    return ResponsiveAppScaffold(
      title: context.l10n.navProgress, activeRoute: AppRoutes.progress,
      body: ResponsiveContent(width: ResponsiveContentWidth.wide, child: ListView(children: [
        if (state.isLoadingQuizAttempts)
          GlassCard(child: LoadingState(label: context.l10n.progressLoading))
        else
          AttemptSummaryCard(score: latest?.score, correct: latest?.correctQuestions, total: latest?.totalQuestions, attemptCount: state.quizAttempts.length),
        const SizedBox(height: 20),
        Text(context.l10n.progressFocusTopics, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(context.l10n.progressHistoryExplanation),
        const SizedBox(height: 12),
        GlassCard(padding: EdgeInsets.zero, child:
          state.isLoadingCumulativeWeakTopics
            ? LoadingState(label: context.l10n.progressLoading)
            : state.weakTopicSyncErrorMessage != null
              ? ErrorRetryState(message: context.localizedSafeMessage(state.weakTopicSyncErrorMessage!), onRetry: () => state.loadCumulativeWeakTopicsFor(AuthScope.read(context).user))
              : state.cumulativeWeakTopics.isEmpty
                ? EmptyState(title: context.l10n.progressFocusTopics, message: context.l10n.progressEmptyMessage, icon: Icons.flag_outlined)
                : Column(children: [for (final topic in state.cumulativeWeakTopics) FocusTopicRow(topic: topic.topic, subject: _subjectName(state, topic.subjectId), missCount: topic.missCount)]),
        ),
      ])),
    );
  }

  String _subjectName(AppState state, String subjectId) {
    for (final subject in state.subjects) {
      if (subject.id == subjectId) return subject.name;
    }
    return 'Subject unavailable';
  }
}
