import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/design_system/tokens.dart';
import 'glass_components.dart';

class StudyContextHeader extends StatelessWidget {
  const StudyContextHeader({
    required this.title,
    required this.subtitle,
    this.status,
    super.key,
  });
  final String title;
  final String subtitle;
  final String? status;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle),
        if (status != null) ...[
          const SizedBox(height: AppSpacing.sm),
          GlassStatusChip(label: status!, icon: Icons.layers_outlined),
        ],
      ],
    ),
  );
}

class StudyProgressHeader extends StatelessWidget {
  const StudyProgressHeader({
    required this.current,
    required this.total,
    this.label = 'Study progress',
    super.key,
  });
  final int current;
  final int total;
  final String label;
  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : current / total;
    return Semantics(
      key: const ValueKey('study-progress'),
      label: label,
      value: '$current of $total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$current / $total'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: value.clamp(0, 1)),
        ],
      ),
    );
  }
}

class FlashcardSurface extends StatelessWidget {
  const FlashcardSurface({
    required this.front,
    required this.back,
    required this.isAnswerVisible,
    required this.onToggleAnswer,
    this.metadata,
    this.trailing,
    super.key,
  });
  final String front;
  final String back;
  final bool isAnswerVisible;
  final VoidCallback onToggleAnswer;
  final String? metadata;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    void activate() => onToggleAnswer();
    return Semantics(
      key: ValueKey('flashcard-${isAnswerVisible ? 'back' : 'front'}'),
      button: true,
      label: isAnswerVisible
          ? 'Flashcard answer. Activate to hide answer.'
          : 'Flashcard question. Activate to show answer.',
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activate();
              return null;
            },
          ),
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: activate,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: GlassCard(
              reading: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isAnswerVisible ? 'Answer' : 'Question',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isAnswerVisible ? back : front,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (metadata != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      metadata!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RatingActionRow extends StatelessWidget {
  const RatingActionRow({
    required this.onMissed,
    required this.onKnown,
    super.key,
  });
  final VoidCallback onMissed;
  final VoidCallback onKnown;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('rating-missed'),
        onPressed: onMissed,
        icon: const Icon(Icons.refresh_outlined),
        label: const Text('I missed it'),
      ),
      FilledButton.icon(
        key: const ValueKey('rating-known'),
        onPressed: onKnown,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('I knew it'),
      ),
    ],
  );
}

class QuizChoiceTile extends StatelessWidget {
  const QuizChoiceTile({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.correct = false,
    this.incorrect = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool correct;
  final bool incorrect;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = correct
        ? AppColors.success
        : incorrect
        ? scheme.error
        : selected
        ? scheme.primary
        : scheme.outline;
    final icon = correct
        ? Icons.check_circle
        : incorrect
        ? Icons.cancel
        : selected
        ? Icons.radio_button_checked
        : Icons.radio_button_unchecked;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label:
          '$label${correct
              ? ', correct answer'
              : incorrect
              ? ', incorrect answer'
              : ''}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            side: BorderSide(
              color: color,
              width: selected || correct || incorrect ? 2 : 1,
            ),
          ),
          icon: Icon(icon, color: color),
          label: Align(alignment: Alignment.centerLeft, child: Text(label)),
        ),
      ),
    );
  }
}

class StudyCompletionCard extends StatelessWidget {
  const StudyCompletionCard({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('study-completion'),
    container: true,
    label: title,
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class FocusTopicRow extends StatelessWidget {
  const FocusTopicRow({
    required this.topic,
    required this.subject,
    required this.missCount,
    super.key,
  });
  final String topic;
  final String subject;
  final int missCount;
  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('focus-topic-$topic'),
    leading: const Icon(Icons.flag_outlined),
    title: Text(topic),
    subtitle: Text(subject),
    trailing: Text(missCount == 1 ? '1 miss' : '$missCount misses'),
  );
}

class AttemptSummaryCard extends StatelessWidget {
  const AttemptSummaryCard({
    this.score,
    this.correct,
    this.total,
    required this.attemptCount,
    super.key,
  });
  final double? score;
  final int? correct;
  final int? total;
  final int attemptCount;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          score == null
              ? 'Complete a quiz to see results here.'
              : 'Score: ${score!.round()}%',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (correct != null && total != null) Text('$correct / $total correct'),
        const SizedBox(height: AppSpacing.sm),
        const Text('Attempts completed'),
        Text(
          '$attemptCount ${attemptCount == 1 ? 'attempt' : 'attempts'} completed',
        ),
      ],
    ),
  );
}

class StudyModeCard extends StatelessWidget {
  const StudyModeCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.school_outlined,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle!),
        ],
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}
