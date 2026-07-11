import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';
import 'auth_message.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.watch(context);

    final disabled = auth.isLoading || _isSubmitting;

    return AuthLayout(
      title: 'Create account',
      subtitle: 'Set up your study profile.',
      formKey: const ValueKey('signup-form-panel'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.errorMessage != null) ...[
            AuthMessage(message: auth.errorMessage!, isError: true),
            const SizedBox(height: 12),
          ],
          if (auth.noticeMessage != null) ...[
            AuthMessage(message: auth.noticeMessage!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameController,
            enabled: !disabled,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !disabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !disabled,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: disabled
                    ? null
                    : () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            enabled: !disabled,
            obscureText: !_isConfirmPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _isConfirmPasswordVisible
                    ? 'Hide password'
                    : 'Show password',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: disabled
                    ? null
                    : () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            onSubmitted: (_) => _createAccount(context),
          ),
          const SizedBox(height: 16),
          if (auth.isLoading || _isSubmitting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const ValueKey('auth-primary-action'),
            onPressed: disabled ? null : () => _createAccount(context),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Create account'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: disabled ? null : () => _returnToLogin(),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount(BuildContext context) async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final signedIn = await AuthScope.read(context).signUpWithEmail(
      displayName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!context.mounted) return;
    if (!signedIn) {
      setState(() => _isSubmitting = false);
      return;
    }
    await AppStateScope.read(
      context,
    ).loadSyncedWorkspaceFor(AuthScope.read(context).user);
    if (!context.mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  void _returnToLogin() {
    AuthScope.read(context).clearMessages();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.login);
  }
}
