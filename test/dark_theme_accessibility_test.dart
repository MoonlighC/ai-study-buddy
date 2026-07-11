import 'package:ai_study_buddy/app/design_system/effects.dart';
import 'package:ai_study_buddy/app/design_system/theme_extensions.dart';
import 'package:ai_study_buddy/app/theme.dart';
import 'package:ai_study_buddy/shared/widgets/glass_components.dart';
import 'package:ai_study_buddy/shared/widgets/study_buddy_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme baseline remains stable and dark recipe is dedicated', () {
    final light = buildAppTheme(Brightness.light);
    final dark = buildAppTheme(Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF1F5FB));
    expect(light.colorScheme.primary, const Color(0xFF315EA8));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF0B1220));
    expect(dark.colorScheme.surface, const Color(0xFF111B2C));
    expect(dark.extension<AppGlassTheme>(), const AppGlassTheme.dark());
  });

  test('representative opaque and composited semantic pairs meet contrast', () {
    final theme = buildAppTheme(Brightness.dark);
    final glass = theme.extension<AppGlassTheme>()!;
    final canvas = theme.scaffoldBackgroundColor;
    final reading = Color.alphaBlend(glass.readingTint, canvas);
    final pairs = <(Color, Color, double)>[
      (theme.colorScheme.onSurface, canvas, 4.5),
      (theme.textTheme.bodyMedium!.color!, reading, 4.5),
      (theme.colorScheme.onPrimary, theme.colorScheme.primary, 4.5),
      (theme.colorScheme.error, canvas, 4.5),
      (const Color(0xFF72D6A5), canvas, 4.5),
      (const Color(0xFFF0BA6A), canvas, 4.5),
      (glass.focusRing, canvas, 3),
    ];
    for (final pair in pairs) {
      expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(pair.$3));
    }
  });

  testWidgets('dark low effects removes blur but reduced motion preserves it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: const AppVisualEffects(
          lowEffects: true,
          child: Scaffold(body: GlassSurface(child: Text('opaque'))),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: const AppVisualEffects(
          lowEffects: false,
          reducedMotion: true,
          child: Scaffold(body: GlassSurface(child: Text('blurred'))),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('system ThemeMode uses emulated platform brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (context) => Text(Theme.of(context).brightness.name),
        ),
      ),
    );
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('brand variants remain visible at compact sizes in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: const Scaffold(
          body: Row(
            children: [
              StudyBuddyMark(size: 16),
              StudyBuddyMark(size: 24, variant: StudyBuddyMarkVariant.flat),
              StudyBuddyMark(
                size: 24,
                variant: StudyBuddyMarkVariant.monochrome,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(StudyBuddyMark), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
