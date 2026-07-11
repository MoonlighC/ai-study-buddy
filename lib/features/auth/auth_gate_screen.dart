import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/design_system/tokens.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/study_buddy_mark.dart';
import 'auth_controller.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _routeAfterAuthCheck();
    });
  }

  Future<void> _routeAfterAuthCheck() async {
    final auth = AuthScope.read(context);
    await auth.initialize();
    if (!mounted) {
      return;
    }
    final route = auth.isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;
    if (auth.isAuthenticated) {
      await AppStateScope.read(context).loadSyncedWorkspaceFor(auth.user);
      if (!mounted) {
        return;
      }
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: GlassCard(
            reading: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudyBuddyMark(size: 52),
                SizedBox(height: AppSpacing.md),
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.sm),
                Text('Preparing your study space'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
