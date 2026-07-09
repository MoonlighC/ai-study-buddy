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

class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({required this.material, super.key});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final freshMaterial = state.materialById(material.id) ?? material;
    final subject = state.subjectFor(freshMaterial.subjectId);
    final isFavorite = state.isMaterialFavorite(freshMaterial.id);

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
            '${freshMaterial.createdLabel} - pasted text',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.article_outlined,
            title: 'Pasted text',
            child: Text(
              freshMaterial.content.isEmpty
                  ? 'No pasted text available for this material.'
                  : freshMaterial.content,
            ),
          ),
          SectionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Summary',
            child: _SummarySection(material: freshMaterial),
          ),
          SectionCard(
            icon: Icons.style_outlined,
            title: 'Flashcards',
            child: _FlashcardsSection(material: freshMaterial),
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

class _FlashcardsSection extends StatelessWidget {
  const _FlashcardsSection({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final cards = state.flashcardsForMaterial(material.id);
    final hasCards = cards.isNotEmpty;
    final canGenerate = material.kind == MaterialKind.pastedText;
    final hasEnoughText = state.canGenerateFlashcardsForMaterial(material);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final buttonLabel = isSupabaseMode
        ? 'Generate flashcards'
        : 'Generate mock flashcards';
    final subject = state.subjectFor(material.subjectId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasCards)
          Text('${cards.length} flashcards ready.')
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
        if (hasCards)
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
                  arguments: subject,
                ),
                icon: const Icon(Icons.style_outlined),
                label: const Text('Review flashcards'),
              ),
            ],
          )
        else if (canGenerate)
          FilledButton.icon(
            onPressed: state.isGeneratingFlashcards || !hasEnoughText
                ? null
                : () => _generateFlashcards(context, material.id),
            icon: state.isGeneratingFlashcards
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              state.isGeneratingFlashcards
                  ? 'Generating flashcards'
                  : buttonLabel,
            ),
          ),
      ],
    );
  }

  Future<void> _generateFlashcards(
    BuildContext context,
    String materialId,
  ) async {
    final generated = await AppStateScope.read(
      context,
    ).generateFlashcardsFor(AuthScope.read(context).user, materialId);
    if (!context.mounted || generated) {
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

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final summary = material.summary?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;
    final canGenerate = material.kind == MaterialKind.pastedText;
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
        if (hasSummary) Text(summary) else const Text('No summary yet.'),
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
