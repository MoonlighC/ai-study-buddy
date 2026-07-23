import 'dart:async';

import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_attempt.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/core/models/study_session.dart';
import 'package:ai_study_buddy/core/models/weak_topic.dart';
import 'package:ai_study_buddy/core/models/knowledge_score.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/favorites/favorite_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/shared/widgets/study_components.dart';
import 'package:ai_study_buddy/features/generation/summary_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/material_lifecycle_repository.dart';
import 'package:ai_study_buddy/features/progress/weak_topic_repository.dart';
import 'package:ai_study_buddy/features/progress/study_progress_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_taking_screen.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:ai_study_buddy/features/study_sessions/study_session_result_screen.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:ai_study_buddy/shared/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login shell and enters dashboard', (tester) async {
    await tester.pumpWidget(const StudyBuddyApp());
    await tester.pumpAndSettle();

    expect(find.text('AI Study Buddy'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Google coming later'), findsOneWidget);
    expect(find.text('Apple coming later'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('Ready for your next study step?'), findsOneWidget);
    expect(find.text('After Lecture'), findsOneWidget);
    expect(find.text('Prepare for Exam'), findsOneWidget);
    expect(find.text('Continue Studying'), findsOneWidget);
  });

  testWidgets('adds pasted material to subject detail', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );
    await _tapVisible(tester, find.text('Add pasted text'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Material title'),
      'Cell respiration notes',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste lecture text'),
      'Cells release energy from glucose during respiration.',
    );
    await tester.tap(find.text('Save material'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Cell respiration notes'), findsOneWidget);
    expect(find.text('Just now · Pasted text'), findsOneWidget);

    await _tapVisible(tester, find.text('Cell respiration notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    await _scrollTo(
      tester,
      find.text('Cells release energy from glucose during respiration.'),
    );
    expect(
      find.text('Cells release energy from glucose during respiration.'),
      findsOneWidget,
    );
  });

  testWidgets('material deletion confirms, cancels, then returns to subject', (
    tester,
  ) async {
    await _enterDashboard(tester);
    final material = MockData.materials.first;
    await _pushRoute(tester, AppRoutes.materialDetail, arguments: material);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete material'));
    await tester.pumpAndSettle();
    expect(find.text('Delete material?'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    for (final label in [
      'Source material',
      'Uploaded file, if present',
      'Summary',
      'Material-specific flashcards',
      'Material-specific quizzes',
      'Completed quiz results',
      'Progress history',
      'Cumulative weak topics',
      'Study history',
    ]) {
      expect(
        find.descendant(of: dialog, matching: find.text(label)),
        findsOneWidget,
      );
    }
    const malformedBullet = '\u0432\u0402\u045e';
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining(malformedBullet),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Delete material'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(material.title), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete material'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete material'));
    await tester.pumpAndSettle();

    expect(find.text('Material deleted.'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text(material.title), findsNothing);
  });

  testWidgets('material deletion falls back to the previous valid route', (
    tester,
  ) async {
    const material = StudyMaterial(
      id: 'orphan-material',
      subjectId: 'missing-origin',
      title: 'Orphan notes',
      kind: MaterialKind.pastedText,
      content: 'Disposable content.',
      createdLabel: 'Today',
    );
    final lifecycle = _WidgetMaterialLifecycle();
    await tester.pumpWidget(
      StudyBuddyApp(
        materialRepository: MockMaterialRepository(
          initialMaterials: const [material],
        ),
        materialLifecycleRepository: lifecycle,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.materialDetail, arguments: material);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete material'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete material'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-scroll-view')), findsOneWidget);
    expect(find.text('Orphan notes'), findsNothing);
    expect(find.text('Material deleted.'), findsOneWidget);
    expect(lifecycle.deleteCalls, 1);
  });

  testWidgets('failed material deletion stays on detail without navigation', (
    tester,
  ) async {
    final lifecycle = _WidgetMaterialLifecycle(fail: true);
    await tester.pumpWidget(
      StudyBuddyApp(materialLifecycleRepository: lifecycle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    final material = MockData.materials.first;
    await _pushRoute(tester, AppRoutes.materialDetail, arguments: material);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete material'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete material'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('material-detail-scroll-view')), findsOne);
    expect(find.text(material.title), findsOneWidget);
    expect(find.text('Could not delete the material. Try again.'), findsOne);
    expect(lifecycle.deleteCalls, 1);
  });

  testWidgets('completed deletion does not navigate with a disposed context', (
    tester,
  ) async {
    final gate = Completer<void>();
    final lifecycle = _WidgetMaterialLifecycle(gate: gate);
    await tester.pumpWidget(
      StudyBuddyApp(materialLifecycleRepository: lifecycle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    final material = MockData.materials.first;
    await _pushRoute(tester, AppRoutes.materialDetail, arguments: material);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete material'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete material'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-scroll-view')), findsOneWidget);
    expect(lifecycle.deleteCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite toggle updates favorites screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    await tester.ensureVisible(find.byTooltip('Favorite').first);
    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Where does photosynthesis happen?'), findsOneWidget);
  });

  testWidgets('favorites can unfavorite and remove a card', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('What is photosynthesis?'), findsOneWidget);

    await tester.tap(find.byTooltip('Unfavorite').first);
    await tester.pumpAndSettle();

    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('material favorites appear on favorites screen in mock mode', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );

    await _tapVisible(tester, find.byTooltip('Favorite material').first);
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);
    expect(find.text('What is photosynthesis?'), findsOneWidget);
  });

  testWidgets('material detail creates a source-specific study session', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);
    await _scrollTo(
      tester,
      find.textContaining(
        'Plants convert light, water, and carbon dioxide into glucose',
      ),
    );
    expect(
      find.textContaining(
        'Plants convert light, water, and carbon dioxide into glucose',
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Create study session'));
    await tester.tap(find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.text('Study Session'), findsOneWidget);
    expect(
      find.text('Generated from: Photosynthesis lecture notes'),
      findsOneWidget,
    );
    expect(find.textContaining('Normal review'), findsOneWidget);
    expect(
      find.textContaining('Source "Photosynthesis lecture notes" says'),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.text('Which source did this study session use?'),
    );
    expect(
      find.text('Which source did this study session use?'),
      findsOneWidget,
    );
  });

  testWidgets('material detail generates and renders mock summary', (
    tester,
  ) async {
    final summaryRepository = _RecordingSummaryRepository(
      summary: 'Widget summary from the selected material.',
    );
    await tester.pumpWidget(
      StudyBuddyApp(summaryRepository: summaryRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('No summary yet.'), findsOneWidget);

    await tester.tap(find.text('Generate mock summary'));
    await tester.pumpAndSettle();

    expect(summaryRepository.generatedMaterialIds, ['bio-lecture-1']);
    expect(
      find.text('Widget summary from the selected material.'),
      findsOneWidget,
    );
  });

  testWidgets('material detail shows helper for too-short summary input', (
    tester,
  ) async {
    const shortMaterial = StudyMaterial(
      id: 'short-material',
      subjectId: 'biology',
      title: 'Tiny note',
      kind: MaterialKind.pastedText,
      content: 'Test',
      createdLabel: 'Today',
    );
    final summaryRepository = _RecordingSummaryRepository();

    await tester.pumpWidget(
      StudyBuddyApp(summaryRepository: summaryRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: shortMaterial,
    );

    expect(
      find.text('Add more lecture text before generating a summary.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate mock summary'),
    );
    expect(button.onPressed, isNull);
    expect(summaryRepository.generatedMaterialIds, isEmpty);
  });

  testWidgets('material detail shows loading while summary generates', (
    tester,
  ) async {
    final completer = Completer<String>();
    final summaryRepository = _RecordingSummaryRepository(
      pendingSummary: completer.future,
    );
    await tester.pumpWidget(
      StudyBuddyApp(summaryRepository: summaryRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await tester.tap(find.text('Generate mock summary'));
    await tester.pump();

    expect(find.text('Generating summary'), findsOneWidget);

    completer.complete('Finished mock summary.');
    await tester.pumpAndSettle();

    expect(find.text('Finished mock summary.'), findsOneWidget);
  });

  testWidgets('material detail summary failure shows safe error', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        summaryRepository: _RecordingSummaryRepository(throwOnGenerate: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await tester.tap(find.text('Generate mock summary'));
    await tester.pumpAndSettle();

    expect(find.text('Could not generate summary. Try again.'), findsWidgets);
  });

  testWidgets('material detail generates and renders mock flashcards', (
    tester,
  ) async {
    final flashcardRepository = _RecordingFlashcardRepository(
      generatedCards: const [
        Flashcard(
          id: 'generated-card-1',
          subjectId: 'biology',
          materialId: 'bio-lecture-1',
          front: 'Generated card front',
          back: 'Generated card back',
          topic: 'Generated topic',
          isFavorite: false,
        ),
      ],
    );
    await tester.pumpWidget(
      StudyBuddyApp(flashcardRepository: flashcardRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Flashcards'));

    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Generate flashcards'), findsOneWidget);

    await _scrollTo(tester, find.text('Generate flashcards'));
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(flashcardRepository.generatedMaterialIds, ['bio-lecture-1']);
    expect(find.text('1 flashcard ready.'), findsOneWidget);
    expect(find.text('Review these flashcards'), findsOneWidget);
  });

  testWidgets('material detail shows loading while flashcards generate', (
    tester,
  ) async {
    final completer = Completer<FlashcardGenerationResult>();
    final flashcardRepository = _RecordingFlashcardRepository(
      pendingCards: completer.future,
    );
    await tester.pumpWidget(
      StudyBuddyApp(flashcardRepository: flashcardRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Generate flashcards'));
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pump();

    expect(find.text('Generating flashcards'), findsOneWidget);

    completer.complete(
      const FlashcardGenerationResult(
        requestedCount: 5,
        createdCount: 1,
        newFlashcards: [
          Flashcard(
            id: 'generated-card-1',
            subjectId: 'biology',
            materialId: 'bio-lecture-1',
            front: 'Generated card front',
            back: 'Generated card back',
            topic: 'Generated topic',
            isFavorite: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 flashcard ready.'), findsOneWidget);
  });

  testWidgets('material detail flashcard failure shows safe error', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        flashcardRepository: _RecordingFlashcardRepository(
          throwOnGenerate: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Generate flashcards'));
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not generate flashcards. Try again.'),
      findsWidgets,
    );
  });

  testWidgets('material detail generates and renders mock quiz', (
    tester,
  ) async {
    final quizRepository = _RecordingQuizRepository(generatedQuiz: _widgetQuiz);
    await tester.pumpWidget(StudyBuddyApp(quizRepository: quizRepository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Generate mock quiz'));
    await tester.tap(find.text('Generate mock quiz'));
    await tester.pumpAndSettle();

    expect(quizRepository.generatedMaterialIds, ['bio-lecture-1']);
    expect(find.text('1 question ready.'), findsOneWidget);
    expect(find.text('Take quiz'), findsOneWidget);
  });

  testWidgets('material detail quiz failure shows safe error', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        quizRepository: _RecordingQuizRepository(throwOnGenerate: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Generate mock quiz'));
    await tester.tap(find.text('Generate mock quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Could not generate quiz. Try again.'), findsWidgets);
  });

  testWidgets('take quiz opens generated questions and shows score', (
    tester,
  ) async {
    final quizRepository = _RecordingQuizRepository(generatedQuiz: _widgetQuiz);
    await tester.pumpWidget(StudyBuddyApp(quizRepository: quizRepository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    await _scrollTo(tester, find.text('Generate mock quiz'));
    await tester.tap(find.text('Generate mock quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Widget quiz'), findsOneWidget);
    expect(find.text('What does this material explain?'), findsOneWidget);

    await tester.tap(find.text('The core idea'));
    await tester.pumpAndSettle();

    expect(find.text('The core idea'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('The material supports the core idea.'), findsOneWidget);

    await tester.tap(find.text('Show score'));
    await tester.pumpAndSettle();

    expect(find.text('1 correct answer out of 1'), findsOneWidget);
    expect(find.text('Score: 100%'), findsOneWidget);
    expect(find.text('No missed topics. Great work!'), findsOneWidget);
    expect(find.text('Review missed questions'), findsNothing);
    expect(quizRepository.savedAttempts, hasLength(1));
    expect(quizRepository.savedAttempts.single.correctQuestions, 1);

    await tester.tap(find.text('Retry quiz'));
    await tester.pumpAndSettle();
    expect(find.text('What does this material explain?'), findsOneWidget);
    expect(find.text('The core idea'), findsOneWidget);

    await tester.tap(find.text('The core idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show score'));
    await tester.pumpAndSettle();
    expect(quizRepository.savedAttempts, hasLength(2));
    expect(
      quizRepository.savedAttempts.first.id,
      isNot(quizRepository.savedAttempts.last.id),
    );
  });

  testWidgets('missed quiz topic is shown and save failure is non-blocking', (
    tester,
  ) async {
    final quizRepository = _RecordingQuizRepository(throwOnSave: true);
    await tester.pumpWidget(StudyBuddyApp(quizRepository: quizRepository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: MockData.subjects.first,
        material: MockData.materials.first,
        quiz: _widgetQuiz,
      ),
    );

    await tester.tap(find.text('An unrelated upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show score'));
    await tester.pumpAndSettle();

    expect(find.text('Score: 0%'), findsOneWidget);
    expect(find.text('0 correct answers out of 1'), findsOneWidget);
    expect(find.text('Core idea'), findsOneWidget);
    expect(find.text('Could not save this quiz attempt.'), findsWidgets);
    expect(find.text('Review material'), findsOneWidget);
    expect(find.text('Retry quiz'), findsOneWidget);
    expect(find.text('Review missed questions'), findsOneWidget);

    final originalAttempt = quizRepository.savedAttempts.single;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review missed questions'));
    await tester.pumpAndSettle();

    expect(find.text('Missed question review'), findsOneWidget);
    expect(find.text('What does this material explain?'), findsOneWidget);
    await tester.tap(find.text('The core idea'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('The material supports the core idea.'), findsOneWidget);
    await _scrollTo(tester, find.text('Finish review'));
    await tester.tap(find.text('Finish review'));
    await tester.pumpAndSettle();

    expect(find.text('Score: 0%'), findsOneWidget);
    expect(quizRepository.savedAttempts, hasLength(1));
    expect(quizRepository.savedAttempts.single, same(originalAttempt));
  });

  testWidgets(
    'randomized attempt saves displayed order and reviews only misses',
    (tester) async {
      final repository = _RecordingQuizRepository();
      await tester.pumpWidget(StudyBuddyApp(quizRepository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await _pushRoute(
        tester,
        AppRoutes.quizTaking,
        arguments: QuizTakingArgs(
          subject: MockData.subjects.first,
          material: MockData.materials.first,
          quiz: _multiQuestionWidgetQuiz,
          randomSeed: 23,
        ),
      );

      final displayedQuestionIds = <String>[];
      final missedQuestionTexts = <String>[];
      for (var index = 0; index < 3; index += 1) {
        final question = _visibleQuestion(tester, _multiQuestionWidgetQuiz);
        displayedQuestionIds.add(question.id);
        final answer = question.id == 'multi-question-2'
            ? question.correctAnswer
            : question.options.firstWhere(
                (option) => option != question.correctAnswer,
              );
        if (answer != question.correctAnswer) {
          missedQuestionTexts.add(question.question);
        }
        await tester.tap(find.text(answer));
        await tester.pumpAndSettle();
        if (answer != question.correctAnswer) {
          expect(
            find.text('Correct answer: ${question.correctAnswer}'),
            findsOneWidget,
          );
        }
        await tester.tap(find.text(index == 2 ? 'Show score' : 'Next'));
        await tester.pumpAndSettle();
      }

      expect(
        repository.savedAttempts.single.answers.map(
          (answer) => answer.questionId,
        ),
        displayedQuestionIds,
      );
      expect(find.text('Review missed questions'), findsOneWidget);
      await tester.tap(find.text('Review missed questions'));
      await tester.pumpAndSettle();

      expect(find.text('Question two'), findsNothing);
      for (var index = 0; index < missedQuestionTexts.length; index += 1) {
        expect(find.text(missedQuestionTexts[index]), findsOneWidget);
        final question = _multiQuestionWidgetQuiz.questions.firstWhere(
          (item) => item.question == missedQuestionTexts[index],
        );
        await tester.tap(find.text(question.correctAnswer));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            index == missedQuestionTexts.length - 1 ? 'Finish review' : 'Next',
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(repository.savedAttempts, hasLength(1));
      expect(find.text('Result'), findsOneWidget);
    },
  );

  testWidgets('attempt order survives rebuild and retry reinitializes it', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      StudyBuddyApp(quizRepository: _RecordingQuizRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: MockData.subjects.first,
        material: MockData.materials.first,
        quiz: _multiQuestionWidgetQuiz,
        randomSeed: 41,
      ),
    );

    final firstQuestion = _visibleQuestion(tester, _multiQuestionWidgetQuiz);
    final firstSignature = [firstQuestion.id, ..._visibleOptionLabels(tester)];
    await tester.binding.setSurfaceSize(const Size(780, 650));
    await tester.pumpAndSettle();

    expect([
      _visibleQuestion(tester, _multiQuestionWidgetQuiz).id,
      ..._visibleOptionLabels(tester),
    ], firstSignature);

    for (var index = 0; index < 3; index += 1) {
      final question = _visibleQuestion(tester, _multiQuestionWidgetQuiz);
      await tester.tap(find.text(question.correctAnswer));
      await tester.pumpAndSettle();
      await tester.tap(find.text(index == 2 ? 'Show score' : 'Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Retry quiz'));
    await tester.pumpAndSettle();

    final retryQuestion = _visibleQuestion(tester, _multiQuestionWidgetQuiz);
    final retrySignature = [retryQuestion.id, ..._visibleOptionLabels(tester)];
    expect(retrySignature, isNot(firstSignature));
  });

  testWidgets('review material returns from completed quiz', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(quizRepository: _RecordingQuizRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );
    await _pushRoute(
      tester,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: MockData.subjects.first,
        material: MockData.materials.first,
        quiz: _widgetQuiz,
      ),
    );
    await tester.tap(find.text('The core idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show score'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review material'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
  });

  testWidgets('progress shows latest quiz and weak topic', (tester) async {
    final repository = _RecordingQuizRepository(attempts: [_progressAttempt]);
    await tester.pumpWidget(StudyBuddyApp(quizRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.progress);

    expect(find.text('Score: 50%'), findsOneWidget);
    expect(find.text('1 correct answer out of 2'), findsOneWidget);
    await _scrollTo(tester, find.text('Cell division'));
    expect(find.text('Cell division'), findsOneWidget);
    expect(find.text('1 miss'), findsOneWidget);
  });

  testWidgets('progress shows safe empty quiz state', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.progress);

    expect(find.text('Complete a quiz to see results here.'), findsOneWidget);
    await _scrollTo(
      tester,
      find.text('Complete a quiz to build your progress history.'),
    );
    expect(
      find.text('Complete a quiz to build your progress history.'),
      findsOneWidget,
    );
  });

  testWidgets('supabase progress shows real cumulative data only', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        subjectRepository: MockSubjectRepository(
          initialSubjects: [MockData.subjects.first],
        ),
        quizRepository: _RecordingQuizRepository(attempts: [_progressAttempt]),
        weakTopicRepository: _StaticWeakTopicRepository([
          CumulativeWeakTopic(
            id: 'progress-weak',
            subjectId: 'biology',
            topic: 'Cell division',
            topicKey: 'cell division',
            missCount: 4,
            lastSeenAt: DateTime.utc(2026, 7, 10),
          ),
        ]),
        studyProgressRepository: _StaticStudyProgressRepository(
          _widgetStudyProgress(withEvidence: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.progress);

    expect(find.text('Knowledge score'), findsOneWidget);
    expect(find.text('50.00%'), findsWidgets);
    expect(find.text('4 misses'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Knowledge scores'), findsNothing);
    expect(find.text('Study history'), findsNothing);
    expect(find.text('Streak placeholder'), findsNothing);

    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );
    expect(find.text('Focus topics'), findsOneWidget);
    expect(find.text('Cell division'), findsOneWidget);
    expect(find.text('4 misses'), findsOneWidget);
  });

  testWidgets('supabase progress shows cumulative empty state', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        weakTopicRepository: const _StaticWeakTopicRepository([]),
        studyProgressRepository: _StaticStudyProgressRepository(
          _widgetStudyProgress(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.progress);

    expect(find.text('Not enough activity'), findsOneWidget);
    expect(find.text('Knowledge scores'), findsNothing);
  });

  testWidgets('flashcards screen shows Start training when cards exist', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    expect(find.text('2 cards available for this selection.'), findsOneWidget);
    expect(find.text('Start training (2 cards)'), findsOneWidget);

    await tester.tap(find.text('Start training (2 cards)'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('flashcards size chips disable unavailable larger sessions', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, _reviewCards(5));

    expect(find.text('5 cards available for this selection.'), findsOneWidget);
    expect(
      find.text(
        'Generate more flashcards from a material to unlock larger sessions.',
      ),
      findsOneWidget,
    );
    _expectChoiceEnabled(tester, '5');
    _expectChoiceDisabled(tester, '10');
    _expectChoiceDisabled(tester, '20');
    expect(find.text('Start training (5 cards)'), findsOneWidget);
  });

  testWidgets('custom session size above availability shows safe message', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, _reviewCards(5));

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cards'), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Only 5 cards are available for this selection.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Generate more flashcards from a material to unlock larger sessions.',
      ),
      findsWidgets,
    );
  });

  testWidgets('custom session size validates minimum card count', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, _reviewCards(5));

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cards'), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Choose at least 1 card.'), findsOneWidget);
  });

  testWidgets('filter changes update available count and custom cap', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, [
      _weakReviewCard,
      _weakReviewCard.copyWith(id: 'weak-review-card-2', front: 'Weak front 2'),
      _knownReviewCard,
      _knownReviewCard.copyWith(
        id: 'known-review-card-2',
        front: 'Known front 2',
      ),
      _futureReviewCard,
    ]);

    expect(find.text('5 cards available for this selection.'), findsOneWidget);

    await tester.tap(find.text('For review'));
    await tester.pumpAndSettle();

    expect(find.text('2 cards available for this selection.'), findsOneWidget);
    expect(find.text('Start training (2 cards)'), findsOneWidget);

    await tester.tap(find.text('Due for review'));
    await tester.pumpAndSettle();

    expect(find.text('0 cards available for this selection.'), findsOneWidget);
    expect(find.text('No cards are due right now.'), findsWidgets);
    expect(find.textContaining('Start training'), findsNothing);
    _expectChoiceDisabled(tester, 'Custom');
  });

  testWidgets('custom valid size starts training with requested cards', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, _reviewCards(5));

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cards'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Start training (3 cards)'), findsOneWidget);

    await tester.tap(find.text('Start training (3 cards)'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('mock flashcards cap larger default session size', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.settings);
    await _scrollTo(tester, find.text('Default flashcard session size'));
    await tester.tap(find.widgetWithText(ChoiceChip, '10'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    expect(find.text('2 cards available for this selection.'), findsOneWidget);
    expect(find.text('Start training (2 cards)'), findsOneWidget);

    await tester.tap(find.text('Start training (2 cards)'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('flashcards screen hides and toggles browse answers', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    expect(find.text('What is photosynthesis?'), findsOneWidget);
    expect(
      find.textContaining(
        'The process plants use to convert light energy into glucose.',
      ),
      findsNothing,
    );

    await tester.ensureVisible(find.byTooltip('Show answer').first);
    await tester.tap(find.byTooltip('Show answer').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The process plants use to convert light energy into glucose.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byTooltip('Hide answer').first);
    await tester.tap(find.byTooltip('Hide answer').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The process plants use to convert light energy into glucose.',
      ),
      findsNothing,
    );
  });

  testWidgets('weak filter shows only weak cards', (tester) async {
    await _pumpFlashcardsHarness(tester, [
      _weakReviewCard,
      _knownReviewCard,
      _dueReviewCard,
    ]);

    await tester.tap(find.text('For review'));
    await tester.pumpAndSettle();

    expect(find.text('Weak front'), findsOneWidget);
    expect(find.text('Known front'), findsNothing);
    expect(find.text('Due front'), findsNothing);
  });

  testWidgets('due filter shows only due cards', (tester) async {
    await _pumpFlashcardsHarness(tester, [
      _weakReviewCard,
      _knownReviewCard,
      _dueReviewCard,
      _futureReviewCard,
    ]);

    await tester.tap(find.text('Due for review'));
    await tester.pumpAndSettle();

    expect(find.text('Due front'), findsOneWidget);
    expect(find.text('Future front'), findsNothing);
    expect(find.text('Weak front'), findsNothing);
  });

  testWidgets('review-focus action starts training with weak cards only', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, [_weakReviewCard, _knownReviewCard]);

    await tester.ensureVisible(find.text('Train cards for review'));
    await tester.tap(find.text('Train cards for review'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Weak front'), findsOneWidget);
    expect(find.text('Known front'), findsNothing);
  });

  testWidgets('Review due cards starts training with due cards only', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, [_dueReviewCard, _futureReviewCard]);

    await tester.ensureVisible(find.text('Review due cards'));
    await tester.tap(find.text('Review due cards'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Due front'), findsOneWidget);
    expect(find.text('Future front'), findsNothing);
  });

  testWidgets('training shows front first and Show answer reveals back', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_trainingCardOne],
      ),
    );

    expect(find.text('Training front 1'), findsOneWidget);
    expect(find.text('Training back 1'), findsNothing);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();

    expect(find.text('Training back 1'), findsOneWidget);
    expect(find.text('I missed it'), findsOneWidget);
    expect(find.text('I knew it'), findsOneWidget);
  });

  testWidgets('tapping training card reveals back', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_trainingCardOne],
      ),
    );

    await tester.tap(find.byType(FlashcardSurface).first);
    await tester.pumpAndSettle();

    expect(find.text('Training back 1'), findsOneWidget);
  });

  testWidgets('rating advances and completion can review again', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_trainingCardOne, _trainingCardTwo],
      ),
    );

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Training front 2'), findsOneWidget);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I missed it'));
    await tester.pumpAndSettle();

    expect(find.text('Training complete'), findsWidgets);
    expect(find.text('2 cards reviewed'), findsOneWidget);
    expect(find.text('1 card known'), findsOneWidget);
    expect(find.text('1 card missed'), findsOneWidget);

    await tester.tap(find.text('Review again'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Training front 1'), findsOneWidget);
  });

  testWidgets('completion can review missed cards again', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_trainingCardOne, _trainingCardTwo],
      ),
    );

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I missed it'));
    await tester.pumpAndSettle();

    expect(find.text('Review missed cards again'), findsOneWidget);

    await tester.tap(find.text('Review missed cards again'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Training front 2'), findsOneWidget);
    expect(find.text('Training front 1'), findsNothing);
  });

  testWidgets('supabase training sends review result to repository', (
    tester,
  ) async {
    final flashcardRepository = _RecordingFlashcardRepository(
      loadedCards: const [_cloudTrainingCard],
    );
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(),
        favoriteRepository: _RecordingFavoriteRepository(),
        flashcardRepository: flashcardRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.flashcards, arguments: subject);

    await tester.tap(find.text('Start training (1 card)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();

    expect(flashcardRepository.reviewedUsers, [_supabaseUser]);
    expect(flashcardRepository.reviewedCardIds, ['cloud-training-card']);
    expect(flashcardRepository.reviewResults, [FlashcardReviewResult.known]);
  });

  testWidgets('training review failure shows safe error', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        flashcardRepository: _RecordingFlashcardRepository(throwOnReview: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_trainingCardOne],
      ),
    );

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save review progress.'), findsOneWidget);
    expect(find.text('Training back 1'), findsOneWidget);
    expect(find.text('I knew it'), findsOneWidget);
  });

  testWidgets('supabase training with no flashcards shows empty state', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.flashcardTraining,
      arguments: const FlashcardTrainingArgs(subject: subject, cards: []),
    );

    expect(find.text('Generate flashcards first.'), findsOneWidget);
  });

  testWidgets('bottom navigation opens core routes', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.byKey(const ValueKey('nav-subjects')));
    await tester.pumpAndSettle();

    expect(find.text('Your subjects'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-progress')));
    await tester.pumpAndSettle();

    expect(find.text('Knowledge scores'), findsNothing);
    expect(find.text('Progress'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    expect(
      find.text('Mock preferences for the local prototype.'),
      findsOneWidget,
    );
  });

  testWidgets('settings renders real controls and usage navigation', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('Edit name'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);

    await _scrollTo(tester, find.text('Study Preferences'));

    expect(find.text('Study Preferences'), findsOneWidget);

    await _scrollTo(tester, find.text('Usage & Limits'));

    expect(find.text('Daily usage and generation policy'), findsOneWidget);
    expect(
      find.text('View today’s authoritative usage and reset time.'),
      findsOneWidget,
    );

    await _scrollTo(tester, find.text('Support'));

    expect(find.text('Report a bug placeholder'), findsOneWidget);
    expect(find.text('Contact support placeholder'), findsOneWidget);
    expect(find.text('Send feedback placeholder'), findsOneWidget);

    await _scrollTo(tester, find.text('About / Debug'));

    expect(find.text('0.1.0 placeholder'), findsNothing);
    expect(find.text('mock'), findsOneWidget);
    expect(
      find.text('No server secrets or OpenAI key in Flutter.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings updates local preferences and flashcards default size',
    (tester) async {
      await _enterDashboard(tester);
      await _pushRoute(tester, AppRoutes.settings);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, 'Deutsch');

      await _scrollTo(
        tester,
        find.text('Standardgröße für Karteikarten-Sitzungen'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '10'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '10');

      await _scrollTo(tester, find.text('Tägliches Lernziel'));
      await tester.tap(find.text('30 Min.'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '30 Min.');

      await _scrollTo(tester, find.text('Standard-Schwierigkeit'));
      await tester.tap(find.text('Prüfung'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, 'Prüfung');

      await _pushRoute(
        tester,
        AppRoutes.flashcards,
        arguments: MockData.subjects.first,
      );

      _expectChoiceSelected(tester, '10');
    },
  );

  testWidgets('mock settings logout returns to login screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('What do you want to do today?'), findsNothing);
  });

  testWidgets('supabase auth UI renders email form and placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with email'), findsNothing);
    expect(find.text('Google coming later'), findsOneWidget);
    expect(find.text('Apple coming later'), findsOneWidget);
  });

  testWidgets('auth layout uses constraints for phone and desktop', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-single-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-split-layout')), findsNothing);

    await _setTestViewport(tester, const Size(1280, 900));
    await tester.pumpWidget(
      StudyBuddyApp(
        key: UniqueKey(),
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-split-layout')), findsOneWidget);
  });

  testWidgets('auth layout falls back at 800 and large text scale', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(800, 900));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-single-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-split-layout')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login password visibility toggle works', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Password').obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Password').obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Password').obscureText, isTrue);
  });

  testWidgets('supabase login Create account navigates to signup', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your study profile.'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('signup screen renders name email and password fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('signup missing name prevents repository call', (tester) async {
    final authRepository = _RecordingAuthRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(authRepository.signUpCount, 0);
  });

  testWidgets('signup empty confirm password prevents repository call', (
    tester,
  ) async {
    final authRepository = _RecordingAuthRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Casey Student',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm your password.'), findsOneWidget);
    expect(authRepository.signUpCount, 0);
  });

  testWidgets('signup mismatched passwords prevents repository call', (
    tester,
  ) async {
    final authRepository = _RecordingAuthRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Casey Student',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'secret2',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(authRepository.signUpCount, 0);
  });

  testWidgets('signup forwards display name and ensures profile with it', (
    tester,
  ) async {
    final authRepository = _RecordingAuthRepository();
    final profileRepository = _RecordingProfileRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Casey Student',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(authRepository.signUpCount, 1);
    expect(authRepository.signUpDisplayNames, ['Casey Student']);
    expect(profileRepository.ensuredUsers.single.displayName, 'Casey Student');
    expect(find.text('Ready for your next study step?'), findsOneWidget);
  });

  testWidgets('login shows field errors and a prominent recovery action', (
    tester,
  ) async {
    final authRepository = _RecordingAuthRepository();
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('forgot-password-action')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(authRepository.signInCount, 0);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'not-an-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('signup password visibility toggle works', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    expect(_textField(tester, 'Password').obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Password').obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Password').obscureText, isTrue);
  });

  testWidgets('signup confirm password visibility toggle works', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    expect(_textField(tester, 'Confirm password').obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').last);
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Confirm password').obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Confirm password').obscureText, isTrue);
  });

  testWidgets('signup already registered error shows friendly message', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          signUpError: const AuthRepositoryException('User already registered'),
        ),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Casey Student',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'An account already exists for this email. Try logging in instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('supabase settings shows profile display name', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: _RecordingProfileRepository(
          profile: const AuthProfile(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Profile Learner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('Profile Learner'), findsOneWidget);
    expect(find.text('Metadata Learner'), findsNothing);
    expect(find.text('learner@example.test'), findsOneWidget);
  });

  testWidgets('edit name dialog rejects blank value', (tester) async {
    final profileRepository = _RecordingProfileRepository(
      profile: const AuthProfile(
        id: 'supabase-user',
        email: 'learner@example.test',
        displayName: 'Profile Learner',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(profileRepository.updatedDisplayNames, isEmpty);
  });

  testWidgets('edit name saves and updates visible Account name', (
    tester,
  ) async {
    final profileRepository = _RecordingProfileRepository(
      profile: const AuthProfile(
        id: 'supabase-user',
        email: 'learner@example.test',
        displayName: 'Profile Learner',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Updated Learner',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(profileRepository.updatedDisplayNames, ['Updated Learner']);
    expect(find.text('Updated Learner'), findsOneWidget);
    expect(find.text('Profile Learner'), findsNothing);
  });

  testWidgets('supabase settings logout calls auth repository', (tester) async {
    final authRepository = _RecordingAuthRepository(
      initialUser: const AuthUser(
        id: 'supabase-user',
        email: 'learner@example.test',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('learner@example.test'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(authRepository.signOutCount, 1);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('What do you want to do today?'), findsNothing);
  });

  testWidgets('supabase subjects load from fake repository after auth', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [
            Subject(
              id: 'cloud-biology',
              name: 'Cloud Biology',
              description: 'Synced from Supabase',
              colorValue: 0xFF16A34A,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjects);

    expect(find.text('Cloud Biology'), findsOneWidget);
    expect(find.text('Synced from Supabase'), findsOneWidget);
    expect(find.text('Biology'), findsNothing);
  });

  testWidgets('supabase subject create uses repository and updates UI', (
    tester,
  ) async {
    final subjectRepository = _RecordingSubjectRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: subjectRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjects);

    await tester.tap(find.byKey(const ValueKey('subjects-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Subject name'),
      'History',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Exam prep',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(subjectRepository.createdNames, ['History']);
    expect(subjectRepository.createdUsers, [_supabaseUser]);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Exam prep'), findsOneWidget);
  });

  testWidgets('supabase subject sync failure shows safe error', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(throwOnLoad: true),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjects);

    expect(find.text('Could not sync subjects. Try again.'), findsOneWidget);
    expect(find.text('Your app is still usable.'), findsOneWidget);
  });

  testWidgets('supabase materials load from fake repository after auth', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [
            Subject(
              id: 'cloud-biology',
              name: 'Cloud Biology',
              description: 'Synced from Supabase',
              colorValue: 0xFF16A34A,
            ),
          ],
        ),
        materialRepository: _RecordingMaterialRepository(
          loadedMaterials: const [
            StudyMaterial(
              id: 'cloud-material',
              subjectId: 'cloud-biology',
              title: 'Cloud lecture notes',
              kind: MaterialKind.pastedText,
              content: 'Synced material text.',
              createdLabel: 'Synced',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: const Subject(
        id: 'cloud-biology',
        name: 'Cloud Biology',
        description: 'Synced from Supabase',
        colorValue: 0xFF16A34A,
      ),
    );

    expect(find.text('Cloud lecture notes'), findsOneWidget);
    expect(find.text('Photosynthesis lecture notes'), findsNothing);
  });

  testWidgets('subject detail shows summaries section with empty state', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);
    await _scrollTo(tester, find.text('Summaries'));

    expect(find.text('Summaries'), findsOneWidget);
    expect(find.text('No summaries yet'), findsOneWidget);
    expect(
      find.text('Generate a summary from a material and it will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('subject study session is disabled with no eligible material', (
    tester,
  ) async {
    await _pumpSubjectDetailWithMaterials(tester, const []);

    final action = tester.widget<GlassButton>(
      find.ancestor(
        of: find.text('Create study session'),
        matching: find.byType(GlassButton),
      ),
    );
    expect(action.onPressed, isNull);
    expect(
      find.text('Add a material to create a study session.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Create study session'));
    await tester.pumpAndSettle();
    expect(find.text('Study Session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending PDF and failed image are not study-session sources', (
    tester,
  ) async {
    for (final material in [
      _studyMaterial(
        id: 'pending-pdf',
        kind: MaterialKind.pdf,
        status: MaterialProcessingStatus.pending,
      ),
      _studyMaterial(
        id: 'failed-image',
        kind: MaterialKind.image,
        status: MaterialProcessingStatus.failed,
      ),
    ]) {
      await _pumpSubjectDetailWithMaterials(tester, [material]);
      final action = tester.widget<GlassButton>(
        find.ancestor(
          of: find.text('Create study session'),
          matching: find.byType(GlassButton),
        ),
      );
      expect(action.onPressed, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ready text PDF and image enable subject study sessions', (
    tester,
  ) async {
    for (final material in [
      _studyMaterial(id: 'ready-text', kind: MaterialKind.pastedText),
      _studyMaterial(id: 'ready-pdf', kind: MaterialKind.pdf),
      _studyMaterial(id: 'ready-image', kind: MaterialKind.image),
    ]) {
      await _pumpSubjectDetailWithMaterials(tester, [material]);
      final action = tester.widget<GlassButton>(
        find.ancestor(
          of: find.text('Create study session'),
          matching: find.byType(GlassButton),
        ),
      );
      expect(action.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty or stale study-session route shows safe state', (
    tester,
  ) async {
    await _pumpSubjectDetailWithMaterials(tester, const []);
    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: _studySessionSubject,
    );

    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsOneWidget,
    );
    expect(find.text('No study material available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('study-session route accepts an exact valid triple', (
    tester,
  ) async {
    final harness = await _createStudySessionRouteHarness(tester);

    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: StudySessionResultArgs(
        subject: _studySessionSubject,
        sessionId: harness.sessionId,
        materialId: harness.material.id,
      ),
    );

    expect(find.text('Generated from: Session material'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsNothing,
    );
  });

  testWidgets('study-session route rejects a wrong material ID', (
    tester,
  ) async {
    final harness = await _createStudySessionRouteHarness(tester);

    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: StudySessionResultArgs(
        subject: _studySessionSubject,
        sessionId: harness.sessionId,
        materialId: 'different-material',
      ),
    );

    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('study-session route rejects a wrong subject', (tester) async {
    final harness = await _createStudySessionRouteHarness(tester);
    const wrongSubject = Subject(
      id: 'different-subject',
      name: 'Different subject',
      description: 'Does not own the session',
      colorValue: 0xFFDC2626,
    );

    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: StudySessionResultArgs(
        subject: wrongSubject,
        sessionId: harness.sessionId,
        materialId: harness.material.id,
      ),
    );

    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('study-session route rejects a missing session', (tester) async {
    final harness = await _createStudySessionRouteHarness(tester);

    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: StudySessionResultArgs(
        subject: _studySessionSubject,
        sessionId: 'missing-session',
        materialId: harness.material.id,
      ),
    );

    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('study-session route rejects a detached deleted material', (
    tester,
  ) async {
    final harness = await _createStudySessionRouteHarness(
      tester,
      lifecycleRepository: MockMaterialLifecycleRepository(),
    );
    harness.repository.loadedMaterials.clear();
    await harness.state.loadMaterialsFor(_supabaseUser);
    expect(
      await harness.state.deleteMaterialFor(_supabaseUser, harness.material.id),
      isTrue,
    );

    await _pushRoute(
      tester,
      AppRoutes.studySessionResult,
      arguments: StudySessionResultArgs(
        subject: _studySessionSubject,
        sessionId: harness.sessionId,
        materialId: harness.material.id,
      ),
    );

    expect(
      find.byKey(const ValueKey('study-session-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('eligible subject action creates and opens study session', (
    tester,
  ) async {
    final material = _studyMaterial(
      id: 'session-source',
      kind: MaterialKind.pastedText,
    );
    await _pumpSubjectDetailWithMaterials(tester, [material]);

    await tester.tap(find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.text('Study Session'), findsOneWidget);
    expect(find.text('Generated from: Session material'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subject summary hub lists summaries and opens material detail', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    const material = StudyMaterial(
      id: 'cloud-material',
      subjectId: 'cloud-biology',
      title: 'Cloud lecture notes',
      kind: MaterialKind.pastedText,
      content:
          'Synced material text with enough detail for the quality guard. It explains a topic, adds context, and gives the learner useful source content.',
      createdLabel: 'Synced',
      summary:
          'This summary explains the main cloud biology idea and the supporting detail to review before practice.',
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(
          loadedMaterials: const [material],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);
    await _scrollTo(tester, find.text('Summaries'));

    expect(find.text('Summaries'), findsOneWidget);
    expect(find.text('Cloud lecture notes'), findsWidgets);
    expect(
      find.textContaining('Synced — This summary explains'),
      findsOneWidget,
    );

    final summaryTile = find.ancestor(
      of: find.textContaining('Synced — This summary explains'),
      matching: find.byType(AppListRow),
    );
    await tester.tap(summaryTile);
    await tester.pumpAndSettle();

    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Pasted text'), findsOneWidget);
    expect(find.textContaining('This summary explains'), findsOneWidget);
  });

  testWidgets('supabase fresh account shows material empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [
            Subject(
              id: 'cloud-biology',
              name: 'Cloud Biology',
              description: 'Synced from Supabase',
              colorValue: 0xFF16A34A,
            ),
          ],
        ),
        materialRepository: _RecordingMaterialRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: const Subject(
        id: 'cloud-biology',
        name: 'Cloud Biology',
        description: 'Synced from Supabase',
        colorValue: 0xFF16A34A,
      ),
    );

    expect(find.text('No materials yet'), findsOneWidget);
    expect(find.text('Photosynthesis lecture notes'), findsNothing);
  });

  testWidgets('supabase material create uses repository and updates UI', (
    tester,
  ) async {
    final materialRepository = _RecordingMaterialRepository();
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: materialRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);

    await tester.tap(find.text('Add pasted text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Material title'),
      'Cloud cell notes',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste lecture text'),
      'Cells sync their source text.',
    );
    await tester.tap(find.text('Save material'));
    await tester.pumpAndSettle();

    expect(materialRepository.createdUsers, [_supabaseUser]);
    expect(materialRepository.createdSubjectIds, ['cloud-biology']);
    expect(materialRepository.createdTitles, ['Cloud cell notes']);
    expect(find.text('Cloud cell notes'), findsOneWidget);
  });

  testWidgets('supabase material sync failure shows safe error', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(throwOnLoad: true),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);

    expect(find.text('Cloud Biology'), findsWidgets);
    expect(find.text('Could not sync materials. Try again.'), findsOneWidget);
    expect(find.text('No materials yet'), findsOneWidget);
  });

  testWidgets('supabase favorites starts empty without mock flashcards', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(),
        materialRepository: _RecordingMaterialRepository(),
        favoriteRepository: _RecordingFavoriteRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('supabase flashcards screen starts empty without mock cards', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(),
        favoriteRepository: _RecordingFavoriteRepository(),
        flashcardRepository: _RecordingFlashcardRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.flashcards, arguments: subject);

    expect(find.text('No flashcards yet'), findsOneWidget);
    expect(
      find.text('Generate them from a pasted-text material.'),
      findsOneWidget,
    );
    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('supabase flashcards screen displays loaded generated cards', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(),
        favoriteRepository: _RecordingFavoriteRepository(),
        flashcardRepository: _RecordingFlashcardRepository(
          loadedCards: const [
            Flashcard(
              id: 'cloud-card-1',
              subjectId: 'cloud-biology',
              materialId: 'cloud-material',
              front: 'Cloud generated front',
              back: 'Cloud generated back',
              topic: 'Cloud topic',
              difficulty: FlashcardDifficulty.exam,
              isFavorite: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.flashcards, arguments: subject);

    expect(find.text('Cloud generated front'), findsOneWidget);
    expect(find.textContaining('Cloud topic · exam'), findsOneWidget);
    expect(find.byTooltip('Favorite'), findsOneWidget);
  });

  testWidgets('supabase material favorites load from fake repository', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    const material = StudyMaterial(
      id: 'cloud-material',
      subjectId: 'cloud-biology',
      title: 'Cloud lecture notes',
      kind: MaterialKind.pastedText,
      content: 'Synced material text.',
      createdLabel: 'Synced',
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(
          loadedMaterials: const [material],
        ),
        favoriteRepository: _RecordingFavoriteRepository(
          loadedMaterialFavoriteIds: const {'cloud-material'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Cloud lecture notes'), findsOneWidget);
    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('supabase material favorite add and remove uses repository', (
    tester,
  ) async {
    final favoriteRepository = _RecordingFavoriteRepository();
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    const material = StudyMaterial(
      id: 'cloud-material',
      subjectId: 'cloud-biology',
      title: 'Cloud lecture notes',
      kind: MaterialKind.pastedText,
      content: 'Synced material text.',
      createdLabel: 'Synced',
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(
          loadedMaterials: const [material],
        ),
        favoriteRepository: favoriteRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);

    await _tapVisible(tester, find.byTooltip('Favorite material'));
    await tester.pumpAndSettle();

    expect(favoriteRepository.addedUsers, [_supabaseUser]);
    expect(favoriteRepository.addedMaterialIds, ['cloud-material']);

    await _pushRoute(tester, AppRoutes.favorites);
    expect(find.text('Cloud lecture notes'), findsOneWidget);

    await tester.tap(find.byTooltip('Unfavorite material'));
    await tester.pumpAndSettle();

    expect(favoriteRepository.removedUsers, [_supabaseUser]);
    expect(favoriteRepository.removedMaterialIds, ['cloud-material']);
    expect(find.text('Cloud lecture notes'), findsNothing);
  });

  testWidgets('supabase material favorite failure shows safe error', (
    tester,
  ) async {
    const subject = Subject(
      id: 'cloud-biology',
      name: 'Cloud Biology',
      description: 'Synced from Supabase',
      colorValue: 0xFF16A34A,
    );
    const material = StudyMaterial(
      id: 'cloud-material',
      subjectId: 'cloud-biology',
      title: 'Cloud lecture notes',
      kind: MaterialKind.pastedText,
      content: 'Synced material text.',
      createdLabel: 'Synced',
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
        profileRepository: _RecordingProfileRepository(),
        subjectRepository: _RecordingSubjectRepository(
          loadedSubjects: const [subject],
        ),
        materialRepository: _RecordingMaterialRepository(
          loadedMaterials: const [material],
        ),
        favoriteRepository: _RecordingFavoriteRepository(throwOnAdd: true),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.subjectDetail, arguments: subject);

    await _tapVisible(tester, find.byTooltip('Favorite material'));
    await tester.pumpAndSettle();

    expect(find.text('Could not update favorite.'), findsOneWidget);

    await _pushRoute(tester, AppRoutes.favorites);
    expect(find.text('Cloud lecture notes'), findsNothing);
  });

  testWidgets('top quick actions open search and home', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Ready for your next study step?'), findsOneWidget);
  });

  testWidgets('scenario screens expose shared navigation actions', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.afterLecture);

    expect(find.byKey(const ValueKey('app-back-button')), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-navigation-bar')), findsNothing);

    await _pushRoute(tester, AppRoutes.examPrep);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-back-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-navigation-bar')), findsNothing);
  });

  testWidgets('local search finds material and opens detail', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search study workspace'),
      'Photosynthesis',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photosynthesis lecture notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    await _scrollTo(
      tester,
      find.textContaining(
        'Plants convert light, water, and carbon dioxide into glucose',
      ),
    );
    expect(
      find.textContaining(
        'Plants convert light, water, and carbon dioxide into glucose',
      ),
      findsOneWidget,
    );
  });

  testWidgets('after lecture creates local session and quiz result', (
    tester,
  ) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('Biology'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Photosynthesis lecture notes'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(
      find.text('Generated from: Photosynthesis lecture notes'),
      findsOneWidget,
    );
    expect(find.textContaining('Simple explanation'), findsWidgets);
    expect(find.text('45 min'), findsOneWidget);

    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    expect(find.text('A generic Biology fallback — incorrect'), findsOneWidget);
    expect(
      find.text(
        'Incorrect. Review the explanation, then retry the flashcards.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('You chose "A generic Biology fallback"'),
      findsOneWidget,
    );
  });

  testWidgets(
    'exam preparation opens the explicitly selected material session',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _enterDashboard(tester);
      await _pushRoute(tester, AppRoutes.examPrep);

      final createButton = find.widgetWithText(
        FilledButton,
        'Create study session',
      );
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

      await _tapVisible(tester, find.text('Photosynthesis lecture notes'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, createButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Generated from: Photosynthesis lecture notes'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('study-session-unavailable')),
        findsNothing,
      );
    },
  );

  testWidgets('continue studying propagates the exact local session', (
    tester,
  ) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('Biology'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Photosynthesis lecture notes'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    await _pushRoute(tester, AppRoutes.continueStudying);

    expect(find.text('Biology'), findsOneWidget);
    expect(find.textContaining('Simple explanation'), findsOneWidget);
    expect(find.text('Last score: 0%'), findsOneWidget);

    await _scrollTo(tester, find.text('Continue session'));
    await tester.tap(find.text('Continue session'));
    await tester.pumpAndSettle();
    expect(
      find.text('Generated from: Photosynthesis lecture notes'),
      findsOneWidget,
    );
  });
}

const _supabaseUser = AuthUser(
  id: 'supabase-user',
  email: 'learner@example.test',
  displayName: 'Supabase Student',
);

const _widgetQuiz = Quiz(
  id: 'widget-quiz',
  subjectId: 'biology',
  materialId: 'bio-lecture-1',
  title: 'Widget quiz',
  questions: [
    QuizQuestion(
      id: 'widget-question-1',
      quizId: 'widget-quiz',
      subjectId: 'biology',
      materialId: 'bio-lecture-1',
      question: 'What does this material explain?',
      options: [
        'The core idea',
        'An unrelated upload',
        'A service key',
        'A password reset',
      ],
      correctAnswer: 'The core idea',
      explanation: 'The material supports the core idea.',
      topic: 'Core idea',
      difficulty: StudyDifficulty.easy,
    ),
  ],
);

const _multiQuestionWidgetQuiz = Quiz(
  id: 'multi-widget-quiz',
  subjectId: 'biology',
  materialId: 'bio-lecture-1',
  title: 'Multi-question widget quiz',
  questions: [
    QuizQuestion(
      id: 'multi-question-1',
      subjectId: 'biology',
      question: 'Question one',
      options: ['Correct one', 'Wrong one'],
      correctAnswer: 'Correct one',
      explanation: 'Explanation one.',
      topic: 'Topic one',
      difficulty: StudyDifficulty.easy,
    ),
    QuizQuestion(
      id: 'multi-question-2',
      subjectId: 'biology',
      question: 'Question two',
      options: ['Correct two', 'Wrong two'],
      correctAnswer: 'Correct two',
      explanation: 'Explanation two.',
      topic: 'Topic two',
      difficulty: StudyDifficulty.medium,
    ),
    QuizQuestion(
      id: 'multi-question-3',
      subjectId: 'biology',
      question: 'Question three',
      options: ['Correct three', 'Wrong three'],
      correctAnswer: 'Correct three',
      explanation: 'Explanation three.',
      topic: 'Topic three',
      difficulty: StudyDifficulty.exam,
    ),
  ],
);

QuizQuestion _visibleQuestion(WidgetTester tester, Quiz quiz) {
  return quiz.questions.singleWhere(
    (question) => find.text(question.question).evaluate().isNotEmpty,
  );
}

List<String> _visibleOptionLabels(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data!)
      .toList();
}

final _progressAttempt = QuizAttempt(
  id: 'progress-attempt',
  quizId: 'progress-quiz',
  subjectId: 'biology',
  score: 50,
  totalQuestions: 2,
  correctQuestions: 1,
  startedAt: DateTime.utc(2026, 7, 10, 10),
  completedAt: DateTime.utc(2026, 7, 10, 10, 5),
  answers: const [],
  weakTopicsSnapshot: const [
    QuizWeakTopicSnapshot(topic: 'Cell division', missCount: 1),
  ],
);

const _trainingCardOne = Flashcard(
  id: 'bio-card-1',
  subjectId: 'biology',
  materialId: 'bio-lecture-1',
  front: 'Training front 1',
  back: 'Training back 1',
  topic: 'Training topic',
  isFavorite: false,
);

const _trainingCardTwo = Flashcard(
  id: 'bio-card-2',
  subjectId: 'biology',
  materialId: 'bio-lecture-1',
  front: 'Training front 2',
  back: 'Training back 2',
  topic: 'Training topic',
  isFavorite: false,
);

const _cloudTrainingCard = Flashcard(
  id: 'cloud-training-card',
  subjectId: 'cloud-biology',
  materialId: 'cloud-material',
  front: 'Cloud training front',
  back: 'Cloud training back',
  topic: 'Cloud topic',
  isFavorite: false,
);

const _reviewSubject = Subject(
  id: 'review-subject',
  name: 'Review Biology',
  description: 'Review cards',
  colorValue: 0xFF16A34A,
);

const _weakReviewCard = Flashcard(
  id: 'weak-review-card',
  subjectId: 'review-subject',
  front: 'Weak front',
  back: 'Weak back',
  topic: 'Weak topic',
  isFavorite: false,
  correctCount: 1,
  incorrectCount: 3,
);

const _knownReviewCard = Flashcard(
  id: 'known-review-card',
  subjectId: 'review-subject',
  front: 'Known front',
  back: 'Known back',
  topic: 'Known topic',
  isFavorite: false,
  correctCount: 3,
  incorrectCount: 1,
);

final _dueReviewCard = Flashcard(
  id: 'due-review-card',
  subjectId: 'review-subject',
  front: 'Due front',
  back: 'Due back',
  topic: 'Due topic',
  isFavorite: false,
  nextReviewAt: DateTime.utc(2020),
);

final _futureReviewCard = Flashcard(
  id: 'future-review-card',
  subjectId: 'review-subject',
  front: 'Future front',
  back: 'Future back',
  topic: 'Future topic',
  isFavorite: false,
  nextReviewAt: DateTime.utc(2099),
);

List<Flashcard> _reviewCards(int count) {
  return [
    for (var index = 1; index <= count; index += 1)
      Flashcard(
        id: 'review-card-$index',
        subjectId: 'review-subject',
        front: 'Review front $index',
        back: 'Review back $index',
        topic: 'Review topic',
        isFavorite: false,
      ),
  ];
}

Future<void> _pumpFlashcardsHarness(
  WidgetTester tester,
  List<Flashcard> cards,
) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      config: _supabaseConfig(),
      authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
      profileRepository: _RecordingProfileRepository(),
      subjectRepository: _RecordingSubjectRepository(
        loadedSubjects: const [_reviewSubject],
      ),
      materialRepository: _RecordingMaterialRepository(),
      favoriteRepository: _RecordingFavoriteRepository(),
      flashcardRepository: _RecordingFlashcardRepository(loadedCards: cards),
    ),
  );
  await tester.pumpAndSettle();
  await _pushRoute(tester, AppRoutes.flashcards, arguments: _reviewSubject);
}

Future<void> _enterDashboard(WidgetTester tester) async {
  await tester.pumpWidget(const StudyBuddyApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _studySessionSubject = Subject(
  id: 'session-subject',
  name: 'Session Subject',
  description: 'Session eligibility tests',
  colorValue: 0xFF2563EB,
);

StudyMaterial _studyMaterial({
  required String id,
  required MaterialKind kind,
  MaterialProcessingStatus status = MaterialProcessingStatus.ready,
}) => StudyMaterial(
  id: id,
  subjectId: _studySessionSubject.id,
  title: 'Session material',
  kind: kind,
  content:
      'Useful study content with enough detail to create summaries, flashcards, quizzes, and a focused study session safely.',
  createdLabel: 'Now',
  sourceKind: kind == MaterialKind.pastedText
      ? MaterialSourceKind.manual
      : MaterialSourceKind.upload,
  processingStatus: status,
);

Future<void> _pumpSubjectDetailWithMaterials(
  WidgetTester tester,
  List<StudyMaterial> materials, {
  MaterialLifecycleRepository? lifecycleRepository,
  MaterialRepository? materialRepository,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      key: UniqueKey(),
      config: _supabaseConfig(),
      authRepository: _RecordingAuthRepository(initialUser: _supabaseUser),
      profileRepository: _RecordingProfileRepository(),
      subjectRepository: _RecordingSubjectRepository(
        loadedSubjects: const [_studySessionSubject],
      ),
      materialRepository:
          materialRepository ??
          _RecordingMaterialRepository(loadedMaterials: materials),
      materialLifecycleRepository: lifecycleRepository,
      preferencesStore: MemoryAppPreferencesStore(),
    ),
  );
  await tester.pumpAndSettle();
  await _pushRoute(
    tester,
    AppRoutes.subjectDetail,
    arguments: _studySessionSubject,
  );
}

Future<
  ({
    AppState state,
    String sessionId,
    StudyMaterial material,
    _RecordingMaterialRepository repository,
  })
>
_createStudySessionRouteHarness(
  WidgetTester tester, {
  MaterialLifecycleRepository? lifecycleRepository,
}) async {
  final material = _studyMaterial(
    id: 'route-session-source',
    kind: MaterialKind.pastedText,
  );
  final repository = _RecordingMaterialRepository(loadedMaterials: [material]);
  await _pumpSubjectDetailWithMaterials(
    tester,
    [material],
    lifecycleRepository: lifecycleRepository,
    materialRepository: repository,
  );
  final state = AppStateScope.read(
    tester.element(find.text('Create study session').first),
  );
  final session = state.createStudySession(
    subject: _studySessionSubject,
    confidence: LectureConfidence.mostly,
    materialId: material.id,
  );
  expect(session, isNotNull);
  return (
    state: state,
    sessionId: session!.id,
    material: material,
    repository: repository,
  );
}

Future<void> _pushRoute(
  WidgetTester tester,
  String routeName, {
  Object? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(routeName, arguments: arguments);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void _expectChoiceSelected(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.widgetWithText(ChoiceChip, label),
  );
  expect(chip.selected, isTrue);
}

void _expectChoiceEnabled(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.widgetWithText(ChoiceChip, label),
  );
  expect(chip.onSelected, isNotNull);
}

void _expectChoiceDisabled(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.widgetWithText(ChoiceChip, label),
  );
  expect(chip.onSelected, isNull);
}

TextField _textField(WidgetTester tester, String label) {
  return tester.widget<TextField>(find.widgetWithText(TextField, label));
}

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'sb_publishable_test-client-key',
  );
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({AuthUser? initialUser, this.signUpError})
    : _user = initialUser;

  AuthUser? _user;
  final Object? signUpError;
  int signInCount = 0;
  int signUpCount = 0;
  int signOutCount = 0;
  final List<String> signUpDisplayNames = [];

  @override
  Future<AuthUser?> currentUser() async {
    return _user;
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCount++;
    _user = AuthUser(
      id: 'signed-in-user',
      email: email.trim(),
      displayName: 'Supabase Student',
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    signUpCount += 1;
    signUpDisplayNames.add(displayName);
    final error = signUpError;
    if (error != null) {
      throw error;
    }
    _user = AuthUser(
      id: 'signed-up-user',
      email: email.trim(),
      displayName: displayName.trim(),
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _user = null;
  }
}

class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({this.profile});

  AuthProfile? profile;
  final List<AuthUser> fetchedUsers = [];
  final List<AuthUser> ensuredUsers = [];
  final List<AuthUser> updateUsers = [];
  final List<String> updatedDisplayNames = [];

  @override
  Future<AuthProfile?> fetchProfile(AuthUser user) async {
    fetchedUsers.add(user);
    return profile;
  }

  @override
  Future<AuthProfile> ensureProfile(AuthUser user) async {
    ensuredUsers.add(user);
    final ensuredProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    );
    profile = ensuredProfile;
    return ensuredProfile;
  }

  @override
  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  }) async {
    updateUsers.add(user);
    updatedDisplayNames.add(displayName);
    final updatedProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: displayName,
    );
    profile = updatedProfile;
    return updatedProfile;
  }
}

class _RecordingSubjectRepository implements SubjectRepository {
  _RecordingSubjectRepository({
    this.loadedSubjects = const [],
    this.throwOnLoad = false,
  });

  final List<Subject> loadedSubjects;
  final bool throwOnLoad;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> createdUsers = [];
  final List<String> createdNames = [];

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    loadedUsers.add(user);
    if (throwOnLoad) {
      throw const SubjectRepositoryException('Could not sync subjects.');
    }
    return List<Subject>.of(loadedSubjects);
  }

  @override
  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  }) async {
    createdUsers.add(user);
    createdNames.add(name);
    return Subject(
      id: 'created-${createdNames.length}',
      name: name,
      description: description,
      colorValue: colorValue,
    );
  }
}

class _RecordingMaterialRepository implements MaterialRepository {
  _RecordingMaterialRepository({
    this.loadedMaterials = const [],
    this.throwOnLoad = false,
  });

  final List<StudyMaterial> loadedMaterials;
  final bool throwOnLoad;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> createdUsers = [];
  final List<String> createdSubjectIds = [];
  final List<String> createdTitles = [];

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    loadedUsers.add(user);
    if (throwOnLoad) {
      throw const MaterialRepositoryException('Could not sync materials.');
    }
    return List<StudyMaterial>.of(loadedMaterials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    createdUsers.add(user);
    createdSubjectIds.add(subjectId);
    createdTitles.add(title);
    return StudyMaterial(
      id: 'created-${createdTitles.length}',
      subjectId: subjectId,
      title: title,
      kind: MaterialKind.pastedText,
      content: content,
      createdLabel: 'Just now',
    );
  }
}

class _RecordingFavoriteRepository implements FavoriteRepository {
  _RecordingFavoriteRepository({
    Set<String> loadedMaterialFavoriteIds = const <String>{},
    this.throwOnAdd = false,
  }) : _materialFavoriteIds = Set<String>.of(loadedMaterialFavoriteIds);

  final bool throwOnAdd;
  final Set<String> _materialFavoriteIds;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> addedUsers = [];
  final List<String> addedMaterialIds = [];
  final List<AuthUser> removedUsers = [];
  final List<String> removedMaterialIds = [];

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    loadedUsers.add(user);
    return Set<String>.of(_materialFavoriteIds);
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    addedUsers.add(user);
    addedMaterialIds.add(materialId);
    if (throwOnAdd) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
    _materialFavoriteIds.add(materialId);
  }

  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    removedUsers.add(user);
    removedMaterialIds.add(materialId);
    _materialFavoriteIds.remove(materialId);
  }
}

class _RecordingFlashcardRepository implements FlashcardRepository {
  _RecordingFlashcardRepository({
    this.loadedCards = const [],
    this.generatedCards = const [],
    this.pendingCards,
    this.throwOnGenerate = false,
    this.throwOnReview = false,
  });

  final List<Flashcard> loadedCards;
  final List<Flashcard> generatedCards;
  final Future<FlashcardGenerationResult>? pendingCards;
  final bool throwOnGenerate;
  final bool throwOnReview;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];
  final List<int> generatedCounts = [];
  final List<AuthUser> reviewedUsers = [];
  final List<String> reviewedCardIds = [];
  final List<FlashcardReviewResult> reviewResults = [];

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    loadedUsers.add(user);
    return List<Flashcard>.of(loadedCards);
  }

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    generatedCounts.add(requestedNewCount);
    if (throwOnGenerate) {
      throw const FlashcardRepositoryException(
        'Could not generate flashcards. Try again.',
      );
    }
    final pending = pendingCards;
    if (pending != null) {
      return pending;
    }
    return FlashcardGenerationResult(
      requestedCount: requestedNewCount,
      createdCount: generatedCards.length,
      newFlashcards: List<Flashcard>.of(generatedCards),
    );
  }

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) async {
    reviewedUsers.add(user);
    reviewedCardIds.add(card.id);
    reviewResults.add(result);
    if (throwOnReview) {
      throw const FlashcardRepositoryException(
        'Could not save review progress.',
      );
    }
    return card.copyWith(
      correctCount: result == FlashcardReviewResult.known
          ? card.correctCount + 1
          : card.correctCount,
      incorrectCount: result == FlashcardReviewResult.missed
          ? card.incorrectCount + 1
          : card.incorrectCount,
      lastReviewedAt: reviewedAt,
      nextReviewAt: reviewedAt.add(
        Duration(days: result == FlashcardReviewResult.known ? 3 : 1),
      ),
    );
  }
}

