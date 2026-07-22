import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/app_config.dart';
import '../../core/models/persisted_study_activity.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import 'study_session_result_screen.dart';
import '../flashcards/flashcard_training_screen.dart';
import '../quizzes/quiz_taking_screen.dart';

class ContinueStudyingScreen extends StatelessWidget {
  const ContinueStudyingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    if (state.config.effectiveBackendMode == AppBackendMode.supabase) {
      return _PersistedContinue(state: state);
    }
    final session = state.latestStudySession;
    final subject = session == null
        ? null
        : state.subjects
              .where((item) => item.id == session.subjectId)
              .firstOrNull;
    final material = session == null
        ? null
        : state.materialById(session.materialId);
    final usable =
        session != null &&
        subject != null &&
        material != null &&
        material.subjectId == subject.id &&
        state.canGenerateSummaryForMaterial(material);
    return ResponsiveAppScaffold(
      title: context.l10n.continueStudyingTitle,
      activeRoute: AppRoutes.continueStudying,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            if (!usable)
              GlassCard(
                child: EmptyState(
                  title: context.l10n.continueEmptyTitle,
                  message: session == null
                      ? context.l10n.continueEmptyMessage
                      : context.l10n.continueUnavailableMessage,
                  icon: Icons.history_toggle_off_outlined,
                  action: FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.subjects),
                    child: Text(context.l10n.studyOpenSubjects),
                  ),
                ),
              )
            else ...[
              StudyContextHeader(
                title: subject.name,
                subtitle: context.l10n.continueFrom(material.title),
                status: context.l10n.continueLatest,
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.continueSummary,
                child: Text(session.summary),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.continueQuickQuiz,
                icon: Icons.quiz_outlined,
                child: Text(
                  session.quizScorePercent == null
                      ? context.l10n.studyNotCompleted
                      : context.l10n.continueLastScore(
                          session.quizScorePercent!,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.progressFocusTopics,
                icon: Icons.flag_outlined,
                child: session.weakTopics.isEmpty
                    ? Text(context.l10n.continueNoTopics)
                    : Column(
                        children: [
                          for (final topic in session.weakTopics)
                            ListTile(
                              title: Text(topic.title),
                              subtitle: Text(topic.reason),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.studySessionResult,
                  arguments: StudySessionResultArgs(
                    subject: subject,
                    sessionId: session.id,
                    materialId: material.id,
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(context.l10n.studyContinueSession),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersistedContinue extends StatelessWidget {
  const _PersistedContinue({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final session = state.latestActiveStudyActivity;
    final material = session == null
        ? null
        : state.materialById(session.materialId);
    final subject = material == null
        ? null
        : state.subjectFor(material.subjectId);
    final usable = session != null && material != null && subject != null;
    return ResponsiveAppScaffold(
      title: context.l10n.continueStudyingTitle,
      activeRoute: AppRoutes.continueStudying,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            if (!usable)
              GlassCard(
                child: EmptyState(
                  title: context.l10n.continueEmptyTitle,
                  message: state.studyActivityErrorMessage == null
                      ? context.l10n.continueEmptyMessage
                      : context.localizedSafeMessage(
                          state.studyActivityErrorMessage!,
                        ),
                  icon: Icons.history_toggle_off_outlined,
                  action: FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.subjects),
                    child: Text(context.l10n.studyOpenSubjects),
                  ),
                ),
              )
            else ...[
              StudyContextHeader(
                title: subject.name,
                subtitle: context.l10n.continueFrom(material.title),
                status: _typeLabel(context, session),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: _typeLabel(context, session),
                icon: _icon(session.type),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.studyProgressValue(
                        session.currentIndex + 1,
                        session.totalItems,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(session.updatedAt.toLocal().toString()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _resume(context, session, material, subject),
                icon: const Icon(Icons.play_arrow),
                label: Text(context.l10n.studyContinueSession),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(BuildContext context, PersistedStudyActivity session) =>
      switch (session.type) {
        PersistedStudyActivityType.flashcards =>
          context.l10n.materialFlashcardsTitle,
        PersistedStudyActivityType.quizDraft => context.l10n.materialQuizTitle,
        PersistedStudyActivityType.quizMistakeReview =>
          context.l10n.quizMissedReview,
      };
  IconData _icon(PersistedStudyActivityType type) => switch (type) {
    PersistedStudyActivityType.flashcards => Icons.style_outlined,
    PersistedStudyActivityType.quizDraft => Icons.quiz_outlined,
    PersistedStudyActivityType.quizMistakeReview => Icons.rate_review_outlined,
  };
  void _resume(
    BuildContext context,
    PersistedStudyActivity session,
    dynamic material,
    dynamic subject,
  ) {
    if (session.type == PersistedStudyActivityType.flashcards) {
      final byId = {
        for (final card in state.flashcardsForMaterial(material.id))
          card.id: card,
      };
      final cards = [
        for (final id in session.itemIds)
          if (byId[id] != null) byId[id]!,
      ];
      if (cards.length != session.itemIds.length) {
        _error(context);
        return;
      }
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
    if (quiz == null) {
      _error(context);
      return;
    }
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

  void _error(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.continueUnavailableMessage)),
    );
  }
}
