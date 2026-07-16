import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_models.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AuthUser?> currentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _mapUser(user);
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user ?? _client.auth.currentUser;
      if (user == null) {
        throw const AuthRepositoryException('No authenticated session found.');
      }
      return AuthResult.signedIn(_mapUser(user));
    } on AuthRepositoryException {
      rethrow;
    } on supabase.AuthException catch (error) {
      throw _mappedAuthException(error);
    } catch (error) {
      throw _unexpectedAuthException(error);
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedDisplayName = displayName.trim();
    try {
      final response = await _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: <String, dynamic>{'display_name': trimmedDisplayName},
      );
      final user = response.user ?? _client.auth.currentUser;
      final session = response.session ?? _client.auth.currentSession;
      if (user == null || session == null) {
        return AuthResult.emailConfirmationRequired(trimmedEmail);
      }
      return AuthResult.signedIn(_mapUser(user));
    } on supabase.AuthException catch (error) {
      throw _mappedAuthException(error);
    } catch (error) {
      throw _unexpectedAuthException(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on supabase.AuthException catch (error) {
      throw _mappedAuthException(error);
    } catch (error) {
      throw _unexpectedAuthException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (error) {
      throw _mappedAuthException(error);
    } catch (error) {
      throw _unexpectedAuthException(error);
    }
  }

  AuthUser _mapUser(supabase.User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: _metadataString(user.userMetadata, 'display_name'),
    );
  }

  String? _metadataString(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    if (value is! String) {
      return null;
    }
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  AuthRepositoryException _mappedAuthException(supabase.AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('email not confirmed')) {
      return AuthRepositoryException(
        error.message,
        code: AuthFailureCode.emailNotConfirmed,
      );
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        message.contains('email or password')) {
      return AuthRepositoryException(
        error.message,
        code: AuthFailureCode.invalidCredentials,
      );
    }
    if (message.contains('invalid email')) {
      return AuthRepositoryException(
        error.message,
        code: AuthFailureCode.invalidEmail,
      );
    }
    if (message.contains('rate limit') ||
        message.contains('too many request') ||
        message.contains('over_email_send_rate_limit')) {
      return AuthRepositoryException(
        error.message,
        code: AuthFailureCode.rateLimited,
      );
    }
    if (message.contains('already registered')) {
      return AuthRepositoryException(
        error.message,
        code: AuthFailureCode.alreadyRegistered,
      );
    }
    return AuthRepositoryException(
      error.message,
      code: AuthFailureCode.serviceUnavailable,
    );
  }

  AuthRepositoryException _unexpectedAuthException(Object error) {
    final diagnostic = '${error.runtimeType} $error'.toLowerCase();
    final networkFailure =
        diagnostic.contains('socket') ||
        diagnostic.contains('timeout') ||
        diagnostic.contains('connection') ||
        diagnostic.contains('failed host') ||
        diagnostic.contains('clientexception');
    return AuthRepositoryException(
      networkFailure ? 'Network failure.' : 'Authentication service failure.',
      code: networkFailure
          ? AuthFailureCode.network
          : AuthFailureCode.serviceUnavailable,
    );
  }
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AuthProfile?> fetchProfile(AuthUser user) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id,email,display_name')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return _mapProfile(row);
    } catch (_) {
      throw const ProfileRepositoryException(
        'Could not load the account profile.',
      );
    }
  }

  @override
  Future<AuthProfile> ensureProfile(AuthUser user) async {
    final existingProfile = await fetchProfile(user);
    if (existingProfile != null) {
      return existingProfile;
    }
    return _upsertProfile(user: user, displayName: user.displayName);
  }

  @override
  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  }) async {
    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      throw const ProfileRepositoryException('Enter your name.');
    }

    try {
      final row = await _client
          .from('profiles')
          .update(<String, Object?>{'display_name': trimmedDisplayName})
          .eq('id', user.id)
          .select('id,email,display_name')
          .maybeSingle();
      if (row != null) {
        return _mapProfile(row);
      }
      return _upsertProfile(user: user, displayName: trimmedDisplayName);
    } on ProfileRepositoryException {
      rethrow;
    } catch (_) {
      throw const ProfileRepositoryException(
        'Could not update the account profile.',
      );
    }
  }

  Future<AuthProfile> _upsertProfile({
    required AuthUser user,
    required String? displayName,
  }) async {
    try {
      final row = await _client
          .from('profiles')
          .upsert(<String, Object?>{
            'id': user.id,
            'email': user.email,
            'display_name': _trimmedOrNull(displayName),
          })
          .select('id,email,display_name')
          .single();
      return _mapProfile(row);
    } catch (_) {
      throw const ProfileRepositoryException(
        'Could not update the account profile.',
      );
    }
  }

  AuthProfile _mapProfile(Map<String, dynamic> row) {
    return AuthProfile(
      id: _profileString(row, 'id') ?? '',
      email: _profileString(row, 'email'),
      displayName: _profileString(row, 'display_name'),
    );
  }

  String? _profileString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      return null;
    }
    return _trimmedOrNull(value);
  }

  String? _trimmedOrNull(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }
    return trimmedValue;
  }
}