class _RecordingQuizRepository implements QuizRepository {
  _RecordingQuizRepository({
    this.generatedQuiz,
    this.throwOnGenerate = false,
    this.throwOnSave = false,
    List<QuizAttempt> attempts = const [],
  }) : _attempts = List<QuizAttempt>.of(attempts);

  final Quiz? generatedQuiz;
  final bool throwOnGenerate;
  final bool throwOnSave;
  final List<QuizAttempt> _attempts;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];
  final List<int> generatedCounts = [];
  final List<QuizAttempt> savedAttempts = [];
  final List<QuizAttemptSubmission> savedSubmissions = [];

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    loadedUsers.add(user);
    return const [];
  }

  @override
  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user) async {
    return List<QuizAttempt>.of(_attempts);
  }

  @override
  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    generatedCounts.add(count);
    if (throwOnGenerate) {
      throw const QuizRepositoryException(
        'Could not generate quiz. Try again.',
      );
    }
    return generatedQuiz ?? _widgetQuiz;
  }

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttemptSubmission submission,
  }) async {
    savedSubmissions.add(submission);
    final authoritativeQuiz = switch (submission.quizId) {
      'multi-widget-quiz' => _multiQuestionWidgetQuiz,
      _ => generatedQuiz ?? _widgetQuiz,
    };
    final server = MockQuizRepository(
      initialQuizzes: [authoritativeQuiz],
      initialAttempts: _attempts,
      now: () => submission.startedAt.toUtc().add(const Duration(minutes: 5)),
    );
    final saved = await server.saveQuizAttempt(
      user: user,
      submission: submission,
    );
    savedAttempts.add(saved);
    if (throwOnSave) {
      throw const QuizRepositoryException('Could not save this quiz attempt.');
    }
    _attempts.insert(0, saved);
    return saved;
  }
}

