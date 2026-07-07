import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/subject.dart';
import '../../features/auth/auth_models.dart';
import 'subject_repository.dart';

class SupabaseSubjectRepository implements SubjectRepository {
  const SupabaseSubjectRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    try {
      final rows = await _client
          .from('subjects')
          .select('id,name,description,color_value')
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('sort_order')
          .order('created_at');

      return rows.map(_mapSubject).toList();
    } catch (_) {
      throw const SubjectRepositoryException('Could not sync subjects.');
    }
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

    try {
      final row = await _client
          .from('subjects')
          .insert(<String, Object?>{
            'user_id': user.id,
            'name': cleanName,
            'description': description.trim(),
            'color_value': colorValue,
            'sort_order': sortOrder,
          })
          .select('id,name,description,color_value')
          .single();
      return _mapSubject(row);
    } on SubjectRepositoryException {
      rethrow;
    } catch (_) {
      throw const SubjectRepositoryException('Could not create the subject.');
    }
  }

  Subject _mapSubject(Map<String, dynamic> row) {
    return Subject(
      id: _stringValue(row, 'id') ?? '',
      name: _stringValue(row, 'name') ?? 'Untitled subject',
      description: _stringValue(row, 'description') ?? '',
      colorValue: _intValue(row, 'color_value') ?? 0xFF2563EB,
    );
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
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
