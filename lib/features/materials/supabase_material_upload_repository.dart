import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_upload.dart';
import 'material_row_mapper.dart';
import 'material_upload_repository.dart';

abstract class MaterialUploadDataSource {
  String? get currentUserId;

  Future<void> uploadObject({
    required String bucket,
    required String path,
    required String mimeType,
    required Uint8List bytes,
  });

  Future<Map<String, dynamic>> insertMaterial(Map<String, Object?> values);

  Future<void> removeObject({required String bucket, required String path});
}

abstract class MaterialUploadReconciliationDataSource {
  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  }) async => null;

  Future<MaterialUploadObjectMetadata?> findObject({
    required String bucket,
    required String path,
  }) async => null;
}

class MaterialUploadObjectMetadata {
  const MaterialUploadObjectMetadata({
    required this.bucket,
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.contentSignature,
  });

  final String bucket;
  final String path;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final String? contentSignature;
}

class SupabaseMaterialUploadDataSource
    implements
        MaterialUploadDataSource,
        MaterialUploadReconciliationDataSource {
  const SupabaseMaterialUploadDataSource(this._client);

  final supabase.SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> uploadObject({
    required String bucket,
    required String path,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: mimeType,
            metadata: <String, dynamic>{
              'content_signature': _contentSignature(bytes),
            },
            upsert: false,
          ),
        );
  }

  @override
  Future<Map<String, dynamic>> insertMaterial(
    Map<String, Object?> values,
  ) async {
    return _client
        .from('materials')
        .insert(values)
        .select(materialSelectColumns)
        .single();
  }

  @override
  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  }) async {
    final row = await _client
        .from('materials')
        .select(materialSelectColumns)
        .eq('id', materialId)
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    return row;
  }

  @override
  Future<MaterialUploadObjectMetadata?> findObject({
    required String bucket,
    required String path,
  }) async {
    final segments = path.split('/');
    if (segments.length != 3) return null;
    final directory = '${segments[0]}/${segments[1]}';
    final filename = segments[2];
    final objects = await _client.storage
        .from(bucket)
        .list(
          path: directory,
          searchOptions: supabase.SearchOptions(search: filename, limit: 100),
        );
    for (final object in objects) {
      if (object.name != filename) continue;
      final metadata = object.metadata;
      final rawSize = metadata?['size'];
      final rawMime = metadata?['mimetype'] ?? metadata?['contentType'];
      final nestedMetadata = metadata?['metadata'];
      final rawSignature =
          metadata?['content_signature'] ??
          (nestedMetadata is Map ? nestedMetadata['content_signature'] : null);
      if (rawSize is! num) {
        return MaterialUploadObjectMetadata(
          bucket: bucket,
          path: path,
          fileName: object.name,
          sizeBytes: -1,
          mimeType: rawMime is String ? rawMime : null,
          contentSignature: rawSignature is String ? rawSignature : null,
        );
      }
      return MaterialUploadObjectMetadata(
        bucket: bucket,
        path: path,
        fileName: object.name,
        sizeBytes: rawSize.toInt(),
        mimeType: rawMime is String ? rawMime : null,
        contentSignature: rawSignature is String ? rawSignature : null,
      );
    }
    return null;
  }

  @override
  Future<void> removeObject({
    required String bucket,
    required String path,
  }) async {
    await _client.storage.from(bucket).remove([path]);
  }
}

class SupabaseMaterialUploadRepository implements MaterialUploadRepository {
  const SupabaseMaterialUploadRepository(this._dataSource);

