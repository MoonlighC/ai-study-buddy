import 'package:ai_study_buddy/app/design_system/effects.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/shared/widgets/glass_components.dart';
import 'package:ai_study_buddy/shared/widgets/responsive_app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mobile_qa_harness.dart';

void main() {
  Widget shell({String route = AppRoutes.subjects}) => ResponsiveAppScaffold(
    title: 'Workspace',
    activeRoute: route,
    body: ResponsiveContent(
      child: ListView(children: const [SizedBox(height: 900)]),
    ),
  );

  testWidgets('authoritative breakpoints switch one shell presentation', (
    tester,
  ) async {
    await setQaViewport(tester, size: const Size(599, 800));
    await tester.pumpWidget(qaApp(home: shell()));
    expect(find.byType(GlassNavigationBar), findsOneWidget);
    expect(find.byType(GlassNavigationRail), findsNothing);

    tester.view.physicalSize = const Size(600, 800);
    await boundedPump(tester);
    expect(find.byType(GlassNavigationBar), findsNothing);
    expect(find.byType(GlassNavigationRail), findsOneWidget);
    expect(
      tester
          .widget<GlassNavigationRail>(find.byType(GlassNavigationRail))
          .extended,
      isFalse,
    );

    tester.view.physicalSize = const Size(1023, 800);
    await boundedPump(tester);
    expect(
      tester
          .widget<GlassNavigationRail>(find.byType(GlassNavigationRail))
          .extended,
      isFalse,
    );

    tester.view.physicalSize = const Size(1024, 800);
    await boundedPump(tester);
    expect(find.byType(GlassNavigationRail), findsOneWidget);
    expect(
      tester
          .widget<GlassNavigationRail>(find.byType(GlassNavigationRail))
          .extended,
      isTrue,
    );
    expect(find.bySemanticsLabel('Subjects'), findsWidgets);
    expectNoFrameworkException(tester);
  });

  testWidgets('required widths remain structurally responsive', (tester) async {
    await setQaViewport(tester, size: const Size(320, 844));
    await tester.pumpWidget(qaApp(home: shell()));
    for (final width in <double>[320, 360, 390, 600, 800, 1024, 1280]) {
      tester.view.physicalSize = Size(width, 844);
      await boundedPump(tester);
      expect(find.byType(ResponsiveAppScaffold), findsOneWidget);
      expectNoFrameworkException(tester);
    }
  });

  testWidgets('intermediate text scale and desktop platform remain usable', (
    tester,
  ) async {
    await setQaViewport(tester, size: const Size(800, 700));
    await tester.pumpWidget(
      qaApp(home: shell(), textScale: 1.5, platform: TargetPlatform.windows),
    );
    expect(find.byType(GlassNavigationRail), findsOneWidget);
    expect(find.bySemanticsLabel('Subjects'), findsWidgets);
    expectNoFrameworkException(tester);
  });

  for (final locale in const [Locale('de'), Locale('ru')]) {
    for (final brightness in const [Brightness.light, Brightness.dark]) {
      testWidgets('320px ${locale.languageCode} 200% ${brightness.name}', (
        tester,
      ) async {
        await setQaViewport(tester, size: const Size(320, 844));
        await tester.pumpWidget(
          qaApp(
            home: shell(),
            locale: locale,
            brightness: brightness,
            textScale: 2,
          ),
        );
        expect(find.byType(GlassNavigationBar), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('.+')), findsWidgets);
        expectNoFrameworkException(tester);
      });
    }
  }

  testWidgets('shell applies side and bottom system insets once', (
    tester,
  ) async {
    await setQaViewport(tester, size: const Size(390, 500));
    await tester.pumpWidget(
      qaApp(home: shell(), padding: const EdgeInsets.fromLTRB(18, 24, 22, 28)),
    );
    final navRect = tester.getRect(find.byType(GlassNavigationBar));
    expect(navRect.left, 30);
    expect(390 - navRect.right, 34);
    expect(500 - navRect.bottom, 38);
  });

  testWidgets(
    'dialog recomputes height above keyboard and remains scrollable',
    (tester) async {
      await setQaViewport(tester, size: const Size(320, 560));
      await tester.pumpWidget(
        qaApp(
          viewInsets: const EdgeInsets.only(bottom: 240),
          textScale: 2,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => GlassDialog(
                    child: Column(
                      children: [
                        const Text('Long dialog content'),
                        const SizedBox(height: 500),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await boundedPump(tester);
      final scroll = find.byKey(const ValueKey('glass-dialog-scroll-view'));
      expect(scroll, findsOneWidget);
      expect(tester.getRect(scroll).bottom, lessThanOrEqualTo(304));
      expectNoFrameworkException(tester);
    },
  );

  testWidgets('blur stays clipped and low effects removes it', (tester) async {
    await setQaViewport(tester, size: const Size(390, 500));
    await tester.pumpWidget(qaApp(home: shell()));
    for (final blur in find.byType(BackdropFilter).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(blur.widget),
          matching: find.byType(ClipRRect),
        ),
        findsWidgets,
      );
      expect(blur.size, isNotNull);
      expect(blur.size!.isFinite, isTrue);
    }

    await tester.pumpWidget(
      qaApp(home: AppVisualEffects(lowEffects: true, child: shell())),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
