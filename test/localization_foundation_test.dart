import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported locales include English, German, and Russian', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(['en', 'de', 'ru']),
    );
  });

  test('language preferences map to nullable app locales', () {
    expect(AppLanguagePreference.system.locale, isNull);
    expect(AppLanguagePreference.english.locale, const Locale('en'));
    expect(AppLanguagePreference.german.locale, const Locale('de'));
    expect(AppLanguagePreference.russian.locale, const Locale('ru'));
    expect(
      AppLanguagePreferenceX.fromPersistedCode('stale'),
      AppLanguagePreference.system,
    );
  });

  test('locale changes notify and persist exactly once', () async {
    final store = MemoryAppPreferencesStore();
    final state = AppState(preferencesStore: store);
    var notifications = 0;
    state.addListener(() => notifications += 1);

    state.setLanguagePreference(AppLanguagePreference.german);
    await Future<void>.delayed(Duration.zero);

    expect(state.languagePreference, AppLanguagePreference.german);
    expect(state.appLocale, const Locale('de'));
    expect(notifications, 1);
    expect(store.savedLocaleCodes, ['de']);

    state.setLanguagePreference(AppLanguagePreference.german);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
    expect(store.savedLocaleCodes, ['de']);
  });

  testWidgets('system preference maps to null MaterialApp locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        preferencesStore: MemoryAppPreferencesStore(localeCode: 'system'),
      ),
    );
    await _settle(tester);

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);
  });

  testWidgets('persisted locale restores after rebuild', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        preferencesStore: MemoryAppPreferencesStore(localeCode: 'de'),
      ),
    );
    await _settle(tester);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('de'),
    );
  });

  testWidgets('invalid persisted locale falls back to system', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        preferencesStore: MemoryAppPreferencesStore(localeCode: 'xx'),
      ),
    );
    await _settle(tester);

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);
  });

  testWidgets('persistence failure does not block visible locale change', (
    tester,
  ) async {
    await _enterDashboard(
      tester,
      preferencesStore: MemoryAppPreferencesStore(throwOnSave: true),
    );
    await _openSettings(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Deutsch'));
    await _settle(tester);

    expect(find.text('Einstellungen'), findsWidgets);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('de'),
    );
  });

  testWidgets(
    'appearance selector switches immediately and exposes selection',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final store = MemoryAppPreferencesStore();
      await _setViewport(tester, const Size(800, 900));
      await _enterDashboard(tester, preferencesStore: store);
      await _openSettings(tester);

      await tester.scrollUntilVisible(
        find.text('Appearance'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dark'));
      await _settle(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(store.savedAppearanceCodes, ['dark']);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dark'))
            .selected,
        isTrue,
      );

      semantics.dispose();
    },
  );

  testWidgets('Settings locale switch updates shared navigation immediately', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    final store = MemoryAppPreferencesStore();
    await _enterDashboard(tester, preferencesStore: store);
    await _openSettings(tester);

    expect(find.text('Settings'), findsWidgets);
    expect(_chip(tester, 'System default').selected, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Deutsch'));
    await _settle(tester);

    expect(find.text('Einstellungen'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('F\u00e4cher'), findsOneWidget);
    expect(_chip(tester, 'Deutsch').selected, isTrue);
    expect(store.savedLocaleCodes, contains('de'));

    await tester.tap(
      find.widgetWithText(
        ChoiceChip,
        '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
      ),
    );
    await _settle(tester);

    expect(
      find.text('\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438'),
      findsWidgets,
    );
    expect(
      find.text('\u0413\u043b\u0430\u0432\u043d\u0430\u044f'),
      findsOneWidget,
    );
    expect(
      find.text('\u041f\u0440\u0435\u0434\u043c\u0435\u0442\u044b'),
      findsOneWidget,
    );
    expect(
      _chip(tester, '\u0420\u0443\u0441\u0441\u043a\u0438\u0439').selected,
      isTrue,
    );
    expect(store.savedLocaleCodes, contains('ru'));
  });

  testWidgets('shared navigation labels render in all three languages', (
    tester,
  ) async {
    for (final entry in <(String, List<String>)>[
      ('en', ['Home', 'Subjects', 'Favorites', 'Progress', 'Settings']),
      (
        'de',
        ['Start', 'F\u00e4cher', 'Favoriten', 'Fortschritt', 'Einstellungen'],
      ),
      (
        'ru',
        [
          '\u0413\u043b\u0430\u0432\u043d\u0430\u044f',
          '\u041f\u0440\u0435\u0434\u043c\u0435\u0442\u044b',
          '\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435',
          '\u041f\u0440\u043e\u0433\u0440\u0435\u0441\u0441',
          '\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438',
        ],
      ),
    ]) {
      await _setViewport(tester, const Size(1280, 900));
      await _enterDashboard(
        tester,
        preferencesStore: MemoryAppPreferencesStore(localeCode: entry.$1),
      );
      await _openSettings(tester);

      for (final label in entry.$2) {
        expect(find.text(label), findsWidgets);
      }
    }
  });

  testWidgets('app title localizes through generated delegates', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        preferencesStore: MemoryAppPreferencesStore(localeCode: 'ru'),
      ),
    );
    await _settle(tester);

    final title = tester.widget<Title>(find.byType(Title).first);
    expect(title.title, 'AI Study Buddy');
  });

  testWidgets('German settings layout is stable at 390px', (tester) async {
    await _expectLocalizedSettingsLayout(
      tester,
      localeCode: 'de',
      size: const Size(390, 844),
      expectedLabels: const ['Einstellungen', 'Fächer'],
    );
  });

  testWidgets('Russian settings layout is stable at 390px', (tester) async {
    await _expectLocalizedSettingsLayout(
      tester,
      localeCode: 'ru',
      size: const Size(390, 844),
      expectedLabels: const ['Настройки', 'Предметы'],
    );
  });

  testWidgets('German settings layout is stable at 1280px', (tester) async {
    await _expectLocalizedSettingsLayout(
      tester,
      localeCode: 'de',
      size: const Size(1280, 900),
      expectedLabels: const ['Einstellungen', 'Fächer'],
    );
  });

  testWidgets('Russian settings layout is stable at 1280px', (tester) async {
    await _expectLocalizedSettingsLayout(
      tester,
      localeCode: 'ru',
      size: const Size(1280, 900),
      expectedLabels: const ['Настройки', 'Предметы'],
    );
  });

  testWidgets('localized settings layout is stable at 200 percent text', (
    tester,
  ) async {
    await _expectLocalizedSettingsLayout(
      tester,
      localeCode: 'de',
      size: const Size(390, 844),
      textScale: 2,
      expectedLabels: const ['Einstellungen', 'Anzeigesprache'],
    );
  });

  testWidgets('localized settings are stable at 800px in every locale', (
    tester,
  ) async {
    for (final entry in const [
      ('en', 'Settings'),
      ('de', 'Einstellungen'),
      ('ru', 'Настройки'),
    ]) {
      await _expectLocalizedSettingsLayout(
        tester,
        localeCode: entry.$1,
        size: const Size(800, 900),
        expectedLabels: [entry.$2],
      );
    }
  });

  testWidgets('200 percent text remains usable in every locale', (
    tester,
  ) async {
    for (final entry in const [
      ('en', 'Display language'),
      ('de', 'Anzeigesprache'),
      ('ru', 'Язык интерфейса'),
    ]) {
      await _expectLocalizedSettingsLayout(
        tester,
        localeCode: entry.$1,
        size: const Size(390, 844),
        textScale: 2,
        expectedLabels: [entry.$2],
      );
    }
  });

  testWidgets('locale changes keep user and AI content unchanged', (
    tester,
  ) async {
    await _enterDashboard(
      tester,
      preferencesStore: MemoryAppPreferencesStore(),
    );

    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);

    await _openSettings(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deutsch'));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await _settle(tester);

    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);
  });

  testWidgets('locale changes do not trigger repository calls', (tester) async {
    final subjectRepository = _CountingSubjectRepository();
    final materialRepository = _CountingMaterialRepository();
    await _enterDashboard(
      tester,
      config: _supabaseConfig(),
      authRepository: _StaticAuthRepository(),
      subjectRepository: subjectRepository,
      materialRepository: materialRepository,
      preferencesStore: MemoryAppPreferencesStore(),
    );
    expect(subjectRepository.loadCount, 1);
    expect(materialRepository.loadCount, 1);

    await _openSettings(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deutsch'));
    await _settle(tester);

    expect(subjectRepository.loadCount, 1);
    expect(materialRepository.loadCount, 1);
  });
}

