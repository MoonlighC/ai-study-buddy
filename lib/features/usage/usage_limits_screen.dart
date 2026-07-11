import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';

class UsageLimitsScreen extends StatelessWidget {
  const UsageLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ResponsiveAppScaffold(
      title: l10n.usageTitle,
      activeRoute: AppRoutes.usage,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: l10n.usageUnavailableTitle,
          message: l10n.usageUnavailableMessage,
        ),
      ),
    );
  }
}
