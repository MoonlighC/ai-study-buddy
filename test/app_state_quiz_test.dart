import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_attempt.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AppState quiz generation', () {
    test('mock quiz generation updates local quizzes', () async {
      final state = AppState(
        quizRepository: _FakeQuizRepository(generatedQuiz: _generatedQuiz),
      );

      final generated = await state.generateQuizFor(null, 'bio-lecture-1');

      expect(generated, isTrue);
      expect(state.latestQuizForMaterial('bio-lecture-1'), isNotNull);
      expect(
        state
            .latestQuizForMaterial('bio-lecture-1')
            ?.questions
            .single
            .subjectId,
        'biology',
      );
      expect(state.quizGenerationErrorMessage, isNull);
    });

    test(
      'supabase generation calls repository with material id and count',
      () async {
        final quizRepository = _FakeQuizRepository(
          generatedQuiz: _generatedQuiz,
        );
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: _FakeMaterialRepository(
            loadedMaterials: const [_material],
          ),
          quizRepository: quizRepository,
        );
        await state.loadMaterialsFor(user);

        final generated = await state.generateQuizFor(user, 'material-1');

        expect(generated, isTrue);
        expect(quizRepository.generatedUsers, [user]);
        expect(quizRepository.generatedMaterialIds, ['material-1']);
        expect(quizRepository.generatedCounts, [5]);
        expect(
          state.latestQuizForMaterial('material-1')?.questions,
          hasLength(1),
        );
      },
    );

    test('unauthenticated supabase generation fails safely', () async {
      final quizRepository = _FakeQuizRepository(generatedQuiz: _generatedQuiz);
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        quizRepository: quizRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateQuizFor(null, 'material-1');

      expect(generated, isFalse);
      expect(quizRepository.generatedMaterialIds, isEmpty);
      expect(
        state.quizGenerationErrorMessage,
        'Could not generate quiz. Try again.',
      );
    });

    test('generation failure preserves existing quiz', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        quizRepository: _FakeQuizRepository(
          loadedQuizzes: const [_existingQuiz],
          throwOnGenerate: true,
        ),
      );
      await state.loadMaterialsFor(user);
      await state.loadQuizzesFor(user);

      final generated = await state.generateQuizFor(user, 'material-1');

      expect(generated, isFalse);
      expect(state.latestQuizForMaterial('material-1')?.id, 'existing-quiz');
      expect(
        state.quizGenerationErrorMessage,
        'Could not generate quiz. Try again.',
      );
    });

    test('fake load path persists generated quizzes', () async {
      final quizRepository = _FakeQuizRepository(generatedQuiz: _generatedQuiz);
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        quizRepository: quizRepository,
      );
      await state.loadMaterialsFor(user);
      await state.generateQuizFor(user, 'material-1');

      final reloadedState = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        quizRepository: quizRepository,
      );
      await reloadedState.loadMaterialsFor(user);
      await reloadedState.loadQuizzesFor(user);

      expect(reloadedState.latestQuizForMaterial('material-1'), isNotNull);
      expect(
        reloadedState
            .latestQuizForMaterial('material-1')
            ?.questions
            .single
            .question,
        'Generated quiz question',
      );
    });

    test('supabase mode starts without mock quizzes', () {
      final state = AppState(config: _supabaseConfig());

      expect(state.quizzes, isEmpty);
      expect(state.latestQuizForMaterial('bio-lecture-1'), isNull);
    });
  });

  group('AppState quiz attempts', () {
    test(
      'completion saves score answers and deduplicated weak topics',
      () async {
        final repository = _FakeQuizRepository();
        final state = AppState(
          config: _supabaseConfig(),
          quizRepository: repository,
        );

        final saved = await state.completeQuizFor(
          user,
          attemptId: '00000000-0000-4000-8000-000000000001',
          quiz: _attemptQuiz,
          selectedAnswers: const {
            'attempt-question-1': 'Wrong',
            'attempt-question-2': 'Wrong',
            'attempt-question-3': 'Correct',
          },
          startedAt: DateTime.utc(2026, 7, 10, 10),
          completedAt: DateTime.utc(2026, 7, 10, 10, 5),
        );

        expect(saved, isTrue);
        expect(repository.attemptUsers, [user]);
        final attempt = repository.savedAttempts.single;
        expect(attempt.score, 33.33);
        expect(attempt.correctQuestions, 1);
        expect(attempt.totalQuestions, 3);
        expect(attempt.answers, hasLength(3));
        expect(attempt.answers.first.questionId, 'attempt-question-1');
        expect(attempt.answers.first.selectedAnswer, 'Wrong');
        expect(attempt.answers.first.correctAnswer, 'Correct');
        expect(attempt.answers.first.isCorrect, isFalse);
        expect(attempt.answers.first.topic, 'Shared topic');
        expect(attempt.weakTopicsSnapshot, hasLength(1));
        expect(attempt.weakTopicsSnapshot.single.topic, 'Shared topic');
        expect(attempt.weakTopicsSnapshot.single.missCount, 2);
        expect(
          state.latestQuizAttempt?.id,
          '00000000-0000-4000-8000-000000000001',
        );
      },
    );

    test('correct-only completion has no weak topics', () async {
      final repository = _FakeQuizRepository();
      final state = AppState(quizRepository: repository);

      final saved = await state.completeQuizFor(
        null,
        attemptId: '00000000-0000-4000-8000-000000000002',
        quiz: _generatedQuiz,
        selectedAnswers: const {'generated-question-1': 'Correct'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isTrue);
      expect(repository.savedAttempts.single.weakTopicsSnapshot, isEmpty);
    });

    test(
      'authoritative repository result replaces forged provisional data',
      () async {
        final repository = _FakeQuizRepository();
        final state = AppState(quizRepository: repository);
        final forgedQuiz = Quiz(
          id: _attemptQuiz.id,
          subjectId: 'forged-subject',
          materialId: _attemptQuiz.materialId,
          title: _attemptQuiz.title,
          questions: [
            for (final question in _attemptQuiz.questions)
              QuizQuestion(
                id: question.id,
                quizId: question.quizId,
                subjectId: 'forged-subject',
                materialId: question.materialId,
                question: 'Forged question',
                options: question.options,
                correctAnswer: 'Wrong',
                explanation: question.explanation,
                topic: 'Forged topic',
                difficulty: question.difficulty,
              ),
          ],
        );

        final saved = await state.completeQuizFor(
          null,
          attemptId: '00000000-0000-4000-8000-000000000007',
          quiz: forgedQuiz,
          selectedAnswers: const {
            'attempt-question-1': 'Correct',
            'attempt-question-2': 'Correct',
            'attempt-question-3': 'Correct',
          },
          startedAt: DateTime.utc(2026, 7, 10, 10),
        );

        expect(saved, isTrue);
        expect(state.latestQuizCompletion?.score, 100);
        expect(state.latestQuizCompletion?.subjectId, 'subject-1');
        expect(
          state.latestQuizCompletion?.answers.first.question,
          'Question one',
        );
        expect(
          state.latestQuizCompletion?.answers.first.correctAnswer,
          'Correct',
        );
        expect(state.latestQuizCompletion?.answers.first.topic, 'Shared topic');
        expect(
          state.latestQuizCompletion?.answers.first.difficulty,
          StudyDifficulty.easy,
        );
        expect(repository.savedSubmissions.single.toRpcParameters().keys, {
          'p_attempt_id',
          'p_quiz_id',
          'p_started_at',
          'p_selected_answers',
        });
      },
    );

    test(
      'completion scores strings and preserves presented question order',
      () async {
        final repository = _FakeQuizRepository();
        final state = AppState(quizRepository: repository);
        final presentedQuiz = Quiz(
          id: _attemptQuiz.id,
          subjectId: _attemptQuiz.subjectId,
          materialId: _attemptQuiz.materialId,
          title: _attemptQuiz.title,
          questions: _attemptQuiz.questions.reversed.toList(),
        );

        await state.completeQuizFor(
          null,
          attemptId: '00000000-0000-4000-8000-000000000003',
          quiz: presentedQuiz,
          selectedAnswers: const {
            'attempt-question-1': 'Correct',
            'attempt-question-2': 'Wrong',
            'attempt-question-3': 'Wrong',
          },
          startedAt: DateTime.utc(2026, 7, 10, 10),
        );

        final attempt = repository.savedAttempts.single;
        expect(attempt.answers.map((answer) => answer.questionId), [
          'attempt-question-3',
          'attempt-question-2',
          'attempt-question-1',
        ]);
        expect(attempt.answers.last.selectedAnswer, 'Correct');
        expect(attempt.answers.last.isCorrect, isTrue);
        expect(attempt.correctQuestions, 1);
      },
    );

    test('unauthenticated supabase completion fails safely', () async {
      final repository = _FakeQuizRepository();
      final state = AppState(
        config: _supabaseConfig(),
        quizRepository: repository,
      );

      final saved = await state.completeQuizFor(
        null,
        attemptId: '00000000-0000-4000-8000-000000000004',
        quiz: _generatedQuiz,
        selectedAnswers: const {'generated-question-1': 'Correct'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isFalse);
      expect(repository.savedAttempts, isEmpty);
      expect(
        state.quizAttemptSyncErrorMessage,
        'Could not save this quiz attempt.',
      );
    });

    test('save failure retains completion and exposes safe warning', () async {
      final state = AppState(
        quizRepository: _FakeQuizRepository(throwOnSave: true),
      );

      final saved = await state.completeQuizFor(
        null,
        attemptId: '00000000-0000-4000-8000-000000000005',
        quiz: _generatedQuiz,
        selectedAnswers: const {'generated-question-1': 'Wrong A'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );

      expect(saved, isFalse);
      expect(state.latestQuizCompletion?.score, 0);
      expect(
        state.latestQuizCompletion?.weakTopicsSnapshot.single.topic,
        'Generated topic',
      );
      expect(state.latestQuizAttempt, isNull);
      expect(
        state.quizAttemptSyncErrorMessage,
        'Could not save this quiz attempt.',
      );
    });

    test('mock repository reloads saved attempts', () async {
      final repository = MockQuizRepository(
        initialQuizzes: [_generatedQuiz],
        now: () => DateTime.utc(2026, 7, 10, 10, 5),
      );
      final state = AppState(quizRepository: repository);
      await state.completeQuizFor(
        null,
        attemptId: '00000000-0000-4000-8000-000000000006',
        quiz: _generatedQuiz,
        selectedAnswers: const {'generated-question-1': 'Correct'},
        startedAt: DateTime.utc(2026, 7, 10, 10),
      );
      final reloaded = AppState(quizRepository: repository);

      await reloaded.loadQuizAttemptsFor(null);

      expect(reloaded.latestQuizAttempt?.score, 100);
    });

    test(
      'loaded attempts are exposed and cleared on supabase sign-out',
      () async {
        final repository = _FakeQuizRepository(
          loadedAttempts: [_loadedAttempt],
        );
        final state = AppState(
          config: _supabaseConfig(),
          quizRepository: repository,
        );

        await state.loadQuizAttemptsFor(user);
        expect(state.latestQuizAttempt?.id, 'loaded-attempt');

        state.clearSyncedWorkspaceForSignOut();
        expect(state.quizAttempts, isEmpty);
      },
    );
  });
}

const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Cloud notes',
  kind: MaterialKind.pastedText,
  content:
      'Synced lecture text with enough detail to generate focused quiz questions. It explains the core idea, supporting evidence, and one point to review.',
  createdLabel: 'Synced',
);

const _generatedQuiz = Quiz(
  id: 'generated-quiz',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Generated quiz',
  questions: [
    QuizQuestion(
      id: 'generated-question-1',
      quizId: 'generated-quiz',
      subjectId: 'subject-1',
      materialId: 'material-1',
      question: 'Generated quiz question',
      options: ['Correct', 'Wrong A', 'Wrong B', 'Wrong C'],
      correctAnswer: 'Correct',
      explanation: 'Correct is supported by the material.',
      topic: 'Generated topic',
      difficulty: StudyDifficulty.medium,
    ),
  ],
);

const _existingQuiz = Quiz(
  id: 'existing-quiz',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Existing quiz',
  questions: [
    QuizQuestion(
      id: 'existing-question-1',
      quizId: 'existing-quiz',
      subjectId: 'subject-1',
      materialId: 'material-1',
      question: 'Existing quiz question',
      options: ['Correct', 'Wrong A', 'Wrong B', 'Wrong C'],
      correctAnswer: 'Correct',
      explanation: 'Existing explanation.',
      topic: 'Existing topic',
      difficulty: StudyDifficulty.easy,
    ),
  ],
);

const _attemptQuiz = Quiz(
  id: 'attempt-quiz',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Attempt quiz',
  questions: [
    QuizQuestion(
      id: 'attempt-question-1',
      subjectId: 'subject-1',
      question: 'Question one',
      options: ['Correct', 'Wrong'],
      correctAnswer: 'Correct',
      explanation: 'Explanation one',
      topic: ' Shared topic ',
      difficulty: StudyDifficulty.easy,
    ),
    QuizQuestion(
      id: 'attempt-question-2',
      subjectId: 'subject-1',
      question: 'Question two',
      options: ['Correct', 'Wrong'],
      correctAnswer: 'Correct',
      explanation: 'Explanation two',
      topic: 'Shared topic',
      difficulty: StudyDifficulty.medium,
    ),
    QuizQuestion(
      id: 'attempt-question-3',
      subjectId: 'subject-1',
      question: 'Question three',
      options: ['Correct', 'Wrong'],
      correctAnswer: 'Correct',
      explanation: 'Explanation three',
      topic: '',
      difficulty: StudyDifficulty.medium,
    ),
  ],
);

final _loadedAttempt = QuizAttempt(
  id: 'loaded-attempt',
  quizId: 'generated-quiz',
  subjectId: 'subject-1',
  score: 100,
  totalQuestions: 1,
  correctQuestions: 1,
  startedAt: DateTime.utc(2026, 7, 10, 10),
  completedAt: DateTime.utc(2026, 7, 10, 10),
  answers: [],
  weakTopicsSnapshot: [],
);

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'placeholder-anon-key',
  );
}

