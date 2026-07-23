import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/persisted_study_activity.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_attempt.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/favorites/favorite_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_taking_screen.dart';
import 'package:ai_study_buddy/features/study_sessions/study_activity_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Review all creates a new persisted session and grades it exactly once',
    (tester) async {
      final activities = _RecordingStudyActivityRepository();
      final cards = _RecordingFlashcardRepository();
      activities.onFlashcardGrade = () => cards.correctCount += 1;
      final original = activities.seedFlashcards();
      await _pump(tester, activities: activities, flashcards: cards);
      await _route(
        tester,
        AppRoutes.flashcardTraining,
        FlashcardTrainingArgs(
          subject: _subject,
          material: _material,
          cards: const [_card],
          session: original,
        ),
      );

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I knew it'));
      await tester.pumpAndSettle();

      final completedOriginal = activities.sessions[original.id]!;
      expect(completedOriginal.isCompleted, isTrue);
      expect(activities.finalizeFlashcardCalls[original.id], 1);
      expect(activities.flashcardGrades[original.id], 1);

      await tester.tap(find.text('Review again'));
      await tester.pumpAndSettle();

      final replacementId = activities.startedFlashcardIds.last;
      expect(replacementId, isNot(original.id));
      expect(activities.sessions[replacementId]!.currentIndex, 0);
      expect(activities.sessions[replacementId]!.itemIds, original.itemIds);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I knew it'));
      await tester.pumpAndSettle();

      expect(activities.flashcardGrades[replacementId], 1);
      expect(cards.correctCount, 2);
      expect(activities.sessions[original.id], completedOriginal);
      expect(activities.finalizeFlashcardCalls[original.id], 1);
    },
  );

  testWidgets(
    'Quiz Retry creates a new draft and attempt without provider generation',
    (tester) async {
      final activities = _RecordingStudyActivityRepository();
      final quizzes = _RecordingQuizRepository();
      final original = activities.seedQuiz();
      await _pump(tester, activities: activities, quizzes: quizzes);
      await _route(
        tester,
        AppRoutes.quizTaking,
        QuizTakingArgs(
          subject: _subject,
          material: _material,
          quiz: _quiz,
          session: original,
          randomSeed: 17,
        ),
      );

      await tester.tap(find.text('Wrong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show score'));
      await tester.pumpAndSettle();

      final completedOriginal = activities.sessions[original.id]!;
      final originalAttempt = quizzes.attempts.single;
      expect(completedOriginal.isCompleted, isTrue);
      expect(activities.finalizeQuizCalls[original.attemptId], 1);

      await tester.tap(find.text('Retry quiz'));
      await tester.pumpAndSettle();

      final replacementId = activities.startedQuizSessionIds.last;
      final replacement = activities.sessions[replacementId]!;
      expect(replacementId, isNot(original.id));
      expect(replacement.attemptId, isNot(original.attemptId));
      expect(replacement.currentIndex, 0);
      expect(replacement.selectedAnswers, isEmpty);

      await tester.tap(find.text('Correct'));
      await tester.pumpAndSettle();

      expect(activities.sessions[replacementId]!.selectedAnswers, {
        _question.id: 'Correct',
      });
      expect(activities.sessions[original.id], completedOriginal);
      expect(
        quizzes.attempts.firstWhere((a) => a.id == originalAttempt.id),
        originalAttempt,
      );
      expect(quizzes.generateCalls, 0);

      await tester.tap(find.text('Show score'));
      await tester.pumpAndSettle();

      expect(quizzes.attempts, hasLength(2));
      expect(activities.finalizeQuizCalls[replacement.attemptId], 1);
      expect(activities.finalizeQuizCalls[original.attemptId], 1);
      expect(
        quizzes.attempts.firstWhere((a) => a.id == originalAttempt.id),
        originalAttempt,
      );
      expect(quizzes.generateCalls, 0);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _RecordingStudyActivityRepository activities,
  _RecordingFlashcardRepository? flashcards,
  _RecordingQuizRepository? quizzes,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      config: _config,
      authRepository: MockAuthRepository(initialUser: _user),
      subjectRepository: MockSubjectRepository(
        initialSubjects: const [_subject],
      ),
      materialRepository: MockMaterialRepository(
        initialMaterials: const [_material],
      ),
      favoriteRepository: MockFavoriteRepository(),
      flashcardRepository: flashcards ?? _RecordingFlashcardRepository(),
      quizRepository: quizzes ?? _RecordingQuizRepository(),
      studyActivityRepository: activities,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _route(WidgetTester tester, String name, Object arguments) async {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed(name, arguments: arguments);
  await tester.pumpAndSettle();
}

const _config = AppConfig(
  backendMode: AppBackendMode.supabase,
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'sb_publishable_test-client-key',
);
const _user = AuthUser(id: 'user-1', email: 'learner@example.test');
const _subject = Subject(
  id: 'subject-1',
  name: 'Physics',
  description: 'Physics',
  colorValue: 0xFF3366CC,
);
const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Energy',
  kind: MaterialKind.pastedText,
  content: 'Energy is conserved in an isolated system.',
  createdLabel: 'Today',
);
const _card = Flashcard(
  id: 'card-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'Energy?',
  back: 'Capacity to do work.',
  topic: 'Energy',
  isFavorite: false,
);
const _question = QuizQuestion(
  id: 'question-1',
  quizId: 'quiz-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  question: 'Choose the correct answer.',
  options: ['Correct', 'Wrong'],
  correctAnswer: 'Correct',
  explanation: 'Correct is correct.',
  topic: 'Energy',
  difficulty: StudyDifficulty.easy,
);
const _quiz = Quiz(
  id: 'quiz-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Energy quiz',
  questions: [_question],
);

class _RecordingFlashcardRepository implements FlashcardRepository {
  int correctCount = 0;

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async => [
    _card.copyWith(correctCount: correctCount),
  ];

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) => throw UnimplementedError();

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) => throw UnimplementedError();
}

