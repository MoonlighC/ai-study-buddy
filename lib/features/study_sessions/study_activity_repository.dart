import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/persisted_study_activity.dart';
import '../../core/models/quiz.dart';
import '../../features/auth/auth_models.dart';

abstract class StudyActivityRepository {
  Future<List<PersistedStudyActivity>> loadActive(AuthUser user);
  Future<List<PersistedStudyActivity>> loadRecentCompleted(AuthUser user);
  Future<PersistedStudyActivity> startFlashcards({
    required AuthUser user,
    required String sessionId,
    required String materialId,
    required FlashcardTrainingMode mode,
    required List<String> cardIds,
  });
  Future<PersistedStudyActivity> updateFlashcards({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required bool answerVisible,
    String? cardId,
    String? result,
    DateTime? reviewedAt,
  });
  Future<PersistedStudyActivity> finalizeFlashcards({
    required AuthUser user,
    required String sessionId,
  });
  Future<PersistedStudyActivity> startQuiz({
    required AuthUser user,
    required String attemptId,
    required Quiz quiz,
  });
  Future<PersistedStudyActivity> updateQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required String questionId,
    required String selectedAnswer,
  });
  Future<PersistedStudyActivity> advanceQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  });
  Future<void> finalizeQuiz({
    required AuthUser user,
    required String attemptId,
  });
  Future<PersistedStudyActivity> startMistakeReview({
    required AuthUser user,
    required String attemptId,
  });
  Future<PersistedStudyActivity> updateMistakeReview({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  });
}

class StudyActivityRepositoryException implements Exception {
  const StudyActivityRepositoryException(this.message);
  final String message;
}

