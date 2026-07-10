import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_upload.dart';

abstract class MaterialUploadRepository {
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  });
}

class MaterialUploadException implements Exception {
  const MaterialUploadException(this.message);

  final String message;
}

class MockMaterialUploadRepository implements MaterialUploadRepository {
  final List<StudyMaterial> uploadedMaterials = [];

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) async {
    onProgress?.call(1);
    final material = StudyMaterial(
      id: request.materialId,
      subjectId: request.subjectId,
      title: request.title,
      kind: request.kind,
      content: '',
      createdLabel: 'Just now',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: request.bucket,
      storagePath:
          '${expectedUser.id}/${request.materialId}/${request.objectFilename}',
      mimeType: request.mimeType,
      fileSizeBytes: request.fileSizeBytes,
      processingStatus: MaterialProcessingStatus.pending,
    );
    uploadedMaterials.insert(0, material);
    return material;
  }
}

class EmptyMaterialUploadRepository implements MaterialUploadRepository {
  const EmptyMaterialUploadRepository();

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) {
    throw const MaterialUploadException('Material upload is not configured.');
  }
}