class _StaticWeakTopicRepository implements WeakTopicRepository {
  const _StaticWeakTopicRepository(this.topics);

  final List<CumulativeWeakTopic> topics;

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) async {
    return List.of(topics);
  }
}

class _StaticStudyProgressRepository implements StudyProgressRepository {
  const _StaticStudyProgressRepository(this.progress);
  final StudyProgress progress;
  @override
  Future<StudyProgress> loadProgress(
    AuthUser user, {
    String? subjectId,
    String? materialId,
  }) async => progress;
}

StudyProgress _widgetStudyProgress({bool withEvidence = false}) {
  final metrics = ProgressMetrics(
    quizCorrectAnswers: withEvidence ? 1 : 0,
    quizTotalAnswers: withEvidence ? 2 : 0,
    quizAccuracy: withEvidence ? 50 : null,
    completedQuizAttemptCount: withEvidence ? 1 : 0,
    flashcardKnownCount: 0,
    flashcardNotKnownCount: 0,
    weakCardCount: 0,
    dueCardCount: 0,
    activeSessionCount: 0,
    completedSessionCount: 0,
    quizEvidenceCount: withEvidence ? 2 : 0,
    flashcardEvidenceCount: 0,
    activeSessions: const [],
    recentCompletedSessions: const [],
    weakTopics: withEvidence
        ? [
            ProgressWeakTopic(
              id: 'progress-weak',
              topic: 'Cell division',
              missCount: 4,
              subjectId: 'biology',
              subjectName: 'Biology',
              materialId: '',
            ),
          ]
        : const [],
    knowledgeScore: withEvidence ? 50 : null,
  );
  return StudyProgress(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 7, 22),
    global: metrics,
    subjects: const [],
    materials: const [],
    historical: const HistoricalProgress(
      label: 'Deleted or detached material activity',
      quizCorrectAnswers: 0,
      quizTotalAnswers: 0,
      completedQuizAttemptCount: 0,
      completedSessionCount: 0,
      recentCompletedSessions: [],
    ),
  );
}

class _WidgetMaterialLifecycle implements MaterialLifecycleRepository {
  _WidgetMaterialLifecycle({this.fail = false, this.gate});

  final bool fail;
  final Completer<void>? gate;
  int deleteCalls = 0;

  @override
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  }) async {
    deleteCalls += 1;
    if (gate != null) await gate!.future;
    if (fail) {
      throw const MaterialLifecycleException(
        'Could not delete the material. Try again.',
      );
    }
  }

  @override
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async => fail;

  @override
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  }) async => const MaterialRecoveryEligibility(eligible: false);

  @override
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  }) async {}
}

class _RecordingSummaryRepository implements SummaryRepository {
  _RecordingSummaryRepository({
    this.summary = 'Generated summary.',
    this.pendingSummary,
    this.throwOnGenerate = false,
  });

  final String summary;
  final Future<String>? pendingSummary;
  final bool throwOnGenerate;
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];

  @override
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    if (throwOnGenerate) {
      throw const SummaryRepositoryException(
        'Could not generate summary. Try again.',
      );
    }
    final pending = pendingSummary;
    if (pending != null) {
      return pending;
    }
    return summary;
  }
}
