import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_attempt.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/core/models/weak_topic.dart';
import 'package:ai_study_buddy/core/utils/uuid.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/progress/weak_topic_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('server-authoritative mock attempts', () {
    test('normalizes cumulative topics and keeps subjects separate', () async {
      final repository = _mockQuizRepository();
      final state = AppState(quizRepository: repository);

      await _completeWrong(state, _quizzes[0], 1);
      await _completeWrong(state, _quizzes[1], 2);
      await _completeWrong(state, _quizzes[2], 3);
      await _completeWrong(state, _quizzes[3], 4);

      final subjectOne = state.cumulativeWeakTopicsFor('subject-1');
      final subjectTwo = state.cumulativeWeakTopicsFor('subject-2');
      expect(subjectOne, hasLength(1));
      expect(subjectOne.single.topic, 'Cell Division');
      expect(subjectOne.single.missCount, 3);
      expect(subjectTwo, hasLength(1));
      expect(subjectTwo.single.missCount, 1);
      expect(
        state.cumulativeWeakTopics.any((topic) => topic.topic.trim().isEmpty),
        isFalse,
      );
    });

    test('same UUID is idempotent and another quiz collides', () async {
      final repository = _mockQuizRepository();
      final submission = _submission(_quizzes.first, 10);

      final first = await repository.saveQuizAttempt(
        user: _user,
        submission: submission,
      );
      final retried = await repository.saveQuizAttempt(
        user: _user,
        submission: QuizAttemptSubmission(
          attemptId: submission.attemptId,
          quizId: submission.quizId,
          startedAt: _serverCompletedAt.subtract(const Duration(days: 2)),
          selectedAnswers: const [],
        ),
      );

      expect(retried, same(first));
      expect(await repository.loadQuizAttempts(_user), hasLength(1));
      await expectLater(
        repository.saveQuizAttempt(
          user: _user,
          submission: QuizAttemptSubmission(
            attemptId: submission.attemptId,
            quizId: _quizzes[1].id,
            startedAt: submission.startedAt,
            selectedAnswers: _answersFor(_quizzes[1]),
          ),
        ),
        throwsA(isA<QuizRepositoryException>()),
      );
    });

    test('missing duplicate and foreign question ids are rejected', () async {
      final repository = _mockQuizRepository();
      final quiz = _quizzes.first;
      final base = _submission(quiz, 20);

      Future<void> rejects(List<QuizSelectedAnswer> answers, int suffix) async {
        await expectLater(
          repository.saveQuizAttempt(
            user: _user,
            submission: QuizAttemptSubmission(
              attemptId: _attemptId(suffix),
              quizId: quiz.id,
              startedAt: base.startedAt,
              selectedAnswers: answers,
            ),
          ),
          throwsA(isA<QuizRepositoryException>()),
        );
      }

      await rejects(base.selectedAnswers.take(1).toList(), 21);
      await rejects([
        base.selectedAnswers.first,
        base.selectedAnswers.first,
      ], 22);
      await rejects([
        base.selectedAnswers.first,
        const QuizSelectedAnswer(
          questionId: 'foreign-question',
          selectedAnswer: '',
        ),
      ], 23);
      expect(await repository.loadQuizAttempts(_user), isEmpty);
    });

    test('submission serializer exposes only permitted RPC fields', () {
      final submission = _submission(_quizzes.first, 30);
      final payload = submission.toRpcParameters();

      expect(payload.keys.toSet(), {
        'p_attempt_id',
        'p_quiz_id',
        'p_started_at',
        'p_selected_answers',
      });
      expect((payload['p_selected_answers']! as List).first, {
        'question_id': 'q-1',
        'selected_answer': 'Wrong',
      });
    });

    test('non-option selected answers are rejected safely', () async {
      final repository = _mockQuizRepository();
      final submission = _submission(_quizzes.first, 24);

      await expectLater(
        repository.saveQuizAttempt(
          user: _user,
          submission: QuizAttemptSubmission(
            attemptId: submission.attemptId,
            quizId: submission.quizId,
            startedAt: submission.startedAt,
            selectedAnswers: const [
              QuizSelectedAnswer(
                questionId: 'q-1',
                selectedAnswer: 'Not a stored option',
              ),
              QuizSelectedAnswer(questionId: 'q-2', selectedAnswer: 'Wrong'),
            ],
          ),
        ),
        throwsA(isA<QuizRepositoryException>()),
      );
      expect(await repository.loadQuizAttempts(_user), isEmpty);
    });

    test('clearly old and future attempt starts are rejected', () async {
      final repository = _mockQuizRepository();

      Future<void> rejects(DateTime startedAt, int suffix) async {
        await expectLater(
          repository.saveQuizAttempt(
            user: _user,
            submission: QuizAttemptSubmission(
              attemptId: _attemptId(suffix),
              quizId: _quizzes.first.id,
              startedAt: startedAt,
              selectedAnswers: _answersFor(_quizzes.first),
            ),
          ),
          throwsA(isA<QuizRepositoryException>()),
        );
      }

      await rejects(_serverCompletedAt.subtract(const Duration(hours: 25)), 25);
      await rejects(_serverCompletedAt.add(const Duration(minutes: 6)), 26);
      expect(await repository.loadQuizAttempts(_user), isEmpty);
    });

    test(
      'empty answers are incorrect and zero-question quizzes fail',
      () async {
        final repository = MockQuizRepository(
          initialQuizzes: [
            _quizzes.first,
            const Quiz(
              id: 'empty-quiz',
              subjectId: 'subject-1',
              materialId: 'material-1',
              title: 'Empty quiz',
              questions: [],
            ),
          ],
          now: () => _serverCompletedAt,
        );
        final base = _submission(_quizzes.first, 31);
        final saved = await repository.saveQuizAttempt(
          user: _user,
          submission: QuizAttemptSubmission(
            attemptId: base.attemptId,
            quizId: base.quizId,
            startedAt: base.startedAt,
            selectedAnswers: [
              for (final answer in base.selectedAnswers)
                QuizSelectedAnswer(
                  questionId: answer.questionId,
                  selectedAnswer: '',
                ),
            ],
          ),
        );

        expect(saved.correctQuestions, 0);
        expect(saved.answers.every((answer) => !answer.isCorrect), isTrue);
        await expectLater(
          repository.saveQuizAttempt(
            user: _user,
            submission: QuizAttemptSubmission(
              attemptId: _attemptId(32),
              quizId: 'empty-quiz',
              startedAt: base.startedAt,
              selectedAnswers: const [],
            ),
          ),
          throwsA(isA<QuizRepositoryException>()),
        );
      },
    );

    test('UUID helper creates version 4 variant UUIDs', () {
      final value = newUuidV4();
      expect(
        value,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });

  group('cumulative weak-topic state', () {
    test('workspace sync loads topics and sign-out clears them', () async {
      final weakRepository = _FakeWeakTopicRepository(topics: [_weakTopic]);
      final state = AppState(
        config: _supabaseConfig,
        weakTopicRepository: weakRepository,
      );

      await state.loadSyncedWorkspaceFor(_user);

      expect(weakRepository.loadedUsers, [_user]);
      expect(state.cumulativeWeakTopics.single.topic, 'Cell Division');
      state.clearSyncedWorkspaceForSignOut();
      expect(state.cumulativeWeakTopics, isEmpty);
      expect(state.weakTopicSyncErrorMessage, isNull);
    });

    test('successful save refreshes topics', () async {
      final weakRepository = _FakeWeakTopicRepository(topics: [_weakTopic]);
      final state = AppState(
        config: _supabaseConfig,
        quizRepository: MockQuizRepository(
          initialQuizzes: [_quizzes.first],
          now: () => _serverCompletedAt,
        ),
        weakTopicRepository: weakRepository,
      );

      final saved = await state.completeQuizFor(
        _user,
        attemptId: _attemptId(40),
        quiz: _quizzes.first,
        selectedAnswers: const {'q-1': 'Wrong', 'q-2': 'Wrong'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isTrue);
      expect(state.cumulativeWeakTopics.single.missCount, 3);
      expect(weakRepository.loadedUsers, [_user]);
    });

    test('returned server completion time replaces provisional time', () async {
      final serverCompletedAt = DateTime.utc(2026, 7, 10, 10, 6);
      final state = AppState(
        quizRepository: MockQuizRepository(
          initialQuizzes: [_quizzes.first],
          now: () => serverCompletedAt,
        ),
      );

      final saved = await state.completeQuizFor(
        null,
        attemptId: _attemptId(43),
        quiz: _quizzes.first,
        selectedAnswers: const {'q-1': 'Wrong', 'q-2': 'Wrong'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
        completedAt: DateTime.utc(2026, 7, 10, 10, 5),
      );

      expect(saved, isTrue);
      expect(state.latestQuizCompletion?.completedAt, serverCompletedAt);
      expect(state.latestQuizAttempt?.completedAt, serverCompletedAt);
    });

    test('failed save does not refresh or change topics', () async {
      final weakRepository = _FakeWeakTopicRepository(topics: [_weakTopic]);
      final state = AppState(
        config: _supabaseConfig,
        quizRepository: const EmptyQuizRepository(),
        weakTopicRepository: weakRepository,
      );

      final saved = await state.completeQuizFor(
        _user,
        attemptId: _attemptId(41),
        quiz: _quizzes.first,
        selectedAnswers: const {'q-1': 'Wrong', 'q-2': 'Wrong'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isFalse);
      expect(weakRepository.loadedUsers, isEmpty);
      expect(state.cumulativeWeakTopics, isEmpty);
      expect(state.latestQuizCompletion, isNotNull);
    });

    test('failed topic refresh preserves a committed attempt', () async {
      final state = AppState(
        config: _supabaseConfig,
        quizRepository: MockQuizRepository(
          initialQuizzes: [_quizzes.first],
          now: () => _serverCompletedAt,
        ),
        weakTopicRepository: const _ThrowingWeakTopicRepository(),
      );

      final saved = await state.completeQuizFor(
        _user,
        attemptId: _attemptId(42),
        quiz: _quizzes.first,
        selectedAnswers: const {'q-1': 'Wrong', 'q-2': 'Wrong'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isTrue);
      expect(state.quizAttempts, hasLength(1));
      expect(state.cumulativeWeakTopics, isEmpty);
      expect(
        state.weakTopicSyncErrorMessage,
        'Could not sync cumulative weak topics.',
      );
    });
  });
}

Future<void> _completeWrong(AppState state, Quiz quiz, int suffix) async {
  await state.completeQuizFor(
    null,
    attemptId: _attemptId(suffix),
    quiz: quiz,
    selectedAnswers: {
      for (final question in quiz.questions) question.id: 'Wrong',
    },
    startedAt: DateTime.utc(2026, 7, 10, 10, suffix),
  );
}

QuizAttemptSubmission _submission(Quiz quiz, int suffix) {
  return QuizAttemptSubmission(
    attemptId: _attemptId(suffix),
    quizId: quiz.id,
    startedAt: DateTime.utc(2026, 7, 10, 10),
    selectedAnswers: _answersFor(quiz),
  );
}

List<QuizSelectedAnswer> _answersFor(Quiz quiz) => [
  for (final question in quiz.questions)
    QuizSelectedAnswer(questionId: question.id, selectedAnswer: 'Wrong'),
];

MockQuizRepository _mockQuizRepository() =>
    MockQuizRepository(initialQuizzes: _quizzes, now: () => _serverCompletedAt);

String _attemptId(int suffix) =>
    '00000000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}';

const _user = AuthUser(id: 'user-1', email: 'learner@example.test');

final _supabaseConfig = AppConfig.fromValues(
  backendModeValue: 'supabase',
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'sb_publishable_test-client-key',
);

final _serverCompletedAt = DateTime.utc(2026, 7, 10, 10, 5);

final _weakTopic = CumulativeWeakTopic(
  id: 'weak-1',
  subjectId: 'subject-1',
  topic: 'Cell Division',
  topicKey: 'cell division',
  missCount: 3,
  lastSeenAt: DateTime.utc(2026, 7, 10),
);

const _quizzes = [
  Quiz(
    id: 'quiz-1',
    subjectId: 'subject-1',
    materialId: 'material-1',
    title: 'First quiz',
    questions: [
      QuizQuestion(
        id: 'q-1',
        quizId: 'quiz-1',
        subjectId: 'subject-1',
        question: 'First question',
        options: ['Correct', 'Wrong'],
        correctAnswer: 'Correct',
        explanation: '',
        topic: ' Cell Division ',
        difficulty: StudyDifficulty.easy,
      ),
      QuizQuestion(
        id: 'q-2',
        quizId: 'quiz-1',
        subjectId: 'subject-1',
        question: 'Second question',
        options: ['Correct', 'Wrong'],
        correctAnswer: 'Correct',
        explanation: '',
        topic: 'cell division',
        difficulty: StudyDifficulty.exam,
      ),
    ],
  ),
  Quiz(
    id: 'quiz-2',
    subjectId: 'subject-1',
    materialId: 'material-1',
    title: 'Second quiz',
    questions: [
      QuizQuestion(
        id: 'q-3',
        quizId: 'quiz-2',
        subjectId: 'subject-1',
        question: 'Third question',
        options: ['Correct', 'Wrong'],
        correctAnswer: 'Correct',
        explanation: '',
        topic: 'CELL DIVISION',
        difficulty: StudyDifficulty.medium,
      ),
    ],
  ),
  Quiz(
    id: 'quiz-3',
    subjectId: 'subject-2',
    materialId: 'material-2',
    title: 'Other subject',
    questions: [
      QuizQuestion(
        id: 'q-4',
        quizId: 'quiz-3',
        subjectId: 'subject-2',
        question: 'Fourth question',
        options: ['Correct', 'Wrong'],
        correctAnswer: 'Correct',
        explanation: '',
        topic: 'cell division',
        difficulty: StudyDifficulty.medium,
      ),
    ],
  ),
  Quiz(
    id: 'quiz-4',
    subjectId: 'subject-1',
    materialId: 'material-1',
    title: 'Blank topic',
    questions: [
      QuizQuestion(
        id: 'q-5',
        quizId: 'quiz-4',
        subjectId: 'subject-1',
        question: 'Fifth question',
        options: ['Correct', 'Wrong'],
        correctAnswer: 'Correct',
        explanation: '',
        topic: '   ',
        difficulty: StudyDifficulty.medium,
      ),
    ],
  ),
];

class _FakeWeakTopicRepository implements WeakTopicRepository {
  _FakeWeakTopicRepository({required this.topics});

  final List<CumulativeWeakTopic> topics;
  final List<AuthUser> loadedUsers = [];

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) async {
    loadedUsers.add(user);
    return List.of(topics);
  }
}

class _ThrowingWeakTopicRepository implements WeakTopicRepository {
  const _ThrowingWeakTopicRepository();

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) {
    throw const WeakTopicRepositoryException(
      'Could not sync cumulative weak topics.',
    );
  }
}
