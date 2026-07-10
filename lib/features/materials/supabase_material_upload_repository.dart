import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_upload.dart';
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
        .select(
          'id,subject_id,title,kind,source_kind,content_text,summary,'
          'storage_bucket,storage_path,mime_type,file_size_bytes,'
          'processing_status,created_at',
        )
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
      return _mapMaterial(row);
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

  StudyMaterial _mapMaterial(Map<String, dynamic> row) {
    return StudyMaterial(
      id: _string(row['id']) ?? '',
      subjectId: _string(row['subject_id']) ?? '',
      title: _string(row['title']) ?? 'Untitled material',
      kind: switch (_string(row['kind'])) {
        'pdf' => MaterialKind.pdf,
        'image' => MaterialKind.image,
        _ => MaterialKind.pastedText,
      },
      content: _string(row['content_text']) ?? '',
      createdLabel: _createdLabel(_string(row['created_at'])),
      summary: _string(row['summary']),
      sourceKind: switch (_string(row['source_kind'])) {
        'upload' => MaterialSourceKind.upload,
        'generated' => MaterialSourceKind.generated,
        _ => MaterialSourceKind.manual,
      },
      storageBucket: _string(row['storage_bucket']),
      storagePath: _string(row['storage_path']),
      mimeType: _string(row['mime_type']),
      fileSizeBytes: row['file_size_bytes'] is num
          ? (row['file_size_bytes'] as num).toInt()
          : null,
      processingStatus: switch (_string(row['processing_status'])) {
        'pending' => MaterialProcessingStatus.pending,
        'processing' => MaterialProcessingStatus.processing,
        'failed' => MaterialProcessingStatus.failed,
        _ => MaterialProcessingStatus.ready,
      },
    );
  }

  String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _createdLabel(String? value) {
    if (value == null || value.length < 10) return 'Just now';
    return value.substring(0, 10);
  }
}
