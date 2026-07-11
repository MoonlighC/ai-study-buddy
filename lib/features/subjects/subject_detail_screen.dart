import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/theme_extensions.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../core/models/weak_topic.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';
import '../materials/material_upload.dart';
import '../materials/upload_material_screen.dart';

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
    final focusTopics = state
        .cumulativeWeakTopicsFor(subject.id)
        .take(3)
        .toList();
    final subjectColor = safeSubjectColor(subject.colorValue);

    return ResponsiveAppScaffold(
      title: subject.name,
      subtitle: 'Subject workspace',
      showBack: true,
      activeRoute: null,
      subjectColor: subjectColor,
      body: SingleChildScrollView(
        key: const ValueKey('subject-detail-scroll-view'),
        child: ResponsiveContent(
          width: ResponsiveContentWidth.wide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubjectHero(
                subject: subject,
                materialCount: materials.length,
                color: subjectColor,
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 820;
                  final main = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionTitle(
                        title: 'Materials',
                        subtitle:
                            '${materials.length} ${materials.length == 1 ? 'item' : 'items'} in this subject',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassSurface(
                        key: const ValueKey('subject-materials-surface'),
                        child: _MaterialsList(
                          materials: materials,
                          state: state,
                          onToggleFavorite: (materialId) =>
                              _toggleMaterialFavorite(context, materialId),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle(
                        title: 'Summaries',
                        subtitle: 'Generated explanations from your materials',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassSurface(
                        key: const ValueKey('subject-summaries-surface'),
                        child: _SummariesList(materials: summaryMaterials),
                      ),
                    ],
                  );
                  final side = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StudyActions(subject: subject),
                      const SizedBox(height: AppSpacing.lg),
                      _UploadActions(subject: subject),
                      if (focusTopics.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _FocusTopics(topics: focusTopics),
                      ],
                    ],
                  );

                  if (!twoColumns) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        side,
                        const SizedBox(height: AppSpacing.xl),
                        main,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: main),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(flex: 3, child: side),
                    ],
                  );
                },
              ),
            ],
          ),
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
    if (!context.mounted || saved) return;
    final message =
        AppStateScope.read(context).favoriteSyncErrorMessage ??
        'Could not update favorite.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SubjectHero extends StatelessWidget {
  const _SubjectHero({
    required this.subject,
    required this.materialCount,
    required this.color,
  });

  final Subject subject;
  final int materialCount;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('subject-hero'),
    depth: GlassDepth.prominent,
    tint: color.withValues(alpha: 0.14),
    padding: EdgeInsets.all(
      AppResponsive.prominentSurfacePaddingFor(
        MediaQuery.sizeOf(context).width,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppShadows.soft,
          ),
          alignment: Alignment.center,
          child: Text(
            subject.name.characters.first.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.name,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subject.description.isEmpty
                    ? 'Your focused study space.'
                    : subject.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassStatusChip(
                label:
                    '$materialCount ${materialCount == 1 ? 'material' : 'materials'}',
                icon: Icons.article_outlined,
                color: color,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StudyActions extends StatelessWidget {
  const _StudyActions({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Study actions',
          subtitle: 'Build from notes in this subject',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const ValueKey('subject-add-pasted-text'),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.addMaterial,
            arguments: subject,
          ),
          icon: const Icon(Icons.post_add_outlined),
          label: const Text('Add pasted text'),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          label: 'Create study session',
          icon: Icons.school_outlined,
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.studySessionResult,
            arguments: subject,
          ),
        ),
      ],
    ),
  );
}

class _UploadActions extends StatelessWidget {
  const _UploadActions({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Upload materials',
          subtitle: 'Private PDFs and images',
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey('subject-upload-pdf'),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.uploadMaterial,
            arguments: UploadMaterialArgs(
              subject: subject,
              kind: MaterialKind.pdf,
            ),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Upload PDF'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          key: const ValueKey('subject-upload-image'),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.uploadMaterial,
            arguments: UploadMaterialArgs(
              subject: subject,
              kind: MaterialKind.image,
            ),
          ),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Upload image'),
        ),
      ],
    ),
  );
}

