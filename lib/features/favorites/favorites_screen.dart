import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = AppStateScope.watch(context).favoriteFlashcards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: const [AppTopActions(showFavorites: false)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Study only favorites',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Favorite cards are grouped here for focused review sessions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (favorites.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.star_border),
                title: Text('No favorites yet'),
                subtitle: Text('Star flashcards to collect them here.'),
              ),
            )
          else
            for (final card in favorites)
              Card(
                child: ListTile(
                  leading: IconButton(
                    tooltip: 'Unfavorite',
                    onPressed: () =>
                        AppStateScope.read(context).toggleFavorite(card.id),
                    icon: const Icon(Icons.star),
                  ),
                  title: Text(card.front),
                  subtitle: Text(card.back),
                ),
              ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
