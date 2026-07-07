import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AuthController', () {
    test('startup without a session remains signed out', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(),
        profileRepository: _FakeProfileRepository(),
      );

      await controller.initialize();

      expect(controller.hasInitialized, isTrue);
      expect(controller.isInitializing, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.user, isNull);
    });

    test('startup with a session signs in and ensures profile', () async {
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: profileRepository,
      );

      await controller.initialize();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.user, user);
      expect(profileRepository.ensuredUsers, [user]);
    });

    test('login signs in and ensures profile', () async {
      final authRepository = _FakeAuthRepository(
        signInResult: AuthResult.signedIn(user),
      );
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );

      final signedIn = await controller.signInWithEmail(
        email: 'learner@example.test',
        password: 'secret1',
      );

      expect(signedIn, isTrue);
      expect(controller.user, user);
      expect(authRepository.signInCount, 1);
      expect(profileRepository.ensuredUsers, [user]);
    });

    test('signup with a session signs in and ensures profile', () async {
      final authRepository = _FakeAuthRepository(
        signUpResult: AuthResult.signedIn(user),
      );
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );

      final signedIn = await controller.signUpWithEmail(
        displayName: 'Learner One',
        email: 'learner@example.test',
        password: 'secret1',
      );

      expect(signedIn, isTrue);
      expect(controller.user, user);
      expect(authRepository.signUpCount, 1);
      expect(profileRepository.ensuredUsers, [user]);
    });

    test('signup requires a display name before calling repository', () async {
      final authRepository = _FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: _FakeProfileRepository(),
      );

      final signedIn = await controller.signUpWithEmail(
        displayName: '  ',
        email: 'learner@example.test',
        password: 'secret1',
      );

      expect(signedIn, isFalse);
      expect(controller.errorMessage, 'Enter your name.');
      expect(authRepository.signUpCount, 0);
    });

    test('signup forwards display name and ensures profile with it', () async {
      final authRepository = _FakeAuthRepository(
        signUpResult: AuthResult.signedIn(user),
      );
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );

      final signedIn = await controller.signUpWithEmail(
        displayName: '  Learner One  ',
        email: 'learner@example.test',
        password: 'secret1',
      );

      expect(signedIn, isTrue);
      expect(authRepository.signUpDisplayNames, ['Learner One']);
      expect(profileRepository.ensuredUsers.single.displayName, 'Learner One');
    });

    test('signup requiring confirmation does not ensure profile', () async {
      final authRepository = _FakeAuthRepository(
        signUpResult: AuthResult.emailConfirmationRequired(
          'learner@example.test',
        ),
      );
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );

      final signedIn = await controller.signUpWithEmail(
        displayName: 'Learner One',
        email: 'learner@example.test',
        password: 'secret1',
      );

      expect(signedIn, isFalse);
      expect(controller.user, isNull);
      expect(controller.noticeMessage, contains('Check learner@example.test'));
      expect(profileRepository.ensuredUsers, isEmpty);
    });

    test('forgot password calls repository and shows notice', () async {
      final authRepository = _FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: _FakeProfileRepository(),
      );

      final sent = await controller.sendPasswordResetEmail(
        'learner@example.test',
      );

      expect(sent, isTrue);
      expect(authRepository.resetEmails, ['learner@example.test']);
      expect(controller.noticeMessage, contains('reset email'));
    });

    test('signout clears authenticated user', () async {
      final authRepository = _FakeAuthRepository(initialUser: user);
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: _FakeProfileRepository(),
      );
      await controller.initialize();

      final signedOut = await controller.signOut();

      expect(signedOut, isTrue);
      expect(controller.user, isNull);
      expect(authRepository.signOutCount, 1);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.initialUser,
    AuthResult? signInResult,
    AuthResult? signUpResult,
  }) : signInResult = signInResult ?? AuthResult.signedIn(initialUser ?? _user),
       signUpResult = signUpResult ?? AuthResult.signedIn(initialUser ?? _user);

  static const _user = AuthUser(
    id: 'fake-user',
    email: 'fake@example.test',
    displayName: 'Fake User',
  );

  final AuthUser? initialUser;
  final AuthResult signInResult;
  final AuthResult signUpResult;

  int signInCount = 0;
  int signUpCount = 0;
  int signOutCount = 0;
  final List<String> signUpDisplayNames = [];
  final List<String> resetEmails = [];

  @override
  Future<AuthUser?> currentUser() async {
    return initialUser;
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCount += 1;
    return signInResult;
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    signUpCount += 1;
    signUpDisplayNames.add(displayName);
    return signUpResult;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final List<AuthUser> ensuredUsers = [];

  @override
  Future<void> ensureProfile(AuthUser user) async {
    ensuredUsers.add(user);
  }
}
