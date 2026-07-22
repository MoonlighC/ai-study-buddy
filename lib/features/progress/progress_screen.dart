import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/knowledge_score.dart';
import '../../core/models/persisted_study_activity.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../auth/auth_controller.dart';
import '../flashcards/flashcard_training_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../quizzes/quiz_taking_screen.dart';

class ProgressRouteArgs {
  const ProgressRouteArgs({this.subjectId, this.materialId});
  final String? subjectId;
  final String? materialId;
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({this.args = const ProgressRouteArgs(), super.key});
  final ProgressRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    if (state.config.effectiveBackendMode != AppBackendMode.supabase) {
      return _LegacyProgress(state: state);
    }
    final progress = state.studyProgress;
    final selectedMaterial = args.materialId == null
        ? null
        : progress?.materialById(args.materialId!);
    final selectedSubject = args.subjectId == null
        ? null
        : progress?.subjectById(args.subjectId!);
    final metrics =
        selectedMaterial?.metrics ??
        selectedSubject?.metrics ??
        progress?.global;
    final title =
        selectedMaterial?.materialTitle ??
        selectedSubject?.subjectName ??
        context.l10n.navProgress;

    return ResponsiveAppScaffold(
      title: title,
      activeRoute: args.subjectId == null && args.materialId == null
          ? AppRoutes.progress
          : null,
      showBack: args.subjectId != null || args.materialId != null,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: RefreshIndicator(
          onRefresh: () =>
              state.loadStudyProgressFor(AuthScope.read(context).user),
          child: ListView(
            key: const ValueKey('authoritative-progress'),
            children: [
              if (state.isLoadingStudyProgress && progress == null)
                GlassCard(
                  child: LoadingState(label: context.l10n.progressLoading),
                )
              else if (state.studyProgressErrorMessage != null &&
                  progress == null)
                GlassCard(
                  child: ErrorRetryState(
                    message: context.localizedSafeMessage(
                      state.studyProgressErrorMessage!,
                    ),
                    onRetry: () => state.loadStudyProgressFor(
                      AuthScope.read(context).user,
                    ),
                  ),
                )
              else if (metrics != null) ...[
                _ScoreCard(metrics: metrics),
                const SizedBox(height: 16),
                _EvidenceGrid(metrics: metrics, materialId: args.materialId),
                if (metrics.weakTopics.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Heading(context.l10n.progressFocusTopics),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final topic in metrics.weakTopics)
                          ListTile(
                            key: ValueKey('progress-topic-${topic.id}'),
                            leading: const Icon(Icons.flag_outlined),
                            title: Text(topic.topic),
                            subtitle: Text(
                              topic.materialTitle.isNotEmpty
                                  ? topic.materialTitle
                                  : topic.subjectName,
                            ),
                            trailing: Text(
                              context.l10n.studyMisses(topic.missCount),
                            ),
                            onTap: () => _openTopic(context, topic),
                          ),
                      ],
                    ),
                  ),
                ],
                if (metrics.activeSessions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Heading(context.l10n.progressActiveSessions),
                  const SizedBox(height: 8),
                  _Sessions(
                    sessions: metrics.activeSessions,
                    onTap: (session) => _openActive(context, session),
                  ),
                ],
                if (metrics.recentCompletedSessions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Heading(context.l10n.progressRecentSessions),
                  const SizedBox(height: 8),
                  _Sessions(
                    sessions: metrics.recentCompletedSessions,
                    onTap: (session) => _openCompleted(context, session),
                  ),
                ],
                if (selectedMaterial == null && selectedSubject == null) ...[
                  const SizedBox(height: 20),
                  _ProgressGroups(
                    title: context.l10n.progressBySubject,
                    items: [
                      for (final item in progress!.subjects)
                        _GroupItem(
                          id: item.subjectId,
                          title: item.subjectName,
                          metrics: item.metrics,
                          args: ProgressRouteArgs(subjectId: item.subjectId),
                        ),
                    ],
                  ),
                ],
                if (selectedMaterial == null) ...[
                  const SizedBox(height: 20),
                  _ProgressGroups(
                    title: context.l10n.progressByMaterial,
                    items: [
                      for (final item in progress!.materials)
                        if (selectedSubject == null ||
                            item.subjectId == selectedSubject.subjectId)
                          _GroupItem(
                            id: item.materialId,
                            title: item.materialTitle,
                            subtitle: item.subjectName,
                            metrics: item.metrics,
                            args: ProgressRouteArgs(
                              subjectId: item.subjectId,
                              materialId: item.materialId,
                            ),
                          ),
                    ],
                  ),
                ],
                if (selectedMaterial == null &&
                    selectedSubject == null &&
                    (progress!.historical.completedQuizAttemptCount > 0 ||
                        progress.historical.completedSessionCount > 0)) ...[
                  const SizedBox(height: 20),
                  _Heading(context.l10n.progressHistoricalActivity),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Text(
                      context.l10n.progressHistoricalSummary(
                        progress.historical.completedQuizAttemptCount,
                        progress.historical.completedSessionCount,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openTopic(BuildContext context, ProgressWeakTopic topic) {
    final material = AppStateScope.read(context).materialById(topic.materialId);
    if (material == null) return _unavailable(context);
    Navigator.pushNamed(context, AppRoutes.materialDetail, arguments: material);
  }

  void _openActive(BuildContext context, ProgressSession summary) {
    final state = AppStateScope.read(context);
    final session = state.activeStudyActivities
        .where((value) => value.id == summary.sessionId)
        .firstOrNull;
    final material = state.materialById(summary.materialId);
    if (session == null || material == null) return _unavailable(context);
    final subject = state.subjectFor(material.subjectId);
    if (session.type == PersistedStudyActivityType.flashcards) {
      final byId = {
        for (final card in state.flashcardsForMaterial(material.id))
          card.id: card,
      };
      final cards = [
        for (final id in session.itemIds)
          if (byId[id] != null) byId[id]!,
      ];
      if (cards.length != session.itemIds.length) return _unavailable(context);
      Navigator.pushNamed(
        context,
        AppRoutes.flashcardTraining,
        arguments: FlashcardTrainingArgs(
          subject: subject,
          material: material,
          cards: cards,
          session: session,
          mode: session.flashcardMode ?? FlashcardTrainingMode.all,
        ),
      );
      return;
    }
    final quiz = session.quizId == null
        ? state.quizById(
            state.quizAttemptById(session.attemptId ?? '')?.quizId ?? '',
          )
        : state.quizById(session.quizId!);
    if (quiz == null) return _unavailable(context);
    Navigator.pushNamed(
      context,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: subject,
        material: material,
        quiz: quiz,
        session: session,
      ),
    );
  }

  void _openCompleted(BuildContext context, ProgressSession session) {
    final state = AppStateScope.read(context);
    final material = state.materialById(session.materialId);
    if (material == null) return _unavailable(context);
    final attempt = state.quizAttemptById(session.quizAttemptId ?? '');
    if (attempt == null) {
      Navigator.pushNamed(
        context,
        AppRoutes.materialDetail,
        arguments: material,
      );
      return;
    }
    final quiz = state.quizById(attempt.quizId);
    if (quiz == null) return _unavailable(context);
    Navigator.pushNamed(
      context,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: state.subjectFor(material.subjectId),
        material: material,
        quiz: quiz,
        completedAttempt: attempt,
      ),
    );
  }

  void _unavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.continueUnavailableMessage)),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.metrics});
  final ProgressMetrics metrics;
  @override
  Widget build(BuildContext context) => GlassCard(
    depth: GlassDepth.prominent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.progressKnowledgeScore,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          metrics.knowledgeScore == null
              ? context.l10n.progressNotEnoughActivity
              : '${metrics.knowledgeScore!.toStringAsFixed(2)}%',
          key: const ValueKey('knowledge-score'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.progressEvidenceCounts(
            metrics.quizEvidenceCount,
            metrics.flashcardEvidenceCount,
          ),
        ),
      ],
    ),
  );
}

