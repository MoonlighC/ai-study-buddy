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

class SupabaseMaterialUploadDataSource implements MaterialUploadDataSource {
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
      throw const MaterialUploadException('Log in to upload materials.');
    }
    if (authenticatedUserId != expectedUser.id) {
      throw const MaterialUploadException(
        'Your session changed. Sign in again before uploading.',
      );
    }

    final path =
        '$authenticatedUserId/${request.materialId}/${request.objectFilename}';
    try {
      onProgress?.call(null);
      await _dataSource.uploadObject(
        bucket: request.bucket,
        path: path,
        mimeType: request.mimeType,
        bytes: request.bytes,
      );
    } catch (_) {
      throw const MaterialUploadException(
        'Could not upload the selected file.',
      );
    }

    try {
      final row = await _dataSource.insertMaterial(<String, Object?>{
        'id': request.materialId,
        'user_id': authenticatedUserId,
        'subject_id': request.subjectId,
        'title': request.title,
        'kind': request.kind == MaterialKind.pdf ? 'pdf' : 'image',
        'source_kind': 'upload',
        'content_text': null,
        'summary': null,
        'storage_bucket': request.bucket,
        'storage_path': path,
        'mime_type': request.mimeType,
        'file_size_bytes': request.fileSizeBytes,
        'processing_status': 'pending',
      });
      onProgress?.call(1);
      return mapMaterialRow(row);
    } catch (_) {
      try {
        await _dataSource.removeObject(bucket: request.bucket, path: path);
      } catch (_) {
        // Best effort only. Preserve the original database failure.
      }
      throw const MaterialUploadException(
        'The file uploaded, but its material could not be saved.',
      );
    }
  }
}
