import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/flashcard.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../auth/auth_controller.dart';
import 'flashcard_repository.dart';

class FlashcardTrainingArgs {
  const FlashcardTrainingArgs({
    required this.subject,
    required this.cards,
    this.material,
  });

  final Subject subject;
  final StudyMaterial? material;
  final List<Flashcard> cards;
}

class FlashcardTrainingScreen extends StatefulWidget {
  const FlashcardTrainingScreen({required this.args, super.key});

  final FlashcardTrainingArgs args;

  @override
  State<FlashcardTrainingScreen> createState() =>
      _FlashcardTrainingScreenState();
}

class _FlashcardTrainingScreenState extends State<FlashcardTrainingScreen> {
  int _currentIndex = 0;
  int _knownCount = 0;
  int _missedCount = 0;
  bool _isShowingAnswer = false;
  bool _isComplete = false;

  List<Flashcard> get _cards => widget.args.cards;

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard training')),
        body: const Center(child: Text('Generate flashcards first.')),
      );
    }

    if (_isComplete) {
      return _CompletionView(
        reviewedCount: cards.length,
        knownCount: _knownCount,
        missedCount: _missedCount,
        onReviewAgain: _reviewAgain,
        onReturn: () => Navigator.pop(context),
      );
    }

    final card = cards[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcard training')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.args.material?.title ?? widget.args.subject.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${_currentIndex + 1} / ${cards.length}'),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isShowingAnswer = true),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isShowingAnswer ? 'Answer' : 'Question',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isShowingAnswer ? card.back : card.front,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isShowingAnswer)
            FilledButton.icon(
              onPressed: () => setState(() => _isShowingAnswer = true),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Show answer'),
            )
          else
            _RatingActions(
              onMissed: () => _rateCard(card, FlashcardReviewResult.missed),
              onKnown: () => _rateCard(card, FlashcardReviewResult.known),
            ),
        ],
      ),
    );
  }

  Future<void> _rateCard(Flashcard card, FlashcardReviewResult result) async {
    final saved = await AppStateScope.read(
      context,
    ).reviewFlashcardFor(AuthScope.read(context).user, card.id, result);
    if (!mounted) {
      return;
    }
    if (!saved) {
      final message =
          AppStateScope.read(context).flashcardReviewErrorMessage ??
          'Could not save review progress.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      if (result == FlashcardReviewResult.known) {
        _knownCount += 1;
      } else {
        _missedCount += 1;
      }
      if (_currentIndex == _cards.length - 1) {
        _isComplete = true;
      } else {
        _currentIndex += 1;
        _isShowingAnswer = false;
      }
    });
  }

  void _reviewAgain() {
    setState(() {
      _currentIndex = 0;
      _knownCount = 0;
      _missedCount = 0;
      _isShowingAnswer = false;
      _isComplete = false;
    });
  }
}

class _RatingActions extends StatelessWidget {
  const _RatingActions({required this.onMissed, required this.onKnown});

  final VoidCallback onMissed;
  final VoidCallback onKnown;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMissed,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('I missed it'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onKnown,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('I knew it'),
          ),
        ),
      ],
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.reviewedCount,
    required this.knownCount,
    required this.missedCount,
    required this.onReviewAgain,
    required this.onReturn,
  });

  final int reviewedCount;
  final int knownCount;
  final int missedCount;
  final VoidCallback onReviewAgain;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training complete')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Training complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.style_outlined),
                  title: const Text('Cards reviewed'),
                  trailing: Text('$reviewedCount'),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Known'),
                  trailing: Text('$knownCount'),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_outlined),
                  title: const Text('Missed'),
                  trailing: Text('$missedCount'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onReviewAgain,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Review again'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReturn,
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Return'),
          ),
        ],
      ),
    );
  }
}
