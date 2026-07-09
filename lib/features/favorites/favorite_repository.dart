import '../auth/auth_models.dart';

abstract class FavoriteRepository {
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user);

  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  });

  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  });
}

class FavoriteRepositoryException implements Exception {
  const FavoriteRepositoryException(this.message);

  final String message;
}

class MockFavoriteRepository implements FavoriteRepository {
  MockFavoriteRepository({Set<String>? initialMaterialFavoriteIds})
    : _materialFavoriteIds = {...?initialMaterialFavoriteIds};

  final Set<String> _materialFavoriteIds;

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    return Set<String>.of(_materialFavoriteIds);
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    _materialFavoriteIds.add(materialId);
  }

  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    _materialFavoriteIds.remove(materialId);
  }
}

class EmptyFavoriteRepository implements FavoriteRepository {
  const EmptyFavoriteRepository();

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    return const <String>{};
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    throw const FavoriteRepositoryException('Favorite sync is not configured.');
  }

  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {
    throw const FavoriteRepositoryException('Favorite sync is not configured.');
  }
}
