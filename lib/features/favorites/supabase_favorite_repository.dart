import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_models.dart';
import 'favorite_repository.dart';

class SupabaseFavoriteRepository implements FavoriteRepository {
  const SupabaseFavoriteRepository(this._client);

  static const _materialEntityType = 'material';

  final supabase.SupabaseClient _client;

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    try {
      final rows = await _client
          .from('favorites')
          .select('entity_id')
          .eq('user_id', user.id)
          .eq('entity_type', _materialEntityType)
          .order('created_at', ascending: false);

      final favoriteIds = <String>{};
      for (final row in rows) {
        final id = _stringValue(row, 'entity_id');
        if (id != null) {
          favoriteIds.add(id);
        }
      }
      return favoriteIds;
    } catch (_) {
      throw const FavoriteRepositoryException('Could not sync favorites.');
    }
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      await _client
          .from('favorites')
          .upsert(
            <String, Object?>{
              'user_id': user.id,
              'entity_type': _materialEntityType,
              'entity_id': materialId,
            },
            onConflict: 'user_id,entity_type,entity_id',
            ignoreDuplicates: true,
          );
    } catch (_) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
  }

  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('entity_type', _materialEntityType)
          .eq('entity_id', materialId);
    } catch (_) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
  }

  String? _stringValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      return null;
    }
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}
