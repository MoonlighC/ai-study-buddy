import 'package:shared_preferences/shared_preferences.dart';

abstract class AppPreferencesStore {
  Future<String?> loadLocaleCode();

  Future<void> saveLocaleCode(String code);
}

class SharedPreferencesAppPreferencesStore implements AppPreferencesStore {
  const SharedPreferencesAppPreferencesStore();

  static const _localePreferenceKey = 'app.localePreference';

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
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore({
    String? localeCode,
    this.throwOnLoad = false,
    this.throwOnSave = false,
  }) {
    _localeCode = localeCode;
  }

  String? _localeCode;
  final bool throwOnLoad;
  final bool throwOnSave;
  final List<String> savedLocaleCodes = [];

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
}
