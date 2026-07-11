import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../flashcards/flashcards_screen.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final results = state.search(query);

    final grouped = {
      for (final kind in LocalSearchResultKind.values)
        kind: results.where((result) => result.kind == kind).toList(),
    };
    return ResponsiveAppScaffold(
      title: 'Search',
      activeRoute: AppRoutes.search,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: ListView(
          key: const ValueKey('search-scroll-view'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => setState(() => query = value),
              decoration: InputDecoration(
                labelText: 'Search study workspace',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('clear-search-query'),
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 16),
            if (query.trim().isEmpty)
              const EmptyState(
                icon: Icons.search,
                title: 'Start typing to search',
                message:
                    'Find subjects, materials, and flashcards in this workspace.',
              )
            else if (results.isEmpty)
              const EmptyState(
                icon: Icons.search_off_outlined,
                title: 'No results',
                message: 'Try another search term.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final groups = [
                    for (final kind in LocalSearchResultKind.values)
                      if (grouped[kind]!.isNotEmpty)
                        _SearchGroup(
                          kind: kind,
                          results: grouped[kind]!,
                          open: (result) => _openResult(context, result),
                          iconFor: _iconFor,
                        ),
                  ];
                  final columns =
                      constraints.maxWidth >= 1000 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.6;
                  return columns
                      ? Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final group in groups)
                              SizedBox(
                                width: (constraints.maxWidth - 16) / 2,
                                child: group,
                              ),
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

  IconData _iconFor(LocalSearchResultKind kind) {
    return switch (kind) {
      LocalSearchResultKind.subject => Icons.folder_outlined,
      LocalSearchResultKind.material => Icons.article_outlined,
      LocalSearchResultKind.flashcard => Icons.style_outlined,
    };
  }

  void _openResult(BuildContext context, LocalSearchResult result) {
    switch (result.kind) {
      case LocalSearchResultKind.subject:
        Navigator.pushNamed(
          context,
          AppRoutes.subjectDetail,
          arguments: result.subject,
        );
      case LocalSearchResultKind.material:
        Navigator.pushNamed(
          context,
          AppRoutes.materialDetail,
          arguments: result.material,
        );
      case LocalSearchResultKind.flashcard:
        Navigator.pushNamed(
          context,
          AppRoutes.flashcards,
          arguments: FlashcardsRouteArgs(subject: result.subject),
        );
    }
  }
}

class _SearchGroup extends StatelessWidget {
  const _SearchGroup({
    required this.kind,
    required this.results,
    required this.open,
    required this.iconFor,
  });
  final LocalSearchResultKind kind;
  final List<LocalSearchResult> results;
  final ValueChanged<LocalSearchResult> open;
  final IconData Function(LocalSearchResultKind) iconFor;
  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      LocalSearchResultKind.subject => 'Subjects',
      LocalSearchResultKind.material => 'Materials',
      LocalSearchResultKind.flashcard => 'Flashcards',
    };
    return GlassCard(
      padding: EdgeInsets.zero,
      key: ValueKey('search-${title.toLowerCase()}-group'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$title (${results.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final result in results)
            AppListRow(
              leading: Icon(iconFor(kind)),
              title: Text(result.title),
              subtitle: Text(result.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(result),
              showDivider: result != results.last,
            ),
        ],
      ),
    );
  }
}
