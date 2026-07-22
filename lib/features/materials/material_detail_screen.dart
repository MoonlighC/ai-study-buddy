import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_config.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/quiz.dart';
import '../../core/models/subject.dart';
import '../../core/models/study_session.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/section_card.dart';
import '../auth/auth_controller.dart';
import '../flashcards/flashcard_training_screen.dart';
import '../flashcards/flashcard_generation_dialog.dart';
import '../flashcards/flashcards_screen.dart';
import '../quizzes/quiz_repository.dart';
import '../quizzes/quiz_taking_screen.dart';
import '../study_sessions/study_session_result_screen.dart';
import 'material_presentation.dart';
import 'summary_document_view.dart';
import 'structured_summary_view.dart';
import 'material_analysis_repository.dart';
import 'material_viewer_screen.dart';
import 'original_material_repository.dart';

class MaterialDetailScreen extends StatefulWidget {
  const MaterialDetailScreen({required this.material, super.key});

  final StudyMaterial material;

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  bool _deletionNavigationCommitted = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final freshMaterial =
        state.materialById(widget.material.id) ?? widget.material;
    final subject = state.subjectFor(freshMaterial.subjectId);
    final isFavorite = state.isMaterialFavorite(freshMaterial.id);
    final deleting = state.isDeletingMaterial(freshMaterial.id);
    final isUpload = freshMaterial.sourceKind == MaterialSourceKind.upload;
    final isReadyUpload =
        isUpload &&
        freshMaterial.processingStatus == MaterialProcessingStatus.ready &&
        freshMaterial.hasContentText;
    final usesPersistentAnalysis =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final analysisStatus = usesPersistentAnalysis
        ? state.analysisStatusFor(freshMaterial.id)
        : null;
    final showPersistentFlashcards =
        isUpload &&
        usesPersistentAnalysis &&
        state.canGenerateFlashcardsForMaterial(freshMaterial);
    final l10n = context.l10n;
    final viewerUser = AuthScope.read(context).user;
    final canViewOriginal =
        viewerUser != null &&
        hasValidOriginalMetadata(freshMaterial, viewerUser.id) &&
        !deleting;

