import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _routes = [
    AppRoutes.dashboard,
    AppRoutes.subjects,
    AppRoutes.favorites,
    AppRoutes.progress,
    AppRoutes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentIndex = _routes.indexOf(routeName ?? AppRoutes.dashboard);

    return NavigationBar(
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
      onDestinationSelected: (index) {
        final target = _routes[index];
        if (target == routeName) {
          return;
        }
        Navigator.pushReplacementNamed(context, target);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: context.l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.folder_outlined),
          selectedIcon: const Icon(Icons.folder),
          label: context.l10n.navSubjects,
        ),
        NavigationDestination(
          icon: const Icon(Icons.star_outline),
          selectedIcon: const Icon(Icons.star),
          label: context.l10n.navFavorites,
        ),
        NavigationDestination(
          icon: const Icon(Icons.trending_up_outlined),
          selectedIcon: const Icon(Icons.trending_up),
          label: context.l10n.navProgress,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: context.l10n.navSettings,
        ),
      ],
    );
  }
}
