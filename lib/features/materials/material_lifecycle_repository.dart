import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_models.dart';

class MaterialLifecycleException implements Exception {
  const MaterialLifecycleException(this.message);
  final String message;
}

class MaterialRecoveryEligibility {
  const MaterialRecoveryEligibility({required this.eligible, this.processor});
  final bool eligible;
  final String? processor;
}

abstract class MaterialLifecycleRepository {
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  });
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  });
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  });

  /// Returns null when existence could not be reconciled safely.
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async => null;
}

class MockMaterialLifecycleRepository implements MaterialLifecycleRepository {
  const MockMaterialLifecycleRepository();
  @override
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  }) async {}
  @override
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  }) async => const MaterialRecoveryEligibility(eligible: false);
  @override
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  }) async {}
  @override
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async => false;
}

class EmptyMaterialLifecycleRepository implements MaterialLifecycleRepository {
  const EmptyMaterialLifecycleRepository();
  Never _unavailable() => throw const MaterialLifecycleException(
    'Material lifecycle is not configured.',
  );
  @override
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  }) async => _unavailable();
  @override
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  }) async => _unavailable();
  @override
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  }) async => _unavailable();
  @override
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async => null;
}

class SupabaseMaterialLifecycleRepository
    implements MaterialLifecycleRepository {
  const SupabaseMaterialLifecycleRepository(this._client);
  final supabase.SupabaseClient _client;

  @override
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'delete-material',
        body: <String, String>{'material_id': materialId},
      );
      final data = response.data;
      if (response.status < 200 ||
          response.status >= 300 ||
          data is! Map ||
          data['ok'] != true) {
        throw const MaterialLifecycleException(
          'Could not delete the material. Try again.',
        );
      }
    } on MaterialLifecycleException {
      rethrow;
    } catch (_) {
      throw const MaterialLifecycleException(
        'Could not delete the material. Try again.',
      );
    }
  }

  @override
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final row = await _client
          .from('materials')
          .select('id')
          .eq('id', materialId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final rows = await _client.rpc(
        'inspect_material_recovery',
        params: <String, Object>{'p_material_id': materialId},
      );
      final row = rows is List && rows.isNotEmpty ? rows.first : null;
      if (row is! Map) {
        return const MaterialRecoveryEligibility(eligible: false);
      }
      return MaterialRecoveryEligibility(
        eligible: row['eligible'] == true,
        processor: row['processor'] as String?,
      );
    } catch (_) {
      return const MaterialRecoveryEligibility(eligible: false);
    }
  }

  @override
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  }) async {
    try {
      final result = await _client.rpc(
        'recover_stale_material',
        params: <String, Object>{
          'p_material_id': materialId,
          'p_processor': processor,
        },
      );
      if (result != 'recovered') {
        throw const MaterialLifecycleException(
          'Processing could not be reset.',
        );
      }
    } on MaterialLifecycleException {
      rethrow;
    } catch (_) {
      throw const MaterialLifecycleException('Processing could not be reset.');
    }
  }
}
