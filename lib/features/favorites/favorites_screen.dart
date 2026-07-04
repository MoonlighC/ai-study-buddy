import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = MockData.flashcards
        .where((flashcard) => flashcard.isFavorite)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
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
          for (final card in favorites)
            Card(
              child: ListTile(
                leading: const Icon(Icons.star),
                title: Text(card.front),
                subtitle: Text(card.back),
              ),
            ),
        ],
      ),
    );
  }
}
