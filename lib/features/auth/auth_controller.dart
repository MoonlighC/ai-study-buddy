import 'package:flutter/widgets.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  AuthUser? _user;
  bool _hasInitialized = false;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _noticeMessage;

  AuthUser? get user => _user;

  bool get hasInitialized => _hasInitialized;

  bool get isInitializing => _isInitializing;

  bool get isLoading => _isLoading;

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
      if (existingUser != null) {
        await _ensureProfileWithoutBlocking(existingUser);
      }
    } catch (error) {
      _user = null;
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
      await profileRepository.ensureProfile(signedInUser);
      _user = signedInUser;
      return true;
    });
  }

  Future<bool> signUpWithEmail({
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
      final result = await authRepository.signUpWithEmail(
        email: email,
        password: password,
      );
      final signedInUser = result.user;
      if (signedInUser == null) {
        _noticeMessage =
            result.message ?? 'Check your email before logging in.';
        return false;
      }
      await profileRepository.ensureProfile(signedInUser);
      _user = signedInUser;
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

  Future<void> _ensureProfileWithoutBlocking(AuthUser user) async {
    try {
      await profileRepository.ensureProfile(user);
    } catch (error) {
      debugPrint('Profile upsert skipped during startup: $error');
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

  void _setError(String message) {
    _errorMessage = message;
    _noticeMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _noticeMessage = null;
  }

  String _messageFor(Object error) {
    if (error is AuthRepositoryException) {
      return error.message;
    }
    if (error is ProfileRepositoryException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
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
    final element = context.getElementForInheritedWidgetOfExactType<AuthScope>();
    final scope = element?.widget as AuthScope?;
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.notifier!;
  }
}
