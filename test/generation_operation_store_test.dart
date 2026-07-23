import 'package:ai_study_buddy/features/generation/generation_operation_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relaunch reuses the same logical generation operation', () async {
    final store = MemoryGenerationOperationStore();
    final first = await store.loadOrCreate(
      userId: 'user',
      feature: 'generate_flashcards',
      materialId: 'material',
      count: 5,
    );
    final relaunched = await store.loadOrCreate(
      userId: 'user',
      feature: 'generate_flashcards',
      materialId: 'material',
      count: 5,
    );

    expect(relaunched, first);
  });

  test('feature, material, count, and user are conflict boundaries', () async {
    final store = MemoryGenerationOperationStore();
    final ids = <String>{};
    for (final input in [
      ('user-a', 'generate_flashcards', 'material-a', 5),
      ('user-b', 'generate_flashcards', 'material-a', 5),
      ('user-a', 'generate_quiz_questions', 'material-a', 5),
      ('user-a', 'generate_flashcards', 'material-b', 5),
      ('user-a', 'generate_flashcards', 'material-a', 6),
    ]) {
      ids.add(
        await store.loadOrCreate(
          userId: input.$1,
          feature: input.$2,
          materialId: input.$3,
          count: input.$4,
        ),
      );
    }
    expect(ids, hasLength(5));
  });

  test('only exact successful or terminal operation is cleared', () async {
    final store = MemoryGenerationOperationStore();
    final operationId = await store.loadOrCreate(
      userId: 'user',
      feature: 'generate_quiz_questions',
      materialId: 'material',
      count: 5,
    );
    await store.clear(
      userId: 'user',
      feature: 'generate_quiz_questions',
      materialId: 'material',
      count: 5,
      operationId: 'different-operation',
    );
    expect(
      store.operationFor(
        userId: 'user',
        feature: 'generate_quiz_questions',
        materialId: 'material',
        count: 5,
      ),
      operationId,
    );
    await store.clear(
      userId: 'user',
      feature: 'generate_quiz_questions',
      materialId: 'material',
      count: 5,
      operationId: operationId,
    );
    expect(
      store.operationFor(
        userId: 'user',
        feature: 'generate_quiz_questions',
        materialId: 'material',
        count: 5,
      ),
      isNull,
    );
  });
}
