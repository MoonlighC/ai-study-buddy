import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/flashcard.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../auth/auth_controller.dart';
import 'flashcard_training_screen.dart';

class FlashcardsRouteArgs {
  const FlashcardsRouteArgs({
    required this.subject,
    this.materialId,
    this.materialTitle,
  });

  final Subject subject;
  final String? materialId;
  final String? materialTitle;

  bool get isMaterialScoped => materialId != null;
}

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({required this.args, super.key});

  final FlashcardsRouteArgs args;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  int? sessionSize;
  _FlashcardFilter _filter = _FlashcardFilter.all;
  final Set<String> _revealedCardIds = {};

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final materialId = widget.args.materialId;
    final allCards = materialId == null
        ? state.flashcardsFor(widget.args.subject.id)
        : state.flashcardsForMaterial(materialId);
    final now = DateTime.now().toUtc();
    final weakCards = allCards.where(_isWeak).toList();
    final dueCards = allCards.where((card) => _isDue(card, now)).toList();
    final visibleCards = switch (_filter) {
      _FlashcardFilter.all => allCards,
      _FlashcardFilter.weak => weakCards,
      _FlashcardFilter.due => dueCards,
    };
    final selectedSessionSize =
        sessionSize ?? state.defaultFlashcardSessionSize;
    final availableCount = visibleCards.length;
    final effectiveSessionSize = availableCount == 0
        ? 0
        : selectedSessionSize.clamp(1, availableCount).toInt();
    final hasUnavailablePreset =
        availableCount > 0 &&
        const [5, 10, 20].any((size) => size > availableCount);
    final isCustomSelected =
        sessionSize != null && !const [5, 10, 20].contains(selectedSessionSize);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;

    final title = widget.args.isMaterialScoped
        ? context.l10n.flashcardsMaterialTitle(widget.args.materialTitle ?? '')
        : context.l10n.flashcardsAllTitle(widget.args.subject.name);
    final helper = widget.args.isMaterialScoped
        ? context.l10n.flashcardsScopeMaterial(allCards.length)
        : _subjectScopeHelper(allCards);

    return ResponsiveAppScaffold(
      title: title,
      showBack: true,
      showNavigation: false,
      subjectColor: Color(widget.args.subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudyContextHeader(
                title: widget.args.materialTitle ?? widget.args.subject.name,
                subtitle: helper,
                status: context.l10n.studyCards(allCards.length),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.flashcardsSessionSize),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final size in [5, 10, 20])
                          ChoiceChip(
                            label: Text('$size'),
                            selected: selectedSessionSize == size,
                            onSelected: size > availableCount
                                ? null
                                : (_) => setState(() => sessionSize = size),
                          ),
                        ChoiceChip(
                          label: Text(context.l10n.commonCustom),
                          selected: isCustomSelected,
                          onSelected: availableCount == 0
                              ? null
                              : (_) => _chooseCustomSessionSize(
                                  availableCount: availableCount,
                                  initialSize: effectiveSessionSize,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _availableCountText(availableCount),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (hasUnavailablePreset) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.flashcardsGenerateMoreGuidance,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state.isLoadingFlashcards)
                GlassCard(
                  child: LoadingState(label: context.l10n.flashcardsLoading),
                ),
              if (state.flashcardSyncErrorMessage != null)
                GlassCard(
                  child: ErrorRetryState(
                    message: context.localizedSafeMessage(
                      state.flashcardSyncErrorMessage!,
                    ),
                    onRetry: null,
                  ),
                ),
              if (!state.isLoadingFlashcards && allCards.isEmpty)
                GlassCard(
                  child: EmptyState(
                    title: context.l10n.flashcardsEmptyTitle,
                    icon: Icons.style_outlined,
                    message: isSupabaseMode
                        ? context.l10n.flashcardsEmptyCloudMessage
                        : context.l10n.flashcardsEmptyMessage,
                  ),
                ),
              if (allCards.isNotEmpty) ...[
                Text(context.l10n.flashcardsReviewFocus),
                const SizedBox(height: 8),
                Semantics(
                  label: context.l10n.flashcardsFilterSemantics,
                  child: SegmentedButton<_FlashcardFilter>(
                    segments: [
                      for (final filter in _FlashcardFilter.values)
                        ButtonSegment(
                          value: filter,
                          label: Text(_filterLabel(filter)),
                        ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.single),
                  ),
                ),
                const SizedBox(height: 16),
                if (visibleCards.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () =>
                        _startTraining(visibleCards, effectiveSessionSize),
                    icon: const Icon(Icons.school_outlined),
                    label: Text(
                      context.l10n.flashcardsStartTrainingCount(
                        effectiveSessionSize,
                      ),
                    ),
                  )
                else
                  GlassCard(
                    child: EmptyState(
                      icon: _emptyFilterIcon(_filter),
                      title: _emptyFilterTitle(_filter),
                      message: _emptyFilterSubtitle(_filter),
                    ),
                  ),
                if (weakCards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _startTraining(weakCards, selectedSessionSize),
                    icon: const Icon(Icons.trending_down_outlined),
                    label: Text(context.l10n.flashcardsTrainWeak),
                  ),
                ],
                if (dueCards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _startTraining(dueCards, selectedSessionSize),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(context.l10n.flashcardsReviewDue),
                  ),
                ],
                if (weakCards.isEmpty || dueCards.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (weakCards.isEmpty)
                        context.l10n.flashcardsNoWeak
                      else
                        null,
                      if (dueCards.isEmpty)
                        context.l10n.flashcardsNoDue
                      else
                        null,
                    ].whereType<String>().join(' '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
              ],
              if (visibleCards.isNotEmpty)
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final card in visibleCards)
                        _FlashcardListItem(
                          card: card,
                          isAnswerVisible: _revealedCardIds.contains(card.id),
                          isSupabaseMode: isSupabaseMode,
                          onToggleAnswer: () => setState(() {
                            if (!_revealedCardIds.add(card.id)) {
                              _revealedCardIds.remove(card.id);
                            }
                          }),
                          onToggleFavorite: () =>
                              state.toggleFlashcardFavoriteFor(
                                AuthScope.read(context).user,
                                card.id,
                              ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTraining(List<Flashcard> cards, int selectedSessionSize) {
    Navigator.pushNamed(
      context,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: widget.args.subject,
        material: widget.args.materialId == null
            ? null
            : AppStateScope.read(context).materialById(widget.args.materialId!),
        cards: cards.take(selectedSessionSize).toList(),
      ),
    );
  }

  Future<void> _chooseCustomSessionSize({
    required int availableCount,
    required int initialSize,
  }) async {
    final customSize = await showDialog<int>(
      context: context,
      builder: (_) => _CustomSessionSizeDialog(
        availableCount: availableCount,
        initialSize: initialSize,
      ),
    );
    if (!mounted || customSize == null) {
      return;
    }
    setState(() {
      sessionSize = customSize;
    });
  }

  bool _isWeak(Flashcard card) {
    return card.incorrectCount > card.correctCount;
  }

  bool _isDue(Flashcard card, DateTime now) {
    final nextReviewAt = card.nextReviewAt;
    return nextReviewAt != null && !nextReviewAt.toUtc().isAfter(now);
  }

  String _filterLabel(_FlashcardFilter filter) {
    return switch (filter) {
      _FlashcardFilter.all => context.l10n.flashcardsFilterAll,
      _FlashcardFilter.weak => context.l10n.flashcardsFilterWeak,
      _FlashcardFilter.due => context.l10n.flashcardsFilterDue,
    };
  }

  IconData _emptyFilterIcon(_FlashcardFilter filter) {
    return switch (filter) {
      _FlashcardFilter.all => Icons.style_outlined,
      _FlashcardFilter.weak => Icons.trending_up_outlined,
      _FlashcardFilter.due => Icons.event_available_outlined,
    };
  }

  String _emptyFilterTitle(_FlashcardFilter filter) {
    return switch (filter) {
      _FlashcardFilter.all => context.l10n.flashcardsEmptyTitle,
      _FlashcardFilter.weak => context.l10n.flashcardsNoWeak,
      _FlashcardFilter.due => context.l10n.flashcardsNoDue,
    };
  }

  String _emptyFilterSubtitle(_FlashcardFilter filter) {
    return switch (filter) {
      _FlashcardFilter.all => context.l10n.flashcardsEmptyMessage,
      _FlashcardFilter.weak => context.l10n.flashcardsNoWeak,
      _FlashcardFilter.due => context.l10n.flashcardsNoDue,
    };
  }

  String _availableCountText(int count) {
    return context.l10n.flashcardsAvailable(count);
  }

  String _subjectScopeHelper(List<Flashcard> cards) {
    final materialIds = cards
        .map((card) => card.materialId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final hasLegacyCards = cards.any(
      (card) => card.materialId == null || card.materialId!.isEmpty,
    );
    if (materialIds.isEmpty || hasLegacyCards) {
      return context.l10n.flashcardsScopeSubject(cards.length);
    }
    final materialsLabel = materialIds.length == 1
        ? '1 material'
        : '${materialIds.length} materials';
    return '${context.l10n.studyCards(cards.length)} · $materialsLabel';
  }
}

enum _FlashcardFilter { all, weak, due }

class _CustomSessionSizeDialog extends StatefulWidget {
  const _CustomSessionSizeDialog({
    required this.availableCount,
    required this.initialSize,
  });

  final int availableCount;
  final int initialSize;

  @override
  State<_CustomSessionSizeDialog> createState() =>
      _CustomSessionSizeDialogState();
}

class _CustomSessionSizeDialogState extends State<_CustomSessionSizeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialSize}',
  );
  String? _errorText;
  bool _showGenerateMoreGuidance = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.flashcardsCustomSessionTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.flashcardsCardsField,
                  helperText: context.l10n.flashcardsMaximum(
                    widget.availableCount,
                  ),
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText == null && !_showGenerateMoreGuidance) {
                    return;
                  }
                  setState(() {
                    _errorText = null;
                    _showGenerateMoreGuidance = false;
                  });
                },
                onSubmitted: (_) => _save(),
              ),
              if (_showGenerateMoreGuidance) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.flashcardsGenerateMoreGuidance,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final requestedSize = int.tryParse(_controller.text.trim());
    if (requestedSize == null || requestedSize < 1) {
      setState(() {
        _errorText = context.l10n.flashcardsChooseAtLeastOne;
        _showGenerateMoreGuidance = false;
      });
      return;
    }
    if (requestedSize > widget.availableCount) {
      setState(() {
        _errorText = context.l10n.flashcardsOnlyAvailable(
          widget.availableCount,
        );
        _showGenerateMoreGuidance = true;
      });
      return;
    }
    Navigator.pop(context, requestedSize);
  }
}

