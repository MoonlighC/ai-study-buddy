import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';

class ContinueStudyingScreen extends StatelessWidget {
  const ContinueStudyingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final session = state.latestStudySession;
    final subject = session == null ? null : state.subjects.where((item) => item.id == session.subjectId).firstOrNull;
    final material = session == null ? null : state.materialById(session.materialId);
    final usable = session != null && subject != null && material != null && material.subjectId == subject.id && state.canGenerateSummaryForMaterial(material);
    return ResponsiveAppScaffold(title: 'Continue Studying', activeRoute: AppRoutes.continueStudying,
      body: ResponsiveContent(width: ResponsiveContentWidth.reading, child: ListView(children: [
        if (!usable)
          GlassCard(child: EmptyState(title: 'Nothing to continue', message: session == null ? 'Start a study session from one of your subjects.' : 'The subject or source for your latest session is no longer available.', icon: Icons.history_toggle_off_outlined,
            action: FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.subjects), child: const Text('Open Subjects'))))
        else ...[
          StudyContextHeader(title: '${subject.name} review', subtitle: 'Continue from ${material.title}', status: 'Latest study session'),
          const SizedBox(height: 12),
          StudyModeCard(title: 'Session summary', child: Text(session.summary)),
          const SizedBox(height: 12),
          StudyModeCard(title: 'Quick quiz', icon: Icons.quiz_outlined, child: Text(session.quizScorePercent == null ? 'Not completed' : 'Last score: ${session.quizScorePercent}%')),
          const SizedBox(height: 12),
          StudyModeCard(title: 'Focus topics', icon: Icons.flag_outlined, child: session.weakTopics.isEmpty ? const Text('No focus topics recorded for this session.') : Column(children: [for (final topic in session.weakTopics) ListTile(title: Text(topic.title), subtitle: Text(topic.reason))])),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.studySessionResult, arguments: subject), icon: const Icon(Icons.play_arrow), label: const Text('Continue session')),
        ],
      ])),
    );
  }
}
