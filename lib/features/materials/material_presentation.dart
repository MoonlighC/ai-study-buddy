import 'package:flutter/material.dart';

import '../../app/design_system/tokens.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';

class MaterialHero extends StatelessWidget {
  const MaterialHero({
    required this.title,
    required this.subject,
    required this.typeLabel,
    required this.statusLabel,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String subject;
  final String typeLabel;
  final String statusLabel;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('material-hero'),
    depth: GlassDepth.prominent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subject, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('material-favorite-action'),
              tooltip: isFavorite
                  ? context.l10n.subjectUnfavoriteMaterialTooltip
                  : context.l10n.subjectFavoriteMaterialTooltip,
              onPressed: onFavorite,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('material-overflow-action'),
              tooltip: context.l10n.materialActionsTooltip,
              enabled: onDelete != null,
              onSelected: (_) => onDelete?.call(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.materialDeleteMaterial),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            GlassStatusChip(label: typeLabel, icon: Icons.description_outlined),
            GlassStatusChip(label: statusLabel, icon: Icons.info_outline),
          ],
        ),
      ],
    ),
  );
}

class MaterialStatusPanel extends StatelessWidget {
  const MaterialStatusPanel({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.progress = false,
    this.warning = false,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool progress;
  final bool warning;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: progress,
    label: '$title. $message',
    child: GlassCard(
      key: const ValueKey('material-status-panel'),
      reading: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: warning ? Theme.of(context).colorScheme.tertiary : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message),
          if (progress) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            GlassButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.refresh_rounded,
            ),
          ],
        ],
      ),
    ),
  );
}

class MaterialMetadata extends StatelessWidget {
  const MaterialMetadata({
    required this.rows,
    this.title,
    super.key,
  });
  final List<(String, String)> rows;
  final String? title;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('material-metadata'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? context.l10n.materialDetailsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Text('${row.$1}: ${row.$2}'),
          ),
      ],
    ),
  );
}

class AiOutputSection extends StatelessWidget {
  const AiOutputSection({
    required this.title,
    required this.icon,
    required this.child,
    this.reading = false,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final bool reading;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: ValueKey('ai-output-${title.toLowerCase()}'),
    reading: reading,
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
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class MaterialActionSection extends StatelessWidget {
  const MaterialActionSection({
    required this.title,
    required this.child,
    super.key,
  });
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('material-action-section'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class DestructiveActionSection extends StatelessWidget {
  const DestructiveActionSection({
    required this.onDelete,
    this.deleting = false,
    super.key,
  });
  final VoidCallback? onDelete;
  final bool deleting;
  @override
  Widget build(BuildContext context) => GlassCard(
    key: const ValueKey('destructive-action-section'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.materialDeleteMaterial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(context.l10n.materialDeleteDescription),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          button: true,
          label: context.l10n.materialDeleteMaterial,
          child: OutlinedButton.icon(
            onPressed: deleting ? null : onDelete,
            icon: deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(
              deleting
                  ? context.l10n.materialDeleting
                  : context.l10n.materialDeleteMaterial,
            ),
          ),
        ),
      ],
    ),
  );
}