ChoiceChip _chip(WidgetTester tester, String label) {
  return tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
}

Future<void> _expectLocalizedSettingsLayout(
  WidgetTester tester, {
  required String localeCode,
  required Size size,
  required List<String> expectedLabels,
  double textScale = 1,
}) async {
  await _setViewport(tester, size, textScale: textScale);
  await _enterDashboard(
    tester,
    preferencesStore: MemoryAppPreferencesStore(localeCode: localeCode),
  );
  await _throwPendingException(tester);
  await _openSettings(tester);
  await _throwPendingException(tester);

  for (final label in expectedLabels) {
    if (find.text(label).evaluate().isEmpty &&
        find
            .byKey(const ValueKey('settings-scroll-view'))
            .evaluate()
            .isNotEmpty) {
      await tester.scrollUntilVisible(find.text(label), 120, maxScrolls: 12);
      await tester.pump();
      await _throwPendingException(tester);
    }
    expect(find.text(label), findsWidgets);
  }

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _enterDashboard(
  WidgetTester tester, {
  AppConfig? config,
  AuthRepository? authRepository,
  SubjectRepository? subjectRepository,
  MaterialRepository? materialRepository,
  required AppPreferencesStore preferencesStore,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      key: UniqueKey(),
      config: config,
      authRepository: authRepository,
      subjectRepository: subjectRepository,
      materialRepository: materialRepository,
      preferencesStore: preferencesStore,
    ),
  );
  await _settle(tester);
  if (find.byKey(const ValueKey('login-form-panel')).evaluate().isNotEmpty) {
    final primaryAction = find.byKey(const ValueKey('auth-primary-action'));
    await tester.ensureVisible(primaryAction);
    await tester.pump();
    await _throwPendingException(tester);
    await tester.tap(primaryAction);
    await _settle(tester);
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-settings')));
  await _settle(tester);
}

Future<void> _throwPendingException(WidgetTester tester) async {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Unexpected Flutter exception: $exception');
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await _throwPendingException(tester);
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    await _throwPendingException(tester);
  }
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'sb_publishable_test-client-key',
  );
}

