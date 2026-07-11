import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';

class UsageLimitsScreen extends StatelessWidget {
  const UsageLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveAppScaffold(
      title: 'Usage',
      activeRoute: AppRoutes.usage,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: 'Usage tracking is not connected yet',
          message: 'Limits and enforcement are planned for a future phase.',
        ),
      ),
    );
  }
}
