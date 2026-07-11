import 'package:shared_preferences/shared_preferences.dart';

abstract class AppPreferencesStore {
  Future<String?> loadLocaleCode();

  Future<String?> loadAppearanceCode();

  Future<void> saveLocaleCode(String code);

  Future<void> saveAppearanceCode(String code);
}

class SharedPreferencesAppPreferencesStore implements AppPreferencesStore {
  const SharedPreferencesAppPreferencesStore();

  static const _localePreferenceKey = 'app.localePreference';
  static const _appearancePreferenceKey = 'app.appearancePreference';

  @override
  Future<String?> loadLocaleCode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_localePreferenceKey);
  }

  @override
  Future<void> saveLocaleCode(String code) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localePreferenceKey, code);
  }

  @override
  Future<String?> loadAppearanceCode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_appearancePreferenceKey);
  }

  @override
  Future<void> saveAppearanceCode(String code) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appearancePreferenceKey, code);
  }
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore({
    String? localeCode,
    String? appearanceCode,
    this.throwOnLoad = false,
    this.throwOnSave = false,
  }) {
    _localeCode = localeCode;
    _appearanceCode = appearanceCode;
  }

  String? _localeCode;
  String? _appearanceCode;
  final bool throwOnLoad;
  final bool throwOnSave;
  final List<String> savedLocaleCodes = [];
  final List<String> savedAppearanceCodes = [];

  @override
  Future<String?> loadLocaleCode() async {
    if (throwOnLoad) {
      throw StateError('Could not load locale preference.');
    }
    return _localeCode;
  }

  @override
  Future<void> saveLocaleCode(String code) async {
    savedLocaleCodes.add(code);
    _localeCode = code;
    if (throwOnSave) {
      throw StateError('Could not save locale preference.');
    }
  }

  @override
  Future<String?> loadAppearanceCode() async {
    if (throwOnLoad) {
      throw StateError('Could not load appearance preference.');
    }
    return _appearanceCode;
  }

  @override
  Future<void> saveAppearanceCode(String code) async {
    savedAppearanceCodes.add(code);
    _appearanceCode = code;
    if (throwOnSave) {
      throw StateError('Could not save appearance preference.');
    }
  }
}
