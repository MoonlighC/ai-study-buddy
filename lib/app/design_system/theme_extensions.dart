import 'package:flutter/material.dart';

@immutable
class AppGlassTheme extends ThemeExtension<AppGlassTheme> {
  const AppGlassTheme({
    required this.subtleTint,
    required this.standardTint,
    required this.prominentTint,
    required this.readingTint,
    required this.navigationTint,
    required this.activeLayerTint,
    required this.border,
    required this.highlight,
    required this.shadow,
  });

  const AppGlassTheme.light()
    : subtleTint = const Color(0x58ECF3FC),
      standardTint = const Color(0x64E5EFFA),
      prominentTint = const Color(0x94EEF4FC),
      readingTint = const Color(0xD1F7FAFE),
      navigationTint = const Color(0x34DCE9F8),
      activeLayerTint = const Color(0x30FFFFFF),
      border = const Color(0x70AFC2DD),
      highlight = const Color(0xF2FFFFFF),
      shadow = const Color(0x2B263A5D);

  final Color subtleTint;
  final Color standardTint;
  final Color prominentTint;
  final Color readingTint;
  final Color navigationTint;
  final Color activeLayerTint;
  final Color border;
  final Color highlight;
  final Color shadow;

  @override
  AppGlassTheme copyWith({
    Color? subtleTint,
    Color? standardTint,
    Color? prominentTint,
    Color? readingTint,
    Color? navigationTint,
    Color? activeLayerTint,
    Color? border,
    Color? highlight,
    Color? shadow,
  }) => AppGlassTheme(
    subtleTint: subtleTint ?? this.subtleTint,
    standardTint: standardTint ?? this.standardTint,
    prominentTint: prominentTint ?? this.prominentTint,
    readingTint: readingTint ?? this.readingTint,
    navigationTint: navigationTint ?? this.navigationTint,
    activeLayerTint: activeLayerTint ?? this.activeLayerTint,
    border: border ?? this.border,
    highlight: highlight ?? this.highlight,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppGlassTheme lerp(covariant AppGlassTheme? other, double t) {
    if (other == null) return this;
    return AppGlassTheme(
      subtleTint: Color.lerp(subtleTint, other.subtleTint, t)!,
      standardTint: Color.lerp(standardTint, other.standardTint, t)!,
      prominentTint: Color.lerp(prominentTint, other.prominentTint, t)!,
      readingTint: Color.lerp(readingTint, other.readingTint, t)!,
      navigationTint: Color.lerp(navigationTint, other.navigationTint, t)!,
      activeLayerTint: Color.lerp(activeLayerTint, other.activeLayerTint, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

@immutable
class AppEffectsTheme extends ThemeExtension<AppEffectsTheme> {
  const AppEffectsTheme({
    this.subtleBlur = 10,
    this.standardBlur = 18,
    this.prominentBlur = 24,
    this.lowEffectsTintBoost = 0.28,
  });

  final double subtleBlur;
  final double standardBlur;
  final double prominentBlur;
  final double lowEffectsTintBoost;

  @override
  AppEffectsTheme copyWith({
    double? subtleBlur,
    double? standardBlur,
    double? prominentBlur,
    double? lowEffectsTintBoost,
  }) => AppEffectsTheme(
    subtleBlur: subtleBlur ?? this.subtleBlur,
    standardBlur: standardBlur ?? this.standardBlur,
    prominentBlur: prominentBlur ?? this.prominentBlur,
    lowEffectsTintBoost: lowEffectsTintBoost ?? this.lowEffectsTintBoost,
  );

  @override
  AppEffectsTheme lerp(covariant AppEffectsTheme? other, double t) {
    if (other == null) return this;
    return AppEffectsTheme(
      subtleBlur: lerpDouble(subtleBlur, other.subtleBlur, t),
      standardBlur: lerpDouble(standardBlur, other.standardBlur, t),
      prominentBlur: lerpDouble(prominentBlur, other.prominentBlur, t),
      lowEffectsTintBoost: lerpDouble(
        lowEffectsTintBoost,
        other.lowEffectsTintBoost,
        t,
      ),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppThemeContext on BuildContext {
  AppGlassTheme get glassTheme =>
      Theme.of(this).extension<AppGlassTheme>() ?? const AppGlassTheme.light();

  AppEffectsTheme get effectsTheme =>
      Theme.of(this).extension<AppEffectsTheme>() ?? const AppEffectsTheme();
}

Color safeSubjectColor(int value) {
  final color = Color(value);
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.35, 0.72).toDouble())
      .withLightness(hsl.lightness.clamp(0.34, 0.56).toDouble())
      .toColor();
}
