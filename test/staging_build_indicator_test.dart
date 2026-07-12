import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mobile_qa_harness.dart';

void main() {
  AppConfig config(String environment) => environment == 'local'
      ? AppConfig.fromValues()
      : AppConfig.fromValues(
          environmentValue: environment,
          backendModeValue: 'supabase',
          supabaseUrl: 'https://fixture.supabase.co',
          supabaseAnonKey: 'FAKE_TEST_FIXTURE_PUBLIC_KEY',
        );

  Widget screen(AppConfig config) {
    final state = AppState(
      config: config,
      preferencesStore: MemoryAppPreferencesStore(),
    );
    final auth = AuthController(
      authRepository: MockAuthRepository(),
      profileRepository: NoopProfileRepository(),
    );
    return AppStateScope(
      state: state,
      child: AuthScope(controller: auth, child: const SettingsScreen()),
    );
  }

  Future<void> reveal(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('staging-build-indicator')),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
  }

  testWidgets('staging marker is localized and accessible', (tester) async {
    await setQaViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(qaApp(home: screen(config('staging'))));
    await reveal(tester);
    expect(find.text('Staging build'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('staging-build-indicator')))
          .label,
      contains('Staging beta build'),
    );

    await tester.pumpWidget(
      qaApp(home: screen(config('staging')), locale: const Locale('de')),
    );
    await reveal(tester);
    expect(find.text('Staging-Build'), findsOneWidget);
  });

  for (final environment in ['local', 'production']) {
    testWidgets('$environment does not show staging marker', (tester) async {
      await tester.pumpWidget(qaApp(home: screen(config(environment))));
      expect(
        find.byKey(const ValueKey('staging-build-indicator')),
        findsNothing,
      );
    });
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('staging marker supports 200% ${brightness.name}', (
      tester,
    ) async {
      await setQaViewport(tester, size: const Size(320, 844));
      await tester.pumpWidget(
        qaApp(
          home: screen(config('staging')),
          brightness: brightness,
          textScale: 2,
          locale: const Locale('ru'),
        ),
      );
      await reveal(tester);
      expect(find.text('Тестовая сборка'), findsOneWidget);
      expectNoFrameworkException(tester);
    });
  }
}
