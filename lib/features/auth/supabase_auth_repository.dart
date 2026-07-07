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
      throw AuthRepositoryException(error.message);
    } catch (_) {
      throw const AuthRepositoryException(
        'Could not log in. Please try again.',
      );
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
      throw AuthRepositoryException(error.message);
    } catch (_) {
      throw const AuthRepositoryException(
        'Could not create the account. Please try again.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on supabase.AuthException catch (error) {
      throw AuthRepositoryException(error.message);
    } catch (_) {
      throw const AuthRepositoryException(
        'Could not send the password reset email. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (error) {
      throw AuthRepositoryException(error.message);
    } catch (_) {
      throw const AuthRepositoryException(
        'Could not log out. Please try again.',
      );
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
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<void> ensureProfile(AuthUser user) async {
    try {
      await _client.from('profiles').upsert(<String, Object?>{
        'id': user.id,
        'email': user.email,
        'display_name': user.displayName,
      });
    } catch (_) {
      throw const ProfileRepositoryException(
        'Could not update the account profile.',
      );
    }
  }
}
