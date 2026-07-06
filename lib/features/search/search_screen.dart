import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: const [AppTopActions(showHome: true, showFavorites: true)],
      ),
      body: AppPage(
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Search study workspace',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.manage_search_outlined,
            title: 'Results',
            subtitle: 'Subjects, materials, and flashcards from local state.',
            child: Column(
              children: [
                if (query.trim().isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.search),
                    title: Text('Start typing to search'),
                  )
                else if (results.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.search_off_outlined),
                    title: Text('No local results'),
                  )
                else
                  for (final result in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_iconFor(result.kind)),
                      title: Text(result.title),
                      subtitle: Text(result.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openResult(context, result),
                    ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
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
          arguments: result.subject,
        );
    }
  }
}
