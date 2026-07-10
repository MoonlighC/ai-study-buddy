import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../../features/auth/auth_models.dart';
import 'material_row_mapper.dart';
import 'material_repository.dart';

class SupabaseMaterialRepository implements MaterialRepository {
  const SupabaseMaterialRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    try {
      final rows = await _client
          .from('materials')
          .select(materialSelectColumns)
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      return rows.map(mapMaterialRow).toList();
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
          .select(materialSelectColumns)
          .single();
      return mapMaterialRow(row);
    } on MaterialRepositoryException {
      rethrow;
    } catch (_) {
      throw const MaterialRepositoryException('Could not create the material.');
    }
  }
}