class EmptyStudyActivityRepository implements StudyActivityRepository {
  const EmptyStudyActivityRepository();
  Never _error() => throw const StudyActivityRepositoryException(
    'Study session sync is not configured.',
  );
  @override
  Future<List<PersistedStudyActivity>> loadActive(AuthUser user) async =>
      const [];
  @override
  Future<List<PersistedStudyActivity>> loadRecentCompleted(
    AuthUser user,
  ) async => const [];
  @override
  Future<PersistedStudyActivity> startFlashcards({
    required AuthUser user,
    required String sessionId,
    required String materialId,
    required FlashcardTrainingMode mode,
    required List<String> cardIds,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> updateFlashcards({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required bool answerVisible,
    String? cardId,
    String? result,
    DateTime? reviewedAt,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> finalizeFlashcards({
    required AuthUser user,
    required String sessionId,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> startQuiz({
    required AuthUser user,
    required String attemptId,
    required Quiz quiz,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> updateQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required String questionId,
    required String selectedAnswer,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> advanceQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async => _error();
  @override
  Future<void> finalizeQuiz({
    required AuthUser user,
    required String attemptId,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> startMistakeReview({
    required AuthUser user,
    required String attemptId,
  }) async => _error();
  @override
  Future<PersistedStudyActivity> updateMistakeReview({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async => _error();
}

class SupabaseStudyActivityRepository implements StudyActivityRepository {
  const SupabaseStudyActivityRepository(this._client);
  final supabase.SupabaseClient _client;
  @override
  Future<List<PersistedStudyActivity>> loadActive(AuthUser user) async {
    try {
      final results = await Future.wait([
        _client.rpc(
          'load_active_flashcard_training',
          params: {'p_material_id': null},
        ),
        _client.rpc('load_active_quiz_draft', params: {'p_material_id': null}),
        _client.rpc(
          'load_active_quiz_mistake_review',
          params: {'p_material_id': null},
        ),
      ]);
      final sessions = <PersistedStudyActivity>[];
      for (final result in results) {
        sessions.addAll(_rows(result).map(_map));
      }
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      throw const StudyActivityRepositoryException(
        'Could not restore study sessions.',
      );
    }
  }

  @override
  Future<List<PersistedStudyActivity>> loadRecentCompleted(
    AuthUser user,
  ) async {
    try {
      return _rows(
        await _client.rpc(
          'read_recent_completed_study_sessions',
          params: {'p_limit': 20},
        ),
      ).map(_map).toList();
    } catch (_) {
      throw const StudyActivityRepositoryException(
        'Could not load session history.',
      );
    }
  }

  @override
  Future<PersistedStudyActivity> startFlashcards({
    required AuthUser user,
    required String sessionId,
    required String materialId,
    required FlashcardTrainingMode mode,
    required List<String> cardIds,
  }) async => _single(
    await _client.rpc(
      'start_flashcard_training',
      params: {
        'p_session_id': sessionId,
        'p_material_id': materialId,
        'p_mode': _mode(mode),
        'p_card_ids': cardIds,
      },
    ),
  );
  @override
  Future<PersistedStudyActivity> updateFlashcards({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required bool answerVisible,
    String? cardId,
    String? result,
    DateTime? reviewedAt,
  }) async => _single(
    await _client.rpc(
      'update_flashcard_training',
      params: {
        'p_session_id': session.id,
        'p_expected_version': session.version,
        'p_current_index': currentIndex,
        'p_answer_visible': answerVisible,
        'p_card_id': cardId,
        'p_result': result,
        'p_reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      },
    ),
  );
  @override
  Future<PersistedStudyActivity> finalizeFlashcards({
    required AuthUser user,
    required String sessionId,
  }) async => _single(
    await _client.rpc(
      'finalize_flashcard_training',
      params: {'p_session_id': sessionId},
    ),
  );
  @override
  Future<PersistedStudyActivity> startQuiz({
    required AuthUser user,
    required String attemptId,
    required Quiz quiz,
  }) async {
    final orders = {for (final q in quiz.questions) q.id: q.options};
    return _single(
      await _client.rpc(
        'start_quiz_draft',
        params: {
          'p_attempt_id': attemptId,
          'p_quiz_id': quiz.id,
          'p_question_ids': quiz.questions.map((q) => q.id).toList(),
          'p_option_orders': orders,
        },
      ),
    );
  }

  @override
  Future<PersistedStudyActivity> updateQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required String questionId,
    required String selectedAnswer,
  }) async => _single(
    await _client.rpc(
      'update_quiz_draft',
      params: {
        'p_attempt_id': session.attemptId,
        'p_expected_version': session.version,
        'p_current_index': currentIndex,
        'p_question_id': questionId,
        'p_selected_answer': selectedAnswer,
      },
    ),
  );
  @override
  Future<PersistedStudyActivity> advanceQuiz({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async => _single(
    await _client.rpc(
      'update_quiz_draft',
      params: {
        'p_attempt_id': session.attemptId,
        'p_expected_version': session.version,
        'p_current_index': currentIndex,
        'p_question_id': null,
        'p_selected_answer': null,
      },
    ),
  );
  @override
  Future<void> finalizeQuiz({
    required AuthUser user,
    required String attemptId,
  }) async {
    await _client.rpc(
      'finalize_quiz_draft',
      params: {'p_attempt_id': attemptId},
    );
  }

  @override
  Future<PersistedStudyActivity> startMistakeReview({
    required AuthUser user,
    required String attemptId,
  }) async => _single(
    await _client.rpc(
      'start_quiz_mistake_review',
      params: {'p_attempt_id': attemptId},
    ),
  );
  @override
  Future<PersistedStudyActivity> updateMistakeReview({
    required AuthUser user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async => _single(
    await _client.rpc(
      'update_quiz_mistake_review',
      params: {
        'p_attempt_id': session.attemptId,
        'p_expected_version': session.version,
        'p_current_index': currentIndex,
      },
    ),
  );
  PersistedStudyActivity _single(Object? value) {
    final rows = _rows(value);
    if (rows.isEmpty) {
      throw const StudyActivityRepositoryException(
        'Could not sync study session.',
      );
    }
    return _map(rows.first);
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? [
          for (final row in value)
            if (row is Map) Map<String, dynamic>.from(row),
        ]
      : value is Map
      ? [Map<String, dynamic>.from(value)]
      : const [];
  PersistedStudyActivity _map(Map<String, dynamic> row) {
    final metadata = Map<String, dynamic>.from(
      row['metadata'] as Map? ?? const {},
    );
    final type = switch (row['session_type']) {
      'flashcards' => PersistedStudyActivityType.flashcards,
      'quiz_draft' => PersistedStudyActivityType.quizDraft,
      _ => PersistedStudyActivityType.quizMistakeReview,
    };
    final items = _strings(metadata['card_ids'] ?? metadata['question_ids']);
    return PersistedStudyActivity(
      id: '${row['id']}',
      subjectId: '${row['subject_id']}',
      materialId: '${row['material_id']}',
      type: type,
      version: (metadata['version'] as num?)?.toInt() ?? 1,
      currentIndex: (metadata['current_index'] as num?)?.toInt() ?? 0,
      itemIds: items,
      updatedAt:
          DateTime.tryParse(
            '${metadata['updated_at'] ?? row['updated_at']}',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attemptId:
          metadata['attempt_id']?.toString() ??
          row['quiz_attempt_id']?.toString(),
      quizId: metadata['quiz_id']?.toString(),
      flashcardMode: type == PersistedStudyActivityType.flashcards
          ? _modeFrom(metadata['mode'])
          : null,
      answerVisible: metadata['answer_visible'] == true,
      firstPassMissedIds: _strings(metadata['first_pass_missed_ids']),
      knownCount: (metadata['known_count'] as num?)?.toInt() ?? 0,
      notKnownCount: (metadata['not_known_count'] as num?)?.toInt() ?? 0,
      selectedAnswers: {
        for (final e
            in (metadata['selected_answers'] as Map? ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      optionOrders: {
        for (final e in (metadata['option_orders'] as Map? ?? const {}).entries)
          '${e.key}': _strings(e.value),
      },
      completedAt: DateTime.tryParse('${row['ended_at'] ?? ''}')?.toUtc(),
    );
  }

  List<String> _strings(Object? value) =>
      value is List ? value.map((e) => '$e').toList() : const [];
  String _mode(FlashcardTrainingMode value) => switch (value) {
    FlashcardTrainingMode.firstPassMissed => 'first_pass_missed',
    _ => value.name,
  };
  FlashcardTrainingMode _modeFrom(Object? value) => switch (value) {
    'first_pass_missed' => FlashcardTrainingMode.firstPassMissed,
    'weak' => FlashcardTrainingMode.weak,
    'due' => FlashcardTrainingMode.due,
    'favorites' => FlashcardTrainingMode.favorites,
    _ => FlashcardTrainingMode.all,
  };
}