    return ResponsiveAppScaffold(
      title: l10n.materialDetailTitle,
      subtitle: subject.name,
      showBack: true,
      subjectColor: Color(subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: ListView(
          key: const ValueKey('material-detail-scroll-view'),
          children: [
            MaterialHero(
              title: freshMaterial.title,
              subject: subject.name,
              typeLabel: _materialTypeLabel(context, freshMaterial),
              statusLabel: _materialStatus(
                context,
                freshMaterial,
                analysisStatus: analysisStatus,
              ),
              isFavorite: isFavorite,
              onFavorite: deleting || state.isUpdatingMaterialFavorite
                  ? null
                  : () => _toggleMaterialFavorite(context, freshMaterial.id),
              onDelete: deleting
                  ? null
                  : () => _confirmDelete(context, freshMaterial),
            ),
            if (canViewOriginal) ...[
              const SizedBox(height: 12),
              GlassButton(
                key: const ValueKey('view-original-material'),
                label: l10n.materialViewOriginal,
                icon: Icons.visibility_outlined,
                onPressed: () => _openOriginalMaterial(context, freshMaterial),
              ),
            ],
            const SizedBox(height: 16),
            if (isUpload && usesPersistentAnalysis && !deleting) ...[
              _MaterialAnalysisSection(material: freshMaterial),
              const SizedBox(height: 16),
            ],
            if (deleting)
              MaterialStatusPanel(
                key: Key('material-delete-progress'),
                title: l10n.materialDeletingTitle,
                message: l10n.materialDeletingMessage,
                icon: Icons.delete_outline,
                progress: true,
              )
            else if ((!isUpload || !usesPersistentAnalysis) &&
                freshMaterial.processingStatus ==
                    MaterialProcessingStatus.processing)
              _StaleRecoverySection(
                materialId: freshMaterial.id,
                processingMessage: freshMaterial.kind == MaterialKind.pdf
                    ? l10n.pdfExtractingSelectable
                    : l10n.imageReadingText,
              )
            else if (state.isGeneratingSummary ||
                state.isGeneratingFlashcards ||
                state.isGeneratingQuiz)
              MaterialStatusPanel(
                title: l10n.materialGeneratingStudyContentTitle,
                message: l10n.materialGeneratingStudyContentMessage,
                icon: Icons.auto_awesome_outlined,
                progress: true,
              )
            else if (freshMaterial.scannedPdfOcr?.partial == true)
              MaterialStatusPanel(
                title: l10n.materialPartialResultTitle,
                message: l10n.materialPartialScannedMessage,
                icon: Icons.warning_amber_rounded,
                warning: true,
              )
            else if (_imageOcrWarning(freshMaterial.imageOcr?.warningCodes)
                case final warning?)
              MaterialStatusPanel(
                title: l10n.materialPartialResultTitle,
                message: context.localizedSafeMessage(warning),
                icon: Icons.warning_amber_rounded,
                warning: true,
              )
            else if (isUpload &&
                !usesPersistentAnalysis &&
                freshMaterial.kind == MaterialKind.pdf)
              _PdfExtractionSection(material: freshMaterial)
            else if (isUpload &&
                !usesPersistentAnalysis &&
                freshMaterial.kind == MaterialKind.image)
              _ImageExtractionSection(material: freshMaterial),
            if (isUpload) ...[
              const SizedBox(height: 16),
              MaterialMetadata(
                title: l10n.materialFileMetadataTitle,
                rows: [
                  (l10n.materialFilenameLabel, freshMaterial.title),
                  (
                    l10n.materialTypeLabel,
                    _materialTypeLabel(context, freshMaterial),
                  ),
                  (
                    l10n.materialSizeLabel,
                    freshMaterial.fileSizeBytes == null
                        ? l10n.commonUnknown
                        : LocalizedFormatters.fileSize(
                            l10n,
                            freshMaterial.fileSizeBytes!,
                          ),
                  ),
                  (
                    l10n.materialMimeLabel,
                    freshMaterial.mimeType ?? l10n.commonUnknown,
                  ),
                  (
                    l10n.materialStatusLabel,
                    _materialStatus(
                      context,
                      freshMaterial,
                      analysisStatus: analysisStatus,
                    ),
                  ),
                ],
              ),
            ],
            if (!isUpload || (!usesPersistentAnalysis && isReadyUpload)) ...[
              const SizedBox(height: 16),
              AiOutputSection(
                key: const Key('summary-section'),
                title: l10n.materialSummaryTitle,
                icon: Icons.auto_awesome_outlined,
                reading: true,
                child: _SummarySection(material: freshMaterial),
              ),
              const SizedBox(height: 16),
              AiOutputSection(
                key: const Key('flashcards-section'),
                title: l10n.materialFlashcardsTitle,
                icon: Icons.style_outlined,
                child: _FlashcardsSection(material: freshMaterial),
              ),
              const SizedBox(height: 16),
              AiOutputSection(
                key: const Key('quiz-section'),
                title: l10n.materialQuizTitle,
                icon: Icons.quiz_outlined,
                child: _QuizSection(material: freshMaterial),
              ),
              const SizedBox(height: 16),
              MaterialActionSection(
                title: l10n.materialStudySessionTitle,
                child: GlassButton(
                  label: l10n.subjectCreateStudySession,
                  icon: Icons.auto_awesome_outlined,
                  prominent: true,
                  onPressed: deleting
                      ? null
                      : () {
                          final session = AppStateScope.read(context)
                              .createStudySession(
                                subject: subject,
                                confidence: LectureConfidence.mostly,
                                materialId: freshMaterial.id,
                              );
                          if (session == null) return;
                          Navigator.pushNamed(
                            context,
                            AppRoutes.studySessionResult,
                            arguments: StudySessionResultArgs(
                              subject: subject,
                              sessionId: session.id,
                              materialId: freshMaterial.id,
                            ),
                          );
                        },
                ),
              ),
            ],
            if (showPersistentFlashcards) ...[
              const SizedBox(height: 16),
              AiOutputSection(
                key: const Key('flashcards-section'),
                title: l10n.materialFlashcardsTitle,
                icon: Icons.style_outlined,
                child: _FlashcardsSection(material: freshMaterial),
              ),
              const SizedBox(height: 16),
              AiOutputSection(
                key: const Key('quiz-section'),
                title: l10n.materialQuizTitle,
                icon: Icons.quiz_outlined,
                child: _QuizSection(material: freshMaterial),
              ),
            ],
            if (!isUpload) ...[
              const SizedBox(height: 16),
              AiOutputSection(
                title: l10n.materialPastedTextKind,
                icon: Icons.article_outlined,
                reading: true,
                child: Text(freshMaterial.content),
              ),
            ],
            const SizedBox(height: 16),
            MaterialMetadata(
              rows: [
                (
                  l10n.materialCreatedLabel,
                  LocalizedFormatters.materialDate(l10n, freshMaterial),
                ),
                (
                  l10n.materialStatusLabel,
                  _materialStatus(
                    context,
                    freshMaterial,
                    analysisStatus: analysisStatus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DestructiveActionSection(
              deleting: deleting,
              onDelete: deleting
                  ? null
                  : () => _confirmDelete(context, freshMaterial),
            ),
          ],
        ),
      ),
    );
    /* legacy presentation retained temporarily for callback reference
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Unfavorite material' : 'Favorite material',
            onPressed: deleting || state.isUpdatingMaterialFavorite
                ? null
                : () => _toggleMaterialFavorite(context, freshMaterial.id),
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          ),
          PopupMenuButton<String>(
            enabled: !deleting,
            onSelected: (_) => _confirmDelete(context, freshMaterial),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete material')),
            ],
          ),
          const AppTopActions(),
        ],
      ),
      body: AbsorbPointer(
        absorbing: deleting,
        child: AppPage(
          children: [
            if (deleting)
              const LinearProgressIndicator(
                key: Key('material-delete-progress'),
              ),
            Text(
              freshMaterial.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              isUpload
                  ? '${freshMaterial.kind == MaterialKind.pdf ? 'PDF' : 'Image'} · ${freshMaterial.createdLabel}'
                  : '${freshMaterial.createdLabel} - pasted text',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (isUpload) ...[
              SectionCard(
                icon: freshMaterial.kind == MaterialKind.pdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                title: 'File metadata',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filename: ${freshMaterial.title}'),
                    Text(
                      'Type: ${freshMaterial.kind == MaterialKind.pdf ? 'PDF' : 'Image'}',
                    ),
                    Text(
                      context.l10n.formattedMaterialSize(
                        freshMaterial.fileSizeBytes == null
                            ? context.l10n.materialUnknownSize
                            : LocalizedFormatters.fileSize(
                                context.l10n,
                                freshMaterial.fileSizeBytes!,
                              ),
                      ),
                    ),
                    Text('MIME: ${freshMaterial.mimeType ?? 'Unknown'}'),
                    Text('Status: ${_materialStatus(freshMaterial)}'),
                    if (freshMaterial.kind == MaterialKind.image &&
                        freshMaterial.processingStatus ==
                            MaterialProcessingStatus.ready &&
                        _imageOcrWarning(
                              freshMaterial.imageOcr?.warningCodes,
                            ) !=
                            null)
                      Text(
                        _imageOcrWarning(freshMaterial.imageOcr?.warningCodes)!,
                      ),
                  ],
                ),
              ),
              if (freshMaterial.kind == MaterialKind.pdf)
                _PdfExtractionSection(material: freshMaterial),
              if (freshMaterial.kind == MaterialKind.image)
                _ImageExtractionSection(material: freshMaterial),
              if (freshMaterial.processingStatus ==
                  MaterialProcessingStatus.processing)
                _StaleRecoverySection(materialId: freshMaterial.id),
            ],
            if (!isUpload)
              SectionCard(
                icon: Icons.article_outlined,
                title: 'Pasted text',
                child: Text(freshMaterial.content),
              ),
            if (!isUpload || isReadyUpload) ...[
              SectionCard(
                key: const Key('summary-section'),
                icon: Icons.auto_awesome_outlined,
                title: 'Summary',
                child: _SummarySection(material: freshMaterial),
              ),
              SectionCard(
                key: const Key('flashcards-section'),
                icon: Icons.style_outlined,
                title: 'Flashcards',
                child: _FlashcardsSection(material: freshMaterial),
              ),
              SectionCard(
                key: const Key('quiz-section'),
                icon: Icons.quiz_outlined,
                title: 'Quiz',
                child: _QuizSection(material: freshMaterial),
              ),
              FilledButton.icon(
                onPressed: () {
                  final session = AppStateScope.read(context).createStudySession(
                    subject: subject,
                    confidence: LectureConfidence.mostly,
                    materialId: freshMaterial.id,
                  );
                  if (session == null) return;
                  Navigator.pushNamed(
                    context,
                    AppRoutes.studySessionResult,
                    arguments: StudySessionResultArgs(
                      subject: subject,
                      sessionId: session.id,
                      materialId: freshMaterial.id,
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Create study session'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    ); */
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StudyMaterial material,
  ) async {
    if (_deletionNavigationCommitted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.materialDeleteDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.materialDeleteRemoved),
              const SizedBox(height: 6),
              _DeleteConfirmationItem(
                context.l10n.materialDeleteSourceMaterial,
              ),
              _DeleteConfirmationItem(context.l10n.materialDeleteUploadedFile),
              _DeleteConfirmationItem(context.l10n.materialDeleteSummary),
              _DeleteConfirmationItem(context.l10n.materialDeleteFlashcards),
              _DeleteConfirmationItem(context.l10n.materialDeleteQuizzes),
              const SizedBox(height: 16),
              Text(context.l10n.materialDeletePreserved),
              const SizedBox(height: 6),
              _DeleteConfirmationItem(context.l10n.materialDeleteQuizResults),
              _DeleteConfirmationItem(
                context.l10n.materialDeleteProgressHistory,
              ),
              _DeleteConfirmationItem(context.l10n.materialDeleteWeakTopics),
              _DeleteConfirmationItem(context.l10n.materialDeleteStudyHistory),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.materialDeleteMaterial),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final state = AppStateScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = context.l10n.materialDeleted;
    final user = AuthScope.read(context).user;
    final deleted = await state.deleteMaterialFor(user, material.id);
    if (!mounted || !context.mounted) return;
    if (deleted) {
      if (_deletionNavigationCommitted || !navigator.mounted) return;
      _deletionNavigationCommitted = true;
      final subject = state.subjects.cast<Subject?>().firstWhere(
        (item) => item?.id == material.subjectId,
        orElse: () => null,
      );
      if (subject != null) {
        navigator.pushReplacementNamed(
          AppRoutes.subjectDetail,
          arguments: subject,
        );
      } else if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacementNamed(AppRoutes.subjects);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!messenger.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedSafeMessage(
              state.materialLifecycleErrorFor(material.id) ??
                  'Could not delete the material. Try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openOriginalMaterial(
    BuildContext context,
    StudyMaterial material,
  ) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.materialViewer,
      arguments: MaterialViewerArgs(
        materialId: material.id,
        kind: material.kind,
      ),
    );
    if (mounted) setState(() {});
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }

  String _materialStatus(
    BuildContext context,
    StudyMaterial material, {
    MaterialAnalysisStatus? analysisStatus,
  }) {
    final l10n = context.l10n;
    if (analysisStatus?.state == AnalysisState.completed) {
      return l10n.analysisCompleted;
    }
    if (analysisStatus?.state == AnalysisState.completedWithWarnings) {
      return l10n.analysisCompletedWithWarnings;
    }
    if (analysisStatus?.state == AnalysisState.failed) {
      return l10n.materialFailedStatus;
    }
    if (material.kind == MaterialKind.pdf &&
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText) {
      if (material.scannedPdfOcr?.extractedAt != null) {
        final ocr = material.scannedPdfOcr!;
        final total = ocr.totalPages;
        return total == null
            ? l10n.materialTextExtractedWithOcr
            : '${l10n.materialTextExtractedWithOcr} · ${l10n.materialPagesProgress(ocr.processedPages.length, total)}${ocr.partial ? ' · ${l10n.materialPartialResultTitle}' : ''}';
      }
      final pageCount = material.pdfExtraction?.pageCount;
      return pageCount == null
          ? l10n.materialTextExtracted
          : '${l10n.materialTextExtracted} · ${l10n.materialPagesCount(pageCount)}';
    }
    if (material.kind == MaterialKind.image &&
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText) {
      return l10n.materialTextExtracted;
    }
    return switch (material.processingStatus) {
      MaterialProcessingStatus.pending =>
        '${l10n.materialUploadedStatus} · ${l10n.materialWaitingForProcessing}',
      MaterialProcessingStatus.processing => l10n.materialProcessingStatus,
      MaterialProcessingStatus.ready => l10n.materialTextExtracted,
      MaterialProcessingStatus.failed => l10n.materialFailedStatus,
    };
  }
}

String _materialTypeLabel(BuildContext context, StudyMaterial material) {
  final l10n = context.l10n;
  return switch (material.kind) {
    MaterialKind.pdf => l10n.uploadPdfKind,
    MaterialKind.image => l10n.uploadImageKind,
    MaterialKind.pastedText => l10n.materialPastedTextKind,
  };
}

class _DeleteConfirmationItem extends StatelessWidget {
  const _DeleteConfirmationItem(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _StaleRecoverySection extends StatefulWidget {
  const _StaleRecoverySection({
    required this.materialId,
    required this.processingMessage,
  });
  final String materialId;
  final String processingMessage;
  @override
  State<_StaleRecoverySection> createState() => _StaleRecoverySectionState();
}

class _StaleRecoverySectionState extends State<_StaleRecoverySection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppStateScope.read(context).inspectMaterialRecoveryFor(
          AuthScope.read(context).user,
          widget.materialId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    if (!state.isMaterialRecoveryEligible(widget.materialId)) {
      return MaterialStatusPanel(
        title: context.l10n.materialProcessingTitle,
        message: widget.processingMessage,
        icon: Icons.autorenew,
        progress: true,
      );
    }
    return MaterialStatusPanel(
      title: context.l10n.materialStuckTitle,
      message: context.l10n.materialStuckMessage,
      icon: Icons.restart_alt,
      actionLabel: context.l10n.materialResetTryAgain,
      onAction: () => state.recoverStuckMaterialFor(
        AuthScope.read(context).user,
        widget.materialId,
      ),
    );
  }
}

String? _imageOcrWarning(List<String>? codes) {
  if (codes == null) return null;
  const messages = <String, String>{
    'handwriting_low_confidence': 'Handwritten text may be less accurate.',
    'blur_detected': 'Some text may be unclear because the image is blurry.',
    'low_contrast': 'Some low-contrast text may be missing.',
    'layout_uncertain': 'The reading order may be imperfect.',
    'formula_uncertain': 'Some formula notation may be incomplete.',
    'partial_text': 'Only part of the image text could be read.',
    'rotated_content': 'Rotated text may be less accurate.',
  };
  for (final code in codes) {
    final message = messages[code];
    if (message != null) return message;
  }
  return null;
}

class _ImageExtractionSection extends StatelessWidget {
  const _ImageExtractionSection({required this.material});
  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final loading = state.isExtractingImage(material.id);
    final processing =
        material.processingStatus == MaterialProcessingStatus.processing;
    final ready =
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText;
    if (ready) return const SizedBox.shrink();
    final failed =
        material.processingStatus == MaterialProcessingStatus.failed ||
        (material.processingStatus == MaterialProcessingStatus.ready &&
            !material.hasContentText);
    final error =
        state.imageExtractionErrorFor(material.id) ??
        material.imageOcr?.failureMessage;
    return SectionCard(
      icon: failed ? Icons.error_outline : Icons.document_scanner_outlined,
      title: failed
          ? context.l10n.imageExtractionFailedTitle
          : context.l10n.imageExtractionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading || processing)
            Text(context.l10n.imageReadingText)
          else if (failed)
            Text(
              context.localizedSafeMessage(
                error ?? 'Could not read the uploaded image.',
              ),
            )
          else
            Text(context.l10n.imageExtractHelper),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading || processing
                ? null
                : () => AppStateScope.read(context).extractImageTextFor(
                    AuthScope.read(context).user,
                    material.id,
                  ),
            icon: loading || processing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(
              loading || processing
                  ? context.l10n.imageReadingText
                  : failed
                  ? context.l10n.imageRetryExtraction
                  : context.l10n.imageExtractText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfExtractionSection extends StatelessWidget {
  const _PdfExtractionSection({required this.material});
  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final loading = state.isExtractingPdf(material.id);
    final processing =
        material.processingStatus == MaterialProcessingStatus.processing;
    final ready =
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText;
    if (ready) return const SizedBox.shrink();
    final failed = material.processingStatus == MaterialProcessingStatus.failed;
    if (state.isScannedPdfOcrAvailable(material)) {
      final pageCount = material.pdfExtraction?.pageCount ?? 0;
      final candidateCount =
          material.pdfExtraction?.ocrCandidatePages.length ?? 0;
      final scanning = state.isScanningPdf(material.id);
      final mixed =
          material.pdfExtraction?.classification == 'mixed_ocr_available';
      return SectionCard(
        icon: Icons.document_scanner_outlined,
        title: mixed
            ? context.l10n.pdfSomePagesNeedOcr
            : context.l10n.pdfNoSelectableText,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scanning)
              Text(context.l10n.pdfReadingScannedPages)
            else if (pageCount > 10)
              Text(context.l10n.errorPdfOcrPageLimit)
            else
              Text(
                mixed
                    ? context.l10n.pdfRequiresOcrCount(
                        candidateCount,
                        pageCount,
                      )
                    : context.l10n.pdfRequiresOcrMessage,
              ),
            if (state.scannedPdfOcrErrorFor(material.id) case final error?) ...[
              const SizedBox(height: 8),
              Text(context.localizedSafeMessage(error)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: scanning || pageCount > 10
                  ? null
                  : () => _confirmOcr(context),
              icon: scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(
                scanning
                    ? context.l10n.pdfReadingScannedPages
                    : context.l10n.pdfScanWithOcr,
              ),
            ),
          ],
        ),
      );
    }
    final error =
        state.pdfExtractionErrorFor(material.id) ??
        material.pdfExtraction?.failureMessage;

    return SectionCard(
      icon: failed ? Icons.error_outline : Icons.text_snippet_outlined,
      title: failed
          ? context.l10n.pdfTextExtractionFailedTitle
          : context.l10n.pdfTextExtractionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading || processing)
            Text(context.l10n.pdfExtractingSelectable)
          else if (failed)
            Text(
              context.localizedSafeMessage(
                error ?? 'Could not read the uploaded PDF.',
              ),
            )
          else
            Text(context.l10n.pdfExtractHelper),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading || processing
                ? null
                : () => _extract(context, material.id),
            icon: loading || processing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.text_snippet_outlined),
            label: Text(
              loading || processing
                  ? context.l10n.pdfExtractingSelectable
                  : failed
                  ? context.l10n.pdfRetryTextExtraction
                  : context.l10n.pdfExtractText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _extract(BuildContext context, String materialId) async {
    await AppStateScope.read(
      context,
    ).extractPdfTextFor(AuthScope.read(context).user, materialId);
  }

  Future<void> _confirmOcr(BuildContext context) async {
    final pageCount = material.pdfExtraction?.pageCount ?? 0;
    final candidateCount =
        material.pdfExtraction?.ocrCandidatePages.length ?? 0;
    final start = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.pdfScanDialogTitle),
        content: Text(
          context.l10n.pdfScanDialogMessage(pageCount, candidateCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.pdfStartOcr),
          ),
        ],
      ),
    );
    if (start == true && context.mounted) {
      await AppStateScope.read(
        context,
      ).scanPdfWithOcrFor(AuthScope.read(context).user, material.id);
    }
  }
}

