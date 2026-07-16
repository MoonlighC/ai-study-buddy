import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';
import 'auth_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final auth = AuthScope.watch(context);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final disabled = auth.isLoading || _isSubmitting;
    final l10n = context.l10n;

    return AuthLayout(
      title: l10n.authWelcomeBackTitle,
      subtitle: l10n.authWelcomeBackSubtitle,
      formKey: const ValueKey('login-form-panel'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.errorMessage != null) ...[
            AuthMessage(message: auth.errorMessage!, isError: true),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (auth.noticeMessage != null) ...[
            AuthMessage(message: auth.noticeMessage!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isSupabaseMode) ...[
            TextField(
              key: const ValueKey('login-email-field'),
              controller: _emailController,
              enabled: !disabled,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.commonEmail,
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _emailError,
              ),
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('login-password-field'),
              controller: _passwordController,
              enabled: !disabled,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.commonPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: _isPasswordVisible
                      ? l10n.authHidePassword
                      : l10n.authShowPassword,
                  onPressed: disabled
                      ? null
                      : () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _logIn(),
            ),
            const SizedBox(height: AppSpacing.md),
            if (auth.isLoading || _isSubmitting) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('auth-primary-action'),
                onPressed: disabled ? null : _logIn,
                icon: const Icon(Icons.login),
                label: Text(l10n.authLogIn),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: disabled ? null : _createAccount,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.authCreateAccountTitle),
            ),
            TextButton(
              key: const ValueKey('forgot-password-action'),
              onPressed: disabled ? null : _resetPassword,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  const Icon(Icons.lock_reset_outlined),
                  Text(l10n.authForgotPassword),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('auth-primary-action'),
                onPressed: disabled ? null : _continueWithEmail,
                icon: const Icon(Icons.mail_outline),
                label: Text(l10n.authContinueWithEmail),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.g_mobiledata),
            label: Text(l10n.authGoogleComingLater),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.apple),
            label: Text(l10n.authAppleComingLater),
          ),
        ],
      ),
    );
  }

  Future<void> _logIn() async {
    if (_isSubmitting) return;
    if (!_validateLoginFields()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final signedIn = await AuthScope.read(context).signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (!signedIn) {
      setState(() => _isSubmitting = false);
      return;
    }
    await AppStateScope.read(
      context,
    ).loadSyncedWorkspaceFor(AuthScope.read(context).user);
    if (!mounted) return;
    final auth = AuthScope.read(context);
    Navigator.pushReplacementNamed(
      context,
      auth.pendingAccountDeletionReauth
          ? AppRoutes.settings
          : AppRoutes.dashboard,
    );
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    AuthScope.read(context).clearMessages();
    await Navigator.pushNamed(context, AppRoutes.signup);
    if (!mounted) return;
    AuthScope.read(context).clearMessages();
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting) return;
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    await AuthScope.read(context).sendPasswordResetEmail(_emailController.text);
    if (mounted) setState(() => _isSubmitting = false);
  }

  bool _validateLoginFields() {
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _passwordController.text.isEmpty
        ? context.l10n.errorPasswordRequired
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return context.l10n.errorEmailRequired;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return context.l10n.errorEnterValidEmail;
    }
    return null;
  }

  Future<void> _continueWithEmail() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final signedIn = await AuthScope.read(context).signInWithEmail(
      email: 'alex.student@example.test',
      password: 'mock-password',
    );
    if (!mounted) return;
    if (!signedIn) {
      setState(() => _isSubmitting = false);
      return;
    }
    await AppStateScope.read(
      context,
    ).loadSyncedWorkspaceFor(AuthScope.read(context).user);
    if (!mounted) return;
    final auth = AuthScope.read(context);
    Navigator.pushReplacementNamed(
      context,
      auth.pendingAccountDeletionReauth
          ? AppRoutes.settings
          : AppRoutes.dashboard,
    );
  }
}