  final MaterialUploadDataSource _dataSource;

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) async {
    final authenticatedUserId = _dataSource.currentUserId;
    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      throw const MaterialUploadException(
        'Log in to upload materials.',
        code: MaterialUploadErrorCode.sessionExpired,
      );
    }
    if (authenticatedUserId != expectedUser.id) {
      throw const MaterialUploadException(
        'Your session changed. Sign in again before uploading.',
        code: MaterialUploadErrorCode.sessionChanged,
      );
    }

    if (!isCanonicalMaterialFilename(
      filename: request.objectFilename,
      kind: request.kind,
      mimeType: request.mimeType,
    )) {
      throw const MaterialUploadException(
        'The selected upload metadata is invalid.',
        code: MaterialUploadErrorCode.invalidMetadata,
      );
    }

    final path =
        '$authenticatedUserId/${request.materialId}/${request.objectFilename}';
    if (!isCanonicalMaterialObjectPath(
      path: path,
      userId: authenticatedUserId,
      materialId: request.materialId,
      kind: request.kind,
      mimeType: request.mimeType,
      expectedFilename: request.objectFilename,
    )) {
      throw const MaterialUploadException(
        'The selected upload metadata is invalid.',
        code: MaterialUploadErrorCode.invalidMetadata,
      );
    }
    final existing = await _reconcileMaterial(
      request: request,
      userId: authenticatedUserId,
      path: path,
    );
    _requireSession(authenticatedUserId);
    if (existing != null) return existing;

    var objectExists = false;
    try {
      objectExists = await _verifiedObjectExists(
        request: request,
        path: path,
        requiredObject: false,
      );
    } on MaterialUploadException {
      rethrow;
    } catch (_) {
      throw const MaterialUploadException(
        'Could not verify the selected upload.',
        code: MaterialUploadErrorCode.uploadFailed,
      );
    }

    try {
      if (!objectExists) {
        _requireSession(authenticatedUserId);
        onProgress?.call(null);
        await _dataSource.uploadObject(
          bucket: request.bucket,
          path: path,
          mimeType: request.mimeType,
          bytes: request.bytes,
        );
        _requireSession(authenticatedUserId);
      }
    } catch (_) {
      final reconciled = await _reconcileMaterial(
        request: request,
        userId: authenticatedUserId,
        path: path,
      );
      if (reconciled != null) return reconciled;
      try {
        objectExists = await _verifiedObjectExists(
          request: request,
          path: path,
          requiredObject: false,
        );
      } on MaterialUploadException {
        rethrow;
      } catch (_) {
        objectExists = false;
      }
      if (!objectExists) {
        throw const MaterialUploadException(
          'Could not upload the selected file.',
          code: MaterialUploadErrorCode.uploadFailed,
        );
      }
    }

    try {
      _requireSession(authenticatedUserId);
      final row = await _dataSource.insertMaterial(<String, Object?>{
        'id': request.materialId,
        'user_id': authenticatedUserId,
        'subject_id': request.subjectId,
        'title': request.title,
        'kind': request.kind == MaterialKind.pdf ? 'pdf' : 'image',
        'source_kind': 'upload',
        'content_text': null,
        'storage_bucket': request.bucket,
        'storage_path': path,
        'mime_type': request.mimeType,
        'file_size_bytes': request.fileSizeBytes,
        'processing_status': 'pending',
      });
      _requireSession(authenticatedUserId);
      onProgress?.call(1);
      return mapMaterialRow(row);
    } catch (_) {
      final reconciled = await _reconcileMaterial(
        request: request,
        userId: authenticatedUserId,
        path: path,
      );
      if (reconciled != null) return reconciled;
      try {
        await _dataSource.removeObject(bucket: request.bucket, path: path);
      } catch (_) {
        // Best effort only. Preserve the original database failure.
      }
      throw const MaterialUploadException(
        'The file uploaded, but its material could not be saved.',
        stage: MaterialUploadFailureStage.materialCreation,
        code: MaterialUploadErrorCode.materialCreationFailed,
      );
    }
  }

  Future<StudyMaterial?> _reconcileMaterial({
    required MaterialUploadRequest request,
    required String userId,
    required String path,
  }) async {
    _requireSession(userId);
    Map<String, dynamic>? row;
    try {
      row = await _reconciliationSource?.findMaterial(
        materialId: request.materialId,
        userId: userId,
      );
    } catch (error) {
      throw _safeReconciliationException(error);
    }
    _requireSession(userId);
    if (row == null) return null;
    try {
      final material = mapMaterialRow(row);
      if (material.id != request.materialId ||
          material.subjectId != request.subjectId ||
          material.kind != request.kind ||
          material.sourceKind != MaterialSourceKind.upload ||
          material.storageBucket != request.bucket ||
          material.storagePath != path ||
          material.mimeType != request.mimeType ||
          material.fileSizeBytes != request.fileSizeBytes ||
          !isCanonicalMaterialObjectPath(
            path: material.storagePath ?? '',
            userId: userId,
            materialId: request.materialId,
            kind: request.kind,
            mimeType: request.mimeType,
            expectedFilename: request.objectFilename,
          )) {
        throw const MaterialUploadException(
          'The existing material could not be verified.',
          code: MaterialUploadErrorCode.invalidReconciliation,
        );
      }
      await _verifiedObjectExists(
        request: request,
        path: path,
        requiredObject: true,
      );
      return material;
    } on MaterialUploadException {
      rethrow;
    } catch (_) {
      throw const MaterialUploadException(
        'The existing material could not be verified.',
        code: MaterialUploadErrorCode.invalidReconciliation,
      );
    }
  }

  Future<bool> _verifiedObjectExists({
    required MaterialUploadRequest request,
    required String path,
    required bool requiredObject,
  }) async {
    final expectedUserId = path.split('/').first;
    _requireSession(expectedUserId);
    MaterialUploadObjectMetadata? object;
    try {
      object = await _reconciliationSource?.findObject(
        bucket: request.bucket,
        path: path,
      );
    } catch (error) {
      throw _safeReconciliationException(error);
    }
    _requireSession(expectedUserId);
    if (object == null) {
      if (requiredObject) {
        throw const MaterialUploadException(
          'The uploaded file is unavailable.',
          code: MaterialUploadErrorCode.storageNotFound,
        );
      }
      return false;
    }
    if (object.bucket != request.bucket ||
        object.path != path ||
        object.fileName != request.objectFilename ||
        object.sizeBytes != request.fileSizeBytes ||
        object.mimeType != request.mimeType ||
        object.contentSignature != _contentSignature(request.bytes) ||
        !isCanonicalMaterialObjectPath(
          path: object.path,
          userId: expectedUserId,
          materialId: request.materialId,
          kind: request.kind,
          mimeType: request.mimeType,
          expectedFilename: request.objectFilename,
        )) {
      throw const MaterialUploadException(
        'The existing upload could not be verified.',
        code: MaterialUploadErrorCode.invalidMetadata,
      );
    }
    return true;
  }

  MaterialUploadReconciliationDataSource? get _reconciliationSource =>
      _dataSource is MaterialUploadReconciliationDataSource
      ? _dataSource as MaterialUploadReconciliationDataSource
      : null;

  void _requireSession(String expectedUserId) {
    final current = _dataSource.currentUserId;
    if (current == null || current.isEmpty) {
      throw const MaterialUploadException(
        'Your session expired. Sign in again.',
        code: MaterialUploadErrorCode.sessionExpired,
      );
    }
    if (current != expectedUserId) {
      throw const MaterialUploadException(
        'Your session changed. Sign in again before uploading.',
        code: MaterialUploadErrorCode.sessionChanged,
      );
    }
  }
}

