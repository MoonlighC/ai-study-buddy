import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/flashcard.dart';
import '../../features/auth/auth_models.dart';
import '../../mock/mock_data.dart';

abstract class FlashcardRepository {
  Future<List<Flashcard>> loadFlashcards(AuthUser user);

  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  });
}

class FlashcardRepositoryException implements Exception {
  const FlashcardRepositoryException(this.message);

  final String message;
}

const flashcardsTooShortMessage =
    'Add more lecture text before generating flashcards.';

class MockFlashcardRepository implements FlashcardRepository {
  const MockFlashcardRepository();

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    return List<Flashcard>.of(MockData.flashcards);
  }

  @override
  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    final safeCount = count.clamp(1, 20).toInt();
    return [
      for (var index = 0; index < safeCount; index += 1)
        Flashcard(
          id: 'mock-generated-$materialId-${index + 1}',
          subjectId: 'biology',
          materialId: materialId,
          front: 'Mock generated question ${index + 1}',
          back: 'Mock generated answer ${index + 1} from the selected material.',
          topic: 'Generated practice',
          difficulty: FlashcardDifficulty.medium,
          isFavorite: false,
        ),
    ];
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
            'id,subject_id,material_id,front,back,topic,difficulty,created_at',
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
  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'generate-flashcards',
        body: <String, Object>{'material_id': materialId, 'count': count},
      );
      final data = response.data;
      final error = data['error'];
      if (error == flashcardsTooShortMessage) {
        throw const FlashcardRepositoryException(flashcardsTooShortMessage);
      }
      final cards = data['flashcards'];
      if (cards is! List) {
        throw const FlashcardRepositoryException(
          'Could not generate flashcards. Try again.',
        );
      }
      return cards
          .whereType<Map<String, dynamic>>()
          .map(_mapFlashcard)
          .where((card) => card.front.trim().isNotEmpty)
          .toList();
    } on FlashcardRepositoryException {
      rethrow;
    } catch (_) {
      throw const FlashcardRepositoryException(
        'Could not generate flashcards. Try again.',
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
}

class EmptyFlashcardRepository implements FlashcardRepository {
  const EmptyFlashcardRepository();

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    return const [];
  }

  @override
  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    throw const FlashcardRepositoryException(
      'Flashcard generation is not configured.',
    );
  }
}
