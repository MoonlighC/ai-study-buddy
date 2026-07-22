import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/knowledge_score.dart';
import '../auth/auth_models.dart';

abstract class StudyProgressRepository {
  Future<StudyProgress> loadProgress(
    AuthUser user, {
    String? subjectId,
    String? materialId,
  });
}

class StudyProgressRepositoryException implements Exception {
  const StudyProgressRepositoryException(this.message);
  final String message;
}

class EmptyStudyProgressRepository implements StudyProgressRepository {
  const EmptyStudyProgressRepository();
  @override
  Future<StudyProgress> loadProgress(
    AuthUser user, {
    String? subjectId,
    String? materialId,
  }) => throw const StudyProgressRepositoryException(
    'Authoritative progress is not configured.',
  );
}

class SupabaseStudyProgressRepository implements StudyProgressRepository {
  const SupabaseStudyProgressRepository(this._client);
  final supabase.SupabaseClient _client;

  @override
  Future<StudyProgress> loadProgress(
    AuthUser user, {
    String? subjectId,
    String? materialId,
  }) async {
    try {
      final response = await _client.rpc(
        'get_study_progress',
        params: {'p_subject_id': subjectId, 'p_material_id': materialId},
      );
      if (response is! Map) throw const FormatException();
      return StudyProgress.fromJson(Map<String, dynamic>.from(response));
    } catch (_) {
      throw const StudyProgressRepositoryException(
        'Could not load authoritative study progress.',
      );
    }
  }
}
