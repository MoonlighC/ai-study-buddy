import 'package:flutter/material.dart';

import '../../app/routes.dart';

class AppTopActions extends StatelessWidget {
  const AppTopActions({
    this.showHome = true,
    this.showFavorites = true,
    super.key,
  });

  final bool showHome;
  final bool showFavorites;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHome)
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.dashboard,
              (route) => false,
            ),
            icon: const Icon(Icons.home_outlined),
          ),
        IconButton(
          tooltip: 'Search',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
          icon: const Icon(Icons.search),
        ),
        if (showFavorites)
          IconButton(
            tooltip: 'Favorites',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
            icon: const Icon(Icons.star_outline),
          ),
      ],
    );
  }
}
