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

abstract class FlashcardFavoriteRepository {
  Future<Set<String>> loadFlashcardFavoriteIds(AuthUser user);
  Future<void> addFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  });
  Future<void> removeFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  });
}

class FavoriteRepositoryException implements Exception {
  const FavoriteRepositoryException(this.message);

  final String message;
}

class MockFavoriteRepository
    implements FavoriteRepository, FlashcardFavoriteRepository {
  MockFavoriteRepository({Set<String>? initialMaterialFavoriteIds})
    : _materialFavoriteIds = {...?initialMaterialFavoriteIds};

  final Set<String> _materialFavoriteIds;
  final Set<String> _flashcardFavoriteIds = {};

  @override
  Future<Set<String>> loadFlashcardFavoriteIds(AuthUser user) async =>
      Set.of(_flashcardFavoriteIds);
  @override
  Future<void> addFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    _flashcardFavoriteIds.add(flashcardId);
  }

  @override
  Future<void> removeFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    _flashcardFavoriteIds.remove(flashcardId);
  }

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

class EmptyFavoriteRepository
    implements FavoriteRepository, FlashcardFavoriteRepository {
  const EmptyFavoriteRepository();

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async {
    return const <String>{};
  }

  @override
  Future<Set<String>> loadFlashcardFavoriteIds(AuthUser user) async => const {};
  @override
  Future<void> addFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    throw const FavoriteRepositoryException('Favorite sync is not configured.');
  }

  @override
  Future<void> removeFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    throw const FavoriteRepositoryException('Favorite sync is not configured.');
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
