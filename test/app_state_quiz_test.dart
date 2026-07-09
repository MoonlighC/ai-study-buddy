import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/quiz.dart';
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
    this._generatedQuiz,
    this.throwOnGenerate = false,
  }) : _quizzes = List<Quiz>.of(loadedQuizzes);

  final List<Quiz> _quizzes;
  final Quiz? _generatedQuiz;
  final bool throwOnGenerate;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];
  final List<int> generatedCounts = [];

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    loadedUsers.add(user);
    return List<Quiz>.of(_quizzes);
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
    final quiz = _generatedQuiz ?? _generatedQuizFor(materialId);
    _quizzes
      ..removeWhere((item) => item.materialId == materialId)
      ..insert(0, quiz);
    return quiz;
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