class _QuizSection extends StatelessWidget {
  const _QuizSection({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final quiz = state.latestQuizForMaterial(material.id);
    final hasQuiz = quiz != null && quiz.questions.isNotEmpty;
    final canGenerate = state.isAiSourceReadyForMaterial(material);
    final hasEnoughText = state.canGenerateQuizForMaterial(material);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final buttonLabel = isSupabaseMode
        ? context.l10n.quizGenerate
        : context.l10n.quizGenerateMock;
    final subject = state.subjectFor(material.subjectId);
    final latestAttempt = state.latestQuizAttemptForMaterial(material.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasQuiz)
          Text(context.l10n.quizQuestionsReady(quiz.questionCount))
        else
          Text(context.l10n.quizNoQuiz),
        if (canGenerate && !hasEnoughText) ...[
          const SizedBox(height: 8),
          Text(
            quizTooShortMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.quizGenerationErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            context.localizedSafeMessage(state.quizGenerationErrorMessage!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        if (hasQuiz)
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.quizTaking,
              arguments: QuizTakingArgs(
                subject: subject,
                material: material,
                quiz: quiz,
              ),
            ),
            icon: const Icon(Icons.quiz_outlined),
            label: Text(context.l10n.quizTakeQuiz),
          )
        else if (canGenerate)
          FilledButton.icon(
            onPressed: state.isGeneratingQuiz || !hasEnoughText
                ? null
                : () => _generateQuiz(context, material.id),
            icon: state.isGeneratingQuiz
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              state.isGeneratingQuiz
                  ? context.l10n.quizGenerating
                  : buttonLabel,
            ),
          ),
        if (hasQuiz && latestAttempt != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _reviewMistakes(
              context,
              subject,
              material,
              quiz,
              latestAttempt.id,
            ),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(context.l10n.quizReviewMissed),
          ),
        ],
      ],
    );
  }

  Future<void> _generateQuiz(BuildContext context, String materialId) async {
    final generated = await AppStateScope.read(
      context,
    ).generateQuizFor(AuthScope.read(context).user, materialId);
    if (!context.mounted || generated) {
      return;
    }
    final message =
        AppStateScope.read(context).quizGenerationErrorMessage ??
        'Could not generate quiz. Try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }

  Future<void> _reviewMistakes(
    BuildContext context,
    Subject subject,
    StudyMaterial material,
    Quiz quiz,
    String attemptId,
  ) async {
    final state = AppStateScope.read(context);
    final review = await state.startMistakeReviewActivity(
      AuthScope.read(context).user,
      attemptId,
    );
    if (!context.mounted) return;
    if (review == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedSafeMessage(
              state.studyActivityErrorMessage ??
                  context.l10n.quizNoMissedTopics,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.quizTaking,
      arguments: QuizTakingArgs(
        subject: subject,
        material: material,
        quiz: quiz,
        session: review,
      ),
    );
  }
}

class _FlashcardsSection extends StatelessWidget {
  const _FlashcardsSection({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final cards = state.flashcardsForMaterial(material.id);
    final hasCards = cards.isNotEmpty;
    final canGenerate = state.isAiSourceReadyForMaterial(material);
    final hasEnoughText = state.canGenerateFlashcardsForMaterial(material);
    final subject = state.subjectFor(material.subjectId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasCards)
          Text(context.l10n.flashcardsReady(cards.length))
        else
          Text(context.l10n.flashcardsNoFlashcards),
        if (canGenerate && !hasEnoughText) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.flashcardsTooShort,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.flashcardGenerationErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            context.localizedSafeMessage(
              state.flashcardGenerationErrorMessage!,
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        if (hasCards) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.flashcardTraining,
                  arguments: FlashcardTrainingArgs(
                    subject: subject,
                    material: material,
                    cards: cards,
                  ),
                ),
                icon: const Icon(Icons.school_outlined),
                label: Text(context.l10n.flashcardsStartTraining),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.flashcards,
                  arguments: FlashcardsRouteArgs(
                    subject: subject,
                    materialId: material.id,
                    materialTitle: material.title,
                  ),
                ),
                icon: const Icon(Icons.style_outlined),
                label: Text(context.l10n.flashcardsReviewThese),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (canGenerate)
          FilledButton.icon(
            onPressed: state.isGeneratingFlashcards || !hasEnoughText
                ? null
                : () => _chooseAndGenerateFlashcards(
                    context,
                    material.id,
                    cards.length,
                  ),
            icon: state.isGeneratingFlashcards
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              state.isGeneratingFlashcards
                  ? context.l10n.flashcardsGenerating
                  : context.l10n.flashcardsGenerate,
            ),
          ),
      ],
    );
  }

  Future<void> _chooseAndGenerateFlashcards(
    BuildContext context,
    String materialId,
    int currentCardCount,
  ) async {
    final requestedNewCount = await showFlashcardGenerationDialog(
      context,
      currentCardCount: currentCardCount,
    );
    if (!context.mounted || requestedNewCount == null) {
      return;
    }
    final result = await AppStateScope.read(context).generateFlashcardsFor(
      AuthScope.read(context).user,
      materialId,
      requestedNewCount: requestedNewCount,
    );
    if (!context.mounted) {
      return;
    }
    if (result != null) {
      final message = switch (result.createdCount) {
        0 => context.l10n.flashcardsNoNewGenerated,
        final count => context.l10n.flashcardsNewGenerated(count),
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final message =
        AppStateScope.read(context).flashcardGenerationErrorMessage ??
        'Could not generate flashcards. Try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }
}

class _MaterialAnalysisSection extends StatefulWidget {
  const _MaterialAnalysisSection({required this.material});
  final StudyMaterial material;
  @override
  State<_MaterialAnalysisSection> createState() =>
      _MaterialAnalysisSectionState();
}

class _MaterialAnalysisSectionState extends State<_MaterialAnalysisSection> {
  bool _started = false;
  Timer? _retryTimer;
  int? _retryRemaining;
  int? _serverRetryValue;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppStateScope.read(context).observeMaterialAnalysis(
          AuthScope.read(context).user,
          widget.material.id,
        );
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context),
        status = state.analysisStatusFor(widget.material.id),
        error = state.analysisErrorFor(widget.material.id),
        actionInFlight = state.isMaterialAnalysisActionInFlight(
          widget.material.id,
        ),
        l = context.l10n;
    _syncRetryCountdown(status?.retryAfterSeconds);
    if (error == AnalysisErrorCode.documentTooLarge) {
      return MaterialStatusPanel(
        title: l.analysisDocumentTooLargeTitle,
        message: l.analysisDocumentTooLargeMessage,
        icon: Icons.block_outlined,
        warning: true,
      );
    }
    if (status == null && error != null) {
      final temporary = {
        AnalysisErrorCode.network,
        AnalysisErrorCode.rateLimited,
        AnalysisErrorCode.serviceUnavailable,
      }.contains(error);
      return MaterialStatusPanel(
        title: l.analysisInvalidDocumentTitle,
        message: temporary
            ? l.analysisTemporaryFailure
            : l.analysisInvalidDocumentMessage,
        icon: temporary ? Icons.cloud_off_outlined : Icons.error_outline,
        warning: true,
      );
    }
    if (status == null) {
      return MaterialStatusPanel(
        title: l.analysisPreparingDocument,
        message: l.analysisResumeProcessing,
        icon: Icons.hourglass_top_outlined,
        progress: true,
      );
    }
    if (!status.isTerminal &&
        const {
          AnalysisErrorCode.requestFailed,
          AnalysisErrorCode.network,
          AnalysisErrorCode.rateLimited,
          AnalysisErrorCode.serviceUnavailable,
        }.contains(error)) {
      return MaterialStatusPanel(
        title: _stage(l, status),
        message: l.analysisTemporaryFailure,
        icon: Icons.cloud_off_outlined,
        warning: true,
      );
    }
    if (status.confirmationRequired) {
      return MaterialStatusPanel(
        title: l.analysisConfirmLargeTitle,
        message: l.analysisLargeDocumentExplanation,
        icon: Icons.warning_amber_rounded,
        warning: true,
        actionLabel: l.analysisConfirmLargeAction,
        onAction: actionInFlight
            ? null
            : () => state.confirmLargeMaterialAnalysis(
                AuthScope.read(context).user,
                widget.material.id,
              ),
      );
    }
    if (status.state == AnalysisState.failed) {
      return MaterialStatusPanel(
        title: l.materialFailedStatus,
        message: _safeFailureMessage(l, status.safeErrorCode),
        icon: Icons.error_outline,
        warning: true,
        actionLabel: status.canRetry ? l.analysisRetryProcessing : null,
        onAction: status.canRetry && !actionInFlight
            ? () => state.retryMaterialAnalysis(
                AuthScope.read(context).user,
                widget.material.id,
              )
            : null,
      );
    }
    if (status.state == AnalysisState.userRetryRequired) {
      return MaterialStatusPanel(
        title: _stage(l, status),
        message: status.safeErrorCode != null
            ? _safeFailureMessage(l, status.safeErrorCode)
            : status.canRetry
            ? l.analysisRetryProcessing
            : (_retryRemaining != null && _retryRemaining! > 0
                  ? l.analysisRetryAvailableIn(_retryRemaining!)
                  : l.analysisResumeProcessing),
        icon: Icons.error_outline,
        warning: true,
        actionLabel: status.canRetry ? l.analysisRetryProcessing : null,
        onAction: status.canRetry && !actionInFlight
            ? () => state.retryMaterialAnalysis(
                AuthScope.read(context).user,
                widget.material.id,
              )
            : null,
      );
    }
    final summary = status.summary;
    final legacySummary = widget.material.summary?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaterialStatusPanel(
          title: status.state == AnalysisState.completedWithWarnings
              ? l.analysisCompletedWithWarnings
              : status.state == AnalysisState.completed
              ? l.analysisCompleted
              : _stage(l, status),
          message: _retryRemaining != null && _retryRemaining! > 0
              ? l.analysisRetryAvailableIn(_retryRemaining!)
              : status.state == AnalysisState.completed
              ? l.analysisCompleted
              : status.publicStage == AnalysisPublicStage.analyzingPages
              ? l.analysisPageProgress(status.completedPages, status.pageCount)
              : _stage(l, status),
          icon: status.state == AnalysisState.completed
              ? Icons.check_circle_outline
              : status.state == AnalysisState.completedWithWarnings
              ? Icons.warning_amber_rounded
              : Icons.auto_awesome_outlined,
          progress: false,
          warning: status.state == AnalysisState.completedWithWarnings,
        ),
        if (status.pageCount > 0 && !status.isTerminal)
          LinearProgressIndicator(
            value: _authoritativeProgress(status),
            semanticsLabel: l.analysisPageProgress(
              status.completedPages,
              status.pageCount,
            ),
          ),
        if (status.structuredSummaryMalformed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.analysisMalformedFallback),
          ),
        if (summary == null &&
            legacySummary != null &&
            legacySummary.isNotEmpty) ...[
          const SizedBox(height: 16),
          SummaryDocumentView(markdown: legacySummary),
        ],
        if (summary != null) ...[
          const SizedBox(height: 16),
          StructuredSummaryView(summary: summary, material: widget.material),
        ],
      ],
    );
  }

  String _stage(dynamic l, MaterialAnalysisStatus s) => switch (s.publicStage) {
    AnalysisPublicStage.preparingDocument => l.analysisPreparingDocument,
    AnalysisPublicStage.analyzingPages => l.analysisPageProgress(
      s.completedPages,
      s.pageCount,
    ),
    AnalysisPublicStage.recognizingFormulasAndDiagrams =>
      l.analysisFormulaProgress(s.completedPages, s.pageCount),
    AnalysisPublicStage.combiningResults => l.analysisCombiningResults,
    AnalysisPublicStage.creatingSummary => l.analysisCreatingSummary,
  };

  double _authoritativeProgress(MaterialAnalysisStatus status) {
    final pages = status.pageCount == 0
        ? 0.0
        : status.completedPages / status.pageCount;
    return switch (status.publicStage) {
      AnalysisPublicStage.preparingDocument => 0.05,
      AnalysisPublicStage.analyzingPages => 0.1 + (0.4 * pages),
      AnalysisPublicStage.recognizingFormulasAndDiagrams => 0.5 + (0.3 * pages),
      AnalysisPublicStage.combiningResults => 0.9,
      AnalysisPublicStage.creatingSummary => 0.95,
    };
  }

  String _safeFailureMessage(dynamic l, String? code) => switch (code) {
    'unable_to_extract_content' => l.analysisUnableToExtractContent,
    'provider_temporarily_unavailable' => l.analysisProviderUnavailable,
    'structured_output_invalid' => l.analysisStructuredOutputInvalid,
    _ => l.analysisInvalidDocumentMessage,
  };

  void _syncRetryCountdown(int? seconds) {
    if (_serverRetryValue == seconds) return;
    _serverRetryValue = seconds;
    _retryTimer?.cancel();
    _retryRemaining = seconds;
    if (seconds == null || seconds == 0) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final current = _retryRemaining ?? 0;
        _retryRemaining = current > 0 ? current - 1 : 0;
        if (_retryRemaining == 0) timer.cancel();
      });
    });
  }
}