class _StaticAuthRepository implements AuthRepository {
  final _user = const AuthUser(
    id: 'supabase-user',
    email: 'student@example.test',
    displayName: 'Supabase Student',
  );

  @override
  Future<AuthUser?> currentUser() async => _user;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthResult.signedIn(_user);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    return AuthResult.signedIn(_user);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _CountingSubjectRepository implements SubjectRepository {
  int loadCount = 0;

  @override
  Future<List<Subject>> loadSubjects(AuthUser user) async {
    loadCount += 1;
    return const [
      Subject(
        id: 'biology',
        name: 'Biology',
        description: 'Bio',
        colorValue: 0xFF2563EB,
      ),
    ];
  }

  @override
  Future<Subject> createSubject({
    required AuthUser user,
    required String name,
    required String description,
    required int colorValue,
    required int sortOrder,
  }) {
    throw UnimplementedError();
  }
}

class _CountingMaterialRepository implements MaterialRepository {
  int loadCount = 0;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    loadCount += 1;
    return const [
      StudyMaterial(
        id: 'material',
        subjectId: 'biology',
        title: 'Photosynthesis lecture notes',
        kind: MaterialKind.pastedText,
        content: 'AI-generated content seed remains unchanged.',
        createdLabel: 'Today',
      ),
    ];
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) {
    throw UnimplementedError();
  }
}
