import 'auth_models.dart';

abstract class AuthRepository {
  Future<AuthUser?> currentUser();

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

abstract class ProfileRepository {
  Future<AuthProfile?> fetchProfile(AuthUser user);

  Future<AuthProfile> ensureProfile(AuthUser user);

  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  });
}

enum AuthFailureCode {
  invalidEmail,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  network,
  serviceUnavailable,
  alreadyRegistered,
  unknown,
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(
    this.message, {
    this.code = AuthFailureCode.unknown,
  });

  final String message;
  final AuthFailureCode code;
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.message);

  final String message;
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  AuthUser? _user;

  @override
  Future<AuthUser?> currentUser() async {
    return _user;
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _user = const AuthUser(
      id: 'mock-user',
      email: 'alex.student@example.test',
      displayName: 'Alex Student',
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    return signInWithEmail(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class NoopProfileRepository implements ProfileRepository {
  @override
  Future<AuthProfile?> fetchProfile(AuthUser user) async {
    return null;
  }

  @override
  Future<AuthProfile> ensureProfile(AuthUser user) async {
    return AuthProfile(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    );
  }

  @override
  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  }) async {
    return AuthProfile(
      id: user.id,
      email: user.email,
      displayName: displayName.trim(),
    );
  }
}
