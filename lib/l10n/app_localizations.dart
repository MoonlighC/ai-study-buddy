import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ru'),
  ];

  /// Application title used by the app shell and operating system.
  ///
  /// In en, this message translates to:
  /// **'AI Study Buddy'**
  String get appTitle;

  /// Root navigation destination for the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Root navigation destination for the subject list.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get navSubjects;

  /// Root navigation destination for saved favorite materials and cards.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// Root navigation destination for learning progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// Root navigation destination for app settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Tooltip or label for opening search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Tooltip or label for navigating back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Common action that dismisses a dialog or cancels an operation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Common action that saves a change.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Common action for trying an operation again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Generic loading state text.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get statusLoading;

  /// Generic error state title.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// Settings screen title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section title for display language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Label for the user-selectable display language preference.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get settingsDisplayLanguage;

  /// Explains that only UI chrome changes language, not study content.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for app navigation and controls.'**
  String get settingsDisplayLanguageDescription;

  /// Locale preference that follows the operating system language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// Locale preference label for English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Locale preference label for German, written in German.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// Locale preference label for Russian, written in Russian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// Settings placeholder explaining that dark mode is not implemented.
  ///
  /// In en, this message translates to:
  /// **'Dark mode is not available yet.'**
  String get settingsAppearanceUnavailable;

  /// Settings placeholder explaining that usage tracking is not connected.
  ///
  /// In en, this message translates to:
  /// **'Usage tracking is not connected'**
  String get settingsUsageUnavailable;

  /// Short placeholder for features planned for a later phase.
  ///
  /// In en, this message translates to:
  /// **'Coming later'**
  String get comingLater;

  /// Generic localized fallback for safe errors when no specific mapping exists.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericLocalizedError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
