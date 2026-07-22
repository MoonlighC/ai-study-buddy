import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/theme_extensions.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../core/models/study_session.dart';
import '../../core/models/weak_topic.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';
import '../deletion/deletion_models.dart';
import '../materials/upload_material_screen.dart';
import '../study_sessions/study_session_result_screen.dart';
import '../progress/progress_screen.dart';

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
    final eligibleMaterial = _firstEligibleStudyMaterial(state, materials);
    final l10n = context.l10n;

    return ResponsiveAppScaffold(
      title: subject.name,
      subtitle: l10n.subjectWorkspaceSubtitle,
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
                deleting: state.isDeletingSubject(subject.id),
                onDelete: () => _confirmDelete(context, materials.length),
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 820;
                  final main = Column(
                    key: const ValueKey('subject-detail-main-column'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionTitle(
                        title: l10n.subjectMaterials,
                        subtitle: l10n.subjectItemsInSubject(materials.length),
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
                      _SectionTitle(
                        title: l10n.subjectSummaries,
                        subtitle: l10n.subjectSummariesSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassSurface(
                        key: const ValueKey('subject-summaries-surface'),
                        child: _SummariesList(materials: summaryMaterials),
                      ),
                    ],
                  );
                  final side = Column(
                    key: const ValueKey('subject-detail-side-column'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StudyActions(
                        subject: subject,
                        eligibleMaterial: eligibleMaterial,
                        materials: materials,
                      ),
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
                      Expanded(flex: 8, child: main),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(flex: 5, child: side),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int materialCount) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.subjectDeleteTitle(subject.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.subjectDeleteCount(materialCount)),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.subjectDeleteBody),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.subjectDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await AppStateScope.read(
      context,
    ).deleteSubjectFor(AuthScope.read(context).user, subject.id);
    if (!context.mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.subjectDeleted)));
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.subjects,
        (route) => route.isFirst,
      );
      return;
    }
    final code =
        AppStateScope.read(context).subjectDeletionErrorFor(subject.id) ??
        DeletionSafeCode.unknown;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_deletionMessage(l10n, code))));
  }

  String _deletionMessage(dynamic l10n, DeletionSafeCode code) =>
      switch (code) {
        DeletionSafeCode.deletionInProgress => l10n.deletionErrorInProgress,
        DeletionSafeCode.storageCleanupFailed => l10n.deletionErrorStorage,
        DeletionSafeCode.databaseCleanupFailed => l10n.deletionErrorDatabase,
        DeletionSafeCode.authCleanupFailed => l10n.deletionErrorAuth,
        DeletionSafeCode.recentAuthRequired => l10n.deletionErrorRecentAuth,
        DeletionSafeCode.recentAuthVerificationFailed =>
          l10n.deletionErrorRecentAuthVerificationFailed,
        DeletionSafeCode.unauthorized => l10n.deletionErrorUnauthorized,
        DeletionSafeCode.retryLater => l10n.deletionErrorRetry,
        DeletionSafeCode.unknown => l10n.deletionErrorUnknown,
      };
}

class _SubjectHero extends StatelessWidget {
  const _SubjectHero({
    required this.subject,
    required this.materialCount,
    required this.color,
    required this.deleting,
    required this.onDelete,
  });

  final Subject subject;
  final int materialCount;
  final Color color;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('subject-hero'),
    depth: GlassDepth.prominent,
    tint: color.withValues(alpha: 0.14),
    padding: EdgeInsets.all(
      AppResponsive.isPhone(context) ? AppSpacing.lg : AppSpacing.xl,
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
                    ? context.l10n.subjectsDefaultDescription
                    : subject.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassStatusChip(
                label: context.l10n.materialsCount(materialCount),
                icon: Icons.article_outlined,
                color: color,
              ),
            ],
          ),
        ),
        Semantics(
          liveRegion: true,
          label: deleting
              ? context.l10n.subjectDeleting
              : context.l10n.subjectDeleteAction,
          child: IconButton(
            key: const ValueKey('subject-delete-action'),
            tooltip: context.l10n.subjectDeleteAction,
            onPressed: deleting ? null : onDelete,
            icon: deleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ),
      ],
    ),
  );
}

class _StudyActions extends StatelessWidget {
  const _StudyActions({
    required this.subject,
    required this.eligibleMaterial,
    required this.materials,
  });

