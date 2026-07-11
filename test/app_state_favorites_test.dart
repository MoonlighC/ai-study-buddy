import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/favorites/favorite_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AppState material favorites', () {
    test('mock mode keeps flashcard favorites and toggles materials', () async {
      final state = AppState();

      expect(
        state.favoriteFlashcards.map((flashcard) => flashcard.front),
        contains('What is photosynthesis?'),
      );
      expect(state.favoriteMaterials, isEmpty);

      final added = await state.toggleMaterialFavoriteFor(
        null,
        'bio-lecture-1',
      );

      expect(added, isTrue);
      expect(
        state.favoriteMaterials.single.title,
        'Photosynthesis lecture notes',
      );

      final removed = await state.toggleMaterialFavoriteFor(
        null,
        'bio-lecture-1',
      );

      expect(removed, isTrue);
      expect(state.favoriteMaterials, isEmpty);
    });

    test('supabase mode does not expose mock flashcard favorites', () {
      final state = AppState(config: _supabaseConfig());

      expect(state.favoriteFlashcards, isEmpty);
      expect(state.favoriteMaterials, isEmpty);
    });

    test('supabase load applies material favorites from repository', () async {
      final favoriteRepository = _FakeFavoriteRepository(
        loadedMaterialFavoriteIds: const {'material-1'},
      );
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        favoriteRepository: favoriteRepository,
      );

      await state.loadMaterialsFor(user);
      await state.loadMaterialFavoritesFor(user);

      expect(favoriteRepository.loadedUsers, [user]);
      expect(state.favoriteMaterials.single.title, 'Cloud notes');
      expect(state.favoriteSyncErrorMessage, isNull);
    });

    test(
      'supabase add and remove update state after repository success',
      () async {
        final favoriteRepository = _FakeFavoriteRepository();
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: _FakeMaterialRepository(
            loadedMaterials: const [_material],
          ),
          favoriteRepository: favoriteRepository,
        );
        await state.loadMaterialsFor(user);

        final added = await state.toggleMaterialFavoriteFor(user, 'material-1');

        expect(added, isTrue);
        expect(favoriteRepository.addedUsers, [user]);
        expect(favoriteRepository.addedMaterialIds, ['material-1']);
        expect(state.favoriteMaterials.single.id, 'material-1');

        final removed = await state.toggleMaterialFavoriteFor(
          user,
          'material-1',
        );

        expect(removed, isTrue);
        expect(favoriteRepository.removedUsers, [user]);
        expect(favoriteRepository.removedMaterialIds, ['material-1']);
        expect(state.favoriteMaterials, isEmpty);
      },
    );

    test('supabase add failure does not mutate local favorite state', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        favoriteRepository: _FakeFavoriteRepository(throwOnAdd: true),
      );
      await state.loadMaterialsFor(user);

      final added = await state.toggleMaterialFavoriteFor(user, 'material-1');

      expect(added, isFalse);
      expect(state.favoriteMaterials, isEmpty);
      expect(state.favoriteSyncErrorMessage, 'Could not update favorite.');
    });

    test('supabase load failure stores safe favorite sync error', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        favoriteRepository: _FakeFavoriteRepository(throwOnLoad: true),
      );
      await state.loadMaterialsFor(user);

      await state.loadMaterialFavoritesFor(user);

      expect(state.favoriteMaterials, isEmpty);
      expect(state.isLoadingMaterialFavorites, isFalse);
      expect(state.favoriteSyncErrorMessage, 'Could not sync favorites.');
    });

    test('supabase remove failure keeps existing favorite state', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        favoriteRepository: _FakeFavoriteRepository(
          loadedMaterialFavoriteIds: const {'material-1'},
          throwOnRemove: true,
        ),
      );
      await state.loadMaterialsFor(user);
      await state.loadMaterialFavoritesFor(user);

      final removed = await state.toggleMaterialFavoriteFor(user, 'material-1');

      expect(removed, isFalse);
      expect(state.favoriteMaterials.single.id, 'material-1');
      expect(state.favoriteSyncErrorMessage, 'Could not update favorite.');
    });

    test('workspace sync keeps subject and material sync working', () async {
      final subjectRepository = _FakeSubjectRepository(
        loadedSubjects: const [_subject],
      );
      final materialRepository = _FakeMaterialRepository(
        loadedMaterials: const [_material],
      );
      final favoriteRepository = _FakeFavoriteRepository(
        loadedMaterialFavoriteIds: const {'material-1'},
      );
      final state = AppState(
        config: _supabaseConfig(),
        subjectRepository: subjectRepository,
        materialRepository: materialRepository,
        favoriteRepository: favoriteRepository,
      );

      await state.loadSyncedWorkspaceFor(user);

      expect(subjectRepository.loadedUsers, [user]);
      expect(materialRepository.loadedUsers, [user]);
      expect(favoriteRepository.loadedUsers, [user]);
      expect(state.subjects.single.name, 'Cloud Biology');
      expect(state.materials.single.title, 'Cloud notes');
      expect(state.favoriteMaterials.single.id, 'material-1');
    });
  });
}

const _subject = Subject(
  id: 'subject-1',
  name: 'Cloud Biology',
  description: 'Synced subject',
  colorValue: 0xFF16A34A,
);

const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Cloud notes',
  kind: MaterialKind.pastedText,
  content: 'Synced lecture text.',
  createdLabel: 'Synced',
);

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'sb_publishable_test-client-key',
  );
}

class _FakeFavoriteRepository implements FavoriteRepository {
  _FakeFavoriteRepository({
    Set<String> loadedMaterialFavoriteIds = const <String>{},
    this.throwOnLoad = false,
    this.throwOnAdd = false,
    this.throwOnRemove = false,
  }) : _materialFavoriteIds = Set<String>.of(loadedMaterialFavoriteIds);

  final bool throwOnLoad;
  final bool throwOnAdd;
  final bool throwOnRemove;
  final Set<String> _materialFavoriteIds;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> addedUsers = [];
  final List<String> addedMaterialIds = [];
  final List<AuthUser> removedUsers = [];
  final List<String> removedMaterialIds = [];

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    loadedUsers.add(user);
    if (throwOnLoad) {
      throw const FavoriteRepositoryException('Could not sync favorites.');
    }
    return Set<String>.of(_materialFavoriteIds);
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    addedUsers.add(user);
    addedMaterialIds.add(materialId);
    if (throwOnAdd) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
    _materialFavoriteIds.add(materialId);
  }

  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    removedUsers.add(user);
    removedMaterialIds.add(materialId);
    if (throwOnRemove) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
    _materialFavoriteIds.remove(materialId);
  }
}

class _FakeMaterialRepository implements MaterialRepository {
  _FakeMaterialRepository({this.loadedMaterials = const []});

  final List<StudyMaterial> loadedMaterials;
  final List<AuthUser> loadedUsers = [];

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    loadedUsers.add(user);
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

class _FakeSubjectRepository implements SubjectRepository {
  _FakeSubjectRepository({this.loadedSubjects = const []});

  final List<Subject> loadedSubjects;
  final List<AuthUser> loadedUsers = [];

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    loadedUsers.add(user);
    return List<Subject>.of(loadedSubjects);
  }

  @override
  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  }) async {
    return Subject(
      id: 'created-1',
      name: name,
      description: description,
      colorValue: colorValue,
    );
  }
}
