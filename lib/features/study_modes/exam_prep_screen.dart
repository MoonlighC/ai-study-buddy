import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/study_session.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../study_sessions/study_session_result_screen.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  static const ai = MockAiService();
  Subject? selectedSubject;
  String? selectedMaterialId;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;
    final effectiveSubject = _selectedSubjectFrom(subjects);
    final materials = effectiveSubject == null
        ? []
        : state.materialsFor(effectiveSubject.id);
    final selectedMaterial = materials
        .where(
          (material) =>
              material.id == selectedMaterialId &&
              state.canGenerateSummaryForMaterial(material),
        )
        .firstOrNull;
    final weakTopics = effectiveSubject == null
        ? []
        : ai.weakTopicsFor(effectiveSubject);
    final plan = effectiveSubject == null
        ? []
        : ai.examPlanFor(effectiveSubject);

    return ResponsiveAppScaffold(
      title: context.l10n.examPrepTitle,
      showBack: true,
      showNavigation: false,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            GlassStatusChip(
              label: context.l10n.examPrepPrototype,
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.examPrepHeading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.examPrepHelp,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (effectiveSubject == null) ...[
              EmptyState(
                title: context.l10n.studyNoSubjectsTitle,
                message: context.l10n.examPrepNoSubjectsMessage,
                icon: Icons.folder_open_outlined,
                action: FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.subjects),
                  child: Text(context.l10n.studyOpenSubjects),
                ),
              ),
            ] else ...[
              StudyModeCard(
                title: context.l10n.studyChooseSubject,
                icon: Icons.folder_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in subjects)
                      ChoiceChip(
                        label: Text(subject.name),
                        selected: effectiveSubject.id == subject.id,
                        onSelected: (_) => setState(() {
                          selectedSubject = subject;
                          selectedMaterialId = null;
                        }),
                      ),
                  ],
                ),
              ),
              StudyModeCard(
                title: context.l10n.examPrepDatePreview,
                icon: Icons.event_outlined,
                subtitle: context.l10n.examPrepDateUnavailable,
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.examPrepDate,
                    hintText: context.l10n.examPrepMockDate,
                    enabled: false,
                    suffixIcon: IconButton(
                      tooltip: context.l10n.examPrepDateUnavailable,
                      onPressed: null,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ),
              StudyModeCard(
                title: context.l10n.examPrepMaterialsPreview,
                icon: Icons.article_outlined,
                child: Column(
                  children: [
                    if (materials.isEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.article_outlined),
                        title: Text(context.l10n.studyNoMaterialsTitle),
                        subtitle: Text(context.l10n.examPrepMaterialsEmptyHelp),
                      )
                    else
                      for (final material in materials)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          selected: selectedMaterialId == material.id,
                          leading: Icon(
                            selectedMaterialId == material.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          onTap: state.canGenerateSummaryForMaterial(material)
                              ? () => setState(
                                  () => selectedMaterialId = material.id,
                                )
                              : null,
                          title: Text(material.title),
                          subtitle: Text(
                            state.canGenerateSummaryForMaterial(material)
                                ? '${LocalizedFormatters.materialDate(context.l10n, material)} · ${context.l10n.examPrepIncluded}'
                                : context.l10n.studyUnavailableTitle,
                          ),
                        ),
                  ],
                ),
              ),
              StudyModeCard(
                title: context.l10n.examPrepTopicsPreview,
                icon: Icons.flag_outlined,
                subtitle: context.l10n.examPrepTopicsHelp,
                child: Column(
                  children: [
                    for (final topic in weakTopics)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(topic.title),
                        subtitle: Text(topic.reason),
                      ),
                  ],
                ),
              ),
              StudyModeCard(
                title: context.l10n.examPrepPlanPreview,
                icon: Icons.calendar_month_outlined,
                subtitle: context.l10n.examPrepPlanHelp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in plan)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(item),
                      ),
                    const SizedBox(height: 6),
                    Text(context.l10n.examPrepRecommendation),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: selectedMaterial == null
                    ? null
                    : () {
                        final session = AppStateScope.read(context)
                            .createStudySession(
                              subject: effectiveSubject,
                              confidence: LectureConfidence.mostly,
                              materialId: selectedMaterial.id,
                            );
                        if (session == null) return;
                        Navigator.pushNamed(
                          context,
                          AppRoutes.studySessionResult,
                          arguments: StudySessionResultArgs(
                            subject: effectiveSubject,
                            sessionId: session.id,
                            materialId: selectedMaterial.id,
                          ),
                        );
                      },
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(context.l10n.studyCreateSession),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Subject? _selectedSubjectFrom(List<Subject> subjects) {
    final current = selectedSubject;
    if (current != null && subjects.any((item) => item.id == current.id)) {
      return current;
    }
    return subjects.firstOrNull;
  }
}
