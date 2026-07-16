import 'dart:typed_data';

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_upload.dart';

enum OriginalMaterialFailureCode {
  materialUnavailable,
  authorizationDenied,
  sessionExpired,
  wrongSourceType,
  invalidMetadata,
  objectNotFound,
  networkFailure,
  previewTooLarge,
}

sealed class OriginalMaterialLoadResult {
  const OriginalMaterialLoadResult();

  void release() {}
}

class OriginalMaterialSuccess extends OriginalMaterialLoadResult {
  OriginalMaterialSuccess.fromTrustedBytes({
    required MaterialKind kind,
    required Uint8List bytes,
  }) : handle = OriginalMaterialPreviewHandle._(kind, bytes);

  final OriginalMaterialPreviewHandle handle;

  @override
  void release() => handle.release();
}

class OriginalMaterialPreviewHandle {
  OriginalMaterialPreviewHandle._(this.kind, Uint8List bytes) : _bytes = bytes;

  final MaterialKind kind;
  Uint8List? _bytes;

  bool get isReleased => _bytes == null;

  T useBytes<T>(T Function(Uint8List bytes) operation) {
    final bytes = _bytes;
    if (bytes == null) {
      throw StateError('The preview is no longer available.');
    }
    return operation(bytes);
  }

  void release() => _bytes = null;

  @override
  String toString() =>
      'OriginalMaterialPreviewHandle(kind: ${kind.name}, released: $isReleased)';
}

class OriginalMaterialFailure extends OriginalMaterialLoadResult {
  const OriginalMaterialFailure(this.code);

  final OriginalMaterialFailureCode code;
}

abstract class OriginalMaterialRepository {
  Future<OriginalMaterialLoadResult> load({
    required AuthUser expectedUser,
    required String materialId,
    required MaterialKind expectedKind,
  });
}

class MockOriginalMaterialRepository implements OriginalMaterialRepository {
  MockOriginalMaterialRepository({
    Map<String, Uint8List>? pdfs,
    Map<String, Uint8List>? images,
  }) : _materials = {
         for (final entry in (pdfs ?? const <String, Uint8List>{}).entries)
           entry.key: (MaterialKind.pdf, entry.value),
         for (final entry in (images ?? const <String, Uint8List>{}).entries)
           entry.key: (MaterialKind.image, entry.value),
       };

  final Map<String, (MaterialKind, Uint8List)> _materials;

  @override
  Future<OriginalMaterialLoadResult> load({
    required AuthUser expectedUser,
    required String materialId,
    required MaterialKind expectedKind,
  }) async {
    final material = _materials[materialId];
    if (material == null) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.materialUnavailable,
      );
    }
    if (material.$1 != expectedKind) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.wrongSourceType,
      );
    }
    final limit = previewByteLimit(expectedKind);
    if (material.$2.lengthInBytes > limit) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.previewTooLarge,
      );
    }
    return OriginalMaterialSuccess.fromTrustedBytes(
      kind: material.$1,
      bytes: material.$2,
    );
  }
}

class EmptyOriginalMaterialRepository implements OriginalMaterialRepository {
  const EmptyOriginalMaterialRepository();

  @override
  Future<OriginalMaterialLoadResult> load({
    required AuthUser expectedUser,
    required String materialId,
    required MaterialKind expectedKind,
  }) async => const OriginalMaterialFailure(
    OriginalMaterialFailureCode.materialUnavailable,
  );
}

int previewByteLimit(MaterialKind kind) =>
    kind == MaterialKind.pdf ? maxPdfUploadBytes : maxImageUploadBytes;

bool hasValidOriginalMetadata(StudyMaterial material, String userId) {
  if (material.sourceKind != MaterialSourceKind.upload ||
      (material.kind != MaterialKind.pdf &&
          material.kind != MaterialKind.image) ||
      material.fileSizeBytes == null ||
      material.fileSizeBytes! < 1) {
    return false;
  }
  final expectedBucket = material.kind == MaterialKind.pdf
      ? 'study-materials'
      : 'study-images';
  if (material.storageBucket != expectedBucket) return false;
  final expectedMime = material.kind == MaterialKind.pdf
      ? const {'application/pdf'}
      : const {'image/png', 'image/jpeg', 'image/webp'};
  if (!expectedMime.contains(material.mimeType)) return false;
  final path = material.storagePath;
  return path != null &&
      isCanonicalMaterialObjectPath(
        path: path,
        userId: userId,
        materialId: material.id,
        kind: material.kind,
        mimeType: material.mimeType!,
      );
}

bool hasExpectedOriginalSignature(
  MaterialKind kind,
  String mimeType,
  Uint8List bytes,
) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  if (kind == MaterialKind.pdf) {
    return mimeType == 'application/pdf' &&
        startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D]);
  }
  return switch (mimeType) {
    'image/png' => startsWith(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]),
    'image/jpeg' => startsWith(const [0xFF, 0xD8, 0xFF]),
    'image/webp' =>
      bytes.length >= 12 &&
          startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50,
    _ => false,
  };
}
