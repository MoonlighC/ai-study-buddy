import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../flashcards/flashcards_screen.dart';

class StudySessionResultArgs {
  const StudySessionResultArgs({
    required this.subject,
    required this.sessionId,
    required this.materialId,
  });

  final Subject subject;
  final String sessionId;
  final String materialId;
}

class StudySessionResultScreen extends StatelessWidget {
  const StudySessionResultScreen({required this.args, super.key});
  final StudySessionResultArgs args;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subject = args.subject;
    final candidate = state.sessionFor(args.sessionId);
    final session =
        candidate != null &&
            candidate.subjectId == subject.id &&
            candidate.materialId == args.materialId
        ? candidate
        : null;
    final material = state.materialById(args.materialId);
    final usable =
        session != null &&
        material != null &&
        material.subjectId == subject.id &&
        state.canGenerateSummaryForMaterial(material);
    return ResponsiveAppScaffold(
      title: context.l10n.studySessionTitle,
      showBack: true,
      showNavigation: false,
      subjectColor: Color(subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            if (!usable)
              EmptyState(
                key: const ValueKey('study-session-unavailable'),
                title: context.l10n.studyUnavailableTitle,
                message: context.l10n.sessionUnavailableForSubject(
                  subject.name,
                ),
                icon: Icons.article_outlined,
                action: OutlinedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.l10n.studyBackToSubject),
                ),
              )
            else ...[
              StudyContextHeader(
                title: subject.name,
                subtitle: context.l10n.sessionGeneratedFrom(material.title),
                status: context.l10n.sessionLocal,
              ),
              const SizedBox(height: 12),
              StudyCompletionCard(
                title: context.l10n.studySessionOverview,
                children: [
                  ListTile(
                    leading: const Icon(Icons.quiz_outlined),
                    title: Text(context.l10n.quizUiTitle),
                    trailing: Text(
                      session.quizScorePercent == null
                          ? context.l10n.studyNotCompleted
                          : LocalizedFormatters.percentage(
                              context.l10n,
                              session.quizScorePercent!,
                            ),
                    ),
                  ),
                  if (session.quizScorePercent == null)
                    Text(context.l10n.sessionNoAnswer),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(context.l10n.studyEstimatedTime),
                    trailing: Text(
                      context.l10n.studyMinutes(
                        session.studyTimeBlocks.fold<int>(
                          0,
                          (sum, block) => sum + block.minutes,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.studySummary,
                icon: Icons.summarize_outlined,
                child: Text(session.summary),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.studyFlashcardsAction,
                icon: Icons.style_outlined,
                child: session.flashcards.isEmpty
                    ? Text(context.l10n.sessionNoFlashcards)
                    : Column(
                        children: [
                          for (final card in session.flashcards)
                            ListTile(
                              title: Text(card.front),
                              subtitle: Text(
                                context.l10n.sessionTopic(card.topic),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.sessionQuickQuiz,
                icon: Icons.quiz_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(session.quizQuestion.question),
                    const SizedBox(height: 8),
                    for (final option in session.quizQuestion.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton(
                          onPressed: () => state.answerQuiz(
                            sessionId: session.id,
                            answer: option,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_answerLabel(context, session, option)),
                          ),
                        ),
                      ),
                    Text(session.feedback ?? context.l10n.sessionNoAnswer),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StudyModeCard(
                title: context.l10n.sessionFocusTopics,
                icon: Icons.flag_outlined,
                child: session.weakTopics.isEmpty
                    ? Text(context.l10n.sessionNoTopics)
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
              StudyModeCard(
                title: context.l10n.sessionPrototypeExplanation,
                subtitle: context.l10n.sessionPrototypeHelp,
                icon: Icons.science_outlined,
                child: Text(ai.mistakeExplanationFor(subject)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.flashcards,
                      arguments: FlashcardsRouteArgs(subject: subject),
                    ),
                    icon: const Icon(Icons.style_outlined),
                    label: Text(context.l10n.sessionMoreFlashcards),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.aiTeacher,
                      arguments: subject,
                    ),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: Text(context.l10n.sessionAskTeacher),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _answerLabel(
    BuildContext context,
    StudySession session,
    String option,
  ) {
    if (session.selectedAnswer != option) return option;
    return session.answeredCorrectly == true
        ? context.l10n.sessionCorrectOption(option)
        : context.l10n.sessionIncorrectOption(option);
  }
}
