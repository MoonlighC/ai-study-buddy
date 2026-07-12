import 'package:flutter/foundation.dart';
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
  SupabaseAccountDeletionRepository(supabase.SupabaseClient client)
    : _sessionPresent = _sessionChecker(client),
      _invoke = _accountDeletionInvoker(client),
      _debugLog = accountDeletionDebugLog;

  @visibleForTesting
  SupabaseAccountDeletionRepository.forTest(
    this._sessionPresent,
    this._invoke, {
    void Function(String)? debugLog,
  }) : _debugLog = debugLog ?? accountDeletionDebugLog;

  final bool Function() _sessionPresent;
  final Future<supabase.FunctionResponse> Function() _invoke;
  final void Function(String) _debugLog;
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) async {
    _debugLog('account_delete_repository_started');
    if (!_sessionPresent()) {
      _debugLog('account_delete_safe_failure_unauthorized');
      throw const DeletionException(DeletionSafeCode.unauthorized);
    }
    _debugLog('account_delete_session_present');
    try {
      _debugLog('account_delete_before_invoke');
      final response = await _invoke();
      _debugLog('account_delete_after_invoke');
      final map = response.data is Map ? response.data as Map : null;
      if (response.status >= 200 &&
          response.status < 300 &&
          map?['ok'] == true) {
        return const DeletionResult(status: DeletionOperationStatus.completed);
      }
      final code = deletionSafeCodeFromWire(map?['code']);
      if (response.status == 409) {
        _debugLog(
          'account_delete_safe_failure_${accountDeletionSafeCodeName(code)}',
        );
        return DeletionResult(
          status: code == DeletionSafeCode.deletionInProgress
              ? DeletionOperationStatus.inProgress
              : DeletionOperationStatus.operatorReview,
          code: code,
        );
      }
      if (response.status == 503) {
        _debugLog(
          'account_delete_safe_failure_${accountDeletionSafeCodeName(code)}',
        );
        return DeletionResult(
          status: DeletionOperationStatus.retryable,
          code: code,
        );
      }
      throw DeletionException(code);
    } on DeletionException catch (error) {
      _debugLog(
        'account_delete_safe_failure_${accountDeletionSafeCodeName(error.code)}',
      );
      rethrow;
    } on supabase.FunctionException catch (error) {
      final code = error.status == 401
          ? DeletionSafeCode.unauthorized
          : deletionSafeCodeFromWire(_safeDetailsCode(error.details));
      _debugLog(
        'account_delete_safe_failure_${accountDeletionSafeCodeName(code)}',
      );
      throw DeletionException(code, completedDeletion: error.status == 401);
    } catch (error) {
      _debugLog('account_delete_exception_${_safeType(error)}');
      throw const DeletionException(DeletionSafeCode.unknown);
    }
  }
}

bool Function() _sessionChecker(supabase.SupabaseClient client) =>
    () => client.auth.currentSession != null;

Future<supabase.FunctionResponse> Function() _accountDeletionInvoker(
  supabase.SupabaseClient client,
) =>
    () => client.functions.invoke(
      'delete-account',
      body: const <String, String>{'confirmation': 'DELETE'},
    );

void accountDeletionDebugLog(String stage) {
  if (kDebugMode) debugPrint(stage);
}

Object? _safeDetailsCode(Object? details) =>
    details is Map ? details['code'] : null;

String accountDeletionSafeCodeName(DeletionSafeCode code) => switch (code) {
  DeletionSafeCode.deletionInProgress => 'deletion_in_progress',
  DeletionSafeCode.storageCleanupFailed => 'storage_cleanup_failed',
  DeletionSafeCode.databaseCleanupFailed => 'database_cleanup_failed',
  DeletionSafeCode.authCleanupFailed => 'auth_cleanup_failed',
  DeletionSafeCode.recentAuthRequired => 'recent_auth_required',
  DeletionSafeCode.recentAuthVerificationFailed =>
    'recent_auth_verification_failed',
  DeletionSafeCode.unauthorized => 'unauthorized',
  DeletionSafeCode.retryLater => 'retry_later',
  DeletionSafeCode.unknown => 'unknown',
};

String _safeType(Object error) {
  final value = error.runtimeType.toString();
  return RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(value) ? value : 'unknown';
}
