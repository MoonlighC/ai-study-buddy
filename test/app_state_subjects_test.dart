import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AppState subject sync', () {
    test('mock mode starts with local subjects', () {
      final state = AppState();

      expect(state.subjects.map((subject) => subject.name), [
        'Biology',
        'Math',
        'German',
      ]);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.subjectSyncErrorMessage, isNull);
    });

    test('supabase mode starts empty before authenticated sync', () {
      final state = AppState(config: _supabaseConfig());

      expect(state.subjects, isEmpty);
    });

    test(
      'supabase load replaces local subjects with repository results',
      () async {
        final repository = _FakeSubjectRepository(
          loadedSubjects: const [
            Subject(
              id: 'subject-1',
              name: 'Cloud Biology',
              description: 'Synced subject',
              colorValue: 0xFF16A34A,
            ),
          ],
        );
        final state = AppState(
          config: _supabaseConfig(),
          subjectRepository: repository,
        );

        await state.loadSubjectsFor(user);

        expect(repository.loadedUsers, [user]);
        expect(state.subjects.single.name, 'Cloud Biology');
        expect(state.isLoadingSubjects, isFalse);
        expect(state.subjectSyncErrorMessage, isNull);
      },
    );

    test('create subject calls repository and appends result', () async {
      final repository = _FakeSubjectRepository();
      final state = AppState(
        config: _supabaseConfig(),
        subjectRepository: repository,
      );
      await state.loadSubjectsFor(user);

      final created = await state.createSubjectFor(
        user,
        name: '  History  ',
        description: 'Exam prep',
        colorValue: 0xFFF59E0B,
      );

      expect(created, isTrue);
      expect(repository.createdUsers, [user]);
      expect(repository.createdNames, ['History']);
      expect(repository.createdSortOrders, [0]);
      expect(state.subjects.single.name, 'History');
      expect(state.subjectSyncErrorMessage, isNull);
    });

    test('load failure stores safe sync error and does not throw', () async {
      final state = AppState(
        config: _supabaseConfig(),
        subjectRepository: _FakeSubjectRepository(throwOnLoad: true),
      );

      await state.loadSubjectsFor(user);

      expect(state.subjects, isEmpty);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.subjectSyncErrorMessage, 'Could not sync subjects.');
    });

    test('create failure stores safe sync error and does not append', () async {
      final state = AppState(
        config: _supabaseConfig(),
        subjectRepository: _FakeSubjectRepository(throwOnCreate: true),
      );

      final created = await state.createSubjectFor(
        user,
        name: 'History',
        description: '',
        colorValue: 0xFF2563EB,
      );

      expect(created, isFalse);
      expect(state.subjects, isEmpty);
      expect(state.subjectSyncErrorMessage, 'Could not create the subject.');
    });
  });

  group('AppState material sync', () {
    test('mock mode starts with local materials and can create one', () async {
      final state = AppState();

      expect(state.materials.map((material) => material.title), [
        'Photosynthesis lecture notes',
        'Linear equations worksheet',
        'Short story vocabulary',
      ]);

      final created = await state.createMaterialFor(
        null,
        subjectId: 'biology',
        title: '  Cell notes  ',
        content: '  Cells use energy.  ',
      );

      expect(created, isTrue);
      expect(state.materials.first.title, 'Cell notes');
      expect(state.materials.first.content, 'Cells use energy.');
      expect(state.materialSyncErrorMessage, isNull);
    });

    test('supabase mode starts empty before authenticated material sync', () {
      final state = AppState(config: _supabaseConfig());

      expect(state.materials, isEmpty);
    });

    test(
      'supabase load replaces local materials with repository results',
      () async {
        final repository = _FakeMaterialRepository(
          loadedMaterials: const [
            StudyMaterial(
              id: 'material-1',
              subjectId: 'subject-1',
              title: 'Cloud notes',
              kind: MaterialKind.pastedText,
              content: 'Synced lecture text.',
              createdLabel: 'Synced',
            ),
          ],
        );
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: repository,
        );

        await state.loadMaterialsFor(user);

        expect(repository.loadedUsers, [user]);
        expect(state.materials.single.title, 'Cloud notes');
        expect(state.isLoadingMaterials, isFalse);
        expect(state.materialSyncErrorMessage, isNull);
      },
    );

    test('create material calls repository and appends result', () async {
      final repository = _FakeMaterialRepository();
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: repository,
      );

      final created = await state.createMaterialFor(
        user,
        subjectId: 'subject-1',
        title: '  History notes  ',
        content: '  The source text.  ',
      );

      expect(created, isTrue);
      expect(repository.createdUsers, [user]);
      expect(repository.createdSubjectIds, ['subject-1']);
      expect(repository.createdTitles, ['History notes']);
      expect(repository.createdContents, ['The source text.']);
      expect(state.materials.single.title, 'History notes');
      expect(state.materialSyncErrorMessage, isNull);
    });

    test(
      'load failure stores safe material sync error and does not throw',
      () async {
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: _FakeMaterialRepository(throwOnLoad: true),
        );

        await state.loadMaterialsFor(user);

        expect(state.materials, isEmpty);
        expect(state.isLoadingMaterials, isFalse);
        expect(state.materialSyncErrorMessage, 'Could not sync materials.');
      },
    );

    test(
      'create failure stores safe material sync error and does not append',
      () async {
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: _FakeMaterialRepository(throwOnCreate: true),
        );

        final created = await state.createMaterialFor(
          user,
          subjectId: 'subject-1',
          title: 'History notes',
          content: 'The source text.',
        );

        expect(created, isFalse);
        expect(state.materials, isEmpty);
        expect(
          state.materialSyncErrorMessage,
          'Could not create the material.',
        );
      },
    );

    test(
      'workspace sync keeps subject sync working while loading materials',
      () async {
        final subjectRepository = _FakeSubjectRepository(
          loadedSubjects: const [
            Subject(
              id: 'subject-1',
              name: 'Cloud Biology',
              description: 'Synced subject',
              colorValue: 0xFF16A34A,
            ),
          ],
        );
        final materialRepository = _FakeMaterialRepository(
          loadedMaterials: const [
            StudyMaterial(
              id: 'material-1',
              subjectId: 'subject-1',
              title: 'Cloud notes',
              kind: MaterialKind.pastedText,
              content: 'Synced lecture text.',
              createdLabel: 'Synced',
            ),
          ],
        );
        final state = AppState(
          config: _supabaseConfig(),
          subjectRepository: subjectRepository,
          materialRepository: materialRepository,
        );

        await state.loadSyncedWorkspaceFor(user);

        expect(subjectRepository.loadedUsers, [user]);
        expect(materialRepository.loadedUsers, [user]);
        expect(state.subjects.single.name, 'Cloud Biology');
        expect(state.materials.single.title, 'Cloud notes');
      },
    );
  });
}

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'placeholder-anon-key',
  );
}

