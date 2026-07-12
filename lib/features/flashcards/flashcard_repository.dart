import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/flashcard.dart';
import '../../features/auth/auth_models.dart';
import '../../mock/mock_data.dart';
import '../generation/generation_function_error.dart';

abstract class FlashcardRepository {
  Future<List<Flashcard>> loadFlashcards(AuthUser user);

  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  });

  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  });
}

class FlashcardGenerationResult {
  const FlashcardGenerationResult({
    required this.requestedCount,
    required this.createdCount,
    required this.newFlashcards,
  });

  final int requestedCount;
  final int createdCount;
  final List<Flashcard> newFlashcards;
}

enum FlashcardReviewResult { missed, known }

class FlashcardRepositoryException implements Exception {
  const FlashcardRepositoryException(this.message);

  final String message;
}

const flashcardsTooShortMessage =
    'Add more lecture text before generating flashcards.';

class MockFlashcardRepository implements FlashcardRepository {
  final Map<String, int> _generatedCardCounts = {};

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    return List<Flashcard>.of(MockData.flashcards);
  }

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) async {
    _validateRequestedCount(requestedNewCount);
    final existingGeneratedCount = _generatedCardCounts[materialId] ?? 0;
    final cards = [
      for (var index = 0; index < requestedNewCount; index += 1)
        Flashcard(
          id: 'mock-generated-$materialId-${existingGeneratedCount + index + 1}',
          subjectId: 'biology',
          materialId: materialId,
          front:
              'Mock generated question ${existingGeneratedCount + index + 1}',
          back:
              'Mock generated answer ${existingGeneratedCount + index + 1} from the selected material.',
          topic: 'Generated practice',
          difficulty: FlashcardDifficulty.medium,
          isFavorite: false,
        ),
    ];
    _generatedCardCounts[materialId] = existingGeneratedCount + cards.length;
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
  }) async {
    return _reviewedCard(card, result, reviewedAt);
  }
}

class SupabaseFlashcardRepository implements FlashcardRepository {
  const SupabaseFlashcardRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    try {
      final rows = await _client
          .from('flashcards')
          .select(
            'id,subject_id,material_id,front,back,topic,difficulty,correct_count,incorrect_count,last_reviewed_at,next_review_at,created_at',
          )
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      return rows.map(_mapFlashcard).toList();
    } catch (_) {
      throw const FlashcardRepositoryException('Could not sync flashcards.');
    }
  }

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) async {
    _validateRequestedCount(requestedNewCount);
    try {
      final response = await _client.functions.invoke(
        'generate-flashcards',
        body: <String, Object>{
          'material_id': materialId,
          'count': requestedNewCount,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FlashcardRepositoryException(
          'Could not generate flashcards. Try again.',
        );
      }
      final error = data['error'];
      if (error == flashcardsTooShortMessage) {
        throw const FlashcardRepositoryException(flashcardsTooShortMessage);
      }
      final cards = data['flashcards'];
      final requestedCount = data['requested_count'];
      final createdCount = data['created_count'];
      if (cards is! List ||
          requestedCount is! int ||
          createdCount is! int ||
          requestedCount != requestedNewCount ||
          createdCount < 0 ||
          createdCount > requestedCount) {
        throw const FlashcardRepositoryException(
          'Could not generate flashcards. Try again.',
        );
      }
      final mappedCards = cards
          .whereType<Map<String, dynamic>>()
          .map(_mapFlashcard)
          .where((card) => card.front.trim().isNotEmpty)
          .toList();
      if (mappedCards.length != createdCount) {
        throw const FlashcardRepositoryException(
          'Could not generate flashcards. Try again.',
        );
      }
      return FlashcardGenerationResult(
        requestedCount: requestedCount,
        createdCount: createdCount,
        newFlashcards: mappedCards,
      );
    } on FlashcardRepositoryException {
      rethrow;
    } on supabase.FunctionException catch (error) {
      final failure = classifyGenerationFunctionException(
        'generate-flashcards',
        error,
        'Could not generate flashcards. Try again.',
      );
      throw FlashcardRepositoryException(failure.message);
    } catch (_) {
      throw const FlashcardRepositoryException(
        'Could not generate flashcards. Try again.',
      );
    }
  }

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) async {
    final reviewedCard = _reviewedCard(card, result, reviewedAt);
    try {
      final row = await _client
          .from('flashcards')
          .update(<String, Object>{
            'correct_count': reviewedCard.correctCount,
            'incorrect_count': reviewedCard.incorrectCount,
            'last_reviewed_at': reviewedCard.lastReviewedAt!.toIso8601String(),
            'next_review_at': reviewedCard.nextReviewAt!.toIso8601String(),
          })
          .eq('id', card.id)
          .eq('user_id', user.id)
          .select(
            'id,subject_id,material_id,front,back,topic,difficulty,correct_count,incorrect_count,last_reviewed_at,next_review_at,created_at',
          )
          .single();

      return _mapFlashcard(row);
    } catch (_) {
      throw const FlashcardRepositoryException(
        'Could not save review progress.',
      );
    }
  }

  Flashcard _mapFlashcard(Map<String, dynamic> row) {
    return Flashcard(
      id: _stringValue(row, 'id') ?? '',
      subjectId: _stringValue(row, 'subject_id') ?? '',
      materialId: _stringValue(row, 'material_id'),
      front: _stringValue(row, 'front') ?? '',
      back: _stringValue(row, 'back') ?? '',
      topic: _stringValue(row, 'topic') ?? 'General',
      difficulty: _difficultyFor(_stringValue(row, 'difficulty')),
      isFavorite: false,
      correctCount: _intValue(row, 'correct_count'),
      incorrectCount: _intValue(row, 'incorrect_count'),
      lastReviewedAt: _dateTimeValue(row, 'last_reviewed_at'),
      nextReviewAt: _dateTimeValue(row, 'next_review_at'),
    );
  }

  FlashcardDifficulty _difficultyFor(String? value) {
    return switch (value) {
      'easy' => FlashcardDifficulty.easy,
      'exam' => FlashcardDifficulty.exam,
      _ => FlashcardDifficulty.medium,
    };
  }

  String? _stringValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      return null;
    }
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  int _intValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  DateTime? _dateTimeValue(Map<String, dynamic> row, String key) {
    final value = _stringValue(row, key);
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class EmptyFlashcardRepository implements FlashcardRepository {
  const EmptyFlashcardRepository();

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    return const [];
  }

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) async {
    throw const FlashcardRepositoryException(
      'Flashcard generation is not configured.',
    );
  }

  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) async {
    throw const FlashcardRepositoryException('Could not save review progress.');
  }
}

void _validateRequestedCount(int requestedNewCount) {
  if (requestedNewCount < 1 || requestedNewCount > 30) {
    throw const FlashcardRepositoryException(
      'Choose between 1 and 30 new flashcards.',
    );
  }
}

Flashcard _reviewedCard(
  Flashcard card,
  FlashcardReviewResult result,
  DateTime reviewedAt,
) {
  final nextReviewAt = switch (result) {
    FlashcardReviewResult.missed => reviewedAt.add(const Duration(days: 1)),
    FlashcardReviewResult.known => reviewedAt.add(const Duration(days: 3)),
  };
  return card.copyWith(
    correctCount: result == FlashcardReviewResult.known
        ? card.correctCount + 1
        : card.correctCount,
    incorrectCount: result == FlashcardReviewResult.missed
        ? card.incorrectCount + 1
        : card.incorrectCount,
    lastReviewedAt: reviewedAt,
    nextReviewAt: nextReviewAt,
  );
}
