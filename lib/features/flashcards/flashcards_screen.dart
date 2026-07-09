import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/flashcard.dart';
import '../../core/models/subject.dart';
import 'flashcard_training_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({required this.subject, super.key});

  final Subject subject;

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
    final allCards = state.flashcardsFor(widget.subject.id);
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
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.subject.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Study session size'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final size in [5, 10, 20])
                ChoiceChip(
                  label: Text('$size'),
                  selected: selectedSessionSize == size,
                  onSelected: (_) => setState(() => sessionSize = size),
                ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.isLoadingFlashcards)
            const Card(
              child: ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading synced flashcards'),
              ),
            ),
          if (state.flashcardSyncErrorMessage != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(state.flashcardSyncErrorMessage!),
              ),
            ),
          if (!state.isLoadingFlashcards && allCards.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('No flashcards yet'),
                subtitle: Text(
                  isSupabaseMode
                      ? 'Generate them from a pasted-text material.'
                      : 'Add or generate cards to start reviewing.',
                ),
              ),
            ),
          if (allCards.isNotEmpty) ...[
            const Text('Review focus'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final filter in _FlashcardFilter.values)
                  ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (visibleCards.isNotEmpty)
              FilledButton.icon(
                onPressed: () =>
                    _startTraining(visibleCards, selectedSessionSize),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Start training'),
              )
            else
              Card(
                child: ListTile(
                  leading: Icon(_emptyFilterIcon(_filter)),
                  title: Text(_emptyFilterTitle(_filter)),
                  subtitle: Text(_emptyFilterSubtitle(_filter)),
                ),
              ),
            if (weakCards.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startTraining(weakCards, selectedSessionSize),
                icon: const Icon(Icons.trending_down_outlined),
                label: const Text('Train weak cards'),
              ),
            ],
            if (dueCards.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startTraining(dueCards, selectedSessionSize),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Review due cards'),
              ),
            ],
            if (weakCards.isEmpty || dueCards.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (weakCards.isEmpty) 'No weak cards right now.' else null,
                  if (dueCards.isEmpty) 'No due cards right now.' else null,
                ].whereType<String>().join(' '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
          ],
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
              onToggleFavorite: () => state.toggleFavorite(card.id),
            ),
        ],
      ),
    );
  }

  void _startTraining(List<Flashcard> cards, int selectedSessionSize) {
    Navigator.pushNamed(
      context,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: widget.subject,
        cards: cards.take(selectedSessionSize).toList(),
      ),
    );
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
      _FlashcardFilter.all => 'All',
      _FlashcardFilter.weak => 'Weak',
      _FlashcardFilter.due => 'Due',
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
      _FlashcardFilter.all => 'No flashcards yet',
      _FlashcardFilter.weak => 'No weak cards',
      _FlashcardFilter.due => 'No due cards',
    };
  }

  String _emptyFilterSubtitle(_FlashcardFilter filter) {
    return switch (filter) {
      _FlashcardFilter.all => 'Add or generate cards to start reviewing.',
      _FlashcardFilter.weak => 'Cards you miss more than you know appear here.',
      _FlashcardFilter.due => 'Reviewed cards will appear here when due.',
    };
  }
}

enum _FlashcardFilter { all, weak, due }

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
        : 'Known ${card.correctCount} - Missed ${card.incorrectCount}';
    final details = [
      'Topic: ${card.topic} - ${card.difficulty.label}',
      ?reviewStats,
      if (isAnswerVisible) card.back,
    ].join('\n');

    return Card(
      child: ListTile(
        title: Text(card.front),
        subtitle: Text(details),
        isThreeLine: isAnswerVisible || reviewStats != null,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: isAnswerVisible ? 'Hide answer' : 'Show answer',
              icon: Icon(
                isAnswerVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: onToggleAnswer,
            ),
            if (!isSupabaseMode)
              IconButton(
                tooltip: card.isFavorite ? 'Unfavorite' : 'Favorite',
                icon: Icon(card.isFavorite ? Icons.star : Icons.star_border),
                onPressed: onToggleFavorite,
              ),
          ],
        ),
      ),
    );
  }
}
