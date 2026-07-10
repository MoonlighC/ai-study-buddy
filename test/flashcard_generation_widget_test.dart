import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generation dialog defaults to 5 and does not invoke early', (
    tester,
  ) async {
    final repository = _GenerationRepository(loadedCards: const [_existing]);
    await _pumpMaterial(tester, repository);

    await _openDialog(tester);
    expect(repository.requestedCounts, isEmpty);
    expect(find.text('Generate new flashcards'), findsOneWidget);
    expect(find.text('Current: 1'), findsOneWidget);
    expect(find.text('Add: 5'), findsOneWidget);
    expect(find.text('After generation: up to 6'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '10'));
    await tester.pumpAndSettle();
    expect(find.text('Add: 10'), findsOneWidget);
    expect(find.text('After generation: up to 11'), findsOneWidget);
    expect(repository.requestedCounts, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.requestedCounts, isEmpty);
  });

  testWidgets('preset count reaches repository only after confirmation', (
    tester,
  ) async {
    final repository = _GenerationRepository();
    await _pumpMaterial(tester, repository);
    await _openDialog(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '20'));
    await tester.pumpAndSettle();
    expect(repository.requestedCounts, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(repository.requestedCounts, [20]);
    expect(find.text('1 new flashcard generated.'), findsOneWidget);
  });

  for (final count in [1, 30]) {
    testWidgets('custom count $count is accepted', (tester) async {
      final repository = _GenerationRepository();
      await _pumpMaterial(tester, repository);
      await _openDialog(tester);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-flashcard-count')),
        '$count',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(repository.requestedCounts, [count]);
    });
  }

  testWidgets('custom count rejects invalid fractional and above maximum', (
    tester,
  ) async {
    final repository = _GenerationRepository();
    await _pumpMaterial(tester, repository);
    await _openDialog(tester);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('custom-flashcard-count'));

    for (final invalid in ['', 'abc', '1.5', '0', '-2']) {
      await tester.enterText(field, invalid);
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 30.'), findsOneWidget);
      expect(repository.requestedCounts, isEmpty);
    }

    await tester.enterText(field, '31');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();
    expect(find.text('Choose no more than 30 flashcards.'), findsOneWidget);
    expect(repository.requestedCounts, isEmpty);
  });

  testWidgets('generation preserves existing cards and shows actual count', (
    tester,
  ) async {
    final repository = _GenerationRepository(loadedCards: const [_existing]);
    await _pumpMaterial(tester, repository);
    await _openDialog(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '10'));
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(find.text('2 flashcards ready.'), findsOneWidget);
    expect(find.text('1 new flashcard generated.'), findsOneWidget);
    expect(repository.loadedCards.single.id, 'existing');
  });

  testWidgets('zero-created generation uses safe copy', (tester) async {
    final repository = _GenerationRepository(createNone: true);
    await _pumpMaterial(tester, repository);
    await _openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(
      find.text('No new unique flashcards were generated.'),
      findsOneWidget,
    );
    expect(find.text('No flashcards yet.'), findsOneWidget);
  });
}

Future<void> _pumpMaterial(
  WidgetTester tester,
  _GenerationRepository repository,
) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [_material],
      ),
      flashcardRepository: repository,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(AppRoutes.materialDetail, arguments: _material);
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Generate flashcards');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _GenerationRepository implements FlashcardRepository {
  _GenerationRepository({this.loadedCards = const [], this.createNone = false});

  final List<Flashcard> loadedCards;
  final bool createNone;
  final List<int> requestedCounts = [];

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async => loadedCards;

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) async {
    requestedCounts.add(requestedNewCount);
    final cards = createNone
        ? const <Flashcard>[]
        : const [
            Flashcard(
              id: 'new-card',
              subjectId: 'ignored',
              materialId: 'ignored',
              front: 'New front',
              back: 'New back',
              topic: 'New topic',
              isFavorite: false,
            ),
          ];
    return FlashcardGenerationResult(
      requestedCount: requestedNewCount,
      createdCount: cards.length,
      newFlashcards: cards,
    );
  }

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) async => card;
}

const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'biology',
  title: 'Generation material',
  kind: MaterialKind.pastedText,
  content:
      'This material contains enough detailed lecture content to create useful flashcards while exercising the explicit additive generation count dialog.',
  createdLabel: 'Today',
);

const _existing = Flashcard(
  id: 'existing',
  subjectId: 'biology',
  materialId: 'material-1',
  front: 'Existing front',
  back: 'Existing back',
  topic: 'Existing',
  isFavorite: false,
);
