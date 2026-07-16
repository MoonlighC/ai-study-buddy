import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import 'study_session_result_screen.dart';

class ContinueStudyingScreen extends StatelessWidget {
  const ContinueStudyingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
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