MaterialUploadException _safeReconciliationException(Object error) {
  if (error is MaterialUploadException) return error;
  if (error is supabase.AuthException) {
    return const MaterialUploadException(
      'Your session expired. Sign in again.',
      code: MaterialUploadErrorCode.sessionExpired,
    );
  }
  if (error is supabase.StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 401) {
      return const MaterialUploadException(
        'Your session expired. Sign in again.',
        code: MaterialUploadErrorCode.sessionExpired,
      );
    }
    if (status == 403) {
      return const MaterialUploadException(
        'The uploaded file is not authorized.',
        code: MaterialUploadErrorCode.authorizationDenied,
      );
    }
    if (status == 404) {
      return const MaterialUploadException(
        'The uploaded file is unavailable.',
        code: MaterialUploadErrorCode.storageNotFound,
      );
    }
  }
  if (error is supabase.PostgrestException &&
      const {'42501', 'PGRST301'}.contains(error.code)) {
    return const MaterialUploadException(
      'The uploaded material is not authorized.',
      code: MaterialUploadErrorCode.authorizationDenied,
    );
  }
  return const MaterialUploadException(
    'Could not verify the selected upload.',
    code: MaterialUploadErrorCode.networkFailure,
  );
}

String _contentSignature(Uint8List bytes) {
  if (bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D) {
    return 'pdf-v1';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'png-v1';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpeg-v1';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp-v1';
  }
  return 'invalid-v1';
}
