import 'package:flutter/material.dart';

import 'design_system/theme_extensions.dart';
import 'design_system/tokens.dart';

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
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
  final baseTextTheme = Typography.material2021().black;
  return ThemeData(
    colorScheme: colorScheme,
    textTheme: baseTextTheme.copyWith(
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 28,
        height: 1.18,
        fontWeight: FontWeight.w700,
        color: AppColors.textStrong,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.textStrong,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.textStrong,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: AppColors.textStrong,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: AppColors.text,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: AppColors.text,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AppColors.textMuted,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.canvas,
    focusColor: AppColors.primary.withValues(alpha: 0.16),
    hoverColor: AppColors.primary.withValues(alpha: 0.08),
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
      color: AppColors.canvasElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: Color(0xFFD5DDE9)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xEFFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: Color(0xFFCAD4E2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF5F8FAFE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.prominent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
    extensions: const [AppGlassTheme.light(), AppEffectsTheme()],
  );
}
