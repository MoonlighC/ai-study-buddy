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

    test('startup with a session fetches profile', () async {
      final profileRepository = _FakeProfileRepository(
        profile: const AuthProfile(
          id: 'user-1',
          email: 'learner@example.test',
          displayName: 'Profile Learner',
        ),
      );
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: profileRepository,
      );

      await controller.initialize();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.user, user);
      expect(controller.profile?.displayName, 'Profile Learner');
      expect(controller.effectiveDisplayName, 'Profile Learner');
      expect(profileRepository.fetchedUsers, [user]);
      expect(profileRepository.ensuredUsers, isEmpty);
    });

    test('profile display name wins over auth metadata', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: _FakeProfileRepository(
          profile: const AuthProfile(
            id: 'user-1',
            email: 'learner@example.test',
            displayName: 'Profile Name',
          ),
        ),
      );

      await controller.initialize();

      expect(controller.user?.displayName, 'Learner One');
      expect(controller.effectiveDisplayName, 'Profile Name');
    });

    test('missing profile calls ensure and falls back safely', () async {
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: profileRepository,
      );

      await controller.initialize();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile?.displayName, 'Learner One');
      expect(controller.effectiveDisplayName, 'Learner One');
      expect(profileRepository.fetchedUsers, [user]);
      expect(profileRepository.ensuredUsers, [user]);
    });

    test('profile failure preserves signed-in startup session', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: _FakeProfileRepository(throwOnFetch: true),
      );

      await controller.initialize();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.user, user);
      expect(controller.profile, isNull);
      expect(controller.effectiveDisplayName, 'Learner One');
      expect(controller.errorMessage, isNull);
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

    test('login requires email and password before repository call', () async {
      final authRepository = _FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: _FakeProfileRepository(),
      );

      expect(
        await controller.signInWithEmail(email: ' ', password: 'secret'),
        isFalse,
      );
      expect(controller.errorMessage, 'Enter your email address.');
      expect(
        await controller.signInWithEmail(
          email: 'learner@example.test',
          password: '',
        ),
        isFalse,
      );
      expect(controller.errorMessage, 'Password is required.');
      expect(authRepository.signInCount, 0);
    });

    test(
      'login accepts a short non-empty password for authentication',
      () async {
        final authRepository = _FakeAuthRepository(
          signInResult: AuthResult.signedIn(user),
        );
        final controller = AuthController(
          authRepository: authRepository,
          profileRepository: _FakeProfileRepository(),
        );

        expect(
          await controller.signInWithEmail(
            email: 'learner@example.test',
            password: 'x',
          ),
          isTrue,
        );
        expect(authRepository.signInCount, 1);
      },
    );

    for (final entry in const <(AuthFailureCode, String)>[
      (
        AuthFailureCode.invalidCredentials,
        'Unable to sign in. Check your email address and password.',
      ),
      (
        AuthFailureCode.emailNotConfirmed,
        'Confirm your email address before signing in.',
      ),
      (
        AuthFailureCode.rateLimited,
        'Too many sign-in attempts. Try again later.',
      ),
      (
        AuthFailureCode.network,
        'Check your internet connection and try again.',
      ),
      (
        AuthFailureCode.serviceUnavailable,
        'The authentication service is temporarily unavailable. Try again later.',
      ),
    ]) {
      test('login maps ${entry.$1} to a safe message', () async {
        final controller = AuthController(
          authRepository: _FakeAuthRepository(
            signInError: AuthRepositoryException(
              'Provider detail',
              code: entry.$1,
            ),
          ),
          profileRepository: _FakeProfileRepository(),
        );

        expect(
          await controller.signInWithEmail(
            email: 'learner@example.test',
            password: 'secret',
          ),
          isFalse,
        );
        expect(controller.errorMessage, entry.$2);
      });
    }

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
        confirmPassword: 'secret1',
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
        confirmPassword: 'secret1',
      );

      expect(signedIn, isFalse);
      expect(controller.errorMessage, 'Enter your name.');
      expect(authRepository.signUpCount, 0);
    });

    test(
      'signup requires confirm password before calling repository',
      () async {
        final authRepository = _FakeAuthRepository();
        final controller = AuthController(
          authRepository: authRepository,
          profileRepository: _FakeProfileRepository(),
        );

        final signedIn = await controller.signUpWithEmail(
          displayName: 'Learner One',
          email: 'learner@example.test',
          password: 'secret1',
          confirmPassword: '',
        );

        expect(signedIn, isFalse);
        expect(controller.errorMessage, 'Confirm your password.');
        expect(authRepository.signUpCount, 0);
      },
    );

    test(
      'signup requires matching passwords before calling repository',
      () async {
        final authRepository = _FakeAuthRepository();
        final controller = AuthController(
          authRepository: authRepository,
          profileRepository: _FakeProfileRepository(),
        );

        final signedIn = await controller.signUpWithEmail(
          displayName: 'Learner One',
          email: 'learner@example.test',
          password: 'secret1',
          confirmPassword: 'secret2',
        );

        expect(signedIn, isFalse);
        expect(controller.errorMessage, 'Passwords do not match.');
        expect(authRepository.signUpCount, 0);
      },
    );

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
        confirmPassword: 'secret1',
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
        confirmPassword: 'secret1',
      );

      expect(signedIn, isFalse);
      expect(controller.user, isNull);
      expect(
        controller.noticeMessage,
        'Check your email to confirm your account, then log in.',
      );
      expect(profileRepository.ensuredUsers, isEmpty);
    });

    test('already registered signup error shows friendly message', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(
          signUpError: const AuthRepositoryException('User already registered'),
        ),
        profileRepository: _FakeProfileRepository(),
      );

      final signedIn = await controller.signUpWithEmail(
        displayName: 'Learner One',
        email: 'learner@example.test',
        password: 'secret1',
        confirmPassword: 'secret1',
      );

      expect(signedIn, isFalse);
      expect(
        controller.errorMessage,
        'An account already exists for this email. Try logging in instead.',
      );
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

    test('empty edit name fails before repository update', () async {
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: profileRepository,
      );
      await controller.initialize();

      final updated = await controller.updateDisplayName('   ');

      expect(updated, isFalse);
      expect(controller.errorMessage, 'Enter your name.');
      expect(profileRepository.updatedDisplayNames, isEmpty);
    });

    test('valid edit name updates repository and controller state', () async {
      final profileRepository = _FakeProfileRepository();
      final controller = AuthController(
        authRepository: _FakeAuthRepository(initialUser: user),
        profileRepository: profileRepository,
      );
      await controller.initialize();

      final updated = await controller.updateDisplayName('  Updated Learner  ');

      expect(updated, isTrue);
      expect(profileRepository.updatedDisplayNames, ['Updated Learner']);
      expect(controller.profile?.displayName, 'Updated Learner');
      expect(controller.effectiveDisplayName, 'Updated Learner');
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
      expect(controller.profile, isNull);
      expect(authRepository.signOutCount, 1);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.initialUser,
    AuthResult? signInResult,
    AuthResult? signUpResult,
    this.signUpError,
    this.signInError,
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
  final Object? signUpError;
  final Object? signInError;

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
    final error = signInError;
    if (error != null) throw error;
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
    final error = signUpError;
    if (error != null) {
      throw error;
    }
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
  _FakeProfileRepository({this.profile, this.throwOnFetch = false});

  AuthProfile? profile;
  final bool throwOnFetch;

  final List<AuthUser> fetchedUsers = [];
  final List<AuthUser> ensuredUsers = [];
  final List<AuthUser> updateUsers = [];
  final List<String> updatedDisplayNames = [];

  @override
  Future<AuthProfile?> fetchProfile(AuthUser user) async {
    if (throwOnFetch) {
      throw const ProfileRepositoryException('Profile failed.');
    }
    fetchedUsers.add(user);
    return profile;
  }

  @override
  Future<AuthProfile> ensureProfile(AuthUser user) async {
    ensuredUsers.add(user);
    final ensuredProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    );
    profile = ensuredProfile;
    return ensuredProfile;
  }

  @override
  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  }) async {
    updateUsers.add(user);
    updatedDisplayNames.add(displayName);
    final updatedProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: displayName,
    );
    profile = updatedProfile;
    return updatedProfile;
  }
}
