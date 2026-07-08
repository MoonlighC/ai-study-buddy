import '../../core/models/material.dart';
import '../../features/auth/auth_models.dart';
import '../../mock/mock_data.dart';

abstract class MaterialRepository {
  Future<List<StudyMaterial>> loadMaterials(AuthUser user);

  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  });
}

class MaterialRepositoryException implements Exception {
  const MaterialRepositoryException(this.message);

  final String message;
}

class MockMaterialRepository implements MaterialRepository {
  MockMaterialRepository({List<StudyMaterial>? initialMaterials})
    : _materials = List<StudyMaterial>.of(
        initialMaterials ?? MockData.materials,
      );

  final List<StudyMaterial> _materials;
  int _counter = 0;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    return List<StudyMaterial>.of(_materials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanContent.isEmpty) {
      throw const MaterialRepositoryException('Enter a title and pasted text.');
    }

    _counter += 1;
    final material = StudyMaterial(
      id: 'local-material-$_counter',
      subjectId: subjectId,
      title: cleanTitle,
      kind: MaterialKind.pastedText,
      content: cleanContent,
      createdLabel: 'Just now',
    );
    _materials.insert(0, material);
    return material;
  }
}

class EmptyMaterialRepository implements MaterialRepository {
  const EmptyMaterialRepository();

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    return const [];
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    throw const MaterialRepositoryException('Material sync is not configured.');
  }
}
