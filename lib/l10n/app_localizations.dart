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

  /// Common destructive delete action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Expands collapsed text.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get actionShowMore;

  /// Collapses expanded text.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get actionShowLess;

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

  /// Email field or account label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// Name field or profile label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// Fallback label when a value is unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// Generic status label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// Accessibility label for error messages.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonErrorSemantics;

  /// Accessibility label for non-error status messages.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatusSemantics;

  /// Supporting text shown when a non-blocking sync error occurs.
  ///
  /// In en, this message translates to:
  /// **'Your app is still usable.'**
  String get commonAppStillUsable;

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

  /// Short settings screen intro for mock/local prototype mode.
  ///
  /// In en, this message translates to:
  /// **'Mock preferences for the local prototype.'**
  String get settingsIntro;

  /// Settings account section title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountTitle;

  /// Subtitle for a Supabase-backed account.
  ///
  /// In en, this message translates to:
  /// **'Supabase account'**
  String get settingsSupabaseAccount;

  /// Subtitle for the local mock account profile.
  ///
  /// In en, this message translates to:
  /// **'Local mock profile'**
  String get settingsLocalMockProfile;

  /// Action to edit the account display name.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get settingsEditName;

  /// Action that signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// Settings section for local study preferences.
  ///
  /// In en, this message translates to:
  /// **'Study Preferences'**
  String get settingsStudyPreferencesTitle;

  /// Explains local-only preference storage.
  ///
  /// In en, this message translates to:
  /// **'Stored in local AppState only'**
  String get settingsStudyPreferencesSubtitle;

  /// Preference label for default flashcard count.
  ///
  /// In en, this message translates to:
  /// **'Default flashcard session size'**
  String get settingsDefaultFlashcardSessionSize;

  /// Preference label for daily study minutes.
  ///
  /// In en, this message translates to:
  /// **'Daily study goal'**
  String get settingsDailyStudyGoal;

  /// Preference label for default study difficulty.
  ///
  /// In en, this message translates to:
  /// **'Default difficulty'**
  String get settingsDefaultDifficulty;

  /// Difficulty preference option.
  ///
  /// In en, this message translates to:
  /// **'easy'**
  String get settingsDifficultyEasy;

  /// Difficulty preference option.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get settingsDifficultyMedium;

  /// Difficulty preference option.
  ///
  /// In en, this message translates to:
  /// **'exam'**
  String get settingsDifficultyExam;

  /// Short minute label for settings chips.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settingsMinutesShort(int minutes);

  /// Settings app preferences section title.
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get settingsAppPreferencesTitle;

  /// Subtitle for future appearance settings.
  ///
  /// In en, this message translates to:
  /// **'Appearance options are planned'**
  String get settingsAppearancePlanned;

  /// Appearance setting row title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Settings placeholder explaining that dark mode is not implemented.
  ///
  /// In en, this message translates to:
  /// **'Dark mode is not available yet.'**
  String get settingsAppearanceUnavailable;

  /// Explains the persisted appearance selector.
  ///
  /// In en, this message translates to:
  /// **'Choose the app appearance. System default follows your device setting.'**
  String get settingsAppearanceDescription;

  /// Appearance option that follows platform brightness.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// Light appearance option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Dark appearance option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Settings section linking to usage screen.
  ///
  /// In en, this message translates to:
  /// **'Usage & Limits'**
  String get settingsUsageTitle;

  /// Settings placeholder explaining that usage tracking is not connected.
  ///
  /// In en, this message translates to:
  /// **'Usage tracking is not connected'**
  String get settingsUsageUnavailable;

  /// Settings action for opening usage screen.
  ///
  /// In en, this message translates to:
  /// **'View usage information'**
  String get settingsViewUsage;

  /// Settings row subtitle for planned usage limits.
  ///
  /// In en, this message translates to:
  /// **'Limits and enforcement are planned.'**
  String get settingsUsagePlanned;

  /// Settings support section title.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupportTitle;

  /// Explains support integrations are unavailable.
  ///
  /// In en, this message translates to:
  /// **'No email or network integration yet'**
  String get settingsSupportSubtitle;

  /// Disabled support placeholder action.
  ///
  /// In en, this message translates to:
  /// **'Report a bug placeholder'**
  String get settingsReportBugPlaceholder;

  /// Disabled support placeholder action.
  ///
  /// In en, this message translates to:
  /// **'Contact support placeholder'**
  String get settingsContactSupportPlaceholder;

  /// Disabled support placeholder action.
  ///
  /// In en, this message translates to:
  /// **'Send feedback placeholder'**
  String get settingsSendFeedbackPlaceholder;

  /// Settings diagnostics section title.
  ///
  /// In en, this message translates to:
  /// **'About / Debug'**
  String get settingsAboutDebugTitle;

  /// Settings diagnostics section subtitle.
  ///
  /// In en, this message translates to:
  /// **'Prototype diagnostics'**
  String get settingsAboutDebugSubtitle;

  /// Small diagnostic label shown only for staging builds.
  ///
  /// In en, this message translates to:
  /// **'Staging build'**
  String get settingsStagingBuildLabel;

  /// Accessible description for the staging-only diagnostic label.
  ///
  /// In en, this message translates to:
  /// **'Staging beta build'**
  String get settingsStagingBuildSemantics;

  /// Diagnostics label for backend mode.
  ///
  /// In en, this message translates to:
  /// **'Backend mode'**
  String get settingsBackendMode;

  /// Diagnostics label for security note.
  ///
  /// In en, this message translates to:
  /// **'Security note'**
  String get settingsSecurityNote;

  /// Diagnostics value explaining secrets are not stored in Flutter.
  ///
  /// In en, this message translates to:
  /// **'No server secrets or OpenAI key in Flutter.'**
  String get settingsSecurityNoteValue;

  /// Short placeholder for features planned for a later phase.
  ///
  /// In en, this message translates to:
  /// **'Coming later'**
  String get comingLater;

  /// Login screen title.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBackTitle;

  /// Login screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn lecture material into focused study sessions.'**
  String get authWelcomeBackSubtitle;

  /// Signup screen title and action.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountTitle;

  /// Signup screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your study profile.'**
  String get authCreateAccountSubtitle;

  /// Login action.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// Password reset action.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Mock mode email continue action.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authContinueWithEmail;

  /// Disabled Google auth placeholder.
  ///
  /// In en, this message translates to:
  /// **'Google coming later'**
  String get authGoogleComingLater;

  /// Disabled Apple auth placeholder.
  ///
  /// In en, this message translates to:
  /// **'Apple coming later'**
  String get authAppleComingLater;

  /// Confirm password field label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// Signup action returning to login.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authAlreadyHaveAccount;

  /// Password visibility tooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Password visibility tooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Auth gate loading message.
  ///
  /// In en, this message translates to:
  /// **'Preparing your study space'**
  String get authPreparingStudySpace;

  /// Password reset notice.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a reset email is on the way.'**
  String authResetNotice(String email);

  /// Signup confirmation notice.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account, then log in.'**
  String get authCheckEmailNotice;

  /// Dashboard app shell subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your calm place to learn'**
  String get homeSubtitle;

  /// Dashboard section title.
  ///
  /// In en, this message translates to:
  /// **'Recent materials'**
  String get homeRecentMaterials;

  /// Dashboard action linking to subjects.
  ///
  /// In en, this message translates to:
  /// **'View subjects'**
  String get homeViewSubjects;

  /// Dashboard empty state title.
  ///
  /// In en, this message translates to:
  /// **'No materials yet'**
  String get homeNoMaterialsTitle;

  /// Dashboard empty state message.
  ///
  /// In en, this message translates to:
  /// **'Open a subject and add your first study material.'**
  String get homeNoMaterialsMessage;

  /// Dashboard subjects section title.
  ///
  /// In en, this message translates to:
  /// **'Your subjects'**
  String get homeYourSubjects;

  /// Dashboard subject empty state title.
  ///
  /// In en, this message translates to:
  /// **'Create your first subject'**
  String get homeCreateFirstSubject;

  /// Dashboard subject empty state message.
  ///
  /// In en, this message translates to:
  /// **'Subjects keep materials and study tools together.'**
  String get homeCreateFirstSubjectMessage;

  /// Dashboard hero status chip.
  ///
  /// In en, this message translates to:
  /// **'Study workspace'**
  String get homeStudyWorkspace;

  /// Dashboard hero headline.
  ///
  /// In en, this message translates to:
  /// **'Ready for your next study step?'**
  String get homeHeroTitle;

  /// Dashboard hero copy when materials exist.
  ///
  /// In en, this message translates to:
  /// **'Continue with a recent material or choose a focused study action.'**
  String get homeHeroWithMaterials;

  /// Dashboard hero copy when no materials exist.
  ///
  /// In en, this message translates to:
  /// **'Add study material to a subject, then build summaries, flashcards, and quizzes.'**
  String get homeHeroWithoutMaterials;

  /// Dashboard hero action when no subjects exist.
  ///
  /// In en, this message translates to:
  /// **'Create a subject'**
  String get homeCreateSubject;

  /// Dashboard hero action when subjects exist.
  ///
  /// In en, this message translates to:
  /// **'Open subjects'**
  String get homeOpenSubjects;

  /// Visible button for deferred After Lecture route.
  ///
  /// In en, this message translates to:
  /// **'After Lecture'**
  String get homeAfterLecture;

  /// Dashboard latest progress section title.
  ///
  /// In en, this message translates to:
  /// **'Latest progress'**
  String get homeLatestProgress;

  /// Dashboard empty progress title.
  ///
  /// In en, this message translates to:
  /// **'No quiz attempts yet'**
  String get homeNoQuizAttemptsTitle;

  /// Dashboard empty progress message.
  ///
  /// In en, this message translates to:
  /// **'Complete a quiz to see your latest result.'**
  String get homeNoQuizAttemptsMessage;

  /// Quiz result count.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String homeCorrectCount(int correct, int total);

  /// Dashboard focus topics section title.
  ///
  /// In en, this message translates to:
  /// **'Focus topics'**
  String get homeFocusTopics;

  /// Dashboard empty focus topics text.
  ///
  /// In en, this message translates to:
  /// **'Complete quizzes to reveal topics worth revisiting.'**
  String get homeFocusTopicsEmpty;

  /// Subject plus miss count.
  ///
  /// In en, this message translates to:
  /// **'{subject} · {count, plural, one {1 miss} other {{count} misses}}'**
  String homeMissesWithSubject(String subject, int count);

  /// Dashboard quick actions section title.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// Visible button for deferred Exam Prep route.
  ///
  /// In en, this message translates to:
  /// **'Prepare for Exam'**
  String get homePrepareForExam;

  /// Visible button for deferred Continue Studying route.
  ///
  /// In en, this message translates to:
  /// **'Continue Studying'**
  String get homeContinueStudying;

  /// Subjects screen title.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjectsTitle;

  /// Subjects screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Study workspace'**
  String get subjectsSubtitle;

  /// Subjects loading state.
  ///
  /// In en, this message translates to:
  /// **'Loading synced subjects'**
  String get subjectsLoading;

  /// Supporting text when synced subjects cannot refresh but cached subjects are visible.
  ///
  /// In en, this message translates to:
  /// **'Showing the subjects currently available.'**
  String get subjectsShowingAvailable;

  /// Subjects empty state title.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet'**
  String get subjectsNoSubjectsTitle;

  /// Subjects empty state message.
  ///
  /// In en, this message translates to:
  /// **'Create a subject to group your materials, summaries, flashcards, and quizzes.'**
  String get subjectsNoSubjectsMessage;

  /// Create subject action.
  ///
  /// In en, this message translates to:
  /// **'Create subject'**
  String get subjectsCreateSubject;

  /// Create subject busy label.
  ///
  /// In en, this message translates to:
  /// **'Creating subject'**
  String get subjectsCreatingSubject;

  /// Subjects screen hero heading.
  ///
  /// In en, this message translates to:
  /// **'Your subjects'**
  String get subjectsHeaderTitle;

  /// Subjects screen hero explanatory copy.
  ///
  /// In en, this message translates to:
  /// **'Create focused spaces for lecture notes, summaries, quizzes, and exam prep.'**
  String get subjectsHeaderMessage;

  /// Fallback shown when a subject has no user-entered description.
  ///
  /// In en, this message translates to:
  /// **'No description yet'**
  String get subjectsNoDescription;

  /// Visible button for deferred Exam Prep route.
  ///
  /// In en, this message translates to:
  /// **'Exam Prep'**
  String get subjectsExamPrep;

  /// Accessibility label for opening a subject.
  ///
  /// In en, this message translates to:
  /// **'Open {subject}'**
  String subjectsOpenSubject(String subject);

  /// Create subject dialog title.
  ///
  /// In en, this message translates to:
  /// **'Create subject'**
  String get subjectsCreateDialogTitle;

  /// Subject name field label.
  ///
  /// In en, this message translates to:
  /// **'Subject name'**
  String get subjectsNameLabel;

  /// Subject name field hint.
  ///
  /// In en, this message translates to:
  /// **'Biology, math, history...'**
  String get subjectsNameHint;

  /// Subject description field label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get subjectsDescriptionLabel;

  /// Subject color picker label.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get subjectsColor;

  /// Subject color picker option.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// Subject color picker option.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// Subject color picker option.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// Subject color picker option.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// Accessibility label for a subject color choice.
  ///
  /// In en, this message translates to:
  /// **'{color} subject color'**
  String subjectsColorSemantics(String color);

  /// Fallback description for a new subject.
  ///
  /// In en, this message translates to:
  /// **'Study materials and practice for this subject.'**
  String get subjectsDefaultDescription;

  /// Material count label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {0 materials} one {1 material} other {{count} materials}}'**
  String materialsCount(int count);

  /// Subject detail materials section count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {0 items in this subject} one {1 item in this subject} other {{count} items in this subject}}'**
  String subjectItemsInSubject(int count);

  /// Summary count label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {0 summaries} one {1 summary} other {{count} summaries}}'**
  String summariesCount(int count);

  /// Subject detail subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subject workspace'**
  String get subjectWorkspaceSubtitle;

  /// Materials section title.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get subjectMaterials;

  /// Summaries section title.
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get subjectSummaries;

  /// Summaries section subtitle.
  ///
  /// In en, this message translates to:
  /// **'Generated explanations from your materials'**
  String get subjectSummariesSubtitle;

  /// Subject detail study actions section.
  ///
  /// In en, this message translates to:
  /// **'Study actions'**
  String get subjectStudyActions;

  /// Study actions section subtitle.
  ///
  /// In en, this message translates to:
  /// **'Build from notes in this subject'**
  String get subjectStudyActionsSubtitle;

  /// Action to add pasted text material.
  ///
  /// In en, this message translates to:
  /// **'Add pasted text'**
  String get subjectAddPastedText;

  /// Action to create a study session.
  ///
  /// In en, this message translates to:
  /// **'Create study session'**
  String get subjectCreateStudySession;

  /// Helper text when study sessions are unavailable.
  ///
  /// In en, this message translates to:
  /// **'Add a material to create a study session.'**
  String get subjectAddMaterialForSession;

  /// Upload section title.
  ///
  /// In en, this message translates to:
  /// **'Upload materials'**
  String get subjectUploadMaterials;

  /// Upload section subtitle.
  ///
  /// In en, this message translates to:
  /// **'Private PDFs and images'**
  String get subjectUploadMaterialsSubtitle;

  /// Upload PDF action.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get subjectUploadPdf;

  /// Upload image action.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get subjectUploadImage;

  /// Focus topics section subtitle.
  ///
  /// In en, this message translates to:
  /// **'Cumulative misses from quizzes'**
  String get subjectFocusTopicsSubtitle;

  /// Quiz miss count without a subject prefix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 miss} other {{count} misses}}'**
  String missesCount(int count);

  /// Subject materials loading text.
  ///
  /// In en, this message translates to:
  /// **'Loading synced materials'**
  String get subjectLoadingMaterials;

  /// Supporting text when a subject detail sync error is non-blocking.
  ///
  /// In en, this message translates to:
  /// **'Your subject is still usable.'**
  String get subjectStillUsable;

  /// Subject materials empty state title.
  ///
  /// In en, this message translates to:
  /// **'No materials yet'**
  String get subjectNoMaterialsTitle;

  /// Subject materials empty message.
  ///
  /// In en, this message translates to:
  /// **'Add pasted text or upload a file to start studying.'**
  String get subjectNoMaterialsMessage;

  /// Subject summaries empty title.
  ///
  /// In en, this message translates to:
  /// **'No summaries yet'**
  String get subjectNoSummariesTitle;

  /// Subject summaries empty message.
  ///
  /// In en, this message translates to:
  /// **'Generate a summary from a material and it will appear here.'**
  String get subjectNoSummariesMessage;

  /// Tooltip to favorite a material.
  ///
  /// In en, this message translates to:
  /// **'Favorite material'**
  String get subjectFavoriteMaterialTooltip;

  /// Tooltip to remove a material favorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite material'**
  String get subjectUnfavoriteMaterialTooltip;

  /// Pasted-text entry screen title.
  ///
  /// In en, this message translates to:
  /// **'Add pasted text'**
  String get materialAddTitle;

  /// Pasted text entry guidance.
  ///
  /// In en, this message translates to:
  /// **'Paste notes, transcripts, or textbook excerpts. Keep the original source language.'**
  String get materialAddIntro;

  /// Material title field label.
  ///
  /// In en, this message translates to:
  /// **'Material title'**
  String get materialTitleLabel;

  /// Pasted material text field label.
  ///
  /// In en, this message translates to:
  /// **'Paste lecture text'**
  String get materialPasteTextLabel;

  /// Material kind label for user-entered pasted text.
  ///
  /// In en, this message translates to:
  /// **'Pasted text'**
  String get materialPastedTextKind;

  /// Uploaded material status label.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get materialUploadedStatus;

  /// Uploaded material status while processing has not started.
  ///
  /// In en, this message translates to:
  /// **'Waiting for processing'**
  String get materialWaitingForProcessing;

  /// Fallback file size label.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get materialUnknownSize;

  /// Save pasted material action.
  ///
  /// In en, this message translates to:
  /// **'Save material'**
  String get materialSaveMaterial;

  /// Busy label while saving material.
  ///
  /// In en, this message translates to:
  /// **'Saving material'**
  String get materialSavingMaterial;

  /// Snackbar after saving material.
  ///
  /// In en, this message translates to:
  /// **'Material saved.'**
  String get materialSaved;

  /// Snackbar after uploading material.
  ///
  /// In en, this message translates to:
  /// **'Material uploaded.'**
  String get materialUploaded;

  /// Upload PDF screen title.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get uploadPdfTitle;

  /// Upload image screen title.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get uploadImageTitle;

  /// PDF upload guidance.
  ///
  /// In en, this message translates to:
  /// **'PDF files up to 10.49 MB.'**
  String get uploadPdfGuidance;

  /// Image upload guidance.
  ///
  /// In en, this message translates to:
  /// **'PNG, JPG, JPEG, or WEBP images up to 8.39 MB.'**
  String get uploadImageGuidance;

  /// Choose PDF file action.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get uploadChoosePdf;

  /// Choose image file action.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get uploadChooseImage;

  /// PDF file kind label.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get uploadPdfKind;

  /// Image file kind label.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get uploadImageKind;

  /// Upload selected material action.
  ///
  /// In en, this message translates to:
  /// **'Upload material'**
  String get uploadMaterial;

  /// Upload busy status.
  ///
  /// In en, this message translates to:
  /// **'Uploading material'**
  String get uploadingMaterial;

  /// Favorites screen title.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// Favorites screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Study only favorites'**
  String get favoritesSubtitle;

  /// Favorite materials group title.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get favoritesMaterials;

  /// Favorite flashcards group title.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get favoritesFlashcards;

  /// Favorites loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading synced favorites'**
  String get favoritesLoading;

  /// Favorites sync error supporting text.
  ///
  /// In en, this message translates to:
  /// **'Your app is still usable.'**
  String get favoritesStillUsable;

  /// Favorites empty state title.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesNoFavoritesTitle;

  /// Favorites empty state message.
  ///
  /// In en, this message translates to:
  /// **'Mark materials or flashcards as favorites to find them here.'**
  String get favoritesNoFavoritesMessage;

  /// Tooltip/action to remove a flashcard favorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get favoritesUnfavorite;

  /// Tooltip/action to remove a material favorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite material'**
  String get favoritesUnfavoriteMaterial;

  /// Search screen title.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// Search field label.
  ///
  /// In en, this message translates to:
  /// **'Search study workspace'**
  String get searchFieldLabel;

  /// Search clear tooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// Initial search empty state title.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get searchStartTitle;

  /// Initial search empty state message.
  ///
  /// In en, this message translates to:
  /// **'Find subjects, materials, summaries, and flashcards.'**
  String get searchStartMessage;

  /// Search no results title.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResultsTitle;

  /// Search no results message.
  ///
  /// In en, this message translates to:
  /// **'Try another word or add more study material.'**
  String get searchNoResultsMessage;

  /// Search group heading for subjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects ({count})'**
  String searchSubjectsGroup(int count);

  /// Search group heading for materials.
  ///
  /// In en, this message translates to:
  /// **'Materials ({count})'**
  String searchMaterialsGroup(int count);

  /// Search group heading for flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards ({count})'**
  String searchFlashcardsGroup(int count);

  /// Usage screen title.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// Usage empty state title.
  ///
  /// In en, this message translates to:
  /// **'Usage tracking is not connected yet'**
  String get usageUnavailableTitle;

  /// Usage empty state message.
  ///
  /// In en, this message translates to:
  /// **'This prototype does not show token counts, quotas, or billing data.'**
  String get usageUnavailableMessage;

  /// Material detail screen title.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get materialDetailTitle;

  /// Busy status while deleting a material.
  ///
  /// In en, this message translates to:
  /// **'Deleting material'**
  String get materialDeletingTitle;

  /// Delete progress explanatory text.
  ///
  /// In en, this message translates to:
  /// **'Removing the source and material-specific study content.'**
  String get materialDeletingMessage;

  /// Busy status while AI content is generated.
  ///
  /// In en, this message translates to:
  /// **'Generating study content'**
  String get materialGeneratingStudyContentTitle;

  /// AI generation progress explanatory text.
  ///
  /// In en, this message translates to:
  /// **'Creating material-scoped learning content…'**
  String get materialGeneratingStudyContentMessage;

  /// Warning title for partial extraction results.
  ///
  /// In en, this message translates to:
  /// **'Partial result'**
  String get materialPartialResultTitle;

  /// Warning text for partial scanned PDF OCR.
  ///
  /// In en, this message translates to:
  /// **'Some pages could not be read. Available study text can still be used.'**
  String get materialPartialScannedMessage;

  /// File metadata section title.
  ///
  /// In en, this message translates to:
  /// **'File metadata'**
  String get materialFileMetadataTitle;

  /// Filename metadata label.
  ///
  /// In en, this message translates to:
  /// **'Filename'**
  String get materialFilenameLabel;

  /// File type metadata label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get materialTypeLabel;

  /// File size metadata label.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get materialSizeLabel;

  /// MIME type metadata label.
  ///
  /// In en, this message translates to:
  /// **'MIME'**
  String get materialMimeLabel;

  /// Material status metadata label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get materialStatusLabel;

  /// Created metadata label.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get materialCreatedLabel;

  /// Summary section title.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get materialSummaryTitle;

  /// Flashcards section title.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get materialFlashcardsTitle;

  /// Quiz section title.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get materialQuizTitle;

  /// Study session action section title.
  ///
  /// In en, this message translates to:
  /// **'Study session'**
  String get materialStudySessionTitle;

  /// Destructive confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete material?'**
  String get materialDeleteDialogTitle;

  /// Destructive action confirming material deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete material'**
  String get materialDeleteMaterial;

  /// Snackbar after material deletion.
  ///
  /// In en, this message translates to:
  /// **'Material deleted.'**
  String get materialDeleted;

  /// Delete dialog heading for deleted items.
  ///
  /// In en, this message translates to:
  /// **'Removed:'**
  String get materialDeleteRemoved;

  /// Delete dialog heading for retained items.
  ///
  /// In en, this message translates to:
  /// **'Preserved:'**
  String get materialDeletePreserved;

  /// Delete dialog item.
  ///
  /// In en, this message translates to:
  /// **'Source material'**
  String get materialDeleteSourceMaterial;

  /// Delete dialog item.
  ///
  /// In en, this message translates to:
  /// **'Uploaded file, if present'**
  String get materialDeleteUploadedFile;

  /// Delete dialog item.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get materialDeleteSummary;

  /// Delete dialog item.
  ///
  /// In en, this message translates to:
  /// **'Material-specific flashcards'**
  String get materialDeleteFlashcards;

  /// Delete dialog item.
  ///
  /// In en, this message translates to:
  /// **'Material-specific quizzes'**
  String get materialDeleteQuizzes;

  /// Delete dialog preserved item.
  ///
  /// In en, this message translates to:
  /// **'Completed quiz results'**
  String get materialDeleteQuizResults;

  /// Delete dialog preserved item.
  ///
  /// In en, this message translates to:
  /// **'Progress history'**
  String get materialDeleteProgressHistory;

  /// Delete dialog preserved item.
  ///
  /// In en, this message translates to:
  /// **'Cumulative weak topics'**
  String get materialDeleteWeakTopics;

  /// Delete dialog preserved item.
  ///
  /// In en, this message translates to:
  /// **'Study history'**
  String get materialDeleteStudyHistory;

  /// Material ready status after text extraction.
  ///
  /// In en, this message translates to:
  /// **'Text extracted'**
  String get materialTextExtracted;

  /// Material ready status after OCR extraction.
  ///
  /// In en, this message translates to:
  /// **'Text extracted with OCR'**
  String get materialTextExtractedWithOcr;

  /// Processed pages out of total pages.
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} pages'**
  String materialPagesProgress(int processed, int total);

  /// Material page count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 page} other {{count} pages}}'**
  String materialPagesCount(int count);

  /// Material processing status.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get materialProcessingStatus;

  /// Material failed status.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get materialFailedStatus;

  /// Material processing panel title.
  ///
  /// In en, this message translates to:
  /// **'Processing material'**
  String get materialProcessingTitle;

  /// Recovery panel title for stuck processing.
  ///
  /// In en, this message translates to:
  /// **'Processing appears to be stuck'**
  String get materialStuckTitle;

  /// Recovery panel text for stuck processing.
  ///
  /// In en, this message translates to:
  /// **'Reset this material and try processing again.'**
  String get materialStuckMessage;

  /// Recovery action label.
  ///
  /// In en, this message translates to:
  /// **'Reset and try again'**
  String get materialResetTryAgain;

  /// Image extraction failure title.
  ///
  /// In en, this message translates to:
  /// **'Image text extraction failed'**
  String get imageExtractionFailedTitle;

  /// Image extraction section title.
  ///
  /// In en, this message translates to:
  /// **'Image text extraction'**
  String get imageExtractionTitle;

  /// Image OCR loading text.
  ///
  /// In en, this message translates to:
  /// **'Reading image text…'**
  String get imageReadingText;

  /// Image extraction helper text.
  ///
  /// In en, this message translates to:
  /// **'Extract readable study text from this image.'**
  String get imageExtractHelper;

  /// Retry image OCR action.
  ///
  /// In en, this message translates to:
  /// **'Retry image text extraction'**
  String get imageRetryExtraction;

  /// Start image OCR action.
  ///
  /// In en, this message translates to:
  /// **'Extract text from image'**
  String get imageExtractText;

  /// PDF OCR mixed-document title.
  ///
  /// In en, this message translates to:
  /// **'Some pages need OCR'**
  String get pdfSomePagesNeedOcr;

  /// PDF needs OCR title.
  ///
  /// In en, this message translates to:
  /// **'No usable selectable text was found'**
  String get pdfNoSelectableText;

  /// Scanned PDF OCR loading text.
  ///
  /// In en, this message translates to:
  /// **'Reading scanned PDF pages…'**
  String get pdfReadingScannedPages;

  /// PDF pages requiring OCR.
  ///
  /// In en, this message translates to:
  /// **'{candidateCount} of {pageCount} pages require OCR.'**
  String pdfRequiresOcrCount(int candidateCount, int pageCount);

  /// PDF requires OCR helper text.
  ///
  /// In en, this message translates to:
  /// **'This PDF requires OCR before its study tools are available.'**
  String get pdfRequiresOcrMessage;

  /// Start PDF OCR action.
  ///
  /// In en, this message translates to:
  /// **'Scan PDF with OCR'**
  String get pdfScanWithOcr;

  /// PDF text extraction failure title.
  ///
  /// In en, this message translates to:
  /// **'Text extraction failed'**
  String get pdfTextExtractionFailedTitle;

  /// PDF text extraction section title.
  ///
  /// In en, this message translates to:
  /// **'PDF text extraction'**
  String get pdfTextExtractionTitle;

  /// PDF text extraction loading text.
  ///
  /// In en, this message translates to:
  /// **'Extracting selectable text…'**
  String get pdfExtractingSelectable;

  /// PDF extraction generic failure.
  ///
  /// In en, this message translates to:
  /// **'Could not extract text. Try again.'**
  String get pdfCouldNotExtract;

  /// PDF extraction helper text.
  ///
  /// In en, this message translates to:
  /// **'Extract selectable text from this PDF.'**
  String get pdfExtractHelper;

  /// Retry PDF extraction action.
  ///
  /// In en, this message translates to:
  /// **'Retry text extraction'**
  String get pdfRetryTextExtraction;

  /// Start PDF extraction action.
  ///
  /// In en, this message translates to:
  /// **'Extract text'**
  String get pdfExtractText;

  /// PDF OCR confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Scan PDF with OCR?'**
  String get pdfScanDialogTitle;

  /// PDF OCR confirmation text.
  ///
  /// In en, this message translates to:
  /// **'This PDF has {pageCount} pages. {candidateCount} pages require OCR.\n\nThis version supports up to 10 total pages. AI OCR can take longer and uses paid processing.'**
  String pdfScanDialogMessage(int pageCount, int candidateCount);

  /// Confirm PDF OCR action.
  ///
  /// In en, this message translates to:
  /// **'Start OCR'**
  String get pdfStartOcr;

  /// Summary empty state.
  ///
  /// In en, this message translates to:
  /// **'No summary yet.'**
  String get summaryNoSummary;

  /// Regenerate summary action.
  ///
  /// In en, this message translates to:
  /// **'Regenerate summary'**
  String get summaryRegenerate;

  /// Generate AI summary action.
  ///
  /// In en, this message translates to:
  /// **'Summarize with AI'**
  String get summaryWithAi;

  /// Generate mock summary action.
  ///
  /// In en, this message translates to:
  /// **'Generate mock summary'**
  String get summaryGenerateMock;

  /// Summary generation busy label.
  ///
  /// In en, this message translates to:
  /// **'Generating summary'**
  String get summaryGenerating;

  /// Flashcard count ready label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 flashcard ready.} other {{count} flashcards ready.}}'**
  String flashcardsReady(int count);

  /// Flashcards empty state.
  ///
  /// In en, this message translates to:
  /// **'No flashcards yet.'**
  String get flashcardsNoFlashcards;

  /// Flashcards too-short helper.
  ///
  /// In en, this message translates to:
  /// **'Add more lecture text before generating flashcards.'**
  String get flashcardsTooShort;

  /// Start flashcard training action.
  ///
  /// In en, this message translates to:
  /// **'Start training'**
  String get flashcardsStartTraining;

  /// Open flashcards action.
  ///
  /// In en, this message translates to:
  /// **'Review these flashcards'**
  String get flashcardsReviewThese;

  /// Generate flashcards action.
  ///
  /// In en, this message translates to:
  /// **'Generate flashcards'**
  String get flashcardsGenerate;

  /// Flashcards generation busy label.
  ///
  /// In en, this message translates to:
  /// **'Generating flashcards'**
  String get flashcardsGenerating;

  /// Snackbar when generation creates no unique flashcards.
  ///
  /// In en, this message translates to:
  /// **'No new unique flashcards were generated.'**
  String get flashcardsNoNewGenerated;

  /// Snackbar after new flashcards are generated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 new flashcard generated.} other {{count} new flashcards generated.}}'**
  String flashcardsNewGenerated(int count);

  /// Quiz question count ready label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 question ready.} other {{count} questions ready.}}'**
  String quizQuestionsReady(int count);

  /// Quiz empty state.
  ///
  /// In en, this message translates to:
  /// **'No quiz yet.'**
  String get quizNoQuiz;

  /// Start quiz action.
  ///
  /// In en, this message translates to:
  /// **'Take quiz'**
  String get quizTakeQuiz;

  /// Generate quiz action.
  ///
  /// In en, this message translates to:
  /// **'Generate quiz'**
  String get quizGenerate;

  /// Generate mock quiz action.
  ///
  /// In en, this message translates to:
  /// **'Generate mock quiz'**
  String get quizGenerateMock;

  /// Quiz generation busy label.
  ///
  /// In en, this message translates to:
  /// **'Generating quiz'**
  String get quizGenerating;

  /// Generic localized fallback for safe errors when no specific mapping exists.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericLocalizedError;

  /// Validation error for empty name.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get errorEnterName;

  /// Validation error for invalid email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errorEnterValidEmail;

  /// Validation error for an empty email field.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get errorEmailRequired;

  /// Validation error for an empty password field.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get errorPasswordRequired;

  /// Safe combined sign-in failure that does not reveal account existence.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Check your email address and password.'**
  String get authInvalidCredentials;

  /// Authoritative email-not-confirmed sign-in error.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address before signing in.'**
  String get authEmailNotConfirmed;

  /// Authentication rate-limit error.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Try again later.'**
  String get authRateLimited;

  /// Authentication network error.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get authNetworkFailure;

  /// Temporary authentication service error.
  ///
  /// In en, this message translates to:
  /// **'The authentication service is temporarily unavailable. Try again later.'**
  String get authServiceUnavailable;

  /// Validation error for a short password.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get errorPasswordTooShort;

  /// Validation error for missing password confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password.'**
  String get errorConfirmPassword;

  /// Validation error for password mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get errorPasswordsDoNotMatch;

  /// Auth error for profile editing.
  ///
  /// In en, this message translates to:
  /// **'Log in to edit your profile.'**
  String get errorLoginToEditProfile;

  /// Friendly signup error for duplicate account.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Try logging in instead.'**
  String get errorAccountAlreadyExists;

  /// Profile update error.
  ///
  /// In en, this message translates to:
  /// **'Could not update the account profile.'**
  String get errorCouldNotUpdateProfile;

  /// Logout failure message.
  ///
  /// In en, this message translates to:
  /// **'Could not log out.'**
  String get errorCouldNotLogOut;

  /// Subject sync error.
  ///
  /// In en, this message translates to:
  /// **'Could not sync subjects. Try again.'**
  String get errorCouldNotSyncSubjects;

  /// Validation error for subject creation.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject name.'**
  String get errorEnterSubjectName;

  /// Auth error for syncing subjects.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync subjects.'**
  String get errorLoginToSyncSubjects;

  /// Material sync error.
  ///
  /// In en, this message translates to:
  /// **'Could not sync materials. Try again.'**
  String get errorCouldNotSyncMaterials;

  /// Validation error for pasted material.
  ///
  /// In en, this message translates to:
  /// **'Enter a title and pasted text.'**
  String get errorEnterTitleAndText;

  /// Auth error for syncing materials.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync materials.'**
  String get errorLoginToSyncMaterials;

  /// Upload validation error.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF or image to upload.'**
  String get errorChoosePdfOrImage;

  /// Auth error for uploads.
  ///
  /// In en, this message translates to:
  /// **'Log in to upload materials.'**
  String get errorLoginToUploadMaterials;

  /// Upload failure.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the selected file.'**
  String get errorCouldNotUploadFile;

  /// Unsupported file validation error.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported PDF, PNG, JPG, JPEG, or WEBP file.'**
  String get errorUnsupportedFile;

  /// Empty file validation error.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty.'**
  String get errorEmptyFile;

  /// File signature validation error.
  ///
  /// In en, this message translates to:
  /// **'The file contents do not match the selected file type.'**
  String get errorFileTypeMismatch;

  /// File picker failure.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file picker.'**
  String get errorCouldNotOpenFilePicker;

  /// Missing material error.
  ///
  /// In en, this message translates to:
  /// **'Material unavailable.'**
  String get errorMaterialUnavailable;

  /// Favorite update error.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorite.'**
  String get errorCouldNotUpdateFavorite;

  /// Favorite sync error.
  ///
  /// In en, this message translates to:
  /// **'Could not sync favorites. Try again.'**
  String get errorCouldNotSyncFavorites;

  /// Material deletion error.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the material. Try again.'**
  String get errorCouldNotDeleteMaterial;

  /// Auth error for deleting a material.
  ///
  /// In en, this message translates to:
  /// **'Log in to delete this material.'**
  String get errorLoginToDeleteMaterial;

  /// Processing recovery error.
  ///
  /// In en, this message translates to:
  /// **'Processing could not be reset.'**
  String get errorCouldNotResetProcessing;

  /// PDF extraction unavailable error.
  ///
  /// In en, this message translates to:
  /// **'This PDF cannot be extracted.'**
  String get errorPdfCannotBeExtracted;

  /// Auth error for PDF text extraction.
  ///
  /// In en, this message translates to:
  /// **'Log in to extract PDF text.'**
  String get errorLoginToExtractPdf;

  /// PDF extraction failure.
  ///
  /// In en, this message translates to:
  /// **'Could not extract text. Try again.'**
  String get errorCouldNotExtractText;

  /// Image OCR unavailable error.
  ///
  /// In en, this message translates to:
  /// **'This image cannot be processed.'**
  String get errorImageCannotBeProcessed;

  /// Auth error for image OCR.
  ///
  /// In en, this message translates to:
  /// **'Log in to extract image text.'**
  String get errorLoginToExtractImage;

  /// Image OCR failure.
  ///
  /// In en, this message translates to:
  /// **'Could not extract image text. Try again.'**
  String get errorCouldNotExtractImageText;

  /// Scanned PDF OCR unavailable error.
  ///
  /// In en, this message translates to:
  /// **'This PDF cannot be scanned with OCR.'**
  String get errorPdfCannotBeScanned;

  /// Auth error for scanned PDF OCR.
  ///
  /// In en, this message translates to:
  /// **'Log in to scan this PDF.'**
  String get errorLoginToScanPdf;

  /// Scanned PDF OCR failure.
  ///
  /// In en, this message translates to:
  /// **'Could not scan this PDF. Try again.'**
  String get errorCouldNotScanPdf;

  /// Scanned PDF OCR page limit error.
  ///
  /// In en, this message translates to:
  /// **'This version can scan PDFs up to 10 pages. Split the PDF and upload a smaller file.'**
  String get errorPdfOcrPageLimit;

  /// PDF extraction safe message for scanned PDFs.
  ///
  /// In en, this message translates to:
  /// **'No selectable text was found. Scanned PDFs will be supported in the OCR phase.'**
  String get errorNoSelectablePdfText;

  /// Image OCR safe message for no text.
  ///
  /// In en, this message translates to:
  /// **'No readable text was found in this image.'**
  String get errorNoReadableImageText;

  /// Invalid PDF safe message.
  ///
  /// In en, this message translates to:
  /// **'The uploaded file is not a valid PDF.'**
  String get errorInvalidPdf;

  /// Unreadable PDF safe message.
  ///
  /// In en, this message translates to:
  /// **'Could not read the uploaded PDF.'**
  String get errorCouldNotReadPdf;

  /// Unreadable image safe message.
  ///
  /// In en, this message translates to:
  /// **'Could not read the uploaded image.'**
  String get errorCouldNotReadImage;

  /// Invalid image safe message.
  ///
  /// In en, this message translates to:
  /// **'The uploaded file is not a valid supported image.'**
  String get errorInvalidImage;

  /// Summary generation failure.
  ///
  /// In en, this message translates to:
  /// **'Could not generate summary. Try again.'**
  String get errorCouldNotGenerateSummary;

  /// Summary minimum input validation.
  ///
  /// In en, this message translates to:
  /// **'Add more lecture text before generating a summary.'**
  String get errorAddMoreLectureText;

  /// Flashcard generation failure.
  ///
  /// In en, this message translates to:
  /// **'Could not generate flashcards. Try again.'**
  String get errorCouldNotGenerateFlashcards;

  /// Quiz generation failure.
  ///
  /// In en, this message translates to:
  /// **'Could not generate quiz. Try again.'**
  String get errorCouldNotGenerateQuiz;

  /// Generic flashcard count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card} other {{count} cards}}'**
  String studyCards(int count);

  /// Generic question count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 question} other {{count} questions}}'**
  String studyQuestions(int count);

  /// Completed attempt count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 attempt} other {{count} attempts}}'**
  String studyAttempts(int count);

  /// Incorrect-answer count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 miss} other {{count} misses}}'**
  String studyMisses(int count);

  /// No description provided for @studyProgress.
  ///
  /// In en, this message translates to:
  /// **'Study progress'**
  String get studyProgress;

  /// Accessible study progress value.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String studyProgressValue(int current, int total);

  /// No description provided for @studyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get studyQuestion;

  /// No description provided for @studyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get studyAnswer;

  /// No description provided for @studyShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get studyShowAnswer;

  /// No description provided for @studyHideAnswer.
  ///
  /// In en, this message translates to:
  /// **'Hide answer'**
  String get studyHideAnswer;

  /// No description provided for @studyFlashcardQuestionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Flashcard question. Activate to show answer.'**
  String get studyFlashcardQuestionSemantics;

  /// No description provided for @studyFlashcardAnswerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Flashcard answer. Activate to hide answer.'**
  String get studyFlashcardAnswerSemantics;

  /// No description provided for @studyMissedAction.
  ///
  /// In en, this message translates to:
  /// **'I missed it'**
  String get studyMissedAction;

  /// No description provided for @studyKnownAction.
  ///
  /// In en, this message translates to:
  /// **'I knew it'**
  String get studyKnownAction;

  /// No description provided for @studyCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get studyCorrect;

  /// No description provided for @studyIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get studyIncorrect;

  /// Correct answer label; answer is generated content.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String studyCorrectAnswer(String answer);

  /// Accessible correctness for a generated answer choice.
  ///
  /// In en, this message translates to:
  /// **'{choice}, correct answer'**
  String studyChoiceCorrectSemantics(String choice);

  /// Accessible incorrect state for a generated answer choice.
  ///
  /// In en, this message translates to:
  /// **'{choice}, incorrect answer'**
  String studyChoiceIncorrectSemantics(String choice);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get commonReturn;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get commonCustom;

  /// No description provided for @commonPrototype.
  ///
  /// In en, this message translates to:
  /// **'Prototype'**
  String get commonPrototype;

  /// No description provided for @commonGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get commonGenerate;

  /// No description provided for @flashcardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcardsTitle;

  /// No description provided for @flashcardsAllTitle.
  ///
  /// In en, this message translates to:
  /// **'All flashcards — {subject}'**
  String flashcardsAllTitle(Object subject);

  /// No description provided for @flashcardsMaterialTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcards — {material}'**
  String flashcardsMaterialTitle(Object material);

  /// No description provided for @flashcardsScopeMaterial.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card from this material} other {{count} cards from this material}}'**
  String flashcardsScopeMaterial(num count);

  /// No description provided for @flashcardsScopeSubject.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card across this subject} other {{count} cards across this subject}}'**
  String flashcardsScopeSubject(num count);

  /// No description provided for @flashcardsSessionSize.
  ///
  /// In en, this message translates to:
  /// **'Study session size'**
  String get flashcardsSessionSize;

  /// No description provided for @flashcardsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card available for this selection.} other {{count} cards available for this selection.}}'**
  String flashcardsAvailable(num count);

  /// No description provided for @flashcardsGenerateMoreGuidance.
  ///
  /// In en, this message translates to:
  /// **'Generate more flashcards from a material to unlock larger sessions.'**
  String get flashcardsGenerateMoreGuidance;

  /// No description provided for @flashcardsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading synced flashcards'**
  String get flashcardsLoading;

  /// No description provided for @flashcardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No flashcards yet'**
  String get flashcardsEmptyTitle;

  /// No description provided for @flashcardsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add or generate cards to start reviewing.'**
  String get flashcardsEmptyMessage;

  /// No description provided for @flashcardsEmptyCloudMessage.
  ///
  /// In en, this message translates to:
  /// **'Generate them from a pasted-text material.'**
  String get flashcardsEmptyCloudMessage;

  /// No description provided for @flashcardsReviewFocus.
  ///
  /// In en, this message translates to:
  /// **'Review focus'**
  String get flashcardsReviewFocus;

  /// No description provided for @flashcardsFilterSemantics.
  ///
  /// In en, this message translates to:
  /// **'Flashcard filter'**
  String get flashcardsFilterSemantics;

  /// No description provided for @flashcardsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get flashcardsFilterAll;

  /// No description provided for @flashcardsFilterWeak.
  ///
  /// In en, this message translates to:
  /// **'For review'**
  String get flashcardsFilterWeak;

  /// No description provided for @flashcardsFilterDue.
  ///
  /// In en, this message translates to:
  /// **'Due for review'**
  String get flashcardsFilterDue;

  /// No description provided for @flashcardsStartTrainingCount.
  ///
  /// In en, this message translates to:
  /// **'Start training ({count, plural, one {1 card} other {{count} cards}})'**
  String flashcardsStartTrainingCount(num count);

  /// No description provided for @flashcardsTrainWeak.
  ///
  /// In en, this message translates to:
  /// **'Train cards for review'**
  String get flashcardsTrainWeak;

  /// No description provided for @flashcardsReviewDue.
  ///
  /// In en, this message translates to:
  /// **'Review due cards'**
  String get flashcardsReviewDue;

  /// No description provided for @flashcardsNoWeak.
  ///
  /// In en, this message translates to:
  /// **'No cards need extra review right now.'**
  String get flashcardsNoWeak;

  /// No description provided for @flashcardsNoDue.
  ///
  /// In en, this message translates to:
  /// **'No cards are due right now.'**
  String get flashcardsNoDue;

  /// No description provided for @flashcardsCustomSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom session size'**
  String get flashcardsCustomSessionTitle;

  /// No description provided for @flashcardsCardsField.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get flashcardsCardsField;

  /// No description provided for @flashcardsMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum: {count}'**
  String flashcardsMaximum(Object count);

  /// No description provided for @flashcardsChooseAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least 1 card.'**
  String get flashcardsChooseAtLeastOne;

  /// No description provided for @flashcardsOnlyAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {count, plural, one {1 card is available} other {{count} cards are available}} for this selection.'**
  String flashcardsOnlyAvailable(num count);

  /// Metadata framing source-language topic and difficulty.
  ///
  /// In en, this message translates to:
  /// **'Topic: {topic} · {difficulty}'**
  String flashcardsTopicDifficulty(String topic, String difficulty);

  /// No description provided for @flashcardsReviewStats.
  ///
  /// In en, this message translates to:
  /// **'Known {known} · Missed {missed}'**
  String flashcardsReviewStats(Object known, Object missed);

  /// No description provided for @flashcardGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate new flashcards'**
  String get flashcardGenerationTitle;

  /// No description provided for @flashcardGenerationGuidance.
  ///
  /// In en, this message translates to:
  /// **'Choose how many new flashcards to add.'**
  String get flashcardGenerationGuidance;

  /// No description provided for @flashcardGenerationCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {count, plural, one {1 card} other {{count} cards}}'**
  String flashcardGenerationCurrent(num count);

  /// No description provided for @flashcardGenerationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add: {count, plural, one {1 card} other {{count} cards}}'**
  String flashcardGenerationAdd(num count);

  /// No description provided for @flashcardGenerationProjected.
  ///
  /// In en, this message translates to:
  /// **'Projected total: {count, plural, one {1 card} other {{count} cards}}'**
  String flashcardGenerationProjected(num count);

  /// No description provided for @flashcardGenerationNewField.
  ///
  /// In en, this message translates to:
  /// **'New flashcards'**
  String get flashcardGenerationNewField;

  /// No description provided for @flashcardGenerationRangeError.
  ///
  /// In en, this message translates to:
  /// **'Choose between 1 and 30 new flashcards.'**
  String get flashcardGenerationRangeError;

  /// No description provided for @flashcardGenerationMaxError.
  ///
  /// In en, this message translates to:
  /// **'Choose no more than 30 flashcards.'**
  String get flashcardGenerationMaxError;

  /// No description provided for @trainingTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcard training'**
  String get trainingTitle;

  /// No description provided for @trainingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No flashcards to train'**
  String get trainingEmptyTitle;

  /// No description provided for @trainingEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Generate flashcards first.'**
  String get trainingEmptyMessage;

  /// No description provided for @trainingProgress.
  ///
  /// In en, this message translates to:
  /// **'Flashcard progress'**
  String get trainingProgress;

  /// No description provided for @trainingComplete.
  ///
  /// In en, this message translates to:
  /// **'Training complete'**
  String get trainingComplete;

  /// No description provided for @trainingReviewed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card reviewed} other {{count} cards reviewed}}'**
  String trainingReviewed(num count);

  /// No description provided for @trainingKnown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card known} other {{count} cards known}}'**
  String trainingKnown(num count);

  /// No description provided for @trainingMissed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 card missed} other {{count} cards missed}}'**
  String trainingMissed(num count);

  /// No description provided for @trainingReviewMissed.
  ///
  /// In en, this message translates to:
  /// **'Review missed cards again'**
  String get trainingReviewMissed;

  /// No description provided for @trainingReviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get trainingReviewAgain;

  /// No description provided for @errorCouldNotSaveReview.
  ///
  /// In en, this message translates to:
  /// **'Could not save review progress.'**
  String get errorCouldNotSaveReview;

  /// No description provided for @quizUiTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quizUiTitle;

  /// No description provided for @quizEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions available'**
  String get quizEmptyTitle;

  /// No description provided for @quizEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Return to the material and generate a quiz first.'**
  String get quizEmptyMessage;

  /// No description provided for @quizProgress.
  ///
  /// In en, this message translates to:
  /// **'Question progress'**
  String get quizProgress;

  /// No description provided for @quizShowScore.
  ///
  /// In en, this message translates to:
  /// **'Show score'**
  String get quizShowScore;

  /// No description provided for @quizMissedReview.
  ///
  /// In en, this message translates to:
  /// **'Missed question review'**
  String get quizMissedReview;

  /// No description provided for @quizFinishReview.
  ///
  /// In en, this message translates to:
  /// **'Finish review'**
  String get quizFinishReview;

  /// No description provided for @quizResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get quizResult;

  /// No description provided for @quizScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {percent}%'**
  String quizScore(Object percent);

  /// No description provided for @quizCorrectCount.
  ///
  /// In en, this message translates to:
  /// **'{correct, plural, one {1 correct answer out of {total}} other {{correct} correct answers out of {total}}}'**
  String quizCorrectCount(num correct, Object total);

  /// No description provided for @quizMissedTopics.
  ///
  /// In en, this message translates to:
  /// **'Missed topics'**
  String get quizMissedTopics;

  /// No description provided for @quizNoMissedTopics.
  ///
  /// In en, this message translates to:
  /// **'No missed topics. Great work!'**
  String get quizNoMissedTopics;

  /// No description provided for @quizSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving quiz attempt…'**
  String get quizSaving;

  /// No description provided for @quizUnsyncedWarning.
  ///
  /// In en, this message translates to:
  /// **'This score was calculated locally and was not synchronized.'**
  String get quizUnsyncedWarning;

  /// No description provided for @quizReviewMissed.
  ///
  /// In en, this message translates to:
  /// **'Review missed questions'**
  String get quizReviewMissed;

  /// No description provided for @quizReviewMaterial.
  ///
  /// In en, this message translates to:
  /// **'Review material'**
  String get quizReviewMaterial;

  /// No description provided for @quizRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry quiz'**
  String get quizRetry;

  /// No description provided for @errorCouldNotSaveQuizAttempt.
  ///
  /// In en, this message translates to:
  /// **'Could not save this quiz attempt.'**
  String get errorCouldNotSaveQuizAttempt;

  /// No description provided for @progressLatestQuiz.
  ///
  /// In en, this message translates to:
  /// **'Latest quiz'**
  String get progressLatestQuiz;

  /// No description provided for @progressAttemptsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Attempts completed'**
  String get progressAttemptsCompleted;

  /// No description provided for @progressFocusTopics.
  ///
  /// In en, this message translates to:
  /// **'Focus topics'**
  String get progressFocusTopics;

  /// No description provided for @progressHistoryExplanation.
  ///
  /// In en, this message translates to:
  /// **'Miss counts are cumulative quiz history, not a mastery score.'**
  String get progressHistoryExplanation;

  /// No description provided for @progressNoAttempts.
  ///
  /// In en, this message translates to:
  /// **'Complete a quiz to see results here.'**
  String get progressNoAttempts;

  /// No description provided for @progressLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading progress'**
  String get progressLoading;

  /// No description provided for @progressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No quiz attempts yet'**
  String get progressEmptyTitle;

  /// No description provided for @progressEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Complete a quiz to build your progress history.'**
  String get progressEmptyMessage;

  /// No description provided for @afterLectureTitle.
  ///
  /// In en, this message translates to:
  /// **'After Lecture'**
  String get afterLectureTitle;

  /// No description provided for @examPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Exam Prep'**
  String get examPrepTitle;

  /// No description provided for @continueStudyingTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue Studying'**
  String get continueStudyingTitle;

  /// No description provided for @aiTeacherTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Teacher'**
  String get aiTeacherTitle;

  /// No description provided for @studySessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Session'**
  String get studySessionTitle;

  /// No description provided for @studyLocalPrototype.
  ///
  /// In en, this message translates to:
  /// **'Local prototype'**
  String get studyLocalPrototype;

  /// No description provided for @studyLocalMockCoaching.
  ///
  /// In en, this message translates to:
  /// **'Local mock coaching'**
  String get studyLocalMockCoaching;

  /// No description provided for @studyChooseSubject.
  ///
  /// In en, this message translates to:
  /// **'Choose subject'**
  String get studyChooseSubject;

  /// No description provided for @studyChooseMaterial.
  ///
  /// In en, this message translates to:
  /// **'Choose material'**
  String get studyChooseMaterial;

  /// No description provided for @studyCreateSession.
  ///
  /// In en, this message translates to:
  /// **'Create study session'**
  String get studyCreateSession;

  /// No description provided for @studyNoSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet'**
  String get studyNoSubjectsTitle;

  /// No description provided for @studyOpenSubjects.
  ///
  /// In en, this message translates to:
  /// **'Open Subjects'**
  String get studyOpenSubjects;

  /// No description provided for @studyNoMaterialsTitle.
  ///
  /// In en, this message translates to:
  /// **'No materials yet'**
  String get studyNoMaterialsTitle;

  /// No description provided for @studyContinueSession.
  ///
  /// In en, this message translates to:
  /// **'Continue session'**
  String get studyContinueSession;

  /// No description provided for @studyNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get studyNotCompleted;

  /// No description provided for @studyBackToSubject.
  ///
  /// In en, this message translates to:
  /// **'Back to subject'**
  String get studyBackToSubject;

  /// No description provided for @studyUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'No study material available'**
  String get studyUnavailableTitle;

  /// No description provided for @studySessionOverview.
  ///
  /// In en, this message translates to:
  /// **'Session overview'**
  String get studySessionOverview;

  /// No description provided for @studyEstimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated study time'**
  String get studyEstimatedTime;

  /// No description provided for @studySummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get studySummary;

  /// No description provided for @studyFlashcardsAction.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get studyFlashcardsAction;

  /// No description provided for @studyAiTeacherAction.
  ///
  /// In en, this message translates to:
  /// **'AI Teacher'**
  String get studyAiTeacherAction;

  /// No description provided for @studyMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String studyMinutes(Object count);

  /// No description provided for @studySelectSubject.
  ///
  /// In en, this message translates to:
  /// **'Select a subject'**
  String get studySelectSubject;

  /// No description provided for @studySelectSubjectMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose the lecture subject to continue.'**
  String get studySelectSubjectMessage;

  /// No description provided for @studyNoMaterialsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a usable material before creating this study session.'**
  String get studyNoMaterialsMessage;

  /// No description provided for @afterLecturePrototype.
  ///
  /// In en, this message translates to:
  /// **'Local prototype guidance'**
  String get afterLecturePrototype;

  /// No description provided for @afterLectureNoSubjectsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a subject before starting an after-lecture session.'**
  String get afterLectureNoSubjectsMessage;

  /// No description provided for @afterLectureConfidence.
  ///
  /// In en, this message translates to:
  /// **'How confident do you feel?'**
  String get afterLectureConfidence;

  /// No description provided for @afterLectureSchedule.
  ///
  /// In en, this message translates to:
  /// **'Prototype study schedule'**
  String get afterLectureSchedule;

  /// No description provided for @afterLectureScheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Estimated locally; this is not tracked study time.'**
  String get afterLectureScheduleHelp;

  /// No description provided for @examPrepPrototype.
  ///
  /// In en, this message translates to:
  /// **'Local prototype plan'**
  String get examPrepPrototype;

  /// No description provided for @examPrepHeading.
  ///
  /// In en, this message translates to:
  /// **'Prepare for an exam'**
  String get examPrepHeading;

  /// No description provided for @examPrepHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a local study plan from a subject, materials, and weak topics.'**
  String get examPrepHelp;

  /// No description provided for @examPrepNoSubjectsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a subject before preparing an exam plan.'**
  String get examPrepNoSubjectsMessage;

  /// No description provided for @examPrepDatePreview.
  ///
  /// In en, this message translates to:
  /// **'Exam date preview'**
  String get examPrepDatePreview;

  /// No description provided for @examPrepDateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date selection is not available in this prototype.'**
  String get examPrepDateUnavailable;

  /// No description provided for @examPrepDate.
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get examPrepDate;

  /// No description provided for @examPrepMockDate.
  ///
  /// In en, this message translates to:
  /// **'Mock date: 2 weeks from now'**
  String get examPrepMockDate;

  /// No description provided for @examPrepMaterialsPreview.
  ///
  /// In en, this message translates to:
  /// **'Selected materials preview'**
  String get examPrepMaterialsPreview;

  /// No description provided for @examPrepMaterialsEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'The plan can still start from the selected subject.'**
  String get examPrepMaterialsEmptyHelp;

  /// No description provided for @examPrepIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included in plan'**
  String get examPrepIncluded;

  /// No description provided for @examPrepTopicsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview focus topics'**
  String get examPrepTopicsPreview;

  /// No description provided for @examPrepTopicsHelp.
  ///
  /// In en, this message translates to:
  /// **'Locally generated prototype guidance; not a mastery score.'**
  String get examPrepTopicsHelp;

  /// No description provided for @examPrepPlanPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview preparation plan'**
  String get examPrepPlanPreview;

  /// No description provided for @examPrepPlanHelp.
  ///
  /// In en, this message translates to:
  /// **'Locally generated prototype guidance.'**
  String get examPrepPlanHelp;

  /// No description provided for @continueEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to continue'**
  String get continueEmptyTitle;

  /// No description provided for @continueEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a study session from one of your subjects.'**
  String get continueEmptyMessage;

  /// No description provided for @continueUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The subject or source for your latest session is no longer available.'**
  String get continueUnavailableMessage;

  /// No description provided for @continueFrom.
  ///
  /// In en, this message translates to:
  /// **'Continue from {material}'**
  String continueFrom(Object material);

  /// No description provided for @continueLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest study session'**
  String get continueLatest;

  /// No description provided for @continueSummary.
  ///
  /// In en, this message translates to:
  /// **'Session summary'**
  String get continueSummary;

  /// No description provided for @continueQuickQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quick quiz'**
  String get continueQuickQuiz;

  /// No description provided for @continueLastScore.
  ///
  /// In en, this message translates to:
  /// **'Last score: {percent}%'**
  String continueLastScore(Object percent);

  /// No description provided for @continueNoTopics.
  ///
  /// In en, this message translates to:
  /// **'No focus topics recorded for this session.'**
  String get continueNoTopics;

  /// No description provided for @aiTeacherStatus.
  ///
  /// In en, this message translates to:
  /// **'Local mock coaching · Prototype'**
  String get aiTeacherStatus;

  /// No description provided for @aiTeacherNoLive.
  ///
  /// In en, this message translates to:
  /// **'Canned local responses; no live AI connection.'**
  String get aiTeacherNoLive;

  /// No description provided for @aiTeacherHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a coaching style. The response below stays entirely local and uses mock text.'**
  String get aiTeacherHelp;

  /// No description provided for @aiTeacherPrompt.
  ///
  /// In en, this message translates to:
  /// **'Coach prompt'**
  String get aiTeacherPrompt;

  /// No description provided for @aiTeacherPromptSimple.
  ///
  /// In en, this message translates to:
  /// **'Explain simpler'**
  String get aiTeacherPromptSimple;

  /// No description provided for @aiTeacherPromptExample.
  ///
  /// In en, this message translates to:
  /// **'Give another example'**
  String get aiTeacherPromptExample;

  /// No description provided for @aiTeacherPromptQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get aiTeacherPromptQuestion;

  /// No description provided for @aiTeacherAnswer.
  ///
  /// In en, this message translates to:
  /// **'Prototype answer'**
  String get aiTeacherAnswer;

  /// No description provided for @aiTeacherTryNext.
  ///
  /// In en, this message translates to:
  /// **'Try next'**
  String get aiTeacherTryNext;

  /// No description provided for @aiTeacherAnotherExample.
  ///
  /// In en, this message translates to:
  /// **'Show another mock example'**
  String get aiTeacherAnotherExample;

  /// No description provided for @aiTeacherQuizMe.
  ///
  /// In en, this message translates to:
  /// **'Quiz me on this'**
  String get aiTeacherQuizMe;

  /// No description provided for @sessionGeneratedFrom.
  ///
  /// In en, this message translates to:
  /// **'Generated from: {material}'**
  String sessionGeneratedFrom(Object material);

  /// No description provided for @sessionLocal.
  ///
  /// In en, this message translates to:
  /// **'Local study session'**
  String get sessionLocal;

  /// No description provided for @sessionNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer submitted.'**
  String get sessionNoAnswer;

  /// No description provided for @sessionNoFlashcards.
  ///
  /// In en, this message translates to:
  /// **'No flashcards in this session.'**
  String get sessionNoFlashcards;

  /// No description provided for @sessionQuickQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quick quiz'**
  String get sessionQuickQuiz;

  /// No description provided for @sessionFocusTopics.
  ///
  /// In en, this message translates to:
  /// **'Focus topics'**
  String get sessionFocusTopics;

  /// No description provided for @sessionNoTopics.
  ///
  /// In en, this message translates to:
  /// **'No focus topics recorded.'**
  String get sessionNoTopics;

  /// No description provided for @sessionPrototypeExplanation.
  ///
  /// In en, this message translates to:
  /// **'Prototype explanation'**
  String get sessionPrototypeExplanation;

  /// No description provided for @sessionPrototypeHelp.
  ///
  /// In en, this message translates to:
  /// **'Local mock guidance; not a live AI response.'**
  String get sessionPrototypeHelp;

  /// No description provided for @sessionMoreFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Generate more flashcards'**
  String get sessionMoreFlashcards;

  /// No description provided for @sessionAskTeacher.
  ///
  /// In en, this message translates to:
  /// **'Ask AI Teacher'**
  String get sessionAskTeacher;

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relativeJustNow;

  /// No description provided for @relativeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get relativeToday;

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get relativeYesterday;

  /// No description provided for @relativeSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get relativeSynced;

  /// No description provided for @relativeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get relativeRecent;

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String fileSizeBytes(Object value);

  /// No description provided for @fileSizeKibibytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KiB'**
  String fileSizeKibibytes(Object value);

  /// No description provided for @fileSizeMebibytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MiB'**
  String fileSizeMebibytes(Object value);

  /// No description provided for @fileSizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String fileSizeMegabytes(Object value);

  /// No description provided for @favoriteAction.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favoriteAction;

  /// No description provided for @unfavoriteAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unfavoriteAction;

  /// No description provided for @sessionTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic: {topic}'**
  String sessionTopic(Object topic);

  /// No description provided for @sessionCorrectOption.
  ///
  /// In en, this message translates to:
  /// **'{option} — correct'**
  String sessionCorrectOption(Object option);

  /// No description provided for @sessionIncorrectOption.
  ///
  /// In en, this message translates to:
  /// **'{option} — incorrect'**
  String sessionIncorrectOption(Object option);

  /// No description provided for @sessionUnavailableForSubject.
  ///
  /// In en, this message translates to:
  /// **'Add a ready material with useful content to {subject} before creating a study session.'**
  String sessionUnavailableForSubject(Object subject);

  /// No description provided for @examPrepRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommended: flashcards first, then a quick quiz.'**
  String get examPrepRecommendation;

  /// No description provided for @formattedMaterialSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String formattedMaterialSize(Object size);

  /// No description provided for @materialKindDate.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {date}'**
  String materialKindDate(Object date, Object kind);

  /// No description provided for @materialPastedDate.
  ///
  /// In en, this message translates to:
  /// **'{date} · {kind}'**
  String materialPastedDate(Object date, Object kind);

  /// No description provided for @errorUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The selected file is too large. Maximum size: {size}.'**
  String errorUploadTooLarge(Object size);

  /// No description provided for @materialActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Material actions'**
  String get materialActionsTooltip;

  /// No description provided for @materialDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get materialDetailsTitle;

  /// No description provided for @materialDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove this source and its generated material-specific study content.'**
  String get materialDeleteDescription;

  /// No description provided for @materialDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting material'**
  String get materialDeleting;

  /// No description provided for @subjectDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete subject'**
  String get subjectDeleteAction;

  /// No description provided for @subjectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {subject}?'**
  String subjectDeleteTitle(Object subject);

  /// No description provided for @subjectDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the subject, uploaded files, summaries, generated study content, quiz attempts, study sessions, and focus-topic history.'**
  String get subjectDeleteBody;

  /// No description provided for @subjectDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No loaded materials} one {1 loaded material} other {{count} loaded materials}}'**
  String subjectDeleteCount(num count);

  /// No description provided for @subjectDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting subject'**
  String get subjectDeleting;

  /// No description provided for @subjectDeleted.
  ///
  /// In en, this message translates to:
  /// **'Subject deleted.'**
  String get subjectDeleted;

  /// No description provided for @accountDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get accountDangerTitle;

  /// No description provided for @accountDangerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all study data.'**
  String get accountDangerSubtitle;

  /// No description provided for @accountDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAction;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your profile, subjects, study history, generated content, and private uploaded files. This cannot be undone.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteRecentAuth.
  ///
  /// In en, this message translates to:
  /// **'For security, you may need to sign in again before deletion can begin.'**
  String get accountDeleteRecentAuth;

  /// No description provided for @accountDeleteTypePrompt.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get accountDeleteTypePrompt;

  /// No description provided for @accountDeleteConfirmationLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get accountDeleteConfirmationLabel;

  /// No description provided for @accountDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting account'**
  String get accountDeleting;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get accountDeleted;

  /// No description provided for @accountDeleteReauth.
  ///
  /// In en, this message translates to:
  /// **'Sign in again, then confirm account deletion once more.'**
  String get accountDeleteReauth;

  /// No description provided for @deletionErrorInProgress.
  ///
  /// In en, this message translates to:
  /// **'Deletion is already in progress.'**
  String get deletionErrorInProgress;

  /// No description provided for @deletionErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Private files could not be removed. Try again.'**
  String get deletionErrorStorage;

  /// No description provided for @deletionErrorDatabase.
  ///
  /// In en, this message translates to:
  /// **'Study data cleanup could not finish. Try again.'**
  String get deletionErrorDatabase;

  /// No description provided for @deletionErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Account removal could not finish. Try again.'**
  String get deletionErrorAuth;

  /// No description provided for @deletionErrorRecentAuth.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again before deleting your account.'**
  String get deletionErrorRecentAuth;

  /// No description provided for @deletionErrorRecentAuthVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Your recent login could not be verified. Please try again manually.'**
  String get deletionErrorRecentAuthVerificationFailed;

  /// No description provided for @deletionErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session is no longer valid.'**
  String get deletionErrorUnauthorized;

  /// No description provided for @deletionErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Deletion cannot continue yet. Try again shortly.'**
  String get deletionErrorRetry;

  /// No description provided for @deletionErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Deletion could not be completed. Try again.'**
  String get deletionErrorUnknown;

  /// No description provided for @deletionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry deletion'**
  String get deletionRetry;

  /// No description provided for @generatedPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Prototype preview'**
  String get generatedPreviewTitle;

  /// No description provided for @generatedPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mock generated output · {subject}'**
  String generatedPreviewSubtitle(Object subject);

  /// No description provided for @generatedPreviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No preview available'**
  String get generatedPreviewEmptyTitle;

  /// No description provided for @generatedPreviewEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Generated study output will appear here when available.'**
  String get generatedPreviewEmptyMessage;

  /// No description provided for @generatedCountPreview.
  ///
  /// In en, this message translates to:
  /// **'Generation preview: {count, plural, one {1 card} other {{count} cards}}'**
  String generatedCountPreview(num count);

  /// No description provided for @generatedOpenFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Open flashcards'**
  String get generatedOpenFlashcards;

  /// No description provided for @generatedExplainMistake.
  ///
  /// In en, this message translates to:
  /// **'Explanation: {explanation}'**
  String generatedExplainMistake(Object explanation);

  /// No description provided for @generatedExamPlan.
  ///
  /// In en, this message translates to:
  /// **'Exam preparation plan'**
  String get generatedExamPlan;

  /// No description provided for @confidenceUnderstoodEverything.
  ///
  /// In en, this message translates to:
  /// **'I understood everything'**
  String get confidenceUnderstoodEverything;

  /// No description provided for @confidenceMostly.
  ///
  /// In en, this message translates to:
  /// **'Mostly'**
  String get confidenceMostly;

  /// No description provided for @confidenceAboutHalf.
  ///
  /// In en, this message translates to:
  /// **'About half'**
  String get confidenceAboutHalf;

  /// No description provided for @confidenceCompletelyLost.
  ///
  /// In en, this message translates to:
  /// **'I am completely lost'**
  String get confidenceCompletelyLost;

  /// No description provided for @blockSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get blockSummary;

  /// No description provided for @blockFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get blockFlashcards;

  /// No description provided for @blockQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get blockQuiz;

  /// No description provided for @blockReviewMistakes.
  ///
  /// In en, this message translates to:
  /// **'Review mistakes'**
  String get blockReviewMistakes;

  /// No description provided for @blockSimpleExplanation.
  ///
  /// In en, this message translates to:
  /// **'Simple explanation'**
  String get blockSimpleExplanation;

  /// No description provided for @blockGuidedFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Guided flashcards'**
  String get blockGuidedFlashcards;

  /// No description provided for @blockQuickQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quick quiz'**
  String get blockQuickQuiz;

  /// No description provided for @searchMaterialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{subject} · {date}'**
  String searchMaterialSubtitle(Object date, Object subject);

  /// No description provided for @searchFlashcardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{subject} · Flashcard · {topic}'**
  String searchFlashcardSubtitle(Object subject, Object topic);
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
