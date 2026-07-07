class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;
}

class AuthProfile {
  const AuthProfile({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;
}

class AuthResult {
  const AuthResult._({
    required this.user,
    required this.needsEmailConfirmation,
    required this.message,
  });

  factory AuthResult.signedIn(AuthUser user) {
    return AuthResult._(
      user: user,
      needsEmailConfirmation: false,
      message: null,
    );
  }

  factory AuthResult.emailConfirmationRequired(String email) {
    return AuthResult._(
      user: null,
      needsEmailConfirmation: true,
      message:
          'Check $email for a confirmation link, then return here to log in.',
    );
  }

  final AuthUser? user;
  final bool needsEmailConfirmation;
  final String? message;
}
