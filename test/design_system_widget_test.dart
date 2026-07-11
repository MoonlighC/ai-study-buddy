import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/design_system/effects.dart';
import 'package:ai_study_buddy/app/design_system/theme_extensions.dart';
import 'package:ai_study_buddy/app/design_system/tokens.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/app/theme.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:ai_study_buddy/shared/widgets/app_bottom_nav.dart';
import 'package:ai_study_buddy/shared/widgets/glass_components.dart';
import 'package:ai_study_buddy/shared/widgets/responsive_app_scaffold.dart';
import 'package:ai_study_buddy/shared/widgets/study_buddy_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone uses only the floating glass navigation bar', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpWorkspace(tester);

    expect(find.byType(GlassNavigationBar), findsOneWidget);
    expect(find.byType(GlassNavigationRail), findsNothing);
    expect(find.byType(AppBottomNav), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
  });

  testWidgets('home top bar uses the original application mark', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpWorkspace(tester);

    expect(find.byType(StudyBuddyMark), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
  });

  testWidgets('phone navigation overlays scrollable content with clearance', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpWorkspace(tester, bottomInset: 24);

    final navigation = find.byType(GlassNavigationBar);
    final scrollable = find.byKey(const ValueKey('home-scroll-view'));
    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('responsive-app-scaffold')),
    );
    final contentPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('responsive-content-padding')),
    );

    expect(scaffold.bottomNavigationBar, isNull);
    expect(scaffold.backgroundColor, Colors.transparent);
    expect(
      find.byKey(const ValueKey('phone-shell-overlay-stack')),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: navigation, matching: find.byType(Positioned)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigation, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(navigation).dy,
      lessThan(tester.getBottomLeft(scrollable).dy),
    );
    expect(
      contentPadding.padding.resolve(TextDirection.ltr).bottom,
      greaterThanOrEqualTo(AppShellMetrics.phoneNavigationScrollClearance + 24),
    );
    expect(
      tester.element(navigation).glassTheme.navigationTint.a,
      inInclusiveRange(0.14, 0.24),
    );

    final opaqueMaterialAncestors = tester
        .widgetList<Material>(
          find.ancestor(of: navigation, matching: find.byType(Material)),
        )
        .where((material) => (material.color?.a ?? 0) >= 0.99);
    expect(opaqueMaterialAncestors, isEmpty);
  });

  testWidgets('tablet and desktop use only the glass navigation rail', (
    tester,
  ) async {
    for (final size in [const Size(800, 900), const Size(1280, 900)]) {
      await _setViewport(tester, size);
      await _pumpWorkspace(tester);

      expect(find.byType(GlassNavigationRail), findsOneWidget);
      expect(find.byType(GlassNavigationBar), findsNothing);
      expect(find.byType(AppBottomNav), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(GlassNavigationRail),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(GlassNavigationRail),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('subject hero starts below the non-overlapping top bar', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpWorkspace(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.subjectDetail, arguments: MockData.subjects.first);
    await tester.pumpAndSettle();

    final topBar = find.byType(AppTopBar);
    final hero = find.byKey(const ValueKey('subject-hero'));
    final scrollable = find.byKey(const ValueKey('subject-detail-scroll-view'));
    final initialTopBarRect = tester.getRect(topBar);

    expect(
      tester.getRect(hero).top,
      greaterThanOrEqualTo(initialTopBarRect.bottom),
    );
    expect(
      tester.getRect(scrollable).top,
      greaterThanOrEqualTo(initialTopBarRect.bottom),
    );

    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getRect(topBar), initialTopBarRect);
    expect(
      tester.getRect(scrollable).top,
      greaterThanOrEqualTo(initialTopBarRect.bottom),
    );
  });

  testWidgets('home destination keeps existing named-route behavior', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpWorkspace(tester);

    await tester.tap(find.byKey(const ValueKey('nav-subjects')));
    await tester.pumpAndSettle();

    expect(find.text('Your subjects'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).widget.initialRoute,
      anyOf(isNull, AppRoutes.dashboard),
    );
  });

  testWidgets('subject detail has one shell and preserves back behavior', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    await _pumpWorkspace(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pushNamed(
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResponsiveAppScaffold), findsOneWidget);
    expect(find.byType(GlassNavigationRail), findsOneWidget);
    expect(find.byType(GlassNavigationBar), findsNothing);
    expect(find.byType(AppBottomNav), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('app-back-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
  });

  testWidgets('low effects is deterministic and removes blur only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const AppVisualEffects(
          lowEffects: true,
          reducedMotion: false,
          child: Scaffold(
            body: GlassSurface(child: Text('Low effects surface')),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Low effects surface'), findsOneWidget);
  });

  testWidgets('reduced motion does not disable glass blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const AppVisualEffects(
          lowEffects: false,
          child: Scaffold(body: GlassSurface(child: Text('Reduced motion'))),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('home omits fictional progress metrics', (tester) async {
    await _setViewport(tester, const Size(1280, 900));
    await _pumpWorkspace(tester);

    expect(find.textContaining('streak', findRichText: true), findsNothing);
    expect(find.text('Knowledge score summary'), findsNothing);
    expect(find.text('Recent study sessions'), findsNothing);
    expect(find.text('Mock-only data'), findsNothing);
  });

  testWidgets('critical proof controls survive 200 percent text scaling', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      await _setViewport(tester, size);
      await _pumpWorkspace(tester, textScale: 2);

      expect(find.byKey(const ValueKey('home-open-subjects')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(
        AppRoutes.subjectDetail,
        arguments: MockData.subjects.first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subject-add-pasted-text')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('subject-upload-pdf')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('rail destinations support keyboard activation', (tester) async {
    await _setViewport(tester, const Size(800, 900));
    await _pumpWorkspace(tester);

    final focus = tester.widget<Focus>(
      find.byKey(const ValueKey('nav-subjects')),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Navigation subjects',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Your subjects'), findsOneWidget);
  });

  testWidgets('subjects adapt columns and keep one navigation system', (
    tester,
  ) async {
    for (final entry in <(Size, int)>[
      (const Size(390, 844), 1),
      (const Size(800, 900), 2),
      (const Size(1280, 900), 2),
      (const Size(1600, 900), 3),
    ]) {
      await _setViewport(tester, entry.$1);
      await _pumpWorkspace(tester);
      await tester.tap(find.byKey(const ValueKey('nav-subjects')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('subjects-grid-${entry.$2}')), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
      expect(
        find.byType(GlassNavigationBar).evaluate().length +
            find.byType(GlassNavigationRail).evaluate().length,
        1,
      );
    }
  });

  testWidgets('large text gracefully reduces subject grid columns', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1600, 900));
    await _pumpWorkspace(tester, textScale: 2);
    await tester.tap(find.byKey(const ValueKey('nav-subjects')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('subjects-grid-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create subject colors expose selected semantics', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 900));
    await _pumpWorkspace(tester);
    await tester.tap(find.byKey(const ValueKey('nav-subjects')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subjects-create-button')));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Blue subject color'),
    );
    expect(semantics.label, 'Blue subject color');
    expect(semantics.toString(), contains('isSelected'));
    expect(semantics.toString(), contains('isButton'));

    await tester.tap(find.byKey(const ValueKey('subject-color-green')));
    await tester.pump();
    final green = tester.getSemantics(
      find.bySemanticsLabel('Green subject color'),
    );
    expect(green.label, 'Green subject color');
    expect(green.toString(), contains('isSelected'));
    expect(green.toString(), contains('isButton'));
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  double textScale = 1,
  double bottomInset = 0,
}) async {
  final config = AppConfig.fromValues();
  final state = AppState(config: config);
  final auth = AuthController(
    authRepository: MockAuthRepository(),
    profileRepository: NoopProfileRepository(),
  );
  addTearDown(state.dispose);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: AuthScope(
        controller: auth,
        child: MaterialApp(
          key: UniqueKey(),
          theme: buildAppTheme(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: AppRoutes.dashboard,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: EdgeInsets.only(bottom: bottomInset),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
