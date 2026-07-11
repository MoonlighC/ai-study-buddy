import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
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

    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Turn lecture material into focused study sessions.',
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
              controller: _emailController,
              enabled: !disabled,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _passwordController,
              enabled: !disabled,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: _isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
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
                label: const Text('Log in'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: disabled ? null : _createAccount,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Create account'),
            ),
            TextButton(
              onPressed: disabled ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          ] else ...[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('auth-primary-action'),
                onPressed: disabled ? null : _continueWithEmail,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Continue with email'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.g_mobiledata),
            label: Text('Google coming later'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.apple),
            label: Text('Apple coming later'),
          ),
        ],
      ),
    );
  }

  Future<void> _logIn() async {
    if (_isSubmitting) return;
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
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
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
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    await AuthScope.read(context).sendPasswordResetEmail(_emailController.text);
    if (mounted) setState(() => _isSubmitting = false);
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
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }
}
