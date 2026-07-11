import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcards_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subject entry shows cards from all subject materials', (
    tester,
  ) async {
    await _pumpScope(tester, [_weakOne, _dueOne, _otherMaterial]);
    await _openFlashcards(tester, const FlashcardsRouteArgs(subject: _subject));

    expect(find.text('All flashcards — Biology'), findsOneWidget);
    expect(find.text('3 cards · 2 materials'), findsOneWidget);
    expect(find.text('Weak one'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Other material'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Other material'), findsOneWidget);
  });

  testWidgets('material entry excludes cards from another material', (
    tester,
  ) async {
    await _pumpScope(tester, [_weakOne, _dueOne, _otherMaterial]);
    await _openFlashcards(tester, _materialOneArgs);

    expect(find.text('Flashcards — First material'), findsOneWidget);
    expect(find.text('2 cards from this material'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Due one'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Due one'), findsOneWidget);
    expect(find.text('Other material'), findsNothing);
    expect(find.text('2 cards available for this selection.'), findsOneWidget);
  });

  testWidgets('material-scoped weak filter and training stay scoped', (
    tester,
  ) async {
    await _pumpScope(tester, [_weakOne, _dueOne, _otherMaterial]);
    await _openFlashcards(tester, _materialOneArgs);

    await tester.tap(find.text('For review'));
    await tester.pumpAndSettle();
    expect(find.text('1 card available for this selection.'), findsOneWidget);
    expect(find.text('Weak one'), findsOneWidget);
    expect(find.text('Due one'), findsNothing);
    expect(find.text('Other material'), findsNothing);

    await tester.ensureVisible(find.text('Train cards for review'));
    await tester.tap(find.text('Train cards for review'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Weak one'), findsOneWidget);
    expect(find.text('Other material'), findsNothing);
  });

  testWidgets('material-scoped due filter and training stay scoped', (
    tester,
  ) async {
    await _pumpScope(tester, [_weakOne, _dueOne, _otherMaterial]);
    await _openFlashcards(tester, _materialOneArgs);

    await tester.tap(find.text('Due for review'));
    await tester.pumpAndSettle();
    expect(find.text('1 card available for this selection.'), findsOneWidget);
    expect(find.text('Due one'), findsOneWidget);
    expect(find.text('Other material'), findsNothing);

    await tester.ensureVisible(find.text('Review due cards'));
    await tester.tap(find.text('Review due cards'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Due one'), findsOneWidget);
    expect(find.text('Other material'), findsNothing);
  });

  testWidgets('empty material scope never falls back to subject cards', (
    tester,
  ) async {
    await _pumpScope(tester, [_otherMaterial]);
    await _openFlashcards(tester, _materialOneArgs);

    expect(find.text('0 cards from this material'), findsOneWidget);
    expect(find.text('No flashcards yet'), findsOneWidget);
    expect(find.text('Other material'), findsNothing);
    expect(find.textContaining('Start training'), findsNothing);
  });
}

Future<void> _pumpScope(WidgetTester tester, List<Flashcard> cards) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [_materialOne, _materialTwo],
      ),
      flashcardRepository: _ScopeFlashcardRepository(cards),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
}

Future<void> _openFlashcards(
  WidgetTester tester,
  FlashcardsRouteArgs args,
) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(AppRoutes.flashcards, arguments: args);
  await tester.pumpAndSettle();
}

class _ScopeFlashcardRepository implements FlashcardRepository {
  _ScopeFlashcardRepository(this.cards);

  final List<Flashcard> cards;

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async => cards;

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) async => card;
}

const _subject = Subject(
  id: 'biology',
  name: 'Biology',
  description: 'Biology subject',
  colorValue: 0xFF16A34A,
);

const _materialOne = StudyMaterial(
  id: 'material-1',
  subjectId: 'biology',
  title: 'First material',
  kind: MaterialKind.pastedText,
  content: 'Enough material content for flashcards and focused study practice.',
  createdLabel: 'Today',
);

const _materialTwo = StudyMaterial(
  id: 'material-2',
  subjectId: 'biology',
  title: 'Second material',
  kind: MaterialKind.pastedText,
  content: 'A second sufficiently detailed material used for scope testing.',
  createdLabel: 'Today',
);

const _materialOneArgs = FlashcardsRouteArgs(
  subject: _subject,
  materialId: 'material-1',
  materialTitle: 'First material',
);

const _weakOne = Flashcard(
  id: 'weak-1',
  subjectId: 'biology',
  materialId: 'material-1',
  front: 'Weak one',
  back: 'Weak answer',
  topic: 'One',
  isFavorite: false,
  incorrectCount: 2,
);

final _dueOne = Flashcard(
  id: 'due-1',
  subjectId: 'biology',
  materialId: 'material-1',
  front: 'Due one',
  back: 'Due answer',
  topic: 'One',
  isFavorite: false,
  nextReviewAt: DateTime.utc(2020),
);

final _otherMaterial = Flashcard(
  id: 'other-1',
  subjectId: 'biology',
  materialId: 'material-2',
  front: 'Other material',
  back: 'Other answer',
  topic: 'Two',
  isFavorite: false,
  incorrectCount: 4,
  nextReviewAt: DateTime.utc(2020),
);
