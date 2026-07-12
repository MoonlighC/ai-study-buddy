import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../auth/auth_models.dart';
import 'deletion_models.dart';

abstract class AccountDeletionRepository {
  Future<DeletionResult> deleteAccount({required AuthUser user});
}

class MockAccountDeletionRepository implements AccountDeletionRepository {
  const MockAccountDeletionRepository();
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) async =>
      const DeletionResult(status: DeletionOperationStatus.completed);
}

class EmptyAccountDeletionRepository implements AccountDeletionRepository {
  const EmptyAccountDeletionRepository();
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) async =>
      throw const DeletionException(DeletionSafeCode.unknown);
}

class SupabaseAccountDeletionRepository implements AccountDeletionRepository {
  const SupabaseAccountDeletionRepository(this._client);
  final supabase.SupabaseClient _client;
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) async {
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: const <String, String>{'confirmation': 'DELETE'},
      );
      final map = response.data is Map ? response.data as Map : null;
      if (response.status >= 200 &&
          response.status < 300 &&
          map?['ok'] == true) {
        return const DeletionResult(status: DeletionOperationStatus.completed);
      }
      final code = deletionSafeCodeFromWire(map?['code']);
      if (response.status == 409) {
        return DeletionResult(
          status: code == DeletionSafeCode.deletionInProgress
              ? DeletionOperationStatus.inProgress
              : DeletionOperationStatus.operatorReview,
          code: code,
        );
      }
      if (response.status == 503) {
        return DeletionResult(
          status: DeletionOperationStatus.retryable,
          code: code,
        );
      }
      throw DeletionException(code);
    } on DeletionException {
      rethrow;
    } catch (_) {
      throw const DeletionException(DeletionSafeCode.unknown);
    }
  }
}
