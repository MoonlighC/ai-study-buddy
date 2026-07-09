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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final cards = state.flashcardsFor(widget.subject.id);
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
          if (!state.isLoadingFlashcards && cards.isEmpty)
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
          if (cards.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.flashcardTraining,
                arguments: FlashcardTrainingArgs(
                  subject: widget.subject,
                  cards: cards.take(selectedSessionSize).toList(),
                ),
              ),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Start training'),
            ),
            const SizedBox(height: 16),
          ],
          for (final card in cards)
            Card(
              child: ListTile(
                title: Text(card.front),
                subtitle: Text(
                  '${card.back}\nTopic: ${card.topic} - ${card.difficulty.label}',
                ),
                isThreeLine: true,
                trailing: isSupabaseMode
                    ? null
                    : IconButton(
                        tooltip: card.isFavorite ? 'Unfavorite' : 'Favorite',
                        icon: Icon(
                          card.isFavorite ? Icons.star : Icons.star_border,
                        ),
                        onPressed: () => state.toggleFavorite(card.id),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
