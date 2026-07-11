import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/flashcard.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
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
  late List<Flashcard> _sessionCards;
  final List<Flashcard> _missedCards = [];
  int _currentIndex = 0;
  int _knownCount = 0;
  int _missedCount = 0;
  bool _isShowingAnswer = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _sessionCards = List<Flashcard>.of(widget.args.cards);
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sessionCards;
    if (cards.isEmpty) {
      return const ResponsiveAppScaffold(
        title: 'Flashcard training',
        showBack: true,
        showNavigation: false,
        body: ResponsiveContent(
          width: ResponsiveContentWidth.reading,
          child: EmptyState(
            title: 'No flashcards to train',
            message: 'Generate flashcards first.',
            icon: Icons.style_outlined,
          ),
        ),
      );
    }

    if (_isComplete) {
      return ResponsiveAppScaffold(
        title: 'Training complete',
        showBack: true,
        showNavigation: false,
        body: ResponsiveContent(
          width: ResponsiveContentWidth.reading,
          child: _CompletionView(
            reviewedCount: cards.length,
            knownCount: _knownCount,
            missedCount: _missedCount,
            canReviewMissedAgain: _missedCards.isNotEmpty,
            onReviewAgain: _reviewAgain,
            onReviewMissedAgain: _reviewMissedAgain,
            onReturn: () => Navigator.pop(context),
          ),
        ),
      );
    }

    final card = cards[_currentIndex];
    return ResponsiveAppScaffold(
      title: 'Flashcard training',
      subtitle: widget.args.material?.title ?? widget.args.subject.name,
      showBack: true,
      showNavigation: false,
      subjectColor: Color(widget.args.subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            StudyProgressHeader(
              current: _currentIndex + 1,
              total: cards.length,
              label: 'Flashcard progress',
            ),
            const SizedBox(height: 16),
            FlashcardSurface(
              front: card.front,
              back: card.back,
              isAnswerVisible: _isShowingAnswer,
              metadata: '${card.topic} · ${card.difficulty.label}',
              onToggleAnswer: () =>
                  setState(() => _isShowingAnswer = !_isShowingAnswer),
            ),
            const SizedBox(height: 16),
            if (!_isShowingAnswer)
              FilledButton.icon(
                onPressed: () => setState(() => _isShowingAnswer = true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Show answer'),
              )
            else
              RatingActionRow(
                onMissed: () => _rateCard(card, FlashcardReviewResult.missed),
                onKnown: () => _rateCard(card, FlashcardReviewResult.known),
              ),
          ],
        ),
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
        _missedCards.add(card);
      }
      if (_currentIndex == _sessionCards.length - 1) {
        _isComplete = true;
      } else {
        _currentIndex += 1;
        _isShowingAnswer = false;
      }
    });
  }

  void _reviewAgain() {
    setState(() {
      _sessionCards = List<Flashcard>.of(widget.args.cards);
      _currentIndex = 0;
      _knownCount = 0;
      _missedCount = 0;
      _missedCards.clear();
      _isShowingAnswer = false;
      _isComplete = false;
    });
  }

  void _reviewMissedAgain() {
    setState(() {
      _sessionCards = List<Flashcard>.of(_missedCards);
      _currentIndex = 0;
      _knownCount = 0;
      _missedCount = 0;
      _missedCards.clear();
      _isShowingAnswer = false;
      _isComplete = false;
    });
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.reviewedCount,
    required this.knownCount,
    required this.missedCount,
    required this.canReviewMissedAgain,
    required this.onReviewAgain,
    required this.onReviewMissedAgain,
    required this.onReturn,
  });

  final int reviewedCount;
  final int knownCount;
  final int missedCount;
  final bool canReviewMissedAgain;
  final VoidCallback onReviewAgain;
  final VoidCallback onReviewMissedAgain;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        StudyCompletionCard(
          title: 'Training complete',
          children: [
            Column(
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
          ],
        ),
        const SizedBox(height: 16),
        if (canReviewMissedAgain) ...[
          FilledButton.icon(
            onPressed: onReviewMissedAgain,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Review missed again'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
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
    );
  }
}