class _FakeQuizRepository implements QuizRepository {
  _FakeQuizRepository({
    List<Quiz> loadedQuizzes = const [],
    List<QuizAttempt> loadedAttempts = const [],
    Quiz? generatedQuiz,
    this.throwOnGenerate = false,
    this.throwOnSave = false,
  }) : _generatedQuizResult = generatedQuiz,
       _quizzes = List<Quiz>.of(loadedQuizzes),
       _attempts = List<QuizAttempt>.of(loadedAttempts);

  final List<Quiz> _quizzes;
  final List<QuizAttempt> _attempts;
  final Quiz? _generatedQuizResult;
  final bool throwOnGenerate;
  final bool throwOnSave;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];
  final List<int> generatedCounts = [];
  final List<AuthUser> attemptUsers = [];
  final List<QuizAttempt> savedAttempts = [];
  final List<QuizAttemptSubmission> savedSubmissions = [];

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    loadedUsers.add(user);
    return List<Quiz>.of(_quizzes);
  }

  @override
  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user) async {
    attemptUsers.add(user);
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
    final quiz = _generatedQuizResult ?? _generatedQuizFor(materialId);
    _quizzes
      ..removeWhere((item) => item.materialId == materialId)
      ..insert(0, quiz);
    return quiz;
  }

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttemptSubmission submission,
  }) async {
    attemptUsers.add(user);
    savedSubmissions.add(submission);
    if (throwOnSave) {
      throw const QuizRepositoryException('Could not save this quiz attempt.');
    }
    final authoritativeQuiz = switch (submission.quizId) {
      'attempt-quiz' => _attemptQuiz,
      'generated-quiz' => _generatedQuiz,
      _ => _quizzes.firstWhere((quiz) => quiz.id == submission.quizId),
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
    _attempts.insert(0, saved);
    return saved;
  }

  Quiz _generatedQuizFor(String materialId) {
    return Quiz(
      id: 'generated-$materialId',
      subjectId: 'subject-1',
      materialId: materialId,
      title: 'Generated quiz',
      questions: [
        QuizQuestion(
          id: 'generated-$materialId-question-1',
          quizId: 'generated-$materialId',
          subjectId: 'subject-1',
          materialId: materialId,
          question: 'Generated quiz question',
          options: const ['Correct', 'Wrong A', 'Wrong B', 'Wrong C'],
          correctAnswer: 'Correct',
          explanation: 'Correct is supported by the material.',
          difficulty: StudyDifficulty.medium,
        ),
      ],
    );
  }
}

class _FakeMaterialRepository implements MaterialRepository {
  _FakeMaterialRepository({this.loadedMaterials = const []});

  final List<StudyMaterial> loadedMaterials;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    return List<StudyMaterial>.of(loadedMaterials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    return StudyMaterial(
      id: 'created-1',
      subjectId: subjectId,
      title: title,
      kind: MaterialKind.pastedText,
      content: content,
      createdLabel: 'Just now',
    );
  }
}
