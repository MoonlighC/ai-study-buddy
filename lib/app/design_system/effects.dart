import 'package:flutter/material.dart';

class AppVisualEffects extends InheritedWidget {
  const AppVisualEffects({
    required super.child,
    this.lowEffects = false,
    this.reducedMotion,
    super.key,
  });

  final bool lowEffects;
  final bool? reducedMotion;

  static AppVisualEffectsData of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<AppVisualEffects>();
    final media = MediaQuery.maybeOf(context);
    return AppVisualEffectsData(
      lowEffects: inherited?.lowEffects ?? false,
      reducedMotion:
          inherited?.reducedMotion ?? media?.disableAnimations ?? false,
    );
  }

  @override
  bool updateShouldNotify(AppVisualEffects oldWidget) =>
      lowEffects != oldWidget.lowEffects ||
      reducedMotion != oldWidget.reducedMotion;
}

@immutable
class AppVisualEffectsData {
  const AppVisualEffectsData({
    required this.lowEffects,
    required this.reducedMotion,
  });

  final bool lowEffects;
  final bool reducedMotion;
}
