import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
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
      title: 'Progress', activeRoute: AppRoutes.progress,
      body: ResponsiveContent(width: ResponsiveContentWidth.wide, child: ListView(children: [
        if (state.isLoadingQuizAttempts)
          const GlassCard(child: LoadingState(label: 'Loading quiz results'))
        else
          AttemptSummaryCard(score: latest?.score, correct: latest?.correctQuestions, total: latest?.totalQuestions, attemptCount: state.quizAttempts.length),
        const SizedBox(height: 20),
        Text('Focus topics', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Miss counts are cumulative quiz history, not a mastery score.'),
        const SizedBox(height: 12),
        GlassCard(padding: EdgeInsets.zero, child:
          state.isLoadingCumulativeWeakTopics
            ? const LoadingState(label: 'Loading focus topics')
            : state.weakTopicSyncErrorMessage != null
              ? ErrorRetryState(message: state.weakTopicSyncErrorMessage!, onRetry: () => state.loadCumulativeWeakTopicsFor(AuthScope.read(context).user))
              : state.cumulativeWeakTopics.isEmpty
                ? const EmptyState(title: 'No focus topics yet', message: 'Complete quizzes to discover topics that need more practice.', icon: Icons.flag_outlined)
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