class _EvidenceGrid extends StatelessWidget {
  const _EvidenceGrid({required this.metrics, this.materialId});
  final ProgressMetrics metrics;
  final String? materialId;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Metric(
        label: context.l10n.progressQuizAccuracy,
        value: metrics.quizAccuracy == null
            ? '—'
            : '${metrics.quizAccuracy!.toStringAsFixed(2)}%',
        detail: context.l10n.studyAttempts(metrics.completedQuizAttemptCount),
      ),
      _Metric(
        label: context.l10n.progressFlashcardState,
        value:
            '${metrics.flashcardKnownCount} / ${metrics.flashcardNotKnownCount}',
        detail: context.l10n.progressKnownNotKnown,
      ),
      _Metric(
        keyValue: const ValueKey('progress-weak-cards'),
        label: context.l10n.progressWeakCards,
        value: '${metrics.weakCardCount}',
        onTap: materialId == null || metrics.weakCardCount == 0
            ? null
            : () => _openCards(context, weak: true),
      ),
      _Metric(
        keyValue: const ValueKey('progress-due-cards'),
        label: context.l10n.progressCardsDue,
        value: '${metrics.dueCardCount}',
        onTap: materialId == null || metrics.dueCardCount == 0
            ? null
            : () => _openCards(context, weak: false),
      ),
      _Metric(
        label: context.l10n.progressActiveSessions,
        value: '${metrics.activeSessionCount}',
      ),
      _Metric(
        label: context.l10n.progressCompletedSessions,
        value: '${metrics.completedSessionCount}',
      ),
    ],
  );

  void _openCards(BuildContext context, {required bool weak}) {
    final state = AppStateScope.read(context);
    final material = state.materialById(materialId!);
    if (material == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.continueUnavailableMessage)),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.flashcards,
      arguments: FlashcardsRouteArgs(
        subject: state.subjectFor(material.subjectId),
        materialId: material.id,
        materialTitle: material.title,
        initialMode: weak
            ? FlashcardTrainingMode.weak
            : FlashcardTrainingMode.due,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
    this.keyValue,
  });
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;
  final Key? keyValue;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: GestureDetector(
      key: keyValue,
      onTap: onTap,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (detail != null)
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _Sessions extends StatelessWidget {
  const _Sessions({required this.sessions, required this.onTap});
  final List<ProgressSession> sessions;
  final ValueChanged<ProgressSession> onTap;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final session in sessions)
          ListTile(
            key: ValueKey('progress-session-${session.sessionId}'),
            title: Text(
              session.materialTitle.isEmpty
                  ? context.l10n.progressUnavailableMaterial
                  : session.materialTitle,
            ),
            subtitle: Text(
              '${session.sessionType.replaceAll('_', ' ')} · ${session.currentProgress}/${session.totalItems}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(session),
          ),
      ],
    ),
  );
}

