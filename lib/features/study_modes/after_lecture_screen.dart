import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_config.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/study_session.dart';
import '../../core/models/study_time_block.dart';
import '../../core/models/subject.dart';
import '../../core/models/persisted_study_activity.dart';
import '../../mock/mock_ai_service.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../study_sessions/study_session_result_screen.dart';
import '../auth/auth_controller.dart';
import '../flashcards/flashcard_training_screen.dart';
import '../quizzes/quiz_taking_screen.dart';

class AfterLectureScreen extends StatefulWidget {
  const AfterLectureScreen({super.key});
  @override
  State<AfterLectureScreen> createState() => _AfterLectureScreenState();
}

class _AfterLectureScreenState extends State<AfterLectureScreen> {
  static const ai = MockAiService();
  LectureConfidence confidence = LectureConfidence.mostly;
  Subject? selectedSubject;
  StudyMaterial? selectedMaterial;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;
    final subject =
        selectedSubject != null &&
            subjects.any((s) => s.id == selectedSubject!.id)
        ? selectedSubject
        : null;
    final materials = subject == null
        ? <StudyMaterial>[]
        : state.materialsFor(subject.id);
    final material =
        selectedMaterial != null &&
            materials.any((m) => m.id == selectedMaterial!.id)
        ? selectedMaterial
        : null;
    return ResponsiveAppScaffold(
      title: context.l10n.afterLectureTitle,
      showBack: true,
      showNavigation: false,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassStatusChip(
                label: context.l10n.afterLecturePrototype,
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                EmptyState(
                  title: context.l10n.studyNoSubjectsTitle,
                  message: context.l10n.afterLectureNoSubjectsMessage,
                  icon: Icons.folder_open_outlined,
                  action: FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.subjects),
                    child: Text(context.l10n.studyOpenSubjects),
                  ),
                )
              else ...[
                StudyModeCard(
                  title: context.l10n.studyChooseSubject,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in subjects)
                        ChoiceChip(
                          label: Text(item.name),
                          selected: subject?.id == item.id,
                          onSelected: (_) => setState(() {
                            selectedSubject = item;
                            selectedMaterial = null;
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (subject == null)
                  GlassCard(
                    child: EmptyState(
                      title: context.l10n.studySelectSubject,
                      message: context.l10n.studySelectSubjectMessage,
                      icon: Icons.touch_app_outlined,
                    ),
                  )
                else if (materials.isEmpty)
                  GlassCard(
                    child: EmptyState(
                      title: context.l10n.studyNoMaterialsTitle,
                      message: context.l10n.studyNoMaterialsMessage,
                      icon: Icons.article_outlined,
                    ),
                  )
                else
                  StudyModeCard(
                    title: context.l10n.studyChooseMaterial,
                    child: Column(
                      children: [
                        for (final item in materials)
                          ListTile(
                            leading: Icon(
                              material?.id == item.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              LocalizedFormatters.materialDate(
                                context.l10n,
                                item,
                              ),
                            ),
                            selected: material?.id == item.id,
                            onTap: () =>
                                setState(() => selectedMaterial = item),
                          ),
                      ],
                    ),
                  ),
                if (material != null) ...[
                  const SizedBox(height: 12),
                  StudyModeCard(
                    title: context.l10n.afterLectureConfidence,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in LectureConfidence.values)
                          ChoiceChip(
                            label: Text(
                              LocalizedFormatters.confidence(
                                context.l10n,
                                option,
                              ),
                            ),
                            selected: confidence == option,
                            onSelected: (_) =>
                                setState(() => confidence = option),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StudyModeCard(
                    title: context.l10n.afterLectureSchedule,
                    subtitle: context.l10n.afterLectureScheduleHelp,
                    child: Column(
                      children: [
                        for (final block in _blocksFor(confidence))
                          ListTile(
                            title: Text(
                              LocalizedFormatters.studyBlock(
                                context.l10n,
                                block.label,
                              ),
                            ),
                            trailing: Text(
                              context.l10n.studyMinutes(block.minutes),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StudyModeCard(
                    title: context.l10n.subjectStudyActions,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.materialDetail,
                            arguments: material,
                          ),
                          icon: const Icon(Icons.notes_outlined),
                          label: Text(context.l10n.materialSummaryTitle),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openFlashcards(
                            context,
                            state,
                            subject!,
                            material,
                          ),
                          icon: const Icon(Icons.style_outlined),
                          label: Text(context.l10n.materialFlashcardsTitle),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openQuiz(context, state, subject!, material),
                          icon: const Icon(Icons.quiz_outlined),
                          label: Text(context.l10n.materialQuizTitle),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _reviewMistakes(
                            context,
                            state,
                            subject!,
                            material,
                          ),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: Text(context.l10n.quizReviewMissed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      if (state.config.effectiveBackendMode ==
                          AppBackendMode.supabase) {
                        await _resumeOrStart(
                          context,
                          state,
                          subject!,
                          material,
                        );
                        return;
                      }
                      final session = state.createStudySession(
                        subject: subject!,
                        confidence: confidence,
                        materialId: material.id,
                      );
                      if (session == null) return;
                      Navigator.pushNamed(
                        context,
                        AppRoutes.studySessionResult,
                        arguments: StudySessionResultArgs(
                          subject: subject,
                          sessionId: session.id,
                          materialId: material.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(context.l10n.studyCreateSession),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openFlashcards(
    BuildContext context,
    AppState state,
    Subject subject,
    StudyMaterial material,
  ) {
    final cards = state.flashcardsForMaterial(material.id);
    if (cards.isEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.materialDetail,
        arguments: material,
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: subject,
        material: material,
        cards: cards,
      ),
    );
  }

  void _openQuiz(
    BuildContext context,
    AppState state,
    Subject subject,
    StudyMaterial material,
  ) {
    final quiz = state.latestQuizForMaterial(material.id);
    if (quiz == null) {
      Navigator.pushNamed(
        context,
        AppRoutes.materialDetail,
        arguments: material,
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: subject,
        material: material,
        quiz: quiz,
      ),
    );
  }

  Future<void> _reviewMistakes(
    BuildContext context,
    AppState state,
    Subject subject,
    StudyMaterial material,
  ) async {
    final attempt = state.latestQuizAttemptForMaterial(material.id);
    final quiz = attempt == null ? null : state.quizById(attempt.quizId);
    if (attempt == null || quiz == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.quizNoMissedTopics)));
      return;
    }
    final review = await state.startMistakeReviewActivity(
      AuthScope.read(context).user,
      attempt.id,
    );
    if (!context.mounted) return;
    if (review == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedSafeMessage(
              state.studyActivityErrorMessage ??
                  context.l10n.quizNoMissedTopics,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: subject,
        material: material,
        quiz: quiz,
        session: review,
      ),
    );
  }

  Future<void> _resumeOrStart(
    BuildContext context,
    AppState state,
    Subject subject,
    StudyMaterial material,
  ) async {
    final active = state.activeStudyActivities
        .where((item) => item.materialId == material.id)
        .firstOrNull;
    if (active != null) {
      Navigator.pushNamed(context, AppRoutes.continueStudying);
      return;
    }
    final cards = state.flashcardsForMaterial(material.id);
    if (cards.isNotEmpty) {
      final session = await state.startFlashcardActivity(
        user: AuthScope.read(context).user,
        material: material,
        cards: cards,
        mode: FlashcardTrainingMode.all,
      );
      if (!context.mounted) return;
      if (session != null) {
        Navigator.pushNamed(
          context,
          AppRoutes.flashcardTraining,
          arguments: FlashcardTrainingArgs(
            subject: subject,
            material: material,
            cards: cards,
            session: session,
          ),
        );
        return;
      }
    }
    Navigator.pushNamed(context, AppRoutes.materialDetail, arguments: material);
  }

  List<StudyTimeBlock> _blocksFor(LectureConfidence value) => switch (value) {
    LectureConfidence.understoodEverything => const [
      StudyTimeBlock(label: 'Summary', minutes: 3),
      StudyTimeBlock(label: 'Flashcards', minutes: 5),
      StudyTimeBlock(label: 'Quiz', minutes: 4),
    ],
    LectureConfidence.mostly => ai.studyTimeBlocks(),
    LectureConfidence.aboutHalf => const [
      StudyTimeBlock(label: 'Summary', minutes: 6),
      StudyTimeBlock(label: 'Flashcards', minutes: 14),
      StudyTimeBlock(label: 'Quiz', minutes: 10),
      StudyTimeBlock(label: 'Review mistakes', minutes: 8),
    ],
    LectureConfidence.completelyLost => const [
      StudyTimeBlock(label: 'Simple explanation', minutes: 10),
      StudyTimeBlock(label: 'Guided flashcards', minutes: 15),
      StudyTimeBlock(label: 'Quick quiz', minutes: 10),
      StudyTimeBlock(label: 'Review mistakes', minutes: 10),
    ],
  }.toList();
}
