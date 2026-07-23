import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/uuid.dart';

abstract class GenerationOperationStore {
  Future<String> loadOrCreate({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
  });

  Future<void> clear({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
    required String operationId,
  });
}

class SharedPreferencesGenerationOperationStore
    implements GenerationOperationStore {
  const SharedPreferencesGenerationOperationStore();

  @override
  Future<String> loadOrCreate({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userId, feature, materialId, count);
    final existing = preferences.getString(key);
    if (existing != null && _uuidPattern.hasMatch(existing)) {
      return existing;
    }
    final operationId = newUuidV4();
    await preferences.setString(key, operationId);
    return operationId;
  }

  @override
  Future<void> clear({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
    required String operationId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userId, feature, materialId, count);
    if (preferences.getString(key) == operationId) {
      await preferences.remove(key);
    }
  }

  String _key(String userId, String feature, String materialId, int count) =>
      'app.studyGeneration.$userId.$feature.$materialId.$count';
}

class MemoryGenerationOperationStore implements GenerationOperationStore {
  final Map<String, String> _operations = {};

  @override
  Future<String> loadOrCreate({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
  }) async {
    final key = _key(userId, feature, materialId, count);
    return _operations.putIfAbsent(key, newUuidV4);
  }

  @override
  Future<void> clear({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
    required String operationId,
  }) async {
    final key = _key(userId, feature, materialId, count);
    if (_operations[key] == operationId) {
      _operations.remove(key);
    }
  }

  String? operationFor({
    required String userId,
    required String feature,
    required String materialId,
    required int count,
  }) => _operations[_key(userId, feature, materialId, count)];

  String _key(String userId, String feature, String materialId, int count) =>
      '$userId|$feature|$materialId|$count';
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
