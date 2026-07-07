import 'auth_models.dart';

abstract class AuthRepository {
  Future<AuthUser?> currentUser();

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

abstract class ProfileRepository {
  Future<void> ensureProfile(AuthUser user);
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;
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
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<AuthResult> signUpWithEmail({
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
  Future<void> ensureProfile(AuthUser user) async {}
}
