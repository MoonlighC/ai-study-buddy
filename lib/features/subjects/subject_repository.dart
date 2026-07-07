import '../../core/models/subject.dart';
import '../../features/auth/auth_models.dart';
import '../../mock/mock_data.dart';

abstract class SubjectRepository {
  Future<List<Subject>> loadSubjects(AuthUser user);

  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  });
}

class SubjectRepositoryException implements Exception {
  const SubjectRepositoryException(this.message);

  final String message;
}

class MockSubjectRepository implements SubjectRepository {
  MockSubjectRepository({List<Subject>? initialSubjects})
    : _subjects = List<Subject>.of(initialSubjects ?? MockData.subjects);

  final List<Subject> _subjects;
  int _counter = 0;

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    return List<Subject>.of(_subjects);
  }

  @override
  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const SubjectRepositoryException('Enter a subject name.');
    }
    _counter += 1;
    final subject = Subject(
      id: 'local-subject-$_counter',
      name: cleanName,
      description: description.trim(),
      colorValue: colorValue,
    );
    _subjects.add(subject);
    return subject;
  }
}

class EmptySubjectRepository implements SubjectRepository {
  const EmptySubjectRepository();

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    return const [];
  }

  @override
  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  }) async {
    throw const SubjectRepositoryException('Subject sync is not configured.');
  }
}
