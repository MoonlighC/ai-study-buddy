import 'package:shared_preferences/shared_preferences.dart';

abstract class AppPreferencesStore {
  Future<String?> loadLocaleCode();

  Future<String?> loadAppearanceCode();

  Future<void> saveLocaleCode(String code);

  Future<void> saveAppearanceCode(String code);

  Future<String?> loadActiveStudySession(String userId);

  Future<void> saveActiveStudySession(String userId, String snapshot);

  Future<void> clearActiveStudySession(String userId);
}

class SharedPreferencesAppPreferencesStore implements AppPreferencesStore {
  const SharedPreferencesAppPreferencesStore();

  static const _localePreferenceKey = 'app.localePreference';
  static const _appearancePreferenceKey = 'app.appearancePreference';
  static String _studySessionKey(String userId) =>
      'app.activeStudySession.$userId';

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

  @override
  Future<String?> loadActiveStudySession(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_studySessionKey(userId));
  }

  @override
  Future<void> saveActiveStudySession(String userId, String snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_studySessionKey(userId), snapshot);
  }

  @override
  Future<void> clearActiveStudySession(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_studySessionKey(userId));
  }
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore({
    String? localeCode,
    String? appearanceCode,
    this.throwOnLoad = false,
    this.throwOnSave = false,
    Map<String, String>? activeStudySessions,
  }) {
    _localeCode = localeCode;
    _appearanceCode = appearanceCode;
    if (activeStudySessions != null) {
      _activeStudySessions.addAll(activeStudySessions);
    }
  }

  String? _localeCode;
  String? _appearanceCode;
  final bool throwOnLoad;
  final bool throwOnSave;
  final List<String> savedLocaleCodes = [];
  final List<String> savedAppearanceCodes = [];
  final Map<String, String> _activeStudySessions = {};
  int studySessionSaveCount = 0;
  int studySessionClearCount = 0;

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

  @override
  Future<String?> loadActiveStudySession(String userId) async {
    if (throwOnLoad) throw StateError('Could not load study session.');
    return _activeStudySessions[userId];
  }

  @override
  Future<void> saveActiveStudySession(String userId, String snapshot) async {
    studySessionSaveCount += 1;
    _activeStudySessions[userId] = snapshot;
    if (throwOnSave) throw StateError('Could not save study session.');
  }

  @override
  Future<void> clearActiveStudySession(String userId) async {
    studySessionClearCount += 1;
    _activeStudySessions.remove(userId);
    if (throwOnSave) throw StateError('Could not clear study session.');
  }

  String? activeStudySessionFor(String userId) => _activeStudySessions[userId];
}