class _ProgressGroups extends StatelessWidget {
  const _ProgressGroups({required this.title, required this.items});
  final String title;
  final List<_GroupItem> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Heading(title),
      const SizedBox(height: 8),
      GlassCard(
        padding: EdgeInsets.zero,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.progressNoCurrentMaterials),
              )
            : Column(
                children: [
                  for (final item in items)
                    ListTile(
                      key: ValueKey('progress-group-${item.id}'),
                      title: Text(item.title),
                      subtitle: Text(
                        item.metrics.knowledgeScore == null
                            ? context.l10n.progressNotEnoughActivity
                            : '${item.metrics.knowledgeScore!.toStringAsFixed(2)}%${item.subtitle == null ? '' : ' · ${item.subtitle}'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.progress,
                        arguments: item.args,
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}

class _GroupItem {
  const _GroupItem({
    required this.id,
    required this.title,
    required this.metrics,
    required this.args,
    this.subtitle,
  });
  final String id;
  final String title;
  final String? subtitle;
  final ProgressMetrics metrics;
  final ProgressRouteArgs args;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _LegacyProgress extends StatelessWidget {
  const _LegacyProgress({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final latest = state.latestQuizAttempt;
    return ResponsiveAppScaffold(
      title: context.l10n.navProgress,
      activeRoute: AppRoutes.progress,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: ListView(
          children: [
            AttemptSummaryCard(
              score: latest?.score,
              correct: latest?.correctQuestions,
              total: latest?.totalQuestions,
              attemptCount: state.quizAttempts.length,
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.progressFocusTopics,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(context.l10n.progressHistoryExplanation),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: state.cumulativeWeakTopics.isEmpty
                  ? EmptyState(
                      title: context.l10n.progressFocusTopics,
                      message: context.l10n.progressEmptyMessage,
                      icon: Icons.flag_outlined,
                    )
                  : Column(
                      children: [
                        for (final topic in state.cumulativeWeakTopics)
                          FocusTopicRow(
                            topic: topic.topic,
                            subject: state.subjectFor(topic.subjectId).name,
                            missCount: topic.missCount,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
