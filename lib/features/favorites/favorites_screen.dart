import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
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

    final groups = <Widget>[
      if (materialFavorites.isNotEmpty)
        _FavoriteGroup(
          title: 'Materials',
          children: [
            for (final material in materialFavorites)
              AppListRow(
                leading: IconButton(
                  tooltip: 'Unfavorite material',
                  onPressed: state.isUpdatingMaterialFavorite
                      ? null
                      : () => _toggleMaterialFavorite(context, material.id),
                  icon: const Icon(Icons.star),
                ),
                title: Text(material.title),
                subtitle: Text(
                  '${state.subjectFor(material.subjectId).name} · ${material.createdLabel} · ${material.kind.name}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.materialDetail,
                  arguments: material,
                ),
                showDivider: material != materialFavorites.last,
              ),
          ],
        ),
      if (flashcardFavorites.isNotEmpty)
        _FavoriteGroup(
          title: 'Flashcards',
          children: [
            for (final card in flashcardFavorites)
              AppListRow(
                leading: IconButton(
                  tooltip: 'Unfavorite',
                  onPressed: () =>
                      AppStateScope.read(context).toggleFavorite(card.id),
                  icon: const Icon(Icons.star),
                ),
                title: Text(card.front),
                subtitle: Text(card.back),
                showDivider: card != flashcardFavorites.last,
              ),
          ],
        ),
    ];
    return ResponsiveAppScaffold(
      title: 'Favorites',
      subtitle: 'Study only favorites',
      activeRoute: AppRoutes.favorites,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: ListView(
          key: const ValueKey('favorites-scroll-view'),
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
              EmptyState(
                icon: Icons.star_border,
                title: 'No favorites yet',
                message: isSupabaseMode
                    ? 'Star materials to collect them here.'
                    : 'Star materials or flashcards to collect them here.',
              ),
            if (groups.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns =
                      groups.length == 2 &&
                      constraints.maxWidth >= 980 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.6;
                  return twoColumns
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: groups[0]),
                            const SizedBox(width: 20),
                            Expanded(child: groups[1]),
                          ],
                        )
                      : Column(
                          children: [
                            for (final group in groups)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: group,
                              ),
                          ],
                        );
                },
              ),
          ],
        ),
      ),
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

class _FavoriteGroup extends StatelessWidget {
  const _FavoriteGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassCard(
    key: ValueKey('favorites-${title.toLowerCase()}-group'),
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children,
      ],
    ),
  );
}
