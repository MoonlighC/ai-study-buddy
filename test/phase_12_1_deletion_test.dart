import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/deletion/account_deletion_repository.dart';
import 'package:ai_study_buddy/features/deletion/deletion_models.dart';
import 'package:ai_study_buddy/features/deletion/subject_deletion_repository.dart';
import 'package:ai_study_buddy/features/settings/settings_screen.dart';
import 'package:ai_study_buddy/features/subjects/subject_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mobile_qa_harness.dart';

void main() {
  const user = AuthUser(id: 'user-1', email: 'learner@example.test');

  test('subject completion purges subject-owned in-memory data', () async {
    final repository = _SubjectDeletionFake();
    final state = AppState(
      config: AppConfig.fromValues(),
      preferencesStore: MemoryAppPreferencesStore(),
      subjectDeletionRepository: repository,
    );
    final subject = state.subjects.first;
    expect(state.materialsFor(subject.id), isNotEmpty);

    final deleted = await state.deleteSubjectFor(user, subject.id);

    expect(deleted, isTrue);
    expect(repository.subjectIds, [subject.id]);
    expect(state.subjects.where((item) => item.id == subject.id), isEmpty);
    expect(state.materialsFor(subject.id), isEmpty);
    expect(state.cumulativeWeakTopicsFor(subject.id), isEmpty);
  });

  test(
    'retryable subject failure keeps subject and exposes safe code',
    () async {
      final state = AppState(
        config: AppConfig.fromValues(),
        preferencesStore: MemoryAppPreferencesStore(),
        subjectDeletionRepository: _SubjectDeletionFake(
          result: const DeletionResult(
            status: DeletionOperationStatus.retryable,
            code: DeletionSafeCode.storageCleanupFailed,
          ),
        ),
      );
      final subject = state.subjects.first;

      expect(await state.deleteSubjectFor(user, subject.id), isFalse);
      expect(state.subjects.any((item) => item.id == subject.id), isTrue);
      expect(
        state.subjectDeletionErrorFor(subject.id),
        DeletionSafeCode.storageCleanupFailed,
      );
    },
  );

  test(
    'recent-auth requirement signs out and preserves only continuation intent',
    () async {
      final auth = _AuthFake(initialUser: user);
      final controller = AuthController(
        authRepository: auth,
        profileRepository: NoopProfileRepository(),
        accountDeletionRepository: _AccountDeletionFake(
          error: const DeletionException(DeletionSafeCode.recentAuthRequired),
        ),
      );
      await controller.initialize();

      expect(await controller.deleteAccount(), isFalse);
      expect(controller.user, isNull);
      expect(controller.pendingAccountDeletionReauth, isTrue);
      expect(auth.signOutCount, 1);
    },
  );

  test('completed account deletion clears local authenticated state', () async {
    final auth = _AuthFake(initialUser: user);
    final controller = AuthController(
      authRepository: auth,
      profileRepository: NoopProfileRepository(),
      accountDeletionRepository: _AccountDeletionFake(),
    );
    await controller.initialize();

    expect(await controller.deleteAccount(), isTrue);
    expect(controller.user, isNull);
    expect(controller.profile, isNull);
    expect(auth.signOutCount, 1);
  });

  testWidgets('subject deletion confirms full scope and loaded count', (
    tester,
  ) async {
    final state = AppState(preferencesStore: MemoryAppPreferencesStore());
    final auth = AuthController(
      authRepository: _AuthFake(initialUser: user),
      profileRepository: NoopProfileRepository(),
    );
    await auth.initialize();
    final subject = state.subjects.first;
    await tester.pumpWidget(
      qaApp(
        home: AppStateScope(
          state: state,
          child: AuthScope(
            controller: auth,
            child: SubjectDetailScreen(subject: subject),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('subject-delete-action')));
    await tester.pumpAndSettle();
    expect(find.textContaining(subject.name), findsWidgets);
    expect(find.textContaining('quiz attempts'), findsOneWidget);
    expect(find.textContaining('loaded material'), findsOneWidget);
  });

  testWidgets('account confirmation is case-sensitive and deliberate', (
    tester,
  ) async {
    final config = AppConfig.fromValues(
      backendModeValue: 'supabase',
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'sb_publishable_test-client-key',
    );
    final state = AppState(
      config: config,
      preferencesStore: MemoryAppPreferencesStore(),
    );
    final auth = AuthController(
      authRepository: _AuthFake(initialUser: user),
      profileRepository: NoopProfileRepository(),
      accountDeletionRepository: _AccountDeletionFake(),
    );
    await auth.initialize();
    await tester.pumpWidget(
      qaApp(
        home: AppStateScope(
          state: state,
          child: AuthScope(controller: auth, child: const SettingsScreen()),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account-delete-action')),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-delete-action')),
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete-action')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('account-delete-confirm'));
    await tester.enterText(
      find.byKey(const ValueKey('account-delete-confirmation')),
      'delete',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('account-delete-confirmation')),
      ' DELETE ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });
}

class _SubjectDeletionFake implements SubjectDeletionRepository {
  _SubjectDeletionFake({
    this.result = const DeletionResult(
      status: DeletionOperationStatus.completed,
    ),
  });
  final DeletionResult result;
  final List<String> subjectIds = [];
  @override
  Future<DeletionResult> deleteSubject({
    required AuthUser user,
    required String subjectId,
  }) async {
    subjectIds.add(subjectId);
    return result;
  }
}

class _AccountDeletionFake implements AccountDeletionRepository {
  _AccountDeletionFake({this.error});
  final Object? error;
  @override
  Future<DeletionResult> deleteAccount({required AuthUser user}) async {
    if (error != null) throw error!;
    return const DeletionResult(status: DeletionOperationStatus.completed);
  }
}

class _AuthFake implements AuthRepository {
  _AuthFake({this.initialUser});
  final AuthUser? initialUser;
  int signOutCount = 0;
  @override
  Future<AuthUser?> currentUser() async => initialUser;
  @override
  Future<void> signOut() async {
    signOutCount++;
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthResult.signedIn(initialUser!);
  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async => AuthResult.signedIn(initialUser!);
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}