class _FakeSubjectRepository implements SubjectRepository {
  _FakeSubjectRepository({
    this.loadedSubjects = const [],
    this.throwOnLoad = false,
    this.throwOnCreate = false,
  });

  final List<Subject> loadedSubjects;
  final bool throwOnLoad;
  final bool throwOnCreate;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> createdUsers = [];
  final List<String> createdNames = [];
  final List<int> createdSortOrders = [];

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    loadedUsers.add(user);
    if (throwOnLoad) {
      throw const SubjectRepositoryException('Could not sync subjects.');
    }
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
    createdUsers.add(user);
    createdNames.add(name);
    createdSortOrders.add(sortOrder);
    if (throwOnCreate) {
      throw const SubjectRepositoryException('Could not create the subject.');
    }
    return Subject(
      id: 'created-${createdNames.length}',
      name: name,
      description: description,
      colorValue: colorValue,
    );
  }
}

class _FakeMaterialRepository implements MaterialRepository {
  _FakeMaterialRepository({
    this.loadedMaterials = const [],
    this.throwOnLoad = false,
    this.throwOnCreate = false,
  });

  final List<StudyMaterial> loadedMaterials;
  final bool throwOnLoad;
  final bool throwOnCreate;
  final List<AuthUser> loadedUsers = [];
  final List<AuthUser> createdUsers = [];
  final List<String> createdSubjectIds = [];
  final List<String> createdTitles = [];
  final List<String> createdContents = [];

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    loadedUsers.add(user);
    if (throwOnLoad) {
      throw const MaterialRepositoryException('Could not sync materials.');
    }
    return List<StudyMaterial>.of(loadedMaterials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    createdUsers.add(user);
    createdSubjectIds.add(subjectId);
    createdTitles.add(title);
    createdContents.add(content);
    if (throwOnCreate) {
      throw const MaterialRepositoryException('Could not create the material.');
    }
    return StudyMaterial(
      id: 'created-${createdTitles.length}',
      subjectId: subjectId,
      title: title,
      kind: MaterialKind.pastedText,
      content: content,
      createdLabel: 'Just now',
    );
  }
}
