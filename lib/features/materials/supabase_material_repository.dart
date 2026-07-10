import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../../features/auth/auth_models.dart';
import 'material_repository.dart';

class SupabaseMaterialRepository implements MaterialRepository {
  const SupabaseMaterialRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    try {
      final rows = await _client
          .from('materials')
          .select(
            'id,subject_id,title,kind,source_kind,content_text,summary,'
            'storage_bucket,storage_path,mime_type,file_size_bytes,'
            'processing_status,created_at',
          )
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      return rows.map(_mapMaterial).toList();
    } catch (_) {
      throw const MaterialRepositoryException('Could not sync materials.');
    }
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

    try {
      final row = await _client
          .from('materials')
          .insert(<String, Object?>{
            'user_id': user.id,
            'subject_id': subjectId,
            'title': cleanTitle,
            'kind': 'pasted_text',
            'source_kind': 'manual',
            'content_text': cleanContent,
            'processing_status': 'ready',
          })
          .select(
            'id,subject_id,title,kind,source_kind,content_text,summary,'
            'storage_bucket,storage_path,mime_type,file_size_bytes,'
            'processing_status,created_at',
          )
          .single();
      return _mapMaterial(row);
    } on MaterialRepositoryException {
      rethrow;
    } catch (_) {
      throw const MaterialRepositoryException('Could not create the material.');
    }
  }

  StudyMaterial _mapMaterial(Map<String, dynamic> row) {
    return StudyMaterial(
      id: _stringValue(row, 'id') ?? '',
      subjectId: _stringValue(row, 'subject_id') ?? '',
      title: _stringValue(row, 'title') ?? 'Untitled material',
      kind: _materialKindFor(_stringValue(row, 'kind')),
      content: _stringValue(row, 'content_text') ?? '',
      createdLabel: _createdLabelFor(_stringValue(row, 'created_at')),
      summary: _stringValue(row, 'summary'),
      sourceKind: _sourceKindFor(_stringValue(row, 'source_kind')),
      storageBucket: _stringValue(row, 'storage_bucket'),
      storagePath: _stringValue(row, 'storage_path'),
      mimeType: _stringValue(row, 'mime_type'),
      fileSizeBytes: _intValue(row, 'file_size_bytes'),
      processingStatus: _processingStatusFor(
        _stringValue(row, 'processing_status'),
      ),
    );
  }

  MaterialKind _materialKindFor(String? value) {
    return switch (value) {
      'pasted_text' => MaterialKind.pastedText,
      'image' => MaterialKind.image,
      'pdf' => MaterialKind.pdf,
      _ => MaterialKind.pastedText,
    };
  }

  MaterialSourceKind _sourceKindFor(String? value) {
    return switch (value) {
      'upload' => MaterialSourceKind.upload,
      'generated' => MaterialSourceKind.generated,
      _ => MaterialSourceKind.manual,
    };
  }

  MaterialProcessingStatus _processingStatusFor(String? value) {
    return switch (value) {
      'pending' => MaterialProcessingStatus.pending,
      'processing' => MaterialProcessingStatus.processing,
      'failed' => MaterialProcessingStatus.failed,
      _ => MaterialProcessingStatus.ready,
    };
  }

  String _createdLabelFor(String? value) {
    if (value == null || value.length < 10) {
      return 'Synced';
    }
    return value.substring(0, 10);
  }

  String? _stringValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      return null;
    }
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  int? _intValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    return value is num ? value.toInt() : null;
  }
}
