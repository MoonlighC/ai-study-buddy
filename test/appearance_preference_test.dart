import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appearance codes map to stable ThemeModes with safe fallback', () {
    expect(AppAppearancePreference.system.persistedCode, 'system');
    expect(AppAppearancePreference.light.persistedCode, 'light');
    expect(AppAppearancePreference.dark.persistedCode, 'dark');
    expect(AppAppearancePreference.system.themeMode, ThemeMode.system);
    expect(AppAppearancePreference.light.themeMode, ThemeMode.light);
    expect(AppAppearancePreference.dark.themeMode, ThemeMode.dark);
    expect(
      AppAppearancePreferenceX.fromPersistedCode(null),
      AppAppearancePreference.system,
    );
    expect(
      AppAppearancePreferenceX.fromPersistedCode('stale'),
      AppAppearancePreference.system,
    );
  });

  test(
    'appearance restores, notifies immediately, persists, and de-duplicates',
    () async {
      final store = MemoryAppPreferencesStore(
        localeCode: 'de',
        appearanceCode: 'dark',
      );
      final state = AppState(preferencesStore: store);
      await state.loadPreferences();
      expect(state.languagePreference, AppLanguagePreference.german);
      expect(state.appearancePreference, AppAppearancePreference.dark);

      var notifications = 0;
      state.addListener(() => notifications++);
      state.setAppearancePreference(AppAppearancePreference.light);
      expect(state.themeMode, ThemeMode.light);
      expect(notifications, 1);
      await Future<void>.delayed(Duration.zero);
      expect(store.savedAppearanceCodes, ['light']);

      state.setAppearancePreference(AppAppearancePreference.light);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(store.savedAppearanceCodes, ['light']);
    },
  );

  test(
    'load and save failures fall back safely without reverting UI',
    () async {
      final failedLoad = AppState(
        preferencesStore: MemoryAppPreferencesStore(throwOnLoad: true),
      );
      await failedLoad.loadPreferences();
      expect(failedLoad.languagePreference, AppLanguagePreference.system);
      expect(failedLoad.appearancePreference, AppAppearancePreference.system);

      final failedSave = AppState(
        preferencesStore: MemoryAppPreferencesStore(throwOnSave: true),
      );
      failedSave.setAppearancePreference(AppAppearancePreference.dark);
      await Future<void>.delayed(Duration.zero);
      expect(failedSave.appearancePreference, AppAppearancePreference.dark);
    },
  );

  test('locale and appearance changes remain independent', () {
    final state = AppState(preferencesStore: MemoryAppPreferencesStore());
    state.setLanguagePreference(AppLanguagePreference.russian);
    expect(state.appearancePreference, AppAppearancePreference.system);
    state.setAppearancePreference(AppAppearancePreference.dark);
    expect(state.languagePreference, AppLanguagePreference.russian);
  });
}
