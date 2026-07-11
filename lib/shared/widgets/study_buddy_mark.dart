import 'package:flutter/material.dart';

import '../../app/design_system/tokens.dart';

enum StudyBuddyMarkVariant { fullColor, flat, monochrome }

/// The AI Study Buddy "Guided S Path" brand mark.
///
/// The artwork is drawn from a normalized 100 x 100 coordinate system and has
/// no asset or network dependency.
class StudyBuddyMark extends StatelessWidget {
  const StudyBuddyMark({
    this.size = 40,
    this.variant = StudyBuddyMarkVariant.fullColor,
    this.color,
    this.secondaryColor,
    this.accentColor,
    this.semanticLabel = 'AI Study Buddy',
    this.excludeFromSemantics = false,
    super.key,
  }) : assert(size > 0);

  final double size;
  final StudyBuddyMarkVariant variant;
  final Color? color;
  final Color? secondaryColor;
  final Color? accentColor;
  final String semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final primary =
        color ??
        switch (variant) {
          StudyBuddyMarkVariant.fullColor => AppColors.primary,
          StudyBuddyMarkVariant.flat => Theme.of(context).colorScheme.onSurface,
          StudyBuddyMarkVariant.monochrome => Theme.of(
            context,
          ).colorScheme.onSurface,
        };
    final secondary = switch (variant) {
      StudyBuddyMarkVariant.fullColor => secondaryColor ?? AppColors.secondary,
      StudyBuddyMarkVariant.flat || StudyBuddyMarkVariant.monochrome => primary,
    };
    final accent = switch (variant) {
      StudyBuddyMarkVariant.fullColor => accentColor ?? AppColors.accent,
      StudyBuddyMarkVariant.flat || StudyBuddyMarkVariant.monochrome => primary,
    };

    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StudyBuddyMarkPainter(
          primary: primary,
          secondary: secondary,
          accent: accent,
        ),
      ),
    );

    if (excludeFromSemantics) return ExcludeSemantics(child: mark);
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class StudyBuddyLockup extends StatelessWidget {
  const StudyBuddyLockup({
    this.size = 40,
    this.variant = StudyBuddyMarkVariant.fullColor,
    this.color,
    this.secondaryColor,
    this.accentColor,
    this.semanticLabel = 'AI Study Buddy',
    this.excludeFromSemantics = false,
    super.key,
  }) : assert(size > 0);

  final double size;
  final StudyBuddyMarkVariant variant;
  final Color? color;
  final Color? secondaryColor;
  final Color? accentColor;
  final String semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudyBuddyMark(
          size: size,
          variant: variant,
          color: color,
          secondaryColor: secondaryColor,
          accentColor: accentColor,
          excludeFromSemantics: true,
        ),
        SizedBox(width: size * 0.3),
        Text(
          'AI Study Buddy',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: color, fontSize: size * 0.45),
        ),
      ],
    );
    if (excludeFromSemantics) return ExcludeSemantics(child: content);
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: content,
    );
  }
}

class _StudyBuddyMarkPainter extends CustomPainter {
  const _StudyBuddyMarkPainter({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    final compact = size.shortestSide <= 24;
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(scale);

    final upperRibbon = Path()
      ..moveTo(8, compact ? 25 : 24)
      ..lineTo(15, 29)
      ..cubicTo(31, 18, 54, compact ? 15 : 13, 77, compact ? 18 : 17)
      ..lineTo(93, 25)
      ..lineTo(84, 30)
      ..cubicTo(70, 33, 61, 40, 52, 48)
      ..cubicTo(45, 54, 38, 57, 30, 55)
      ..cubicTo(20, 52, 13, 46, 8, compact ? 41 : 40)
      ..close();
    final lowerRibbon = Path()
      ..moveTo(92, 58)
      ..lineTo(compact ? 86 : 85, compact ? 62 : 63)
      ..cubicTo(70, compact ? 62 : 63, 60, 69, 50, 77)
      ..cubicTo(42, 84, 34, compact ? 87 : 88, 24, compact ? 84 : 85)
      ..lineTo(compact ? 8 : 7, 76)
      ..lineTo(16, 72)
      ..cubicTo(30, 69, 39, 62, 48, 54)
      ..cubicTo(55, 48, 62, compact ? 45 : 44, 70, compact ? 47 : 46)
      ..cubicTo(80, 48, 87, 54, 92, 58)
      ..close();

    canvas.drawPath(upperRibbon, Paint()..color = primary);
    canvas.drawPath(lowerRibbon, Paint()..color = secondary);
    canvas.drawCircle(
      Offset(compact ? 84 : 85, compact ? 39 : 38),
      compact ? 5 : 4.8,
      Paint()..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StudyBuddyMarkPainter oldDelegate) =>
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary ||
      accent != oldDelegate.accent;
}