class _RecordingQuizRepository implements QuizRepository {
  final List<QuizAttempt> attempts = [];
  int generateCalls = 0;

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async => const [_quiz];

  @override
  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user) async =>
      List.of(attempts);

  @override
  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    generateCalls += 1;
    return _quiz;
  }

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttemptSubmission submission,
  }) async {
    final selected = submission.selectedAnswers.single.selectedAnswer;
    final correct = selected == _question.correctAnswer;
    final attempt = QuizAttempt(
      id: submission.attemptId,
      quizId: submission.quizId,
      subjectId: _subject.id,
      score: correct ? 100 : 0,
      totalQuestions: 1,
      correctQuestions: correct ? 1 : 0,
      startedAt: submission.startedAt,
      completedAt: DateTime.utc(2026, 7, 23, 12),
      answers: [
        QuizAttemptAnswer(
          questionId: _question.id,
          question: _question.question,
          selectedAnswer: selected,
          correctAnswer: _question.correctAnswer,
          isCorrect: correct,
          topic: _question.topic,
          difficulty: _question.difficulty,
        ),
      ],
      weakTopicsSnapshot: correct
          ? const []
          : const [QuizWeakTopicSnapshot(topic: 'Energy', missCount: 1)],
    );
    attempts.add(attempt);
    return attempt;
  }
}

class _RecordingStudyActivityRepository extends EmptyStudyActivityRepository {
  final Map<String, PersistedStudyActivity> sessions = {};
  final List<String> startedFlashcardIds = [];
  final List<String> startedQuizSessionIds = [];
  final Map<String, int> flashcardGrades = {};
  final Map<String, int> finalizeFlashcardCalls = {};
  final Map<String, int> finalizeQuizCalls = {};
  void Function()? onFlashcardGrade;

  PersistedStudyActivity seedFlashcards() {
    final session = _session(
      id: 'old-flashcard-session',
      type: PersistedStudyActivityType.flashcards,
      itemIds: [_card.id],
      flashcardMode: FlashcardTrainingMode.all,
    );
    sessions[session.id] = session;
    return session;
  }