class _FlashcardListItem extends StatelessWidget {
  const _FlashcardListItem({
    required this.card,
    required this.isAnswerVisible,
    required this.isSupabaseMode,
    required this.onToggleAnswer,
    required this.onToggleFavorite,
  });

  final Flashcard card;
  final bool isAnswerVisible;
  final bool isSupabaseMode;
  final VoidCallback onToggleAnswer;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final reviewStats = card.correctCount == 0 && card.incorrectCount == 0
        ? null
        : context.l10n.flashcardsReviewStats(
            card.correctCount,
            card.incorrectCount,
          );
    final details = [
      context.l10n.flashcardsTopicDifficulty(
        card.topic,
        LocalizedFormatters.difficulty(context.l10n, card.difficulty),
      ),
      ?reviewStats,
      if (isAnswerVisible) card.back,
    ].join('\n');

    return AppListRow(
      title: Text(card.front),
      subtitle: Text(details),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: isAnswerVisible
                ? context.l10n.studyHideAnswer
                : context.l10n.studyShowAnswer,
            icon: Icon(
              isAnswerVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: onToggleAnswer,
          ),
          if (!isSupabaseMode)
            IconButton(
              tooltip: card.isFavorite
                  ? context.l10n.unfavoriteAction
                  : context.l10n.favoriteAction,
              icon: Icon(card.isFavorite ? Icons.star : Icons.star_border),
              onPressed: onToggleFavorite,
            ),
        ],
      ),
    );
  }
}
