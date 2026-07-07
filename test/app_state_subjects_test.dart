import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
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
