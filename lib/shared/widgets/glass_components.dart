import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/design_system/effects.dart';
import '../../app/design_system/theme_extensions.dart';
import '../../app/design_system/tokens.dart';

enum GlassDepth { subtle, standard, prominent }

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.depth = GlassDepth.standard,
    this.padding,
    this.borderRadius,
    this.tint,
    this.reading = false,
    this.blurSigma,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final GlassDepth depth;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? tint;
  final bool reading;
  final double? blurSigma;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final effects = context.effectsTheme;
    final visualEffects = AppVisualEffects.of(context);
    final radius = borderRadius ?? BorderRadius.circular(_radiusForDepth());
    final baseTint =
        tint ??
        (reading
            ? glass.readingTint
            : switch (depth) {
                GlassDepth.subtle => glass.subtleTint,
                GlassDepth.standard => glass.standardTint,
                GlassDepth.prominent => glass.prominentTint,
              });
    final effectiveTint = visualEffects.lowEffects
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: effects.lowEffectsTintBoost),
            baseTint,
          )
        : baseTint;
    final sigma =
        blurSigma ??
        switch (depth) {
          GlassDepth.subtle => effects.subtleBlur,
          GlassDepth.standard => effects.standardBlur,
          GlassDepth.prominent => effects.prominentBlur,
        };
    final topLight = Color.alphaBlend(
      glass.highlight.withValues(alpha: 0.14),
      effectiveTint,
    );
    final innerTint = Color.alphaBlend(
      glass.highlight.withValues(alpha: 0.05),
      effectiveTint,
    );

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            topLight,
            innerTint,
            effectiveTint.withValues(alpha: effectiveTint.a * 0.9),
          ],
          stops: const [0, 0.38, 1],
        ),
        borderRadius: radius,
        border: Border.all(
          color: visualEffects.lowEffects
              ? glass.border.withValues(alpha: 0.9)
              : glass.border.withValues(alpha: 0.66),
          width: visualEffects.lowEffects ? 1 : 0.8,
        ),
        boxShadow: switch (depth) {
          GlassDepth.subtle => AppShadows.soft,
          GlassDepth.standard => AppShadows.floating,
          GlassDepth.prominent => AppShadows.modal,
        },
      ),
      child: CustomPaint(
        foregroundPainter: _GlassEdgePainter(
          radius: radius.topLeft.x,
          color: glass.highlight,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    if (!visualEffects.lowEffects) {
      content = BackdropFilter(
        key: const ValueKey('glass-backdrop-filter'),
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    content = ClipRRect(borderRadius: radius, child: content);
    if (semanticLabel != null) {
      content = Semantics(
        container: true,
        label: semanticLabel,
        child: content,
      );
    }
    return content;
  }

  double _radiusForDepth() => switch (depth) {
    GlassDepth.subtle => AppRadii.control,
    GlassDepth.standard => AppRadii.card,
    GlassDepth.prominent => AppRadii.prominent,
  };
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final edgeBounds = Rect.fromLTWH(
      0,
      0,
      size.width * 0.5,
      size.height * 0.38,
    );
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.55)
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.58),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.44, 1],
      ).createShader(edgeBounds);
    final edgePath = Path()
      ..moveTo(1, size.height * 0.3)
      ..lineTo(1, radius + 2)
      ..quadraticBezierTo(1, 1, radius + 2, 1)
      ..lineTo(size.width * 0.44, 1);
    canvas.drawPath(edgePath, edgePaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4)
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(4, 4, size.width * 0.3, radius + 8));
    final innerPath = Path()
      ..moveTo(4, radius + 5)
      ..quadraticBezierTo(4, 4, radius + 4, 4)
      ..lineTo(size.width * 0.25, 4);
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) =>
      radius != oldDelegate.radius || color != oldDelegate.color;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.depth = GlassDepth.standard,
    this.reading = false,
    this.tint,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final GlassDepth depth;
  final bool reading;
  final Color? tint;

  @override
  Widget build(BuildContext context) => GlassSurface(
    depth: depth,
    padding: padding,
    reading: reading,
    tint: tint,
    child: child,
  );
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.prominent = false,
    this.keyValue,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool prominent;
  final Key? keyValue;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: keyValue,
            onTap: onPressed,
            canRequestFocus: onPressed != null,
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: GlassSurface(
              depth: prominent ? GlassDepth.prominent : GlassDepth.subtle,
              borderRadius: BorderRadius.circular(AppRadii.control),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppIconSizes.control),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(child: Text(label)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class GlassDialog extends StatelessWidget {
  const GlassDialog({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: GlassSurface(
      depth: GlassDepth.prominent,
      reading: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: child,
    ),
  );
}

class GlassStatusChip extends StatelessWidget {
  const GlassStatusChip({
    required this.label,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => GlassSurface(
    depth: GlassDepth.subtle,
    borderRadius: BorderRadius.circular(AppRadii.navigation),
    tint: color?.withValues(alpha: 0.22),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSizes.metadata, color: color),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            canRequestFocus: onTap != null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.titleMedium,
                          child: title,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          DefaultTextStyle.merge(
                            style: Theme.of(context).textTheme.bodySmall,
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      if (showDivider)
        const Divider(
          height: 1,
          indent: AppSpacing.md,
          endIndent: AppSpacing.md,
        ),
    ],
  );
}
