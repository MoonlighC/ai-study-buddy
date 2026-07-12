import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../auth/auth_models.dart';
import 'deletion_models.dart';

abstract class SubjectDeletionRepository {
  Future<DeletionResult> deleteSubject({
    required AuthUser user,
    required String subjectId,
  });
}

class MockSubjectDeletionRepository implements SubjectDeletionRepository {
  const MockSubjectDeletionRepository();
  @override
  Future<DeletionResult> deleteSubject({
    required AuthUser user,
    required String subjectId,
  }) async => const DeletionResult(status: DeletionOperationStatus.completed);
}

class EmptySubjectDeletionRepository implements SubjectDeletionRepository {
  const EmptySubjectDeletionRepository();
  @override
  Future<DeletionResult> deleteSubject({
    required AuthUser user,
    required String subjectId,
  }) async => throw const DeletionException(DeletionSafeCode.unknown);
}

class SupabaseSubjectDeletionRepository implements SubjectDeletionRepository {
  const SupabaseSubjectDeletionRepository(this._client);
  final supabase.SupabaseClient _client;
  @override
  Future<DeletionResult> deleteSubject({
    required AuthUser user,
    required String subjectId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'delete-subject',
        body: <String, String>{'subject_id': subjectId},
      );
      return _result(response.status, response.data);
    } on DeletionException {
      rethrow;
    } catch (_) {
      throw const DeletionException(DeletionSafeCode.unknown);
    }
  }
}

DeletionResult _result(int status, Object? data) {
  final map = data is Map ? data : null;
  if (status >= 200 && status < 300 && map?['ok'] == true) {
    return DeletionResult(
      status: DeletionOperationStatus.completed,
      idempotent: map?['idempotent'] == true,
    );
  }
  final code = deletionSafeCodeFromWire(map?['code']);
  if (status == 409) {
    return DeletionResult(
      status: code == DeletionSafeCode.deletionInProgress
          ? DeletionOperationStatus.inProgress
          : DeletionOperationStatus.operatorReview,
      code: code,
    );
  }
  if (status == 503) {
    return DeletionResult(
      status: DeletionOperationStatus.retryable,
      code: code,
    );
  }
  throw DeletionException(code);
}
