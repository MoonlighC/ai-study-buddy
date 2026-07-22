import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_config.dart';
import '../../core/models/flashcard.dart';
import '../../core/models/material.dart';
import '../../core/models/persisted_study_activity.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../auth/auth_controller.dart';
import '../study_sessions/study_activity_repository.dart';
import 'flashcard_repository.dart';

class FlashcardTrainingArgs {
  const FlashcardTrainingArgs({
    required this.subject,
    required this.cards,
    this.material,
    this.session,
    this.mode = FlashcardTrainingMode.all,
  });

  final Subject subject;
  final StudyMaterial? material;
  final List<Flashcard> cards;
  final PersistedStudyActivity? session;
  final FlashcardTrainingMode mode;
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
  PersistedStudyActivity? _persisted;
  bool _starting = false;
  bool _initialized = false;
  StudyMaterial? _sessionMaterial;

  @override
  void initState() {
    super.initState();
    _sessionCards = List<Flashcard>.of(widget.args.cards);
    _persisted = widget.args.session;
    _sessionMaterial = widget.args.material;
    _restoreFromPersisted();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _ensurePersisted();
    }
  }

  void _restoreFromPersisted() {
    final session = _persisted;
    if (session == null) return;
    final byId = {for (final card in widget.args.cards) card.id: card};
    final ordered = [
      for (final id in session.itemIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (ordered.length == session.itemIds.length) _sessionCards = ordered;
    _currentIndex = session.currentIndex.clamp(0, _sessionCards.length);
    _knownCount = session.knownCount;
    _missedCount = session.notKnownCount;
    _isShowingAnswer = session.answerVisible;
    _missedCards
      ..clear()
      ..addAll([
        for (final id in session.firstPassMissedIds)
          if (byId[id] != null) byId[id]!,
      ]);
    _isComplete = session.isCompleted || _currentIndex >= _sessionCards.length;
  }

  Future<void> _ensurePersisted() async {
    if (_persisted != null) return;
    final state = AppStateScope.read(context);
    final isSupabase =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    if (!isSupabase && _sessionMaterial == null) return;
    final materialIds = widget.args.cards
        .map((card) => card.materialId)
        .whereType<String>()
        .toSet();
    if (_sessionMaterial == null && materialIds.length == 1) {
      _sessionMaterial = state.materialById(materialIds.single);
    }
    if (_sessionMaterial == null) {
      if (isSupabase &&
          state.studyActivityRepository is! EmptyStudyActivityRepository) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showSessionError(),
        );
      }
      return;
    }
    setState(() => _starting = true);
    final session = await state.startFlashcardActivity(
      user: AuthScope.read(context).user,
      material: _sessionMaterial!,
      cards: widget.args.cards,
      mode: widget.args.mode,
    );
    if (!mounted) return;
    setState(() {
      _starting = false;
      _persisted = session;
      _restoreFromPersisted();
    });
    if (session == null) _showSessionError();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sessionCards;
    if (_starting) {
      return ResponsiveAppScaffold(
        title: context.l10n.trainingTitle,
        showBack: true,
        showNavigation: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (cards.isEmpty) {
      return ResponsiveAppScaffold(
        title: context.l10n.trainingTitle,
        showBack: true,
        showNavigation: false,
        body: ResponsiveContent(
          width: ResponsiveContentWidth.reading,
          child: EmptyState(
            title: context.l10n.trainingEmptyTitle,
            message: context.l10n.trainingEmptyMessage,
            icon: Icons.style_outlined,
          ),
        ),
      );
    }

    if (_isComplete) {
      return ResponsiveAppScaffold(
        title: context.l10n.trainingComplete,
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
      title: context.l10n.trainingTitle,
      subtitle: _sessionMaterial?.title ?? widget.args.subject.name,
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
              label: context.l10n.trainingProgress,
            ),
            const SizedBox(height: 16),
            FlashcardSurface(
              front: card.front,
              back: card.back,
              isAnswerVisible: _isShowingAnswer,
              metadata:
                  '${card.topic} · ${LocalizedFormatters.difficulty(context.l10n, card.difficulty)}',
              onToggleAnswer: () => _setAnswerVisible(!_isShowingAnswer),
            ),
            const SizedBox(height: 16),
            if (!_isShowingAnswer)
              FilledButton.icon(
                onPressed: () => _setAnswerVisible(true),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(context.l10n.studyShowAnswer),
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
    final state = AppStateScope.read(context);
    final user = AuthScope.read(context).user;
    final persisted = _persisted;
    final updated = persisted == null
        ? null
        : await state.updateFlashcardActivity(
            user: user,
            session: persisted,
            currentIndex: _currentIndex + 1,
            answerVisible: false,
            cardId: card.id,
            result: result,
          );
    final saved = persisted == null
        ? state.config.effectiveBackendMode == AppBackendMode.supabase &&
                  state.studyActivityRepository is! EmptyStudyActivityRepository
              ? false
              : await state.reviewFlashcardFor(user, card.id, result)
        : updated != null;
    if (!mounted) {
      return;
    }
    if (!saved) {
      final message =
          AppStateScope.read(context).flashcardReviewErrorMessage ??
          context.l10n.errorCouldNotSaveReview;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizedSafeMessage(message))),
      );
      return;
    }

    setState(() {
      if (updated != null) _persisted = updated;
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
    if (_isComplete && _persisted != null) {
      await AppStateScope.read(
        context,
      ).finalizeFlashcardActivity(AuthScope.read(context).user, _persisted!.id);
    }
  }

  Future<void> _setAnswerVisible(bool value) async {
    final persisted = _persisted;
    if (persisted == null) {
      setState(() => _isShowingAnswer = value);
      return;
    }
    final updated = await AppStateScope.read(context).updateFlashcardActivity(
      user: AuthScope.read(context).user,
      session: persisted,
      currentIndex: _currentIndex,
      answerVisible: value,
    );
    if (!mounted) return;
    if (updated == null) {
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = updated;
      _isShowingAnswer = value;
    });
  }

  void _showSessionError() {
    if (!mounted) return;
    final message =
        AppStateScope.read(context).studyActivityErrorMessage ??
        'Could not save study session.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
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

  Future<void> _reviewMissedAgain() async {
    final immutableMisses = List<Flashcard>.of(_missedCards);
    final material = _sessionMaterial;
    PersistedStudyActivity? next;
    if (material != null && immutableMisses.isNotEmpty) {
      next = await AppStateScope.read(context).startFlashcardActivity(
        user: AuthScope.read(context).user,
        material: material,
        cards: immutableMisses,
        mode: FlashcardTrainingMode.firstPassMissed,
      );
      if (!mounted) return;
      if (next == null) {
        _showSessionError();
        return;
      }
    }
    setState(() {
      _sessionCards = immutableMisses;
      _persisted = next;
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
          title: context.l10n.trainingComplete,
          children: [
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.style_outlined),
                  title: Text(context.l10n.trainingReviewed(reviewedCount)),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(context.l10n.trainingKnown(knownCount)),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_outlined),
                  title: Text(context.l10n.trainingMissed(missedCount)),
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
            label: Text(context.l10n.trainingReviewMissed),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onReviewAgain,
          icon: const Icon(Icons.replay_outlined),
          label: Text(context.l10n.trainingReviewAgain),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReturn,
          icon: const Icon(Icons.arrow_back_outlined),
          label: Text(context.l10n.commonReturn),
        ),
      ],
    );
  }
}
