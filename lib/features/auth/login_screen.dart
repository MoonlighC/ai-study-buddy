import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AI Study Buddy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turn lecture material into focused study sessions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (auth.errorMessage != null) ...[
                    _AuthMessage(
                      message: auth.errorMessage!,
                      isError: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (auth.noticeMessage != null) ...[
                    _AuthMessage(message: auth.noticeMessage!),
                    const SizedBox(height: 12),
                  ],
                  if (isSupabaseMode)
                    _SupabaseEmailForm(
                      emailController: _emailController,
                      passwordController: _passwordController,
                    )
                  else
                    _MockLoginButton(isLoading: auth.isLoading),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Google coming later'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple coming later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupabaseEmailForm extends StatelessWidget {
  const _SupabaseEmailForm({
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          enabled: !auth.isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          enabled: !auth.isLoading,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => _logIn(context),
        ),
        const SizedBox(height: 16),
        if (auth.isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: auth.isLoading ? null : () => _logIn(context),
          icon: const Icon(Icons.login),
          label: const Text('Log in'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: auth.isLoading ? null : () => _createAccount(context),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Create account'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: auth.isLoading ? null : () => _resetPassword(context),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }

  Future<void> _logIn(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final signedIn = await AuthScope.read(context).signInWithEmail(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!context.mounted || !signedIn) {
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  Future<void> _createAccount(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final signedIn = await AuthScope.read(context).signUpWithEmail(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!context.mounted || !signedIn) {
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  Future<void> _resetPassword(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await AuthScope.read(context).sendPasswordResetEmail(emailController.text);
  }
}

class _MockLoginButton extends StatelessWidget {
  const _MockLoginButton({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : () => _continueWithEmail(context),
      icon: const Icon(Icons.mail_outline),
      label: const Text('Continue with email'),
    );
  }

  Future<void> _continueWithEmail(BuildContext context) async {
    final signedIn = await AuthScope.read(context).signInWithEmail(
      email: 'alex.student@example.test',
      password: 'mock-password',
    );
    if (!context.mounted || !signedIn) {
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}
