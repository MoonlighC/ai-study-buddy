import 'package:flutter/material.dart';

import 'design_system/theme_extensions.dart';
import 'design_system/tokens.dart';

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: AppColors.darkPrimary,
          onPrimary: Color(0xFF102344),
          primaryContainer: Color(0xFF29466F),
          onPrimaryContainer: Color(0xFFE0EAFF),
          secondary: AppColors.darkSecondary,
          onSecondary: Color(0xFF082F2E),
          secondaryContainer: Color(0xFF244B4A),
          onSecondaryContainer: Color(0xFFD5F7F2),
          tertiary: AppColors.darkAccent,
          onTertiary: Color(0xFF3D2604),
          tertiaryContainer: Color(0xFF60451D),
          onTertiaryContainer: Color(0xFFFFE3B5),
          error: AppColors.darkError,
          onError: Color(0xFF4A0710),
          errorContainer: Color(0xFF64232B),
          onErrorContainer: Color(0xFFFFD9DD),
          surface: AppColors.darkCanvasElevated,
          onSurface: AppColors.darkTextStrong,
          onSurfaceVariant: AppColors.darkText,
          outline: AppColors.darkBorder,
          outlineVariant: Color(0xFF536177),
          shadow: Color(0xFF000712),
          scrim: Color(0xFF00040B),
        )
      : const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFD9E6FA),
          onPrimaryContainer: Color(0xFF17345F),
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFD5ECE8),
          onSecondaryContainer: Color(0xFF173F3C),
          tertiary: AppColors.accent,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFF5E3CA),
          onTertiaryContainer: Color(0xFF533510),
          error: AppColors.error,
          onError: Colors.white,
          errorContainer: Color(0xFFF8DDE0),
          onErrorContainer: Color(0xFF5F1720),
          surface: AppColors.canvasElevated,
          onSurface: AppColors.textStrong,
          onSurfaceVariant: AppColors.text,
          outline: AppColors.border,
          outlineVariant: Color(0xFFD5DDE9),
          shadow: Color(0xFF263A5D),
          scrim: Color(0xFF15233A),
        );
  final base = dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  final strong = dark ? AppColors.darkTextStrong : AppColors.textStrong;
  final body = dark ? AppColors.darkText : AppColors.text;
  final muted = dark ? AppColors.darkTextMuted : AppColors.textMuted;
  final textTheme = base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 28,
      height: 1.18,
      fontWeight: FontWeight.w700,
      color: strong,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: strong,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: strong,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: strong,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5, color: body),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.45,
      color: body,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.4,
      color: muted,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.control),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? AppColors.darkCanvas : AppColors.canvas,
    focusColor: (dark ? AppColors.darkPrimary : AppColors.primary).withValues(
      alpha: 0.22,
    ),
    hoverColor: scheme.primary.withValues(alpha: 0.12),
    splashColor: scheme.primary.withValues(alpha: 0.16),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xF21B293D) : const Color(0xEFFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(
          color: dark ? const Color(0xFFA9C7FF) : AppColors.primary,
          width: 2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outline),
      shape: controlShape,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFA172438) : const Color(0xF5F8FAFE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.prominent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF26364D) : const Color(0xFF263A5D),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: controlShape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFF3F6FC) : const Color(0xFF182133),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      textStyle: TextStyle(
        color: dark ? const Color(0xFF111B2C) : Colors.white,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
    ),
    extensions: [
      dark ? const AppGlassTheme.dark() : const AppGlassTheme.light(),
      const AppEffectsTheme(),
    ],
  );
}
