import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AppState flashcard generation', () {
    test('mock flashcard generation updates local cards', () async {
      final state = AppState(
        flashcardRepository: _FakeFlashcardRepository(
          generatedCards: const [
            Flashcard(
              id: 'generated-1',
              subjectId: 'ignored',
              materialId: 'ignored',
              front: 'What is the source idea?',
              back: 'A focused answer from the material.',
              topic: 'Generated',
              isFavorite: false,
            ),
          ],
        ),
      );

      final generated = await state.generateFlashcardsFor(
        null,
        'bio-lecture-1',
      );

      expect(generated, isTrue);
      expect(state.flashcardsForMaterial('bio-lecture-1'), hasLength(1));
      expect(
        state.flashcardsForMaterial('bio-lecture-1').single.subjectId,
        'biology',
      );
      expect(state.flashcardGenerationErrorMessage, isNull);
    });

    test('supabase generation calls repository with material id and count', () async {
      final flashcardRepository = _FakeFlashcardRepository(
        generatedCards: const [_generatedCard],
      );
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        flashcardRepository: flashcardRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateFlashcardsFor(user, 'material-1');

      expect(generated, isTrue);
      expect(flashcardRepository.generatedUsers, [user]);
      expect(flashcardRepository.generatedMaterialIds, ['material-1']);
      expect(flashcardRepository.generatedCounts, [5]);
      expect(state.flashcardsForMaterial('material-1'), hasLength(1));
    });

    test('unauthenticated supabase generation fails safely', () async {
      final flashcardRepository = _FakeFlashcardRepository(
        generatedCards: const [_generatedCard],
      );
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        flashcardRepository: flashcardRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateFlashcardsFor(null, 'material-1');

      expect(generated, isFalse);
      expect(flashcardRepository.generatedMaterialIds, isEmpty);
      expect(
        state.flashcardGenerationErrorMessage,
        'Could not generate flashcards. Try again.',
      );
    });

    test('generation failure preserves existing flashcards', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        flashcardRepository: _FakeFlashcardRepository(
          loadedCards: const [_existingCard],
          throwOnGenerate: true,
        ),
      );
      await state.loadMaterialsFor(user);
      await state.loadFlashcardsFor(user);

      final generated = await state.generateFlashcardsFor(user, 'material-1');

      expect(generated, isFalse);
      expect(state.flashcardsForMaterial('material-1').single.id, 'existing-1');
      expect(
        state.flashcardGenerationErrorMessage,
        'Could not generate flashcards. Try again.',
      );
    });

    test('fake load path persists generated flashcards', () async {
      final flashcardRepository = _FakeFlashcardRepository(
        generatedCards: const [_generatedCard],
      );
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        flashcardRepository: flashcardRepository,
      );
      await state.loadMaterialsFor(user);
      await state.generateFlashcardsFor(user, 'material-1');

      final reloadedState = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        flashcardRepository: flashcardRepository,
      );
      await reloadedState.loadMaterialsFor(user);
      await reloadedState.loadFlashcardsFor(user);

      expect(reloadedState.flashcardsForMaterial('material-1'), hasLength(1));
      expect(reloadedState.flashcardsForMaterial('material-1').single.front, 'Generated front');
    });

    test('supabase mode starts without mock flashcards', () {
      final state = AppState(config: _supabaseConfig());

      expect(state.flashcardsFor('biology'), isEmpty);
      expect(state.favoriteFlashcards, isEmpty);
    });
  });
}

const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Cloud notes',
  kind: MaterialKind.pastedText,
  content:
      'Synced lecture text with enough detail to generate focused flashcards. It explains the core idea, supporting evidence, and one point to review.',
  createdLabel: 'Synced',
);

const _generatedCard = Flashcard(
  id: 'generated-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'Generated front',
  back: 'Generated back',
  topic: 'Generated topic',
  difficulty: FlashcardDifficulty.medium,
  isFavorite: false,
);

const _existingCard = Flashcard(
  id: 'existing-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'Existing front',
  back: 'Existing back',
  topic: 'Existing topic',
  isFavorite: false,
);

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'placeholder-anon-key',
  );
}

class _FakeFlashcardRepository implements FlashcardRepository {
  _FakeFlashcardRepository({
    List<Flashcard> loadedCards = const [],
    List<Flashcard> generatedCards = const [],
    this.throwOnGenerate = false,
  }) : _cards = List<Flashcard>.of(loadedCards),
       _generatedCards = List<Flashcard>.of(generatedCards);

  final List<Flashcard> _cards;
  final List<Flashcard> _generatedCards;
  final bool throwOnGenerate;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];
  final List<int> generatedCounts = [];

  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async {
    loadedUsers.add(user);
    return List<Flashcard>.of(_cards);
  }

  @override
  Future<List<Flashcard>> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int count,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    generatedCounts.add(count);
    if (throwOnGenerate) {
      throw const FlashcardRepositoryException(
        'Could not generate flashcards. Try again.',
      );
    }
    _cards
      ..removeWhere((card) => card.materialId == materialId)
      ..addAll(_generatedCards);
    return List<Flashcard>.of(_generatedCards);
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
