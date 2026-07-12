import 'package:flutter/widgets.dart';

import 'auth_models.dart';
import 'auth_repository.dart';
import '../deletion/account_deletion_repository.dart';
import '../deletion/deletion_models.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this.authRepository,
    required this.profileRepository,
    AccountDeletionRepository? accountDeletionRepository,
  }) : accountDeletionRepository =
           accountDeletionRepository ?? const MockAccountDeletionRepository();

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AccountDeletionRepository accountDeletionRepository;

  AuthUser? _user;
  AuthProfile? _profile;
  bool _hasInitialized = false;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isDeletingAccount = false;
  bool _pendingAccountDeletionReauth = false;
  bool _accountDeletionReauthContinuationActive = false;
  DeletionSafeCode? _accountDeletionError;
  String? _errorMessage;
  String? _noticeMessage;

  AuthUser? get user => _user;

  AuthProfile? get profile => _profile;

  String get effectiveDisplayName {
    final profileName = _cleanName(_profile?.displayName);
    if (profileName != null) {
      return profileName;
    }

    final userName = _cleanName(_user?.displayName);
    if (userName != null) {
      return userName;
    }

    final email = _user?.email.trim();
    if (email != null && email.isNotEmpty) {
      final atIndex = email.indexOf('@');
      if (atIndex > 0) {
        return email.substring(0, atIndex);
      }
    }
    return 'Study buddy';
  }

  bool get hasInitialized => _hasInitialized;

  bool get isInitializing => _isInitializing;

  bool get isLoading => _isLoading;
  bool get isDeletingAccount => _isDeletingAccount;
  bool get pendingAccountDeletionReauth => _pendingAccountDeletionReauth;
  DeletionSafeCode? get accountDeletionError => _accountDeletionError;

  void consumeAccountDeletionReauthIntent() {
    _pendingAccountDeletionReauth = false;
    _accountDeletionReauthContinuationActive = true;
    accountDeletionDebugLog('account_delete_recent_auth_continuation_resumed');
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    final current = _user;
    if (current == null) {
      accountDeletionDebugLog('account_delete_safe_failure_unauthorized');
      _accountDeletionError = DeletionSafeCode.unauthorized;
      return false;
    }
    if (_isDeletingAccount) {
      accountDeletionDebugLog(
        'account_delete_safe_failure_deletion_in_progress',
      );
      return false;
    }
    _isDeletingAccount = true;
    _accountDeletionError = null;
    notifyListeners();
    try {
      final result = await accountDeletionRepository.deleteAccount(
        user: current,
      );
      if (result.completed) {
        try {
          await authRepository.signOut();
        } catch (_) {}
        _user = null;
        _profile = null;
        _pendingAccountDeletionReauth = false;
        _accountDeletionReauthContinuationActive = false;
        return true;
      }
      _accountDeletionError = result.code ?? DeletionSafeCode.unknown;
      return false;
    } on DeletionException catch (error) {
      if (error.code == DeletionSafeCode.recentAuthRequired) {
        if (_accountDeletionReauthContinuationActive) {
          accountDeletionDebugLog('account_delete_recent_auth_loop_prevented');
          _pendingAccountDeletionReauth = false;
          _accountDeletionReauthContinuationActive = false;
          _accountDeletionError = DeletionSafeCode.recentAuthVerificationFailed;
        } else {
          accountDeletionDebugLog(
            'account_delete_recent_auth_redirect_started',
          );
          _pendingAccountDeletionReauth = true;
          _accountDeletionError = error.code;
          await authRepository.signOut();
          _user = null;
          _profile = null;
        }
      } else if (error.code == DeletionSafeCode.unauthorized &&
          error.completedDeletion) {
        _user = null;
        _profile = null;
        _pendingAccountDeletionReauth = false;
        _accountDeletionReauthContinuationActive = false;
        return true;
      } else {
        _accountDeletionError = error.code;
      }
      accountDeletionDebugLog(
        'account_delete_safe_failure_${accountDeletionSafeCodeName(error.code)}',
      );
      return false;
    } catch (error) {
      accountDeletionDebugLog(
        'account_delete_exception_${_accountDeletionExceptionType(error)}',
      );
      _accountDeletionError = DeletionSafeCode.unknown;
      return false;
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  bool get isAuthenticated => _user != null;

  String? get errorMessage => _errorMessage;

  String? get noticeMessage => _noticeMessage;

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }
    _isInitializing = true;
    _clearMessages();
    notifyListeners();

    try {
      final existingUser = await authRepository.currentUser();
      _user = existingUser;
      _profile = null;
      if (existingUser != null) {
        _profile = await _loadProfileWithoutBlocking(existingUser);
      }
    } catch (error) {
      _user = null;
      _profile = null;
      _errorMessage = _messageFor(error);
    } finally {
      _hasInitialized = true;
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final validationMessage = _validateCredentials(
      email: email,
      password: password,
    );
    if (validationMessage != null) {
      _setError(validationMessage);
      return false;
    }

    return _runAuthAction(() async {
      final result = await authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      final signedInUser = result.user;
      if (signedInUser == null) {
        _noticeMessage = result.message;
        return false;
      }
      final profile = await _loadOrEnsureProfile(signedInUser);
      _user = signedInUser;
      _profile = profile;
      return true;
    });
  }

  Future<bool> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      _setError('Enter your name.');
      return false;
    }

    final validationMessage = _validateCredentials(
      email: email,
      password: password,
    );
    if (validationMessage != null) {
      _setError(validationMessage);
      return false;
    }
    if (confirmPassword.isEmpty) {
      _setError('Confirm your password.');
      return false;
    }
    if (password != confirmPassword) {
      _setError('Passwords do not match.');
      return false;
    }

    return _runAuthAction(() async {
      final result = await authRepository.signUpWithEmail(
        displayName: trimmedDisplayName,
        email: email,
        password: password,
      );
      final signedInUser = result.user;
      if (signedInUser == null) {
        _noticeMessage =
            result.message ??
            'Check your email to confirm your account, then log in.';
        return false;
      }
      final profile = await _loadOrEnsureProfile(signedInUser);
      _user = signedInUser;
      _profile = profile;
      return true;
    });
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (!_looksLikeEmail(trimmedEmail)) {
      _setError('Enter a valid email address.');
      return false;
    }

    return _runAuthAction(() async {
      await authRepository.sendPasswordResetEmail(trimmedEmail);
      _noticeMessage =
          'If an account exists for $trimmedEmail, a reset email is on the way.';
      return true;
    });
  }

  Future<bool> signOut() async {
    return _runAuthAction(() async {
      await authRepository.signOut();
      _user = null;
      _profile = null;
      return true;
    });
  }

  Future<bool> updateDisplayName(String displayName) async {
    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      _setError('Enter your name.');
      return false;
    }

    final currentUser = _user;
    if (currentUser == null) {
      _setError('Log in to edit your profile.');
      return false;
    }

    return _runAuthAction(() async {
      _profile = await profileRepository.updateDisplayName(
        user: currentUser,
        displayName: trimmedDisplayName,
      );
      return true;
    });
  }

  Future<bool> _runAuthAction(Future<bool> Function() action) async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();

    try {
      return await action();
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthProfile> _loadOrEnsureProfile(AuthUser user) async {
    final profile = await profileRepository.fetchProfile(user);
    if (profile != null) {
      return profile;
    }
    return profileRepository.ensureProfile(user);
  }

  Future<AuthProfile?> _loadProfileWithoutBlocking(AuthUser user) async {
    try {
      return await _loadOrEnsureProfile(user);
    } catch (error) {
      debugPrint('Profile upsert skipped during startup: $error');
      return null;
    }
  }

  String? _validateCredentials({
    required String email,
    required String password,
  }) {
    if (!_looksLikeEmail(email.trim())) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  bool _looksLikeEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  String? _cleanName(String? name) {
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return null;
    }
    return trimmedName;
  }

  void _setError(String message) {
    _errorMessage = message;
    _noticeMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _clearMessages();
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _noticeMessage = null;
  }

  String _messageFor(Object error) {
    if (error is AuthRepositoryException) {
      final normalizedMessage = error.message.toLowerCase();
      if (normalizedMessage.contains('user already registered')) {
        return 'An account already exists for this email. Try logging in instead.';
      }
      return error.message;
    }
    if (error is ProfileRepositoryException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}

String _accountDeletionExceptionType(Object error) {
  final value = error.runtimeType.toString();
  return RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(value) ? value : 'unknown';
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    required AuthController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AuthController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.notifier!;
  }

  static AuthController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AuthScope>();
    final scope = element?.widget as AuthScope?;
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.notifier!;
  }
}
