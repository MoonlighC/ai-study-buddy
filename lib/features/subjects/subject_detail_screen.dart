import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';
import '../auth/auth_controller.dart';

class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final materials = state.materialsFor(subject.id);
    final summaryMaterials = materials
        .where((material) => material.summary?.trim().isNotEmpty ?? false)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
          _SubjectHeader(subject: subject),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Study actions',
            subtitle: 'Use pasted text for this subject.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.addMaterial,
                    arguments: subject,
                  ),
                  icon: const Icon(Icons.post_add_outlined),
                  label: const Text('Add pasted text'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.studySessionResult,
                    arguments: subject,
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Create study session'),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.article_outlined,
            title: 'Materials',
            child: Column(
              children: [
                if (state.isLoadingMaterials)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading synced materials'),
                  ),
                if (state.materialSyncErrorMessage != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(state.materialSyncErrorMessage!),
                    subtitle: const Text('Your subject is still usable.'),
                    trailing: TextButton(
                      onPressed: state.isLoadingMaterials
                          ? null
                          : () => state.loadMaterialsFor(
                              AuthScope.read(context).user,
                            ),
                      child: const Text('Retry'),
                    ),
                  ),
                if (!state.isLoadingMaterials && materials.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.article_outlined),
                    title: Text('No materials yet'),
                    subtitle: Text('Add pasted text to start from notes.'),
                  )
                else
                  for (final material in materials)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.article_outlined),
                      title: Text(material.title),
                      subtitle: Text('${material.createdLabel} - pasted text'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: state.isMaterialFavorite(material.id)
                                ? 'Unfavorite material'
                                : 'Favorite material',
                            onPressed: state.isUpdatingMaterialFavorite
                                ? null
                                : () => _toggleMaterialFavorite(
                                    context,
                                    material.id,
                                  ),
                            icon: Icon(
                              state.isMaterialFavorite(material.id)
                                  ? Icons.star
                                  : Icons.star_border,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.materialDetail,
                        arguments: material,
                      ),
                    ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Summaries',
            child: _SummariesList(materials: summaryMaterials),
          ),
          SectionCard(
            icon: Icons.hourglass_empty_outlined,
            title: 'Coming later',
            subtitle: 'Visible placeholders only; no upload is performed.',
            child: const Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_outlined),
                  title: Text('Photo upload placeholder'),
                  subtitle: Text('Later: storage plus OCR pipeline'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('PDF upload placeholder'),
                  subtitle: Text('Later: storage plus extraction'),
                ),
              ],
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

class _SummariesList extends StatelessWidget {
  const _SummariesList({required this.materials});

  final List<StudyMaterial> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.auto_awesome_outlined),
        title: Text('No summaries yet. Generate one from a material.'),
      );
    }

    return Column(
      children: [
        for (final material in materials)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(material.title),
            subtitle: Text(
              '${material.createdLabel} - ${material.summary!.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.materialDetail,
              arguments: material,
            ),
          ),
      ],
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(subject.colorValue).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Color(subject.colorValue),
              child: Text(
                subject.name.characters.first,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(subject.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
