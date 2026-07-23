import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_config.dart';
import '../../core/models/material.dart';
import '../../core/models/persisted_study_activity.dart';
import '../../core/models/quiz.dart';
import '../../core/models/quiz_attempt.dart';
import '../../core/models/quiz_question.dart';
import '../../core/utils/uuid.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/study_components.dart';
import '../auth/auth_controller.dart';
import 'quiz_attempt_presentation.dart';

class QuizTakingArgs {
  const QuizTakingArgs({
    required this.subject,
    required this.material,
    required this.quiz,
    this.randomSeed,
    this.session,
    this.completedAttempt,
  });

  final Subject subject;
  final StudyMaterial material;
  final Quiz quiz;
  final int? randomSeed;
  final PersistedStudyActivity? session;
  final QuizAttempt? completedAttempt;
}

class QuizTakingScreen extends StatefulWidget {
  const QuizTakingScreen({required this.args, super.key});

  final QuizTakingArgs args;

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final Map<String, String> _answers = {};
  final Map<String, String> _reviewAnswers = {};
  late final Random _random;
  late QuizAttemptPresentation _attempt;
  int _index = 0;
  int _reviewIndex = 0;
  _QuizMode _mode = _QuizMode.taking;
  bool _isCompleting = false;
  late DateTime _startedAt;
  late String _attemptId;
  PersistedStudyActivity? _persisted;
  QuizAttempt? _displayedCompletedAttempt;
  bool _starting = true;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _random = Random(widget.args.randomSeed);
    _initializeAttempt();
    _persisted = widget.args.session;
    final completed = widget.args.completedAttempt;
    _displayedCompletedAttempt = completed;
    if (completed != null) {
      _answers.addEntries(
        completed.answers.map(
          (answer) => MapEntry(answer.questionId, answer.selectedAnswer),
        ),
      );
      _mode = _QuizMode.result;
      _starting = false;
    }
    if (_persisted != null) {
      _restorePersisted(_persisted!);
      _starting = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStart) {
      _didStart = true;
      if (AppStateScope.read(context).config.effectiveBackendMode !=
          AppBackendMode.supabase) {
        _starting = false;
      } else if (_persisted == null && widget.args.completedAttempt == null) {
        _startPersisted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final questions = _attempt.quiz.questions;
    if (_starting) {
      return ResponsiveAppScaffold(
        title: context.l10n.quizUiTitle,
        showBack: true,
        showNavigation: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (questions.isEmpty) {
      return ResponsiveAppScaffold(
        title: context.l10n.quizUiTitle,
        showBack: true,
        showNavigation: false,
        body: ResponsiveContent(
          width: ResponsiveContentWidth.reading,
          child: EmptyState(
            title: context.l10n.quizEmptyTitle,
            message: context.l10n.quizEmptyMessage,
            icon: Icons.quiz_outlined,
          ),
        ),
      );
    }

    return ResponsiveAppScaffold(
      title: context.l10n.quizUiTitle,
      subtitle: widget.args.material.title,
      showBack: true,
      showNavigation: false,
      subjectColor: Color(widget.args.subject.colorValue),
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          children: [
            Text(
              widget.args.quiz.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget.args.material.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_mode == _QuizMode.result)
              _ResultView(
                questions: questions,
                answers: _answers,
                attempt:
                    _displayedCompletedAttempt ?? state.latestQuizCompletion,
                isSaving: state.isSavingQuizAttempt || _isCompleting,
                warningMessage: state.quizAttemptSyncErrorMessage,
                onReviewMaterial: () => Navigator.pop(context),
                onRetry: _retry,
                onReviewMissed: _missedQuestions.isEmpty
                    ? null
                    : _startMissedReview,
              )
            else if (_mode == _QuizMode.missedReview) ...[
              Text(
                context.l10n.quizMissedReview,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _QuestionView(
                question: _missedQuestions[_reviewIndex],
                questionNumber: _reviewIndex + 1,
                totalQuestions: _missedQuestions.length,
                selectedAnswer:
                    _reviewAnswers[_missedQuestions[_reviewIndex].id],
                onAnswer: _answerMistake,
                onNext:
                    _reviewAnswers[_missedQuestions[_reviewIndex].id] == null
                    ? null
                    : _advanceMissedReview,
                finalActionLabel: context.l10n.quizFinishReview,
              ),
            ] else
              _QuestionView(
                question: questions[_index],
                questionNumber: _index + 1,
                totalQuestions: questions.length,
                selectedAnswer: _answers[questions[_index].id],
                onAnswer: _answerQuestion,
                onNext: _answers[questions[_index].id] == null
                    ? null
                    : () async {
                        if (_index == questions.length - 1) {
                          await _completeQuiz();
                          return;
                        }
                        await _advanceQuiz();
                      },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeQuiz() async {
    if (_isCompleting) return;
    setState(() {
      _mode = _QuizMode.result;
      _isCompleting = true;
    });
    final saved = await AppStateScope.read(context).completeQuizFor(
      AuthScope.read(context).user,
      quiz: _attempt.quiz,
      selectedAnswers: _answers,
      startedAt: _startedAt,
      attemptId: _attemptId,
    );
    if (!mounted) return;
    if (saved && _persisted?.attemptId != null) {
      await AppStateScope.read(context).finalizeQuizActivity(
        AuthScope.read(context).user,
        _persisted!.attemptId!,
      );
    }
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (!saved) {
      final message =
          AppStateScope.read(context).quizAttemptSyncErrorMessage ??
          context.l10n.errorCouldNotSaveQuizAttempt;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizedSafeMessage(message))),
      );
    }
  }

  Future<void> _retry() async {
    final previousAttempt = _attempt;
    final previousAnswers = Map<String, String>.of(_answers);
    final previousReviewAnswers = Map<String, String>.of(_reviewAnswers);
    final previousIndex = _index;
    final previousReviewIndex = _reviewIndex;
    final previousMode = _mode;
    final previousStartedAt = _startedAt;
    final previousAttemptId = _attemptId;
    final previousPersisted = _persisted;
    final previousDisplayedAttempt = _displayedCompletedAttempt;
    final state = AppStateScope.read(context);
    final isSupabase =
        state.config.effectiveBackendMode == AppBackendMode.supabase;

    setState(() {
      _initializeAttempt();
      _displayedCompletedAttempt = null;
      _starting = isSupabase;
    });
    if (!isSupabase) return;

    final next = await state.startQuizActivity(
      user: AuthScope.read(context).user,
      quiz: _attempt.quiz,
    );
    if (!mounted) return;
    if (next == null) {
      setState(() {
        _attempt = previousAttempt;
        _answers
          ..clear()
          ..addAll(previousAnswers);
        _reviewAnswers
          ..clear()
          ..addAll(previousReviewAnswers);
        _index = previousIndex;
        _reviewIndex = previousReviewIndex;
        _mode = previousMode;
        _startedAt = previousStartedAt;
        _attemptId = previousAttemptId;
        _persisted = previousPersisted;
        _displayedCompletedAttempt = previousDisplayedAttempt;
        _starting = false;
      });
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = next;
      _attemptId = next.attemptId!;
      _starting = false;
      _restorePersisted(next);
    });
  }

  List<QuizQuestion> get _missedQuestions => [
    for (final question in _attempt.quiz.questions)
      if (_persisted?.type == PersistedStudyActivityType.quizMistakeReview
          ? _persisted!.itemIds.contains(question.id)
          : _answers[question.id] != question.correctAnswer)
        question,
  ];

  void _initializeAttempt() {
    _attempt = QuizAttemptPresentation.randomized(widget.args.quiz, _random);
    _answers.clear();
    _reviewAnswers.clear();
    _index = 0;
    _reviewIndex = 0;
    _mode = _QuizMode.taking;
    _isCompleting = false;
    _startedAt = DateTime.now().toUtc();
    _attemptId = newUuidV4();
  }

  Future<void> _startPersisted() async {
    final session = await AppStateScope.read(context).startQuizActivity(
      user: AuthScope.read(context).user,
      quiz: _attempt.quiz,
    );
    if (!mounted) return;
    if (session == null) {
      setState(() => _starting = false);
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = session;
      _attemptId = session.attemptId!;
      _starting = false;
      _restorePersisted(session);
    });
  }

  void _restorePersisted(PersistedStudyActivity session) {
    final source = widget.args.quiz;
    final byId = {for (final q in source.questions) q.id: q};
    final restored = <QuizQuestion>[];
    for (final id in session.itemIds) {
      final q = byId[id];
      if (q == null) continue;
      restored.add(
        QuizQuestion(
          id: q.id,
          quizId: q.quizId,
          subjectId: q.subjectId,
          materialId: q.materialId,
          question: q.question,
          options: session.optionOrders[id] ?? q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          topic: q.topic,
          difficulty: q.difficulty,
        ),
      );
    }
    if (restored.length == session.itemIds.length && restored.isNotEmpty) {
      _attempt = QuizAttemptPresentation.fixed(
        Quiz(
          id: source.id,
          subjectId: source.subjectId,
          materialId: source.materialId,
          title: source.title,
          questions: restored,
        ),
      );
    }
    _answers
      ..clear()
      ..addAll(session.selectedAnswers);
    _index = session.currentIndex.clamp(
      0,
      restored.isEmpty ? 0 : restored.length - 1,
    );
    _attemptId = session.attemptId ?? _attemptId;
    if (session.type == PersistedStudyActivityType.quizMistakeReview) {
      _mode = _QuizMode.missedReview;
      _reviewIndex = session.currentIndex.clamp(0, session.itemIds.length - 1);
    }
  }

  Future<void> _answerQuestion(String answer) async {
    final session = _persisted;
    final question = _attempt.quiz.questions[_index];
    if (session == null) {
      setState(() => _answers[question.id] = answer);
      return;
    }
    final updated = await AppStateScope.read(context).updateQuizActivity(
      user: AuthScope.read(context).user,
      session: session,
      currentIndex: _index,
      questionId: question.id,
      answer: answer,
    );
    if (!mounted) return;
    if (updated == null) {
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = updated;
      _answers[question.id] = answer;
    });
  }

  Future<void> _advanceQuiz() async {
    final session = _persisted;
    if (session == null) {
      setState(() => _index += 1);
      return;
    }
    final updated = await AppStateScope.read(context).advanceQuizActivity(
      user: AuthScope.read(context).user,
      session: session,
      currentIndex: _index + 1,
    );
    if (!mounted) return;
    if (updated == null) {
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = updated;
      _index += 1;
    });
  }

  Future<void> _answerMistake(String answer) async {
    setState(() => _reviewAnswers[_missedQuestions[_reviewIndex].id] = answer);
  }

  void _showSessionError() {
    final message =
        AppStateScope.read(context).studyActivityErrorMessage ??
        'Could not save quiz progress.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }

  Future<void> _startMissedReview() async {
    if (AppStateScope.read(context).config.effectiveBackendMode !=
        AppBackendMode.supabase) {
      setState(() {
        _reviewAnswers.clear();
        _reviewIndex = 0;
        _mode = _QuizMode.missedReview;
      });
      return;
    }
    final attemptId = _persisted?.attemptId ?? _attemptId;
    final review = await AppStateScope.read(
      context,
    ).startMistakeReviewActivity(AuthScope.read(context).user, attemptId);
    if (!mounted) return;
    if (review == null) {
      _showSessionError();
      return;
    }
    setState(() {
      _persisted = review;
      _reviewAnswers.clear();
      _reviewIndex = 0;
      _mode = _QuizMode.missedReview;
    });
  }

  Future<void> _advanceMissedReview() async {
    final session = _persisted;
    if (session != null) {
      final updated = await AppStateScope.read(context)
          .updateMistakeReviewActivity(
            user: AuthScope.read(context).user,
            session: session,
            currentIndex: _reviewIndex + 1,
          );
      if (!mounted) return;
      if (updated == null) {
        _showSessionError();
        return;
      }
      _persisted = updated;
    }
    if (_reviewIndex == _missedQuestions.length - 1) {
      setState(() => _mode = _QuizMode.result);
      return;
    }
    setState(() => _reviewIndex += 1);
  }
}

enum _QuizMode { taking, result, missedReview }

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedAnswer,
    required this.onAnswer,
    required this.onNext,
    this.finalActionLabel,
  });

  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswer;
  final VoidCallback? onNext;
  final String? finalActionLabel;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAnswer;
    final hasAnswer = selected != null;
    final isCorrect = selected == question.correctAnswer;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudyProgressHeader(
            current: questionNumber,
            total: totalQuestions,
            label: context.l10n.quizProgress,
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizChoiceTile(
                label: _optionLabel(option),
                selected: option == selected,
                correct: hasAnswer && option == question.correctAnswer,
                incorrect:
                    hasAnswer &&
                    option == selected &&
                    option != question.correctAnswer,
                onPressed: hasAnswer ? null : () => onAnswer(option),
              ),
            ),
          if (hasAnswer) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect
                        ? context.l10n.studyCorrect
                        : context.l10n.studyIncorrect,
                  ),
                  if (!isCorrect) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.studyCorrectAnswer(question.correctAnswer),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(question.explanation),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onNext,
            child: Text(
              questionNumber == totalQuestions
                  ? (finalActionLabel ?? context.l10n.quizShowScore)
                  : context.l10n.commonNext,
            ),
          ),
        ],
      ),
    );
  }

  String _optionLabel(String option) {
    if (selectedAnswer == null) {
      return option;
    }
    if (option == question.correctAnswer) {
      return option;
    }
    if (option == selectedAnswer) {
      return option;
    }
    return option;
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.questions,
    required this.answers,
    required this.attempt,
    required this.isSaving,
    required this.warningMessage,
    required this.onReviewMaterial,
    required this.onRetry,
    required this.onReviewMissed,
  });

  final List<QuizQuestion> questions;
  final Map<String, String> answers;
  final QuizAttempt? attempt;
  final bool isSaving;
  final String? warningMessage;
  final VoidCallback onReviewMaterial;
  final VoidCallback onRetry;
  final VoidCallback? onReviewMissed;

  @override
  Widget build(BuildContext context) {
    final result = attempt;
    final correctCount =
        result?.correctQuestions ??
        questions
            .where((question) => answers[question.id] == question.correctAnswer)
            .length;
    final percent =
        result?.score.round() ??
        ((correctCount / questions.length) * 100).round();
    final weakTopics = result?.weakTopicsSnapshot ?? _weakTopics();

    return StudyCompletionCard(
      title: context.l10n.quizResult,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.quizScore(percent),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(context.l10n.quizCorrectCount(correctCount, questions.length)),
            const SizedBox(height: 16),
            Text(
              context.l10n.quizMissedTopics,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (weakTopics.isEmpty)
              Text(context.l10n.quizNoMissedTopics)
            else
              for (final topic in weakTopics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    topic.missCount > 1
                        ? '${topic.topic} (${context.l10n.studyMisses(topic.missCount)})'
                        : topic.topic,
                  ),
                ),
            if (isSaving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(context.l10n.quizSaving),
            ],
            if (!isSaving && warningMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                '${context.localizedSafeMessage(warningMessage!)} ${context.l10n.quizUnsyncedWarning}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (onReviewMissed != null) ...[
              FilledButton.icon(
                onPressed: onReviewMissed,
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(context.l10n.quizReviewMissed),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: onReviewMaterial,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(context.l10n.quizReviewMaterial),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isSaving ? null : onRetry,
              icon: const Icon(Icons.replay_outlined),
              label: Text(context.l10n.quizRetry),
            ),
          ],
        ),
      ],
    );
  }

  List<QuizWeakTopicSnapshot> _weakTopics() {
    final counts = <String, int>{};
    for (final question in questions) {
      if (answers[question.id] == question.correctAnswer) continue;
      final topic = question.topic.trim();
      if (topic.isEmpty) continue;
      counts.update(topic, (count) => count + 1, ifAbsent: () => 1);
    }
    return [
      for (final entry in counts.entries)
        QuizWeakTopicSnapshot(topic: entry.key, missCount: entry.value),
    ];
  }
}
