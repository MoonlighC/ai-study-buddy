// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'AI Study Buddy';

  @override
  String get navHome => 'Start';

  @override
  String get navSubjects => 'Fächer';

  @override
  String get navFavorites => 'Favoriten';

  @override
  String get navProgress => 'Fortschritt';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get actionSearch => 'Suchen';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get statusLoading => 'Laden';

  @override
  String get statusError => 'Fehler';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String get settingsDisplayLanguage => 'Anzeigesprache';

  @override
  String get settingsDisplayLanguageDescription =>
      'Wähle die Sprache für Navigation und Bedienelemente der App.';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsAppearanceUnavailable =>
      'Der Dunkelmodus ist noch nicht verfügbar.';

  @override
  String get settingsUsageUnavailable =>
      'Die Nutzungsverfolgung ist nicht verbunden';

  @override
  String get comingLater => 'Kommt später';

  @override
  String get genericLocalizedError =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';
}
