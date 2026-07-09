import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../auth/auth_controller.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final materialFavorites = state.favoriteMaterials;
    final flashcardFavorites = state.favoriteFlashcards;
    final hasFavorites =
        materialFavorites.isNotEmpty || flashcardFavorites.isNotEmpty;
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;

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
            isSupabaseMode
                ? 'Favorite materials are grouped here for focused review.'
                : 'Favorite materials and cards are grouped here for focused review.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (state.isLoadingMaterialFavorites)
            const Card(
              child: ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading synced favorites'),
              ),
            ),
          if (state.favoriteSyncErrorMessage != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(state.favoriteSyncErrorMessage!),
                subtitle: const Text('Your app is still usable.'),
                trailing: TextButton(
                  onPressed: state.isLoadingMaterialFavorites
                      ? null
                      : () => state.loadMaterialFavoritesFor(
                          AuthScope.read(context).user,
                        ),
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (!state.isLoadingMaterialFavorites && !hasFavorites)
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('No favorites yet'),
                subtitle: Text(
                  isSupabaseMode
                      ? 'Star materials to collect them here.'
                      : 'Star materials or flashcards to collect them here.',
                ),
              ),
            ),
          for (final material in materialFavorites)
            Card(
              child: ListTile(
                leading: IconButton(
                  tooltip: 'Unfavorite material',
                  onPressed: state.isUpdatingMaterialFavorite
                      ? null
                      : () => _toggleMaterialFavorite(context, material.id),
                  icon: const Icon(Icons.star),
                ),
                title: Text(material.title),
                subtitle: Text(
                  '${state.subjectFor(material.subjectId).name} - ${material.createdLabel} - pasted text',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.materialDetail,
                  arguments: material,
                ),
              ),
            ),
          for (final card in flashcardFavorites)
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

  Future<void> _toggleMaterialFavorite(
    BuildContext context,
    String materialId,
  ) async {
    final saved = await AppStateScope.read(
      context,
    ).toggleMaterialFavoriteFor(AuthScope.read(context).user, materialId);
    if (!context.mounted || saved) {
      return;
    }
    final message =
        AppStateScope.read(context).favoriteSyncErrorMessage ??
        'Could not update favorite.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