  PersistedStudyActivity seedQuiz() {
    final session = _session(
      id: 'old-quiz-session',
      type: PersistedStudyActivityType.quizDraft,
      itemIds: [_question.id],
      attemptId: '00000000-0000-4000-8000-000000000001',
      quizId: _quiz.id,
      optionOrders: {
        _question.id: ['Correct', 'Wrong'],
      },
    );
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<List<PersistedStudyActivity>> loadActive(AuthUser user) async =>
      sessions.values.where((session) => !session.isCompleted).toList();

  @override
  Future<List<PersistedStudyActivity>> loadRecentCompleted(
    AuthUser user,
  ) async => sessions.values.where((session) => session.isCompleted).toList();

  @override
  Future<PersistedStudyActivity> startFlashcards({
    required AuthUser user,
    required String sessionId,
    required String materialId,
    required FlashcardTrainingMode mode,
    required List<String> cardIds,
  }) async {
    final session = _session(
      id: sessionId,
      type: PersistedStudyActivityType.flashcards,
      itemIds: cardIds,
      flashcardMode: mode,
    );
    sessions[sessionId] = session;
    startedFlashcardIds.add(sessionId);
    return session;
  }

  @override
  Future<PersistedStudyActivity> updateFlashcards({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required bool answerVisible,
    String? cardId,
    String? result,
    DateTime? reviewedAt,
  }) async {
    final current = sessions[session.id]!;
    if (current.isCompleted) {
      throw const StudyActivityRepositoryException('completed');
    }
    if (cardId != null && result != null) {
      flashcardGrades.update(
        session.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      onFlashcardGrade?.call();
    }
    final updated = _copy(
      current,
      version: current.version + 1,
      currentIndex: currentIndex,
      answerVisible: answerVisible,
      knownCount: current.knownCount + (result == 'known' ? 1 : 0),
      notKnownCount: current.notKnownCount + (result == 'not_known' ? 1 : 0),
    );
    sessions[session.id] = updated;
    return updated;
  }

  @override
  Future<PersistedStudyActivity> finalizeFlashcards({
    required AuthUser user,
    required String sessionId,
  }) async {
    finalizeFlashcardCalls.update(
      sessionId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final completed = _copy(
      sessions[sessionId]!,
      completedAt: DateTime.utc(2026, 7, 23, 11),
    );
    sessions[sessionId] = completed;
    return completed;
  }

  @override
  Future<PersistedStudyActivity> startQuiz({
    required AuthUser user,
    required String attemptId,
    required Quiz quiz,
  }) async {
    final id = 'quiz-session-$attemptId';
    final session = _session(
      id: id,
      type: PersistedStudyActivityType.quizDraft,
      itemIds: [for (final question in quiz.questions) question.id],
      attemptId: attemptId,
      quizId: quiz.id,
      optionOrders: {
        for (final question in quiz.questions) question.id: question.options,
      },
    );
    sessions[id] = session;
    startedQuizSessionIds.add(id);
    return session;
  }

  @override
  Future<PersistedStudyActivity> updateQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required String questionId,
    required String selectedAnswer,
  }) async {
    final current = sessions[session.id]!;
    if (current.isCompleted) {
      throw const StudyActivityRepositoryException('completed');
    }
    final updated = _copy(
      current,
      version: current.version + 1,
      currentIndex: currentIndex,
      selectedAnswers: {...current.selectedAnswers, questionId: selectedAnswer},
    );
    sessions[session.id] = updated;
    return updated;
  }

  @override
  Future<void> finalizeQuiz({
    required AuthUser user,
    required String attemptId,
  }) async {
    finalizeQuizCalls.update(
      attemptId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final entry = sessions.entries.singleWhere(
      (entry) => entry.value.attemptId == attemptId,
    );
    sessions[entry.key] = _copy(
      entry.value,
      completedAt: DateTime.utc(2026, 7, 23, 12),
    );
  }
}

PersistedStudyActivity _session({
  required String id,
  required PersistedStudyActivityType type,
  required List<String> itemIds,
  String? attemptId,
  String? quizId,
  FlashcardTrainingMode? flashcardMode,
  Map<String, List<String>> optionOrders = const {},
}) => PersistedStudyActivity(
  id: id,
  subjectId: _subject.id,
  materialId: _material.id,
  type: type,
  version: 1,
  currentIndex: 0,
  itemIds: itemIds,
  updatedAt: DateTime.utc(2026, 7, 23),
  attemptId: attemptId,
  quizId: quizId,
  flashcardMode: flashcardMode,
  optionOrders: optionOrders,
);

PersistedStudyActivity _copy(
  PersistedStudyActivity source, {
  int? version,
  int? currentIndex,
  bool? answerVisible,
  int? knownCount,
  int? notKnownCount,
  Map<String, String>? selectedAnswers,
  DateTime? completedAt,
}) => PersistedStudyActivity(
  id: source.id,
  subjectId: source.subjectId,
  materialId: source.materialId,
  type: source.type,
  version: version ?? source.version,
  currentIndex: currentIndex ?? source.currentIndex,
  itemIds: source.itemIds,
  updatedAt: DateTime.utc(2026, 7, 23, 10, version ?? source.version),
  attemptId: source.attemptId,
  quizId: source.quizId,
  flashcardMode: source.flashcardMode,
  answerVisible: answerVisible ?? source.answerVisible,
  firstPassMissedIds: source.firstPassMissedIds,
  knownCount: knownCount ?? source.knownCount,
  notKnownCount: notKnownCount ?? source.notKnownCount,
  selectedAnswers: selectedAnswers ?? source.selectedAnswers,
  optionOrders: source.optionOrders,
  completedAt: completedAt ?? source.completedAt,
);
