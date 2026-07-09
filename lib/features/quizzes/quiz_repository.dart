import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/quiz.dart';
import '../../core/models/quiz_question.dart';
import '../../features/auth/auth_models.dart';

abstract class QuizRepository {
  Future<List<Quiz>> loadQuizzes(AuthUser user);

  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  });
}

class QuizRepositoryException implements Exception {
  const QuizRepositoryException(this.message);

  final String message;
}

const quizTooShortMessage = 'Add more lecture text before generating a quiz.';

class MockQuizRepository implements QuizRepository {
  MockQuizRepository({List<Quiz> initialQuizzes = const []})
    : _quizzes = List<Quiz>.of(initialQuizzes);

  final List<Quiz> _quizzes;

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    return List<Quiz>.of(_quizzes);
  }

  @override
  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    final safeCount = count.clamp(1, 20).toInt();
    final quiz = Quiz(
      id: 'mock-quiz-$materialId',
      subjectId: '',
      materialId: materialId,
      title: 'Mock quiz',
      questions: [
        for (var index = 0; index < safeCount; index += 1)
          QuizQuestion(
            id: 'mock-quiz-$materialId-question-${index + 1}',
            quizId: 'mock-quiz-$materialId',
            subjectId: '',
            materialId: materialId,
            question: 'Mock quiz question ${index + 1}',
            options: const [
              'A focused answer',
              'A distractor',
              'Another distractor',
              'Last distractor',
            ],
            correctAnswer: 'A focused answer',
            explanation:
                'This mock answer is generated from the selected material.',
            topic: 'Generated practice',
            difficulty: StudyDifficulty.medium,
          ),
      ],
    );
    _quizzes
      ..removeWhere((item) => item.materialId == materialId)
      ..insert(0, quiz);
    return quiz;
  }
}

class SupabaseQuizRepository implements QuizRepository {
  const SupabaseQuizRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    try {
      final quizRows = await _client
          .from('quizzes')
          .select('id,subject_id,material_id,title,question_count,created_at')
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      final quizIds = quizRows
          .map((row) => _stringValue(row, 'id'))
          .whereType<String>()
          .toList();
      if (quizIds.isEmpty) {
        return const [];
      }

      final questionRows = await _client
          .from('quiz_questions')
          .select(
            'id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order',
          )
          .eq('user_id', user.id)
          .inFilter('quiz_id', quizIds)
          .filter('deleted_at', 'is', null)
          .order('sort_order', ascending: true);

      final questionsByQuizId = <String, List<QuizQuestion>>{};
      for (final row in questionRows) {
        final question = _mapQuestion(row);
        final quizId = question.quizId;
        if (quizId == null || quizId.isEmpty) {
          continue;
        }
        questionsByQuizId.putIfAbsent(quizId, () => []).add(question);
      }

      return [
        for (final row in quizRows)
          _mapQuiz(row, questionsByQuizId[_stringValue(row, 'id')] ?? const []),
      ];
    } catch (_) {
      throw const QuizRepositoryException('Could not sync quizzes.');
    }
  }

  @override
  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'generate-quiz',
        body: <String, Object>{'material_id': materialId, 'count': count},
      );
      final data = response.data;
      final error = data['error'];
      if (error == quizTooShortMessage) {
        throw const QuizRepositoryException(quizTooShortMessage);
      }
      final questions = data['questions'];
      final quizId = _stringValue(data, 'quiz_id') ?? '';
      final returnedMaterialId =
          _stringValue(data, 'material_id') ?? materialId;
      final title = _stringValue(data, 'title') ?? 'Generated quiz';
      if (quizId.isEmpty || questions is! List) {
        throw const QuizRepositoryException(
          'Could not generate quiz. Try again.',
        );
      }
      final mappedQuestions = questions
          .whereType<Map<String, dynamic>>()
          .map(_mapQuestion)
          .where((question) => question.question.trim().isNotEmpty)
          .toList();
      if (mappedQuestions.isEmpty) {
        throw const QuizRepositoryException(
          'Could not generate quiz. Try again.',
        );
      }
      return Quiz(
        id: quizId,
        subjectId: mappedQuestions.first.subjectId,
        materialId: returnedMaterialId,
        title: title,
        questions: mappedQuestions,
      );
    } on QuizRepositoryException {
      rethrow;
    } catch (_) {
      throw const QuizRepositoryException(
        'Could not generate quiz. Try again.',
      );
    }
  }

  Quiz _mapQuiz(Map<String, dynamic> row, List<QuizQuestion> questions) {
    return Quiz(
      id: _stringValue(row, 'id') ?? '',
      subjectId: _stringValue(row, 'subject_id') ?? '',
      materialId: _stringValue(row, 'material_id') ?? '',
      title: _stringValue(row, 'title') ?? 'Generated quiz',
      questions: questions,
    );
  }

  QuizQuestion _mapQuestion(Map<String, dynamic> row) {
    return QuizQuestion(
      id: _stringValue(row, 'id') ?? '',
      quizId: _stringValue(row, 'quiz_id'),
      subjectId: _stringValue(row, 'subject_id') ?? '',
      materialId: _stringValue(row, 'material_id'),
      question: _stringValue(row, 'question') ?? '',
      options: _stringListValue(row['options']),
      correctAnswer: _stringValue(row, 'correct_answer') ?? '',
      explanation: _stringValue(row, 'explanation') ?? '',
      topic: _stringValue(row, 'topic') ?? 'General',
      difficulty: _difficultyFor(_stringValue(row, 'difficulty')),
    );
  }

  StudyDifficulty _difficultyFor(String? value) {
    return switch (value) {
      'easy' => StudyDifficulty.easy,
      'exam' => StudyDifficulty.exam,
      _ => StudyDifficulty.medium,
    };
  }

  List<String> _stringListValue(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ];
    }
    return const [];
  }

  static String? _stringValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      return null;
    }
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}

class EmptyQuizRepository implements QuizRepository {
  const EmptyQuizRepository();

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    return const [];
  }

  @override
  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    throw const QuizRepositoryException('Quiz generation is not configured.');
  }
}