class _SummarySection extends StatefulWidget {
  const _SummarySection({required this.material});

  final StudyMaterial material;

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final state = AppStateScope.watch(context);
    final summary = material.summary?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;
    final canGenerate = state.isAiSourceReadyForMaterial(material);
    final hasEnoughText = state.canGenerateSummaryForMaterial(material);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final buttonLabel = hasSummary
        ? context.l10n.summaryRegenerate
        : isSupabaseMode
        ? context.l10n.summaryWithAi
        : context.l10n.summaryGenerateMock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSummary) ...[
          SummaryDocumentView(
            markdown: summary,
            collapsed: _shouldCollapse(summary) && !_isExpanded,
          ),
          if (_shouldCollapse(summary))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                child: Text(
                  _isExpanded
                      ? context.l10n.actionShowLess
                      : context.l10n.actionShowMore,
                ),
              ),
            ),
        ] else
          Text(context.l10n.summaryNoSummary),
        if (canGenerate && !hasEnoughText) ...[
          const SizedBox(height: 8),
          Text(
            context.localizedSafeMessage(AppState.summaryTooShortMessage),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.summaryGenerationErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            context.localizedSafeMessage(state.summaryGenerationErrorMessage!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (canGenerate) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.isGeneratingSummary || !hasEnoughText
                ? null
                : () => _generateSummary(context, material.id),
            icon: state.isGeneratingSummary
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              state.isGeneratingSummary
                  ? context.l10n.summaryGenerating
                  : buttonLabel,
            ),
          ),
        ],
      ],
    );
  }

  bool _shouldCollapse(String summary) {
    return (widget.material.kind == MaterialKind.pdf ||
            widget.material.kind == MaterialKind.image) &&
        (summary.length > 900 || '\n'.allMatches(summary).length >= 14);
  }

  Future<void> _generateSummary(BuildContext context, String materialId) async {
    final generated = await AppStateScope.read(
      context,
    ).generateSummaryFor(AuthScope.read(context).user, materialId);
    if (!context.mounted || generated) {
      return;
    }
    final message =
        AppStateScope.read(context).summaryGenerationErrorMessage ??
        'Could not generate summary. Try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }
}
