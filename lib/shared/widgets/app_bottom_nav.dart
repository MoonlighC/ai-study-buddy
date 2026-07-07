import 'package:flutter/material.dart';

import '../../app/routes.dart';

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
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'Subjects',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_outline),
          selectedIcon: Icon(Icons.star),
          label: 'Favorites',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