class _FocusTopics extends StatelessWidget {
  const _FocusTopics({required this.topics});

  final List<CumulativeWeakTopic> topics;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Focus topics',
          subtitle: 'Cumulative misses from quizzes',
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final topic in topics)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, size: AppIconSizes.control),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(topic.topic)),
                Text(
                  '${topic.missCount} ${topic.missCount == 1 ? 'miss' : 'misses'}',
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _MaterialsList extends StatelessWidget {
  const _MaterialsList({
    required this.materials,
    required this.state,
    required this.onToggleFavorite,
  });

  final List<StudyMaterial> materials;
  final AppState state;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.isLoadingMaterials)
          const LoadingState(label: 'Loading synced materials'),
        if (state.materialSyncErrorMessage != null)
          ErrorRetryState(
            message: state.materialSyncErrorMessage!,
            supportingText: 'Your subject is still usable.',
            onRetry: state.isLoadingMaterials
                ? null
                : () => state.loadMaterialsFor(AuthScope.read(context).user),
          ),
        if (!state.isLoadingMaterials && materials.isEmpty)
          const EmptyState(
            title: 'No materials yet',
            message: 'Add pasted text or upload a file to begin.',
            icon: Icons.article_outlined,
          )
        else
          for (var index = 0; index < materials.length; index++)
            AppListRow(
              title: Text(materials[index].title),
              subtitle: Text(_materialSubtitle(materials[index])),
              leading: Icon(
                _materialIcon(materials[index]),
                color: Theme.of(context).colorScheme.primary,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: state.isMaterialFavorite(materials[index].id)
                        ? 'Unfavorite material'
                        : 'Favorite material',
                    onPressed: state.isUpdatingMaterialFavorite
                        ? null
                        : () => onToggleFavorite(materials[index].id),
                    icon: Icon(
                      state.isMaterialFavorite(materials[index].id)
                          ? Icons.star
                          : Icons.star_border,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              showDivider: index != materials.length - 1,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.materialDetail,
                arguments: materials[index],
              ),
            ),
      ],
    );
  }
}

class _SummariesList extends StatelessWidget {
  const _SummariesList({required this.materials});

  final List<StudyMaterial> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const EmptyState(
        title: 'No summaries yet',
        message: 'No summaries yet. Generate one from a material.',
        icon: Icons.notes_outlined,
      );
    }
    return Column(
      children: [
        for (var index = 0; index < materials.length; index++)
          AppListRow(
            key: ValueKey('summary-${materials[index].id}'),
            title: Text(materials[index].title),
            subtitle: Text(
              '${materials[index].createdLabel} - ${materials[index].summary!.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: const Icon(Icons.notes_outlined),
            trailing: const Icon(Icons.chevron_right),
            showDivider: index != materials.length - 1,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.materialDetail,
              arguments: materials[index],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

IconData _materialIcon(StudyMaterial material) => switch (material.kind) {
  MaterialKind.pdf => Icons.picture_as_pdf_outlined,
  MaterialKind.image => Icons.image_outlined,
  MaterialKind.pastedText => Icons.article_outlined,
};

String _materialSubtitle(StudyMaterial material) {
  if (material.sourceKind != MaterialSourceKind.upload) {
    return '${material.createdLabel} - pasted text';
  }
  final type = material.kind == MaterialKind.pdf ? 'PDF' : 'Image';
  final size = material.fileSizeBytes == null
      ? 'Unknown size'
      : formatFileSize(material.fileSizeBytes!);
  final status = material.processingStatus == MaterialProcessingStatus.pending
      ? 'Uploaded · Waiting for processing'
      : 'Uploaded';
  return '$type · $size · $status';
}
