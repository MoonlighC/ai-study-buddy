import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
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
    final l10n = context.l10n;
    final results = state.search(query);

    final grouped = {
      for (final kind in LocalSearchResultKind.values)
        kind: results.where((result) => result.kind == kind).toList(),
    };
    return ResponsiveAppScaffold(
      title: l10n.searchTitle,
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
                labelText: l10n.searchFieldLabel,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('clear-search-query'),
                        tooltip: l10n.searchClear,
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
              EmptyState(
                icon: Icons.search,
                title: l10n.searchStartTitle,
                message: l10n.searchStartMessage,
              )
            else if (results.isEmpty)
              EmptyState(
                icon: Icons.search_off_outlined,
                title: l10n.searchNoResultsTitle,
                message: l10n.searchNoResultsMessage,
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
    final l10n = context.l10n;
    final title = switch (kind) {
      LocalSearchResultKind.subject => l10n.searchSubjectsGroup(results.length),
      LocalSearchResultKind.material => l10n.searchMaterialsGroup(
        results.length,
      ),
      LocalSearchResultKind.flashcard => l10n.searchFlashcardsGroup(
        results.length,
      ),
    };
    return GlassCard(
      padding: EdgeInsets.zero,
      key: ValueKey('search-${title.toLowerCase()}-group'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final result in results)
            AppListRow(
              leading: Icon(iconFor(kind)),
              title: Text(result.title),
              subtitle: Text(_localizedSubtitle(context, result)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(result),
              showDivider: result != results.last,
            ),
        ],
      ),
    );
  }

  String _localizedSubtitle(BuildContext context, LocalSearchResult result) {
    if (result.kind == LocalSearchResultKind.material &&
        result.material != null) {
      return context.l10n.searchMaterialSubtitle(
        result.subject.name,
        LocalizedFormatters.materialDate(context.l10n, result.material!),
      );
    }
    if (result.kind == LocalSearchResultKind.flashcard) {
      final separator = result.subtitle.lastIndexOf(' - ');
      final topic = separator < 0
          ? context.l10n.relativeRecent
          : result.subtitle.substring(separator + 3);
      return context.l10n.searchFlashcardSubtitle(result.subject.name, topic);
    }
    return result.subtitle;
  }
}
