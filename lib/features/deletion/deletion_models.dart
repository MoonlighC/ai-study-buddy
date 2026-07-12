enum DeletionSafeCode {
  deletionInProgress,
  storageCleanupFailed,
  databaseCleanupFailed,
  authCleanupFailed,
  recentAuthRequired,
  recentAuthVerificationFailed,
  unauthorized,
  retryLater,
  unknown,
}

enum DeletionOperationStatus {
  inProgress,
  retryable,
  completed,
  operatorReview,
}

class DeletionResult {
  const DeletionResult({
    required this.status,
    this.code,
    this.idempotent = false,
  });
  final DeletionOperationStatus status;
  final DeletionSafeCode? code;
  final bool idempotent;
  bool get completed => status == DeletionOperationStatus.completed;
}

class DeletionException implements Exception {
  const DeletionException(this.code, {this.completedDeletion = false});
  final DeletionSafeCode code;
  final bool completedDeletion;
}

DeletionSafeCode deletionSafeCodeFromWire(Object? value) => switch (value) {
  'deletion_in_progress' => DeletionSafeCode.deletionInProgress,
  'storage_cleanup_failed' => DeletionSafeCode.storageCleanupFailed,
  'database_cleanup_failed' => DeletionSafeCode.databaseCleanupFailed,
  'auth_cleanup_failed' => DeletionSafeCode.authCleanupFailed,
  'recent_auth_required' => DeletionSafeCode.recentAuthRequired,
  'unauthorized' => DeletionSafeCode.unauthorized,
  'retry_later' => DeletionSafeCode.retryLater,
  _ => DeletionSafeCode.unknown,
};
