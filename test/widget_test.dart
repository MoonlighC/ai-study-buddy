import 'dart:async';

import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/favorites/favorite_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/features/generation/summary_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
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

    expect(find.text('What do you want to do today?'), findsOneWidget);
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
    await tester.tap(find.text('Add pasted text'));
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
    expect(find.text('Just now - pasted text'), findsOneWidget);

    await tester.tap(find.text('Cell respiration notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    expect(
      find.text('Cells release energy from glucose during respiration.'),
      findsOneWidget,
    );
    expect(find.text('Generate mock summary'), findsOneWidget);
  });

  testWidgets('favorite toggle updates favorites screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Where does photosynthesis happen?'), findsOneWidget);
  });

  testWidgets('favorites can unfavorite and remove a card', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('What is photosynthesis?'), findsOneWidget);

    final favoriteTile = find.ancestor(
      of: find.text('What is photosynthesis?'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: favoriteTile, matching: find.byTooltip('Unfavorite')),
    );
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

    await tester.tap(find.byTooltip('Favorite material').first);
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
    expect(
      find.textContaining(
        'Plants convert light, water, and carbon dioxide into glucose',
      ),
      findsOneWidget,
    );
    expect(find.text('Generate mock summary'), findsOneWidget);

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
    expect(find.text('Generate mock flashcards'), findsOneWidget);

    await _scrollTo(tester, find.text('Generate mock flashcards'));
    await _scrollTo(tester, find.text('Generate mock flashcards'));
    await tester.tap(find.text('Generate mock flashcards'));
    await tester.pumpAndSettle();

    expect(flashcardRepository.generatedMaterialIds, ['bio-lecture-1']);
    expect(find.text('1 flashcards ready.'), findsOneWidget);
    expect(find.text('Review flashcards'), findsOneWidget);
  });

  testWidgets('material detail shows loading while flashcards generate', (
    tester,
  ) async {
    final completer = Completer<List<Flashcard>>();
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

    await _scrollTo(tester, find.text('Generate mock flashcards'));
    await tester.tap(find.text('Generate mock flashcards'));
    await tester.pump();

    expect(find.text('Generating flashcards'), findsOneWidget);

    completer.complete(const [
      Flashcard(
        id: 'generated-card-1',
        subjectId: 'biology',
        materialId: 'bio-lecture-1',
        front: 'Generated card front',
        back: 'Generated card back',
        topic: 'Generated topic',
        isFavorite: false,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('1 flashcards ready.'), findsOneWidget);
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

    await _scrollTo(tester, find.text('Generate mock flashcards'));
    await tester.tap(find.text('Generate mock flashcards'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not generate flashcards. Try again.'),
      findsWidgets,
    );
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
      find.text('Only 5 cards available for this selection.'),
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

    await tester.tap(find.text('Weak'));
    await tester.pumpAndSettle();

    expect(find.text('2 cards available for this selection.'), findsOneWidget);
    expect(find.text('Start training (2 cards)'), findsOneWidget);

    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();

    expect(find.text('0 cards available for this selection.'), findsOneWidget);
    expect(find.text('No due cards'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Show answer').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The process plants use to convert light energy into glucose.',
      ),
      findsOneWidget,
    );

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

    await tester.tap(find.text('Weak'));
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

    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();

    expect(find.text('Due front'), findsOneWidget);
    expect(find.text('Future front'), findsNothing);
    expect(find.text('Weak front'), findsNothing);
  });

  testWidgets('Train weak cards starts training with weak cards only', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, [_weakReviewCard, _knownReviewCard]);

    await tester.tap(find.text('Train weak cards'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Weak front'), findsOneWidget);
    expect(find.text('Known front'), findsNothing);
  });

  testWidgets('Review due cards starts training with due cards only', (
    tester,
  ) async {
    await _pumpFlashcardsHarness(tester, [_dueReviewCard, _futureReviewCard]);

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

    await tester.tap(find.byType(Card).first);
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
    expect(find.text('Cards reviewed'), findsOneWidget);
    expect(find.text('Known'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);

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

    expect(find.text('Review missed again'), findsOneWidget);

    await tester.tap(find.text('Review missed again'));
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

    await tester.tap(find.text('Subjects').last);
    await tester.pumpAndSettle();

    expect(find.text('Study Workspace'), findsOneWidget);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Knowledge scores'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Mock preferences for the local prototype.'),
      findsOneWidget,
    );
  });

  testWidgets('settings renders required mock sections and planned limits', (
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

    expect(find.text('120/day'), findsOneWidget);
    expect(find.text('80/day'), findsOneWidget);
    expect(find.text('3/day'), findsOneWidget);
    expect(find.text(r'$0.25/day'), findsOneWidget);

    await _scrollTo(tester, find.text('Support'));

    expect(find.text('Report a bug placeholder'), findsOneWidget);
    expect(find.text('Contact support placeholder'), findsOneWidget);
    expect(find.text('Send feedback placeholder'), findsOneWidget);

    await _scrollTo(tester, find.text('About / Debug'));

    expect(find.text('0.1.0 placeholder'), findsOneWidget);
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

      await _scrollTo(tester, find.text('Default flashcard session size'));
      await tester.tap(find.widgetWithText(ChoiceChip, '10'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '10');

      await _scrollTo(tester, find.text('Daily study goal'));
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '30 min');

      await _scrollTo(tester, find.text('Default difficulty'));
      await tester.tap(find.text('exam'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, 'exam');

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
    expect(find.text('What do you want to do today?'), findsOneWidget);
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

    await tester.tap(find.text('Create subject'));
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

    expect(find.text('Could not sync subjects.'), findsOneWidget);
    expect(find.text('No subjects yet'), findsOneWidget);
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
    expect(
      find.text('No summaries yet. Generate one from a material.'),
      findsOneWidget,
    );
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
      find.textContaining('Synced - This summary explains'),
      findsOneWidget,
    );

    final summaryTile = find.ancestor(
      of: find.textContaining('Synced - This summary explains'),
      matching: find.byType(ListTile),
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
    expect(find.text('Could not sync materials.'), findsOneWidget);
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
    expect(find.textContaining('Cloud topic - exam'), findsOneWidget);
    expect(find.byTooltip('Favorite'), findsNothing);
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

    await tester.tap(find.byTooltip('Favorite material'));
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

    await tester.tap(find.byTooltip('Favorite material'));
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

    expect(find.text('What do you want to do today?'), findsOneWidget);
  });

  testWidgets('scenario screens expose shared navigation actions', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.afterLecture);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsWidgets);
    expect(find.byTooltip('Home'), findsWidgets);
    expect(find.text('Subjects'), findsOneWidget);

    await _pushRoute(tester, AppRoutes.examPrep);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsWidgets);
    expect(find.byTooltip('Home'), findsWidgets);
    expect(find.text('Progress'), findsOneWidget);
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
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Simple explanation'), findsWidgets);
    expect(find.text('45 min'), findsOneWidget);

    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    expect(find.text('A generic Biology fallback - incorrect'), findsOneWidget);
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

  testWidgets('continue studying reads latest local session', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    await _pushRoute(tester, AppRoutes.continueStudying);

    expect(find.text('Biology review'), findsOneWidget);
    expect(find.textContaining('Simple explanation'), findsOneWidget);
    expect(find.text('Biology quick quiz: 0%'), findsOneWidget);
  });
}

const _supabaseUser = AuthUser(
  id: 'supabase-user',
  email: 'learner@example.test',
  displayName: 'Supabase Student',
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
    supabaseAnonKey: 'placeholder-anon-key',
  );
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({AuthUser? initialUser, this.signUpError})
    : _user = initialUser;

  AuthUser? _user;
  final Object? signUpError;
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
  final Future<List<Flashcard>>? pendingCards;
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
  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    generatedCounts.add(count);
    if (throwOnGenerate) {
      throw const FlashcardRepositoryException(
        'Could not generate flashcards. Try again.',
      );
    }
    final pending = pendingCards;
    if (pending != null) {
      return pending;
    }
    return List<Flashcard>.of(generatedCards);
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
