import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/persisted_study_activity.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_taking_screen.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(id: 'user-1', email: 'student@example.test');
const _subject = Subject(
  id: 'subject-1',
  name: 'Physics',
  description: '',
  colorValue: 0xFF2563EB,
);
const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Lecture A',
  kind: MaterialKind.pastedText,
  content: 'Authoritative material content.',
  createdLabel: 'Today',
);
const _cards = [
  Flashcard(
    id: 'card-1',
    subjectId: 'subject-1',
    materialId: 'material-1',
    front: 'First question',
    back: 'First answer',
    topic: 'One',
    isFavorite: false,
  ),
  Flashcard(
    id: 'card-2',
    subjectId: 'subject-1',
    materialId: 'material-1',
    front: 'Restored question',
    back: 'Restored answer',
    topic: 'Two',
    isFavorite: false,
  ),
];
const _quiz = Quiz(
  id: 'quiz-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Quick quiz',
  questions: [
    QuizQuestion(
      id: 'question-1',
      quizId: 'quiz-1',
      subjectId: 'subject-1',
      materialId: 'material-1',
      question: 'First quiz question',
      options: ['A', 'B'],
      correctAnswer: 'A',
      explanation: 'First explanation',
      difficulty: StudyDifficulty.easy,
    ),
    QuizQuestion(
      id: 'question-2',
      quizId: 'quiz-1',
      subjectId: 'subject-1',
      materialId: 'material-1',
      question: 'Restored quiz question',
      options: ['C', 'D'],
      correctAnswer: 'D',
      explanation: 'Second explanation',
      difficulty: StudyDifficulty.medium,
    ),
  ],
);

void main() {
  testWidgets('flashcard force-stop snapshot restores exact card and answer', (
    tester,
  ) async {
    final session = _activity(
      type: PersistedStudyActivityType.flashcards,
      itemIds: const ['card-1', 'card-2'],
      currentIndex: 1,
      answerVisible: true,
      missed: const ['card-1'],
    );
    await _pump(
      tester,
      FlashcardTrainingScreen(
        args: FlashcardTrainingArgs(
          subject: _subject,
          material: _material,
          cards: _cards,
          session: session,
        ),
      ),
    );
    expect(find.textContaining('Restored answer'), findsOneWidget);
    expect(find.textContaining('First answer'), findsNothing);
  });

  testWidgets('quiz draft restores question, answer, and randomized options', (
    tester,
  ) async {
    final session = _activity(
      type: PersistedStudyActivityType.quizDraft,
      itemIds: const ['question-1', 'question-2'],
      currentIndex: 1,
      attemptId: 'attempt-1',
      quizId: 'quiz-1',
      selectedAnswers: const {'question-1': 'B'},
      optionOrders: const {
        'question-1': ['B', 'A'],
        'question-2': ['D', 'C'],
      },
    );
    await _pump(
      tester,
      QuizTakingScreen(
        args: QuizTakingArgs(
          subject: _subject,
          material: _material,
          quiz: _quiz,
          session: session,
        ),
      ),
    );
    expect(find.text('Restored quiz question'), findsOneWidget);
    final d = tester.getTopLeft(find.text('D')).dy;
    final c = tester.getTopLeft(find.text('C')).dy;
    expect(d, lessThan(c));
  });

  testWidgets('mistake-review snapshot restores only authoritative mistakes', (
    tester,
  ) async {
    final session = _activity(
      type: PersistedStudyActivityType.quizMistakeReview,
      itemIds: const ['question-2'],
      currentIndex: 0,
      attemptId: 'attempt-1',
    );
    await _pump(
      tester,
      QuizTakingScreen(
        args: QuizTakingArgs(
          subject: _subject,
          material: _material,
          quiz: _quiz,
          session: session,
        ),
      ),
    );
    expect(find.text('Restored quiz question'), findsOneWidget);
    expect(find.text('First quiz question'), findsNothing);
  });
}

PersistedStudyActivity _activity({
  required PersistedStudyActivityType type,
  required List<String> itemIds,
  required int currentIndex,
  bool answerVisible = false,
  List<String> missed = const [],
  String? attemptId,
  String? quizId,
  Map<String, String> selectedAnswers = const {},
  Map<String, List<String>> optionOrders = const {},
}) => PersistedStudyActivity(
  id: 'session-1',
  subjectId: _subject.id,
  materialId: _material.id,
  type: type,
  version: 3,
  currentIndex: currentIndex,
  itemIds: itemIds,
  updatedAt: DateTime.utc(2026, 7, 22),
  attemptId: attemptId,
  quizId: quizId,
  flashcardMode: type == PersistedStudyActivityType.flashcards
      ? FlashcardTrainingMode.all
      : null,
  answerVisible: answerVisible,
  firstPassMissedIds: missed,
  selectedAnswers: selectedAnswers,
  optionOrders: optionOrders,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  final state = AppState(config: AppConfig.fromValues());
  final auth = AuthController(
    authRepository: MockAuthRepository(initialUser: _user),
    profileRepository: NoopProfileRepository(),
  );
  await auth.initialize();
  addTearDown(state.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: AuthScope(
        controller: auth,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
