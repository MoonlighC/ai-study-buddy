import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_config.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/study_session.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';
import '../auth/auth_controller.dart';
import '../flashcards/flashcard_training_screen.dart';
import '../flashcards/flashcard_generation_dialog.dart';
import '../flashcards/flashcards_screen.dart';
import '../quizzes/quiz_repository.dart';
import '../quizzes/quiz_taking_screen.dart';
import 'material_upload.dart';

class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({required this.material, super.key});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final freshMaterial = state.materialById(material.id) ?? material;
    final subject = state.subjectFor(freshMaterial.subjectId);
    final isFavorite = state.isMaterialFavorite(freshMaterial.id);
    final isUpload = freshMaterial.sourceKind == MaterialSourceKind.upload;
    final isReadyUpload =
        isUpload &&
        freshMaterial.processingStatus == MaterialProcessingStatus.ready &&
        freshMaterial.hasContentText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Unfavorite material' : 'Favorite material',
            onPressed: state.isUpdatingMaterialFavorite
                ? null
                : () => _toggleMaterialFavorite(context, freshMaterial.id),
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          ),
          const AppTopActions(),
        ],
      ),
      body: AppPage(
        children: [
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
                    'Size: ${freshMaterial.fileSizeBytes == null ? 'Unknown' : formatFileSize(freshMaterial.fileSizeBytes!)}',
                  ),
                  Text('MIME: ${freshMaterial.mimeType ?? 'Unknown'}'),
                  Text('Status: ${_materialStatus(freshMaterial)}'),
                  if (freshMaterial.kind == MaterialKind.image &&
                      freshMaterial.processingStatus ==
                          MaterialProcessingStatus.ready &&
                      _imageOcrWarning(freshMaterial.imageOcr?.warningCodes) !=
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
                AppStateScope.read(context).createStudySession(
                  subject: subject,
                  confidence: LectureConfidence.mostly,
                  materialId: freshMaterial.id,
                );
                Navigator.pushNamed(
                  context,
                  AppRoutes.studySessionResult,
                  arguments: subject,
                );
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Create study session'),
            ),
          ],
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

  String _materialStatus(StudyMaterial material) {
    if (material.kind == MaterialKind.pdf &&
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText) {
      final pageCount = material.pdfExtraction?.pageCount;
      return pageCount == null
          ? 'Text extracted'
          : 'Text extracted · $pageCount ${pageCount == 1 ? 'page' : 'pages'}';
    }
    if (material.kind == MaterialKind.image &&
        material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText) {
      return 'Text extracted';
    }
    return material.processingStatus == MaterialProcessingStatus.pending
        ? 'Uploaded · Waiting for processing'
        : material.processingStatus.name;
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
      title: failed ? 'Image text extraction failed' : 'Image text extraction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading || processing)
            const Text('Reading image text…')
          else if (failed)
            Text(error ?? 'Could not extract image text. Try again.')
          else
            const Text('Extract readable study text from this image.'),
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
                  ? 'Reading image text…'
                  : failed
                  ? 'Retry image text extraction'
                  : 'Extract text from image',
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
    final error =
        state.pdfExtractionErrorFor(material.id) ??
        material.pdfExtraction?.failureMessage;

    return SectionCard(
      icon: failed ? Icons.error_outline : Icons.text_snippet_outlined,
      title: failed ? 'Text extraction failed' : 'PDF text extraction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading || processing)
            const Text('Extracting selectable text…')
          else if (failed)
            Text(error ?? 'Could not extract text. Try again.')
          else
            const Text('Extract selectable text from this PDF.'),
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
                  ? 'Extracting selectable text…'
                  : failed
                  ? 'Retry text extraction'
                  : 'Extract text',
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
    final buttonLabel = isSupabaseMode ? 'Generate quiz' : 'Generate mock quiz';
    final subject = state.subjectFor(material.subjectId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasQuiz)
          Text('${quiz.questionCount} questions ready.')
        else
          const Text('No quiz yet.'),
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
            state.quizGenerationErrorMessage!,
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
            label: const Text('Take quiz'),
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
              state.isGeneratingQuiz ? 'Generating quiz' : buttonLabel,
            ),
          ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          Text(
            cards.length == 1
                ? '1 flashcard ready.'
                : '${cards.length} flashcards ready.',
          )
        else
          const Text('No flashcards yet.'),
        if (canGenerate && !hasEnoughText) ...[
          const SizedBox(height: 8),
          Text(
            'Add more lecture text before generating flashcards.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.flashcardGenerationErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.flashcardGenerationErrorMessage!,
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
                label: const Text('Start training'),
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
                label: const Text('Review these flashcards'),
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
                  ? 'Generating flashcards'
                  : 'Generate flashcards',
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
        0 => 'No new unique flashcards were generated.',
        1 => '1 new flashcard generated.',
        final count => '$count new flashcards generated.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final message =
        AppStateScope.read(context).flashcardGenerationErrorMessage ??
        'Could not generate flashcards. Try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        ? 'Regenerate summary'
        : isSupabaseMode
        ? 'Summarize with AI'
        : 'Generate mock summary';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSummary) ...[
          Text(
            summary,
            maxLines: _shouldCollapse(summary) && !_isExpanded ? 14 : null,
            overflow: _shouldCollapse(summary) && !_isExpanded
                ? TextOverflow.ellipsis
                : null,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (_shouldCollapse(summary))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                child: Text(_isExpanded ? 'Show less' : 'Show more'),
              ),
            ),
        ] else
          const Text('No summary yet.'),
        if (canGenerate && !hasEnoughText) ...[
          const SizedBox(height: 8),
          Text(
            AppState.summaryTooShortMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.summaryGenerationErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.summaryGenerationErrorMessage!,
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
              state.isGeneratingSummary ? 'Generating summary' : buttonLabel,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