  final Subject subject;
  final StudyMaterial? eligibleMaterial;
  final List<StudyMaterial> materials;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: context.l10n.subjectStudyActions,
          subtitle: context.l10n.subjectStudyActionsSubtitle,
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
          label: Text(context.l10n.subjectAddPastedText),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          keyValue: const ValueKey('subject-open-flashcards'),
          label: context.l10n.materialFlashcardsTitle,
          icon: Icons.style_outlined,
          onPressed: materials.isEmpty
              ? null
              : () => _chooseFlashcardMaterial(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          keyValue: const ValueKey('subject-open-quiz'),
          label: context.l10n.materialQuizTitle,
          icon: Icons.quiz_outlined,
          onPressed: materials.isEmpty
              ? null
              : () => _chooseFlashcardMaterial(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          keyValue: const ValueKey('subject-open-progress'),
          label: context.l10n.progressOpenAction,
          icon: Icons.insights_outlined,
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.progress,
            arguments: ProgressRouteArgs(subjectId: subject.id),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassButton(
          keyValue: const ValueKey('subject-create-study-session'),
          label: context.l10n.subjectCreateStudySession,
          icon: Icons.school_outlined,
          onPressed: eligibleMaterial == null
              ? null
              : () async {
                  final material = await _chooseMaterial(
                    context,
                    materials
                        .where(
                          (item) => AppStateScope.read(
                            context,
                          ).canGenerateSummaryForMaterial(item),
                        )
                        .toList(),
                  );
                  if (material == null || !context.mounted) return;
                  final session = AppStateScope.read(context)
                      .createStudySession(
                        subject: subject,
                        confidence: LectureConfidence.mostly,
                        materialId: material.id,
                      );
                  if (session == null) return;
                  Navigator.pushNamed(
                    context,
                    AppRoutes.studySessionResult,
                    arguments: StudySessionResultArgs(
                      subject: subject,
                      sessionId: session.id,
                      materialId: material.id,
                    ),
                  );
                },
        ),
        if (eligibleMaterial == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(context.l10n.subjectAddMaterialForSession),
        ],
      ],
    ),
  );

  Future<void> _chooseFlashcardMaterial(BuildContext context) async {
    final selected = await _chooseMaterial(context, materials);
    if (selected != null && context.mounted) {
      await Navigator.pushNamed(
        context,
        AppRoutes.materialDetail,
        arguments: selected,
      );
    }
  }

  Future<StudyMaterial?> _chooseMaterial(
    BuildContext context,
    List<StudyMaterial> choices,
  ) async {
    if (choices.length == 1) return choices.single;
    return showDialog<StudyMaterial>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.studyChooseMaterial),
        children: [
          for (final material in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, material),
              child: Text(material.title),
            ),
        ],
      ),
    );
  }
}

class _UploadActions extends StatelessWidget {
  const _UploadActions({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: context.l10n.subjectUploadMaterials,
          subtitle: context.l10n.subjectUploadMaterialsSubtitle,
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
          label: Text(context.l10n.subjectUploadPdf),
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
          label: Text(context.l10n.subjectUploadImage),
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
        _SectionTitle(
          title: context.l10n.homeFocusTopics,
          subtitle: context.l10n.subjectFocusTopicsSubtitle,
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
                Text(context.l10n.missesCount(topic.missCount)),
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
          LoadingState(label: context.l10n.subjectLoadingMaterials),
        if (state.materialSyncErrorMessage != null)
          ErrorRetryState(
            message: context.localizedSafeMessage(
              state.materialSyncErrorMessage!,
            ),
            supportingText: context.l10n.subjectStillUsable,
            onRetry: state.isLoadingMaterials
                ? null
                : () => state.loadMaterialsFor(AuthScope.read(context).user),
          ),
        if (!state.isLoadingMaterials && materials.isEmpty)
          EmptyState(
            title: context.l10n.subjectNoMaterialsTitle,
            message: context.l10n.subjectNoMaterialsMessage,
            icon: Icons.article_outlined,
          )
        else
          for (var index = 0; index < materials.length; index++)
            AppListRow(
              title: Text(materials[index].title),
              subtitle: Text(_materialSubtitle(context, materials[index])),
              leading: Icon(
                _materialIcon(materials[index]),
                color: Theme.of(context).colorScheme.primary,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: state.isMaterialFavorite(materials[index].id)
                        ? context.l10n.subjectUnfavoriteMaterialTooltip
                        : context.l10n.subjectFavoriteMaterialTooltip,
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
      return EmptyState(
        title: context.l10n.subjectNoSummariesTitle,
        message: context.l10n.subjectNoSummariesMessage,
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
              '${LocalizedFormatters.materialDate(context.l10n, materials[index])} — ${materials[index].summary!.trim()}',
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

String _materialSubtitle(BuildContext context, StudyMaterial material) {
  final l10n = context.l10n;
  if (material.sourceKind != MaterialSourceKind.upload) {
    return l10n.materialPastedDate(
      LocalizedFormatters.materialDate(l10n, material),
      l10n.materialPastedTextKind,
    );
  }
  final type = material.kind == MaterialKind.pdf
      ? l10n.uploadPdfKind
      : l10n.uploadImageKind;
  final size = material.fileSizeBytes == null
      ? l10n.materialUnknownSize
      : LocalizedFormatters.fileSize(l10n, material.fileSizeBytes!);
  final status = material.processingStatus == MaterialProcessingStatus.pending
      ? '${l10n.materialUploadedStatus} · ${l10n.materialWaitingForProcessing}'
      : l10n.materialUploadedStatus;
  return '$type · $size · $status';
}

StudyMaterial? _firstEligibleStudyMaterial(
  AppState state,
  List<StudyMaterial> materials,
) {
  for (final material in materials) {
    if (state.canGenerateSummaryForMaterial(material)) return material;
  }
  return null;
}
