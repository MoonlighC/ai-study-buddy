import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/quiz.dart';
import '../../core/models/quiz_attempt.dart';
import '../../core/models/quiz_question.dart';
import '../../features/auth/auth_models.dart';

abstract class QuizRepository {
  Future<List<Quiz>> loadQuizzes(AuthUser user);

  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user);

  Future<Quiz> generateQuiz({
    required AuthUser user,
    required String materialId,
    required int count,
  });

  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttempt attempt,
  });
}

class QuizRepositoryException implements Exception {
  const QuizRepositoryException(this.message);

  final String message;
}

const quizTooShortMessage = 'Add more lecture text before generating a quiz.';

class MockQuizRepository implements QuizRepository {
  MockQuizRepository({
    List<Quiz> initialQuizzes = const [],
    List<QuizAttempt> initialAttempts = const [],
  }) : _quizzes = List<Quiz>.of(initialQuizzes),
       _attempts = List<QuizAttempt>.of(initialAttempts);

  final List<Quiz> _quizzes;
  final List<QuizAttempt> _attempts;

  @override
  Future<List<Quiz>> loadQuizzes(AuthUser user) async {
    return List<Quiz>.of(_quizzes);
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

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttempt attempt,
  }) async {
    final saved = attempt.copyWith(
      id: attempt.id.isEmpty
          ? 'mock-attempt-${_attempts.length + 1}'
          : attempt.id,
    );
    _attempts.insert(0, saved);
    return saved;
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
  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user) async {
    try {
      final rows = await _client
          .from('quiz_attempts')
          .select(
            'id,quiz_id,subject_id,score,total_questions,correct_questions,started_at,completed_at,answers,weak_topics_snapshot',
          )
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('completed_at', ascending: false);
      return [for (final row in rows) _mapAttempt(row)];
    } catch (_) {
      throw const QuizRepositoryException('Could not sync quiz attempts.');
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

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttempt attempt,
  }) async {
    try {
      final row = await _client
          .from('quiz_attempts')
          .insert({
            'user_id': user.id,
            'quiz_id': attempt.quizId,
            'subject_id': attempt.subjectId,
            'score': attempt.score,
            'total_questions': attempt.totalQuestions,
            'correct_questions': attempt.correctQuestions,
            'started_at': attempt.startedAt.toUtc().toIso8601String(),
            'completed_at': attempt.completedAt.toUtc().toIso8601String(),
            'answers': [for (final answer in attempt.answers) answer.toJson()],
            'weak_topics_snapshot': [
              for (final topic in attempt.weakTopicsSnapshot) topic.toJson(),
            ],
          })
          .select(
            'id,quiz_id,subject_id,score,total_questions,correct_questions,started_at,completed_at,answers,weak_topics_snapshot',
          )
          .single();
      return _mapAttempt(row);
    } catch (_) {
      throw const QuizRepositoryException('Could not save this quiz attempt.');
    }
  }

  QuizAttempt _mapAttempt(Map<String, dynamic> row) {
    final answers = row['answers'];
    final weakTopics = row['weak_topics_snapshot'];
    return QuizAttempt(
      id: _stringValue(row, 'id') ?? '',
      quizId: _stringValue(row, 'quiz_id') ?? '',
      subjectId: _stringValue(row, 'subject_id') ?? '',
      score: _doubleValue(row['score']),
      totalQuestions: _intValue(row['total_questions']),
      correctQuestions: _intValue(row['correct_questions']),
      startedAt: _dateTimeValue(row['started_at']),
      completedAt: _dateTimeValue(row['completed_at']),
      answers: answers is List
          ? [
              for (final answer in answers.whereType<Map<String, dynamic>>())
                QuizAttemptAnswer.fromJson(answer),
            ]
          : const [],
      weakTopicsSnapshot: weakTopics is List
          ? [
              for (final topic in weakTopics.whereType<Map<String, dynamic>>())
                QuizWeakTopicSnapshot.fromJson(topic),
            ]
          : const [],
    );
  }

  double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _dateTimeValue(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
  Future<List<QuizAttempt>> loadQuizAttempts(AuthUser user) async {
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

  @override
  Future<QuizAttempt> saveQuizAttempt({
    required AuthUser user,
    required QuizAttempt attempt,
  }) async {
    throw const QuizRepositoryException('Could not save this quiz attempt.');
  }
}
