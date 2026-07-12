import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/deletion/account_deletion_repository.dart';
import 'package:ai_study_buddy/features/deletion/deletion_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  const user = AuthUser(id: 'private-id-123', email: 'private@example.test');

  test('active session reaches invoke exactly once', () async {
    var invokes = 0;
    final logs = <String>[];
    final repository = SupabaseAccountDeletionRepository.forTest(
      () => true,
      () async {
        invokes++;
        return const supabase.FunctionResponse(status: 200, data: {'ok': true});
      },
      debugLog: logs.add,
    );

    final result = await repository.deleteAccount(user: user);

    expect(result.completed, isTrue);
    expect(invokes, 1);
    expect(
      logs,
      containsAllInOrder([
        'account_delete_repository_started',
        'account_delete_session_present',
        'account_delete_before_invoke',
        'account_delete_after_invoke',
      ]),
    );
  });

  test('null session fails safely before invoke', () async {
    var invokes = 0;
    final logs = <String>[];
    final repository = SupabaseAccountDeletionRepository.forTest(
      () => false,
      () async {
        invokes++;
        return const supabase.FunctionResponse(status: 200);
      },
      debugLog: logs.add,
    );

    await expectLater(
      repository.deleteAccount(user: user),
      throwsA(
        isA<DeletionException>().having(
          (error) => error.code,
          'code',
          DeletionSafeCode.unauthorized,
        ),
      ),
    );
    expect(invokes, 0);
    expect(logs, contains('account_delete_safe_failure_unauthorized'));
  });

  test('duplicate guard resets after synchronous repository failure', () async {
    final repository = _ThrowingDeletionRepository();
    final controller = AuthController(
      authRepository: _AuthFake(user),
      profileRepository: NoopProfileRepository(),
      accountDeletionRepository: repository,
    );
    await controller.initialize();

    expect(await controller.deleteAccount(), isFalse);
    expect(controller.isDeletingAccount, isFalse);
    expect(await controller.deleteAccount(), isFalse);
    expect(repository.calls, 2);
  });

  test(
    'synchronous repository exception is logged by safe type only',
    () async {
      final messages = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      try {
        final controller = AuthController(
          authRepository: _AuthFake(user),
          profileRepository: NoopProfileRepository(),
          accountDeletionRepository: _ThrowingDeletionRepository(),
        );
        await controller.initialize();
        expect(await controller.deleteAccount(), isFalse);
        expect(messages, contains('account_delete_exception_StateError'));
        expect(messages.join(' '), isNot(contains(user.email)));
        expect(messages.join(' '), isNot(contains(user.id)));
      } finally {
        debugPrint = original;
      }
    },
  );
}

class _ThrowingDeletionRepository implements AccountDeletionRepository {
  int calls = 0;
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) {
    calls++;
    throw StateError('raw private failure');
  }
}

class _AuthFake implements AuthRepository {
  const _AuthFake(this.user);
  final AuthUser user;
  @override
  Future<AuthUser?> currentUser() async => user;
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthResult.signedIn(user);
  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async => AuthResult.signedIn(user);
  @override
  Future<void> signOut() async {}
}
