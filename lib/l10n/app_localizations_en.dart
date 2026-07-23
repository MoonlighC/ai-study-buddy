// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Study Buddy';

  @override
  String get navHome => 'Home';

  @override
  String get navSubjects => 'Subjects';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navProgress => 'Progress';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionBack => 'Back';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionShowMore => 'Show more';

  @override
  String get actionShowLess => 'Show less';

  @override
  String get statusLoading => 'Loading';

  @override
  String get statusError => 'Error';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonName => 'Name';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonErrorSemantics => 'Error';

  @override
  String get commonStatusSemantics => 'Status';

  @override
  String get commonAppStillUsable => 'Your app is still usable.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsDisplayLanguage => 'Display language';

  @override
  String get settingsDisplayLanguageDescription =>
      'Choose the language for app navigation and controls.';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsIntro => 'Mock preferences for the local prototype.';

  @override
  String get settingsAccountTitle => 'Account';

  @override
  String get settingsSupabaseAccount => 'Supabase account';

  @override
  String get settingsLocalMockProfile => 'Local mock profile';

  @override
  String get settingsEditName => 'Edit name';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsStudyPreferencesTitle => 'Study Preferences';

  @override
  String get settingsStudyPreferencesSubtitle =>
      'Stored in local AppState only';

  @override
  String get settingsDefaultFlashcardSessionSize =>
      'Default flashcard session size';

  @override
  String get settingsDailyStudyGoal => 'Daily study goal';

  @override
  String get settingsDefaultDifficulty => 'Default difficulty';

  @override
  String get settingsDifficultyEasy => 'easy';

  @override
  String get settingsDifficultyMedium => 'medium';

  @override
  String get settingsDifficultyExam => 'exam';

  @override
  String settingsMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsAppPreferencesTitle => 'App preferences';

  @override
  String get settingsAppearancePlanned => 'Appearance options are planned';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceUnavailable => 'Dark mode is not available yet.';

  @override
  String get settingsAppearanceDescription =>
      'Choose the app appearance. System default follows your device setting.';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get settingsUsageTitle => 'Usage & Limits';

  @override
  String get settingsUsageUnavailable => 'Daily usage and generation policy';

  @override
  String get settingsViewUsage => 'View usage information';

  @override
  String get settingsUsagePlanned =>
      'View today’s authoritative usage and reset time.';

  @override
  String get settingsSupportTitle => 'Support';

  @override
  String get settingsSupportSubtitle => 'No email or network integration yet';

  @override
  String get settingsReportBugPlaceholder => 'Report a bug placeholder';

  @override
  String get settingsContactSupportPlaceholder => 'Contact support placeholder';

  @override
  String get settingsSendFeedbackPlaceholder => 'Send feedback placeholder';

  @override
  String get settingsAboutDebugTitle => 'About / Debug';

  @override
  String get settingsAboutDebugSubtitle => 'Prototype diagnostics';

  @override
  String get settingsStagingBuildLabel => 'Staging build';

  @override
  String get settingsStagingBuildSemantics => 'Staging beta build';

  @override
  String get settingsBackendMode => 'Backend mode';

  @override
  String get settingsSecurityNote => 'Security note';

  @override
  String get settingsSecurityNoteValue =>
      'No server secrets or OpenAI key in Flutter.';

  @override
  String get comingLater => 'Coming later';

  @override
  String get authWelcomeBackTitle => 'Welcome back';

  @override
  String get authWelcomeBackSubtitle =>
      'Turn lecture material into focused study sessions.';

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authCreateAccountSubtitle => 'Set up your study profile.';

  @override
  String get authLogIn => 'Log in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authContinueWithEmail => 'Continue with email';

  @override
  String get authGoogleComingLater => 'Google coming later';

  @override
  String get authAppleComingLater => 'Apple coming later';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authPreparingStudySpace => 'Preparing your study space';

  @override
  String authResetNotice(String email) {
    return 'If an account exists for $email, a reset email is on the way.';
  }

  @override
  String get authCheckEmailNotice =>
      'Check your email to confirm your account, then log in.';

  @override
  String get homeSubtitle => 'Your calm place to learn';

  @override
  String get homeRecentMaterials => 'Recent materials';

  @override
  String get homeViewSubjects => 'View subjects';

  @override
  String get homeNoMaterialsTitle => 'No materials yet';

  @override
  String get homeNoMaterialsMessage =>
      'Open a subject and add your first study material.';

  @override
  String get homeYourSubjects => 'Your subjects';

  @override
  String get homeCreateFirstSubject => 'Create your first subject';

  @override
  String get homeCreateFirstSubjectMessage =>
      'Subjects keep materials and study tools together.';

  @override
  String get homeStudyWorkspace => 'Study workspace';

  @override
  String get homeHeroTitle => 'Ready for your next study step?';

  @override
  String get homeHeroWithMaterials =>
      'Continue with a recent material or choose a focused study action.';

  @override
  String get homeHeroWithoutMaterials =>
      'Add study material to a subject, then build summaries, flashcards, and quizzes.';

  @override
  String get homeCreateSubject => 'Create a subject';

  @override
  String get homeOpenSubjects => 'Open subjects';

  @override
  String get homeAfterLecture => 'After Lecture';

  @override
  String get homeLatestProgress => 'Latest progress';

  @override
  String get homeNoQuizAttemptsTitle => 'No quiz attempts yet';

  @override
  String get homeNoQuizAttemptsMessage =>
      'Complete a quiz to see your latest result.';

  @override
  String homeCorrectCount(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get homeFocusTopics => 'Focus topics';

  @override
  String get homeFocusTopicsEmpty =>
      'Complete quizzes to reveal topics worth revisiting.';

  @override
  String homeMissesWithSubject(String subject, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misses',
      one: '1 miss',
    );
    return '$subject · $_temp0';
  }

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homePrepareForExam => 'Prepare for Exam';

  @override
  String get homeContinueStudying => 'Continue Studying';

  @override
  String get subjectsTitle => 'Subjects';

  @override
  String get subjectsSubtitle => 'Study workspace';

  @override
  String get subjectsLoading => 'Loading synced subjects';

  @override
  String get subjectsShowingAvailable =>
      'Showing the subjects currently available.';

  @override
  String get subjectsNoSubjectsTitle => 'No subjects yet';

  @override
  String get subjectsNoSubjectsMessage =>
      'Create a subject to group your materials, summaries, flashcards, and quizzes.';

  @override
  String get subjectsCreateSubject => 'Create subject';

  @override
  String get subjectsCreatingSubject => 'Creating subject';

  @override
  String get subjectsHeaderTitle => 'Your subjects';

  @override
  String get subjectsHeaderMessage =>
      'Create focused spaces for lecture notes, summaries, quizzes, and exam prep.';

  @override
  String get subjectsNoDescription => 'No description yet';

  @override
  String get subjectsExamPrep => 'Exam Prep';

  @override
  String subjectsOpenSubject(String subject) {
    return 'Open $subject';
  }

  @override
  String get subjectsCreateDialogTitle => 'Create subject';

  @override
  String get subjectsNameLabel => 'Subject name';

  @override
  String get subjectsNameHint => 'Biology, math, history...';

  @override
  String get subjectsDescriptionLabel => 'Description';

  @override
  String get subjectsColor => 'Color';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorAmber => 'Amber';

  @override
  String subjectsColorSemantics(String color) {
    return '$color subject color';
  }

  @override
  String get subjectsDefaultDescription =>
      'Study materials and practice for this subject.';

  @override
  String materialsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count materials',
      one: '1 material',
      zero: '0 materials',
    );
    return '$_temp0';
  }

  @override
  String subjectItemsInSubject(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in this subject',
      one: '1 item in this subject',
      zero: '0 items in this subject',
    );
    return '$_temp0';
  }

  @override
  String summariesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count summaries',
      one: '1 summary',
      zero: '0 summaries',
    );
    return '$_temp0';
  }

  @override
  String get subjectWorkspaceSubtitle => 'Subject workspace';

  @override
  String get subjectMaterials => 'Materials';

  @override
  String get subjectSummaries => 'Summaries';

  @override
  String get subjectSummariesSubtitle =>
      'Generated explanations from your materials';

  @override
  String get subjectStudyActions => 'Study actions';

  @override
  String get subjectStudyActionsSubtitle => 'Build from notes in this subject';

  @override
  String get subjectAddPastedText => 'Add pasted text';

  @override
  String get subjectCreateStudySession => 'Create study session';

  @override
  String get subjectAddMaterialForSession =>
      'Add a material to create a study session.';

  @override
  String get subjectUploadMaterials => 'Upload materials';

  @override
  String get subjectUploadMaterialsSubtitle => 'Private PDFs and images';

  @override
  String get subjectUploadPdf => 'Upload PDF';

  @override
  String get subjectUploadImage => 'Upload image';

  @override
  String get subjectFocusTopicsSubtitle => 'Cumulative misses from quizzes';

  @override
  String missesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misses',
      one: '1 miss',
    );
    return '$_temp0';
  }

  @override
  String get subjectLoadingMaterials => 'Loading synced materials';

  @override
  String get subjectStillUsable => 'Your subject is still usable.';

  @override
  String get subjectNoMaterialsTitle => 'No materials yet';

  @override
  String get subjectNoMaterialsMessage =>
      'Add pasted text or upload a file to start studying.';

  @override
  String get subjectNoSummariesTitle => 'No summaries yet';

  @override
  String get subjectNoSummariesMessage =>
      'Generate a summary from a material and it will appear here.';

  @override
  String get subjectFavoriteMaterialTooltip => 'Favorite material';

  @override
  String get subjectUnfavoriteMaterialTooltip => 'Unfavorite material';

  @override
  String get materialAddTitle => 'Add pasted text';

  @override
  String get materialAddIntro =>
      'Paste notes, transcripts, or textbook excerpts. Keep the original source language.';

  @override
  String get materialTitleLabel => 'Material title';

  @override
  String get materialPasteTextLabel => 'Paste lecture text';

  @override
  String get materialPastedTextKind => 'Pasted text';

  @override
  String get materialUploadedStatus => 'Uploaded';

  @override
  String get materialWaitingForProcessing => 'Waiting for processing';

  @override
  String get materialUnknownSize => 'Unknown';

  @override
  String get materialSaveMaterial => 'Save material';

  @override
  String get materialSavingMaterial => 'Saving material';

  @override
  String get materialSaved => 'Material saved.';

  @override
  String get materialUploaded => 'Material uploaded.';

  @override
  String get uploadPdfTitle => 'Upload PDF';

  @override
  String get uploadImageTitle => 'Upload image';

  @override
  String get uploadPdfGuidance => 'PDF files up to 40 MiB.';

  @override
  String get uploadImageGuidance =>
      'PNG, JPG, JPEG, or WEBP images up to 8.39 MB.';

  @override
  String get uploadChoosePdf => 'Choose PDF';

  @override
  String get uploadChooseImage => 'Choose image';

  @override
  String get uploadPdfKind => 'PDF';

  @override
  String get uploadImageKind => 'Image';

  @override
  String get uploadMaterial => 'Upload material';

  @override
  String get uploadingMaterial => 'Uploading material';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesSubtitle => 'Study only favorites';

  @override
  String get favoritesMaterials => 'Materials';

  @override
  String get favoritesFlashcards => 'Flashcards';

  @override
  String get favoritesLoading => 'Loading synced favorites';

  @override
  String get favoritesStillUsable => 'Your app is still usable.';

  @override
  String get favoritesNoFavoritesTitle => 'No favorites yet';

  @override
  String get favoritesNoFavoritesMessage =>
      'Mark materials or flashcards as favorites to find them here.';

  @override
  String get favoritesUnfavorite => 'Unfavorite';

  @override
  String get favoritesUnfavoriteMaterial => 'Unfavorite material';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchFieldLabel => 'Search study workspace';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchStartTitle => 'Start typing to search';

  @override
  String get searchStartMessage =>
      'Find subjects, materials, summaries, and flashcards.';

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String get searchNoResultsMessage =>
      'Try another word or add more study material.';

  @override
  String searchSubjectsGroup(int count) {
    return 'Subjects ($count)';
  }

  @override
  String searchMaterialsGroup(int count) {
    return 'Materials ($count)';
  }

  @override
  String searchFlashcardsGroup(int count) {
    return 'Flashcards ($count)';
  }

  @override
  String get usageTitle => 'Usage';

  @override
  String get usageUnavailableTitle => 'Could not load usage';

  @override
  String get usageUnavailableMessage =>
      'Your usage status is temporarily unavailable. Try again.';

  @override
  String get usageRetry => 'Retry';

  @override
  String get usageTesterTitle => 'Tester mode: unlimited daily generation';

  @override
  String get usageTesterMessage =>
      'Today’s usage is still recorded. Per-request limits and duplicate/retry protections still apply.';

  @override
  String get usageStandardTitle => 'Standard daily limits';

  @override
  String get usageFlashcards => 'Flashcards';

  @override
  String get usageQuizQuestions => 'Quiz questions';

  @override
  String get usageEstimatedCost => 'Estimated provider cost';

  @override
  String usageCountOfLimit(int used, int limit) {
    return '$used / $limit';
  }

  @override
  String usageCountToday(int used) {
    return '$used today';
  }

  @override
  String usageCostOfLimit(String used, String limit) {
    return '$used / $limit USD';
  }

  @override
  String usageCostToday(String used) {
    return '$used USD today';
  }

  @override
  String usageActiveReservations(int count) {
    return 'Active generations: $count';
  }

  @override
  String usageResetAt(String dateTime) {
    return 'Resets $dateTime';
  }

  @override
  String get generationReconcilingMessage =>
      'A previous generation is being reconciled. Resume it without starting a new provider request.';

  @override
  String get generationResume => 'Resume generation';

  @override
  String get materialDetailTitle => 'Material';

  @override
  String get materialDeletingTitle => 'Deleting material';

  @override
  String get materialDeletingMessage =>
      'Removing the source and material-specific study content.';

  @override
  String get materialGeneratingStudyContentTitle => 'Generating study content';

  @override
  String get materialGeneratingStudyContentMessage =>
      'Creating material-scoped learning content…';

  @override
  String get materialPartialResultTitle => 'Partial result';

  @override
  String get materialPartialScannedMessage =>
      'Some pages could not be read. Available study text can still be used.';

  @override
  String get materialFileMetadataTitle => 'File metadata';

  @override
  String get materialFilenameLabel => 'Filename';

  @override
  String get materialTypeLabel => 'Type';

  @override
  String get materialSizeLabel => 'Size';

  @override
  String get materialMimeLabel => 'MIME';

  @override
  String get materialStatusLabel => 'Status';

  @override
  String get materialCreatedLabel => 'Created';

  @override
  String get materialSummaryTitle => 'Summary';

  @override
  String get materialFlashcardsTitle => 'Flashcards';

  @override
  String get materialQuizTitle => 'Quiz';

  @override
  String get materialStudySessionTitle => 'Study session';

  @override
  String get materialDeleteDialogTitle => 'Delete material?';

  @override
  String get materialDeleteMaterial => 'Delete material';

  @override
  String get materialDeleted => 'Material deleted.';

  @override
  String get materialDeleteRemoved => 'Removed:';

  @override
  String get materialDeletePreserved => 'Preserved:';

  @override
  String get materialDeleteSourceMaterial => 'Source material';

  @override
  String get materialDeleteUploadedFile => 'Uploaded file, if present';

  @override
  String get materialDeleteSummary => 'Summary';

  @override
  String get materialDeleteFlashcards => 'Material-specific flashcards';

  @override
  String get materialDeleteQuizzes => 'Material-specific quizzes';

  @override
  String get materialDeleteQuizResults => 'Completed quiz results';

  @override
  String get materialDeleteProgressHistory => 'Progress history';

  @override
  String get materialDeleteWeakTopics => 'Cumulative weak topics';

  @override
  String get materialDeleteStudyHistory => 'Study history';

  @override
  String get materialTextExtracted => 'Text extracted';

  @override
  String get materialTextExtractedWithOcr => 'Text extracted with OCR';

  @override
  String materialPagesProgress(int processed, int total) {
    return '$processed/$total pages';
  }

  @override
  String materialPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get materialProcessingStatus => 'Processing';

  @override
  String get materialFailedStatus => 'Failed';

  @override
  String get materialProcessingTitle => 'Processing material';

  @override
  String get materialStuckTitle => 'Processing appears to be stuck';

  @override
  String get materialStuckMessage =>
      'Reset this material and try processing again.';

  @override
  String get materialResetTryAgain => 'Reset and try again';

  @override
  String get imageExtractionFailedTitle => 'Image text extraction failed';

  @override
  String get imageExtractionTitle => 'Image text extraction';

  @override
  String get imageReadingText => 'Reading image text…';

  @override
  String get imageExtractHelper =>
      'Extract readable study text from this image.';

  @override
  String get imageRetryExtraction => 'Retry image text extraction';

  @override
  String get imageExtractText => 'Extract text from image';

  @override
  String get pdfSomePagesNeedOcr => 'Some pages need OCR';

  @override
  String get pdfNoSelectableText => 'No usable selectable text was found';

  @override
  String get pdfReadingScannedPages => 'Reading scanned PDF pages…';

  @override
  String pdfRequiresOcrCount(int candidateCount, int pageCount) {
    return '$candidateCount of $pageCount pages require OCR.';
  }

  @override
  String get pdfRequiresOcrMessage =>
      'This PDF requires OCR before its study tools are available.';

  @override
  String get pdfScanWithOcr => 'Scan PDF with OCR';

  @override
  String get pdfTextExtractionFailedTitle => 'Text extraction failed';

  @override
  String get pdfTextExtractionTitle => 'PDF text extraction';

  @override
  String get pdfExtractingSelectable => 'Extracting selectable text…';

  @override
  String get pdfCouldNotExtract => 'Could not extract text. Try again.';

  @override
  String get pdfExtractHelper => 'Extract selectable text from this PDF.';

  @override
  String get pdfRetryTextExtraction => 'Retry text extraction';

  @override
  String get pdfExtractText => 'Extract text';

  @override
  String get pdfScanDialogTitle => 'Scan PDF with OCR?';

  @override
  String pdfScanDialogMessage(int pageCount, int candidateCount) {
    return 'This PDF has $pageCount pages. $candidateCount pages require OCR.\n\nThis version supports up to 10 total pages. AI OCR can take longer and uses paid processing.';
  }

  @override
  String get pdfStartOcr => 'Start OCR';

  @override
  String get summaryNoSummary => 'No summary yet.';

  @override
  String get summaryRegenerate => 'Regenerate summary';

  @override
  String get summaryWithAi => 'Summarize with AI';

  @override
  String get summaryGenerateMock => 'Generate mock summary';

  @override
  String get summaryGenerating => 'Generating summary';

  @override
  String flashcardsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flashcards ready.',
      one: '1 flashcard ready.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsNoFlashcards => 'No flashcards yet.';

  @override
  String get flashcardsTooShort =>
      'Add more lecture text before generating flashcards.';

  @override
  String get flashcardsStartTraining => 'Start training';

  @override
  String get flashcardsReviewThese => 'Review these flashcards';

  @override
  String get flashcardsGenerate => 'Generate flashcards';

  @override
  String get flashcardsGenerating => 'Generating flashcards';

  @override
  String get flashcardsNoNewGenerated =>
      'No new unique flashcards were generated.';

  @override
  String flashcardsNewGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new flashcards generated.',
      one: '1 new flashcard generated.',
    );
    return '$_temp0';
  }

  @override
  String quizQuestionsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions ready.',
      one: '1 question ready.',
    );
    return '$_temp0';
  }

  @override
  String get quizNoQuiz => 'No quiz yet.';

  @override
  String get quizTakeQuiz => 'Take quiz';

  @override
  String get quizGenerate => 'Generate quiz';

  @override
  String get quizGenerateMock => 'Generate mock quiz';

  @override
  String get quizGenerating => 'Generating quiz';

  @override
  String get genericLocalizedError => 'Something went wrong. Please try again.';

  @override
  String get errorEnterName => 'Enter your name.';

  @override
  String get errorEnterValidEmail => 'Enter a valid email address.';

  @override
  String get errorEmailRequired => 'Enter your email address.';

  @override
  String get errorPasswordRequired => 'Enter your password.';

  @override
  String get authInvalidCredentials =>
      'Unable to sign in. Check your email address and password.';

  @override
  String get authEmailNotConfirmed =>
      'Confirm your email address before signing in.';

  @override
  String get authRateLimited => 'Too many sign-in attempts. Try again later.';

  @override
  String get authNetworkFailure =>
      'Check your internet connection and try again.';

  @override
  String get authServiceUnavailable =>
      'The authentication service is temporarily unavailable. Try again later.';

  @override
  String get errorPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get errorConfirmPassword => 'Confirm your password.';

  @override
  String get errorPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get errorLoginToEditProfile => 'Log in to edit your profile.';

  @override
  String get errorAccountAlreadyExists =>
      'An account already exists for this email. Try logging in instead.';

  @override
  String get errorCouldNotUpdateProfile =>
      'Could not update the account profile.';

  @override
  String get errorCouldNotLogOut => 'Could not log out.';

  @override
  String get errorCouldNotSyncSubjects => 'Could not sync subjects. Try again.';

  @override
  String get errorEnterSubjectName => 'Enter a subject name.';

  @override
  String get errorLoginToSyncSubjects => 'Log in to sync subjects.';

  @override
  String get errorCouldNotSyncMaterials =>
      'Could not sync materials. Try again.';

  @override
  String get errorEnterTitleAndText => 'Enter a title and pasted text.';

  @override
  String get errorLoginToSyncMaterials => 'Log in to sync materials.';

  @override
  String get errorChoosePdfOrImage => 'Choose a PDF or image to upload.';

  @override
  String get errorLoginToUploadMaterials => 'Log in to upload materials.';

  @override
  String get errorCouldNotUploadFile => 'Could not upload the selected file.';

  @override
  String get errorUnsupportedFile =>
      'Choose a supported PDF, PNG, JPG, JPEG, or WEBP file.';

  @override
  String get errorEmptyFile => 'The selected file is empty.';

  @override
  String get errorFileTypeMismatch =>
      'The file contents do not match the selected file type.';

  @override
  String get errorCouldNotOpenFilePicker => 'Could not open the file picker.';

  @override
  String get errorMaterialUnavailable => 'Material unavailable.';

  @override
  String get errorCouldNotUpdateFavorite => 'Could not update favorite.';

  @override
  String get errorCouldNotSyncFavorites =>
      'Could not sync favorites. Try again.';

  @override
  String get errorCouldNotDeleteMaterial =>
      'Could not delete the material. Try again.';

  @override
  String get errorLoginToDeleteMaterial => 'Log in to delete this material.';

  @override
  String get errorCouldNotResetProcessing => 'Processing could not be reset.';

  @override
  String get errorPdfCannotBeExtracted => 'This PDF cannot be extracted.';

  @override
  String get errorLoginToExtractPdf => 'Log in to extract PDF text.';

  @override
  String get errorCouldNotExtractText => 'Could not extract text. Try again.';

  @override
  String get errorImageCannotBeProcessed => 'This image cannot be processed.';

  @override
  String get errorLoginToExtractImage => 'Log in to extract image text.';

  @override
  String get errorCouldNotExtractImageText =>
      'Could not extract image text. Try again.';

  @override
  String get errorPdfCannotBeScanned => 'This PDF cannot be scanned with OCR.';

  @override
  String get errorLoginToScanPdf => 'Log in to scan this PDF.';

  @override
  String get errorCouldNotScanPdf => 'Could not scan this PDF. Try again.';

  @override
  String get errorPdfOcrPageLimit =>
      'This version can scan PDFs up to 10 pages. Split the PDF and upload a smaller file.';

  @override
  String get errorNoSelectablePdfText =>
      'No selectable text was found. Scanned PDFs will be supported in the OCR phase.';

  @override
  String get errorNoReadableImageText =>
      'No readable text was found in this image.';

  @override
  String get errorInvalidPdf => 'The uploaded file is not a valid PDF.';

  @override
  String get errorCouldNotReadPdf => 'Could not read the uploaded PDF.';

  @override
  String get errorCouldNotReadImage => 'Could not read the uploaded image.';

  @override
  String get errorInvalidImage =>
      'The uploaded file is not a valid supported image.';

  @override
  String get errorCouldNotGenerateSummary =>
      'Could not generate summary. Try again.';

  @override
  String get errorAddMoreLectureText =>
      'Add more lecture text before generating a summary.';

  @override
  String get errorCouldNotGenerateFlashcards =>
      'Could not generate flashcards. Try again.';

  @override
  String get errorCouldNotGenerateQuiz => 'Could not generate quiz. Try again.';

  @override
  String studyCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String studyQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String studyAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$_temp0';
  }

  @override
  String studyMisses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misses',
      one: '1 miss',
    );
    return '$_temp0';
  }

  @override
  String get studyProgress => 'Study progress';

  @override
  String studyProgressValue(int current, int total) {
    return '$current of $total';
  }

  @override
  String get studyQuestion => 'Question';

  @override
  String get studyAnswer => 'Answer';

  @override
  String get studyShowAnswer => 'Show answer';

  @override
  String get studyHideAnswer => 'Hide answer';

  @override
  String get studyFlashcardQuestionSemantics =>
      'Flashcard question. Activate to show answer.';

  @override
  String get studyFlashcardAnswerSemantics =>
      'Flashcard answer. Activate to hide answer.';

  @override
  String get studyMissedAction => 'I missed it';

  @override
  String get studyKnownAction => 'I knew it';

  @override
  String get studyCorrect => 'Correct';

  @override
  String get studyIncorrect => 'Incorrect';

  @override
  String studyCorrectAnswer(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String studyChoiceCorrectSemantics(String choice) {
    return '$choice, correct answer';
  }

  @override
  String studyChoiceIncorrectSemantics(String choice) {
    return '$choice, incorrect answer';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonReturn => 'Return';

  @override
  String get commonNext => 'Next';

  @override
  String get commonCustom => 'Custom';

  @override
  String get commonPrototype => 'Prototype';

  @override
  String get commonGenerate => 'Generate';

  @override
  String get flashcardsTitle => 'Flashcards';

  @override
  String flashcardsAllTitle(Object subject) {
    return 'All flashcards — $subject';
  }

  @override
  String flashcardsMaterialTitle(Object material) {
    return 'Flashcards — $material';
  }

  @override
  String flashcardsScopeMaterial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards from this material',
      one: '1 card from this material',
    );
    return '$_temp0';
  }

  @override
  String flashcardsScopeSubject(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards across this subject',
      one: '1 card across this subject',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsSessionSize => 'Study session size';

  @override
  String flashcardsAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards available for this selection.',
      one: '1 card available for this selection.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsGenerateMoreGuidance =>
      'Generate more flashcards from a material to unlock larger sessions.';

  @override
  String get flashcardsLoading => 'Loading synced flashcards';

  @override
  String get flashcardsEmptyTitle => 'No flashcards yet';

  @override
  String get flashcardsEmptyMessage =>
      'Add or generate cards to start reviewing.';

  @override
  String get flashcardsEmptyCloudMessage =>
      'Generate them from a pasted-text material.';

  @override
  String get flashcardsReviewFocus => 'Review focus';

  @override
  String get flashcardsFilterSemantics => 'Flashcard filter';

  @override
  String get flashcardsFilterAll => 'All';

  @override
  String get flashcardsFilterWeak => 'For review';

  @override
  String get flashcardsFilterDue => 'Due for review';

  @override
  String flashcardsStartTrainingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return 'Start training ($_temp0)';
  }

  @override
  String get flashcardsTrainWeak => 'Train cards for review';

  @override
  String get flashcardsReviewDue => 'Review due cards';

  @override
  String get flashcardsNoWeak => 'No cards need extra review right now.';

  @override
  String get flashcardsNoDue => 'No cards are due right now.';

  @override
  String get flashcardsCustomSessionTitle => 'Custom session size';

  @override
  String get flashcardsCardsField => 'Cards';

  @override
  String flashcardsMaximum(Object count) {
    return 'Maximum: $count';
  }

  @override
  String get flashcardsChooseAtLeastOne => 'Choose at least 1 card.';

  @override
  String flashcardsOnlyAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards are available',
      one: '1 card is available',
    );
    return 'Only $_temp0 for this selection.';
  }

  @override
  String flashcardsTopicDifficulty(String topic, String difficulty) {
    return 'Topic: $topic · $difficulty';
  }

  @override
  String flashcardsReviewStats(Object known, Object missed) {
    return 'Known $known · Missed $missed';
  }

  @override
  String get flashcardGenerationTitle => 'Generate new flashcards';

  @override
  String get flashcardGenerationGuidance =>
      'Choose how many new flashcards to add.';

  @override
  String flashcardGenerationCurrent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return 'Current: $_temp0';
  }

  @override
  String flashcardGenerationAdd(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return 'Add: $_temp0';
  }

  @override
  String flashcardGenerationProjected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return 'Projected total: $_temp0';
  }

  @override
  String get flashcardGenerationNewField => 'New flashcards';

  @override
  String get flashcardGenerationRangeError =>
      'Choose between 1 and 30 new flashcards.';

  @override
  String get flashcardGenerationMaxError =>
      'Choose no more than 30 flashcards.';

  @override
  String get trainingTitle => 'Flashcard training';

  @override
  String get trainingEmptyTitle => 'No flashcards to train';

  @override
  String get trainingEmptyMessage => 'Generate flashcards first.';

  @override
  String get trainingProgress => 'Flashcard progress';

  @override
  String get trainingComplete => 'Training complete';

  @override
  String trainingReviewed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards reviewed',
      one: '1 card reviewed',
    );
    return '$_temp0';
  }

  @override
  String trainingKnown(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards known',
      one: '1 card known',
    );
    return '$_temp0';
  }

  @override
  String trainingMissed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards missed',
      one: '1 card missed',
    );
    return '$_temp0';
  }

  @override
  String get trainingReviewMissed => 'Review missed cards again';

  @override
  String get trainingReviewAgain => 'Review again';

  @override
  String get errorCouldNotSaveReview => 'Could not save review progress.';

  @override
  String get quizUiTitle => 'Quiz';

  @override
  String get quizEmptyTitle => 'No questions available';

  @override
  String get quizEmptyMessage =>
      'Return to the material and generate a quiz first.';

  @override
  String get quizProgress => 'Question progress';

  @override
  String get quizShowScore => 'Show score';

  @override
  String get quizMissedReview => 'Missed question review';

  @override
  String get quizFinishReview => 'Finish review';

  @override
  String get quizResult => 'Result';

  @override
  String quizScore(Object percent) {
    return 'Score: $percent%';
  }

  @override
  String quizCorrectCount(num correct, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct correct answers out of $total',
      one: '1 correct answer out of $total',
    );
    return '$_temp0';
  }

  @override
  String get quizMissedTopics => 'Missed topics';

  @override
  String get quizNoMissedTopics => 'No missed topics. Great work!';

  @override
  String get quizSaving => 'Saving quiz attempt…';

  @override
  String get quizUnsyncedWarning =>
      'This score was calculated locally and was not synchronized.';

  @override
  String get quizReviewMissed => 'Review missed questions';

  @override
  String get quizReviewMaterial => 'Review material';

  @override
  String get quizRetry => 'Retry quiz';

  @override
  String get errorCouldNotSaveQuizAttempt =>
      'Could not save this quiz attempt.';

  @override
  String get progressLatestQuiz => 'Latest quiz';

  @override
  String get progressAttemptsCompleted => 'Attempts completed';

  @override
  String get progressFocusTopics => 'Focus topics';

  @override
  String get progressHistoryExplanation =>
      'Miss counts are cumulative quiz history, not a mastery score.';

  @override
  String get progressNoAttempts => 'Complete a quiz to see results here.';

  @override
  String get progressLoading => 'Loading progress';

  @override
  String get progressEmptyTitle => 'No quiz attempts yet';

  @override
  String get progressEmptyMessage =>
      'Complete a quiz to build your progress history.';

  @override
  String get progressKnowledgeScore => 'Knowledge score';

  @override
  String get progressNotEnoughActivity => 'Not enough activity';

  @override
  String progressEvidenceCounts(int quiz, int flashcards) {
    return 'Quiz evidence: $quiz answers · Flashcard evidence: $flashcards cards';
  }

  @override
  String get progressQuizAccuracy => 'Quiz accuracy';

  @override
  String get progressFlashcardState => 'Flashcards';

  @override
  String get progressKnownNotKnown => 'Known / not known';

  @override
  String get progressWeakCards => 'Weak cards';

  @override
  String get progressCardsDue => 'Cards due';

  @override
  String get progressActiveSessions => 'Active sessions';

  @override
  String get progressCompletedSessions => 'Completed sessions';

  @override
  String get progressRecentSessions => 'Recent completed sessions';

  @override
  String get progressBySubject => 'By subject';

  @override
  String get progressByMaterial => 'By material';

  @override
  String get progressHistoricalActivity => 'Historical activity';

  @override
  String progressHistoricalSummary(int attempts, int sessions) {
    return '$attempts completed quiz attempts and $sessions completed sessions belong to deleted or detached materials. They do not affect the current score.';
  }

  @override
  String get progressNoCurrentMaterials =>
      'No current materials in this scope.';

  @override
  String get progressUnavailableMaterial => 'Material unavailable';

  @override
  String get progressOpenAction => 'Open progress';

  @override
  String get afterLectureTitle => 'After Lecture';

  @override
  String get examPrepTitle => 'Exam Prep';

  @override
  String get continueStudyingTitle => 'Continue Studying';

  @override
  String get aiTeacherTitle => 'AI Teacher';

  @override
  String get studySessionTitle => 'Study Session';

  @override
  String get studyLocalPrototype => 'Local prototype';

  @override
  String get studyLocalMockCoaching => 'Local mock coaching';

  @override
  String get studyChooseSubject => 'Choose subject';

  @override
  String get studyChooseMaterial => 'Choose material';

  @override
  String get studyCreateSession => 'Create study session';

  @override
  String get studyNoSubjectsTitle => 'No subjects yet';

  @override
  String get studyOpenSubjects => 'Open Subjects';

  @override
  String get studyNoMaterialsTitle => 'No materials yet';

  @override
  String get studyContinueSession => 'Continue session';

  @override
  String get studyCancelEmptySession => 'Cancel empty session';

  @override
  String get studyCancelEmptySessionError =>
      'Could not cancel the empty study session.';

  @override
  String get studyNotCompleted => 'Not completed';

  @override
  String get studyBackToSubject => 'Back to subject';

  @override
  String get studyUnavailableTitle => 'No study material available';

  @override
  String get studySessionOverview => 'Session overview';

  @override
  String get studyEstimatedTime => 'Estimated study time';

  @override
  String get studySummary => 'Summary';

  @override
  String get studyFlashcardsAction => 'Flashcards';

  @override
  String get studyAiTeacherAction => 'AI Teacher';

  @override
  String studyMinutes(Object count) {
    return '$count min';
  }

  @override
  String get studySelectSubject => 'Select a subject';

  @override
  String get studySelectSubjectMessage =>
      'Choose the lecture subject to continue.';

  @override
  String get studyNoMaterialsMessage =>
      'Add a usable material before creating this study session.';

  @override
  String get afterLecturePrototype => 'Local prototype guidance';

  @override
  String get afterLectureNoSubjectsMessage =>
      'Create a subject before starting an after-lecture session.';

  @override
  String get afterLectureConfidence => 'How confident do you feel?';

  @override
  String get afterLectureSchedule => 'Prototype study schedule';

  @override
  String get afterLectureScheduleHelp =>
      'Estimated locally; this is not tracked study time.';

  @override
  String get examPrepPrototype => 'Local prototype plan';

  @override
  String get examPrepHeading => 'Prepare for an exam';

  @override
  String get examPrepHelp =>
      'Create a local study plan from a subject, materials, and weak topics.';

  @override
  String get examPrepNoSubjectsMessage =>
      'Create a subject before preparing an exam plan.';

  @override
  String get examPrepDatePreview => 'Exam date preview';

  @override
  String get examPrepDateUnavailable =>
      'Date selection is not available in this prototype.';

  @override
  String get examPrepDate => 'Exam date';

  @override
  String get examPrepMockDate => 'Mock date: 2 weeks from now';

  @override
  String get examPrepMaterialsPreview => 'Selected materials preview';

  @override
  String get examPrepMaterialsEmptyHelp =>
      'The plan can still start from the selected subject.';

  @override
  String get examPrepIncluded => 'Included in plan';

  @override
  String get examPrepTopicsPreview => 'Preview focus topics';

  @override
  String get examPrepTopicsHelp =>
      'Locally generated prototype guidance; not a mastery score.';

  @override
  String get examPrepPlanPreview => 'Preview preparation plan';

  @override
  String get examPrepPlanHelp => 'Locally generated prototype guidance.';

  @override
  String get continueEmptyTitle => 'Nothing to continue';

  @override
  String get continueEmptyMessage =>
      'Start a study session from one of your subjects.';

  @override
  String get continueUnavailableMessage =>
      'The subject or source for your latest session is no longer available.';

  @override
  String continueFrom(Object material) {
    return 'Continue from $material';
  }

  @override
  String get continueLatest => 'Latest study session';

  @override
  String get continueSummary => 'Session summary';

  @override
  String get continueQuickQuiz => 'Quick quiz';

  @override
  String continueLastScore(Object percent) {
    return 'Last score: $percent%';
  }

  @override
  String get continueNoTopics => 'No focus topics recorded for this session.';

  @override
  String get aiTeacherStatus => 'Local mock coaching · Prototype';

  @override
  String get aiTeacherNoLive =>
      'Canned local responses; no live AI connection.';

  @override
  String get aiTeacherHelp =>
      'Choose a coaching style. The response below stays entirely local and uses mock text.';

  @override
  String get aiTeacherPrompt => 'Coach prompt';

  @override
  String get aiTeacherPromptSimple => 'Explain simpler';

  @override
  String get aiTeacherPromptExample => 'Give another example';

  @override
  String get aiTeacherPromptQuestion => 'Ask a question';

  @override
  String get aiTeacherAnswer => 'Prototype answer';

  @override
  String get aiTeacherTryNext => 'Try next';

  @override
  String get aiTeacherAnotherExample => 'Show another mock example';

  @override
  String get aiTeacherQuizMe => 'Quiz me on this';

  @override
  String sessionGeneratedFrom(Object material) {
    return 'Generated from: $material';
  }

  @override
  String get sessionLocal => 'Local study session';

  @override
  String get sessionNoAnswer => 'No answer submitted.';

  @override
  String get sessionNoFlashcards => 'No flashcards in this session.';

  @override
  String get sessionQuickQuiz => 'Quick quiz';

  @override
  String get sessionFocusTopics => 'Focus topics';

  @override
  String get sessionNoTopics => 'No focus topics recorded.';

  @override
  String get sessionPrototypeExplanation => 'Prototype explanation';

  @override
  String get sessionPrototypeHelp =>
      'Local mock guidance; not a live AI response.';

  @override
  String get sessionMoreFlashcards => 'Generate more flashcards';

  @override
  String get sessionAskTeacher => 'Ask AI Teacher';

  @override
  String get relativeJustNow => 'Just now';

  @override
  String get relativeToday => 'Today';

  @override
  String get relativeYesterday => 'Yesterday';

  @override
  String get relativeSynced => 'Synced';

  @override
  String get relativeRecent => 'Recently';

  @override
  String fileSizeBytes(Object value) {
    return '$value B';
  }

  @override
  String fileSizeKibibytes(Object value) {
    return '$value KiB';
  }

  @override
  String fileSizeMebibytes(Object value) {
    return '$value MiB';
  }

  @override
  String fileSizeMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get favoriteAction => 'Favorite';

  @override
  String get unfavoriteAction => 'Remove from favorites';

  @override
  String sessionTopic(Object topic) {
    return 'Topic: $topic';
  }

  @override
  String sessionCorrectOption(Object option) {
    return '$option — correct';
  }

  @override
  String sessionIncorrectOption(Object option) {
    return '$option — incorrect';
  }

  @override
  String sessionUnavailableForSubject(Object subject) {
    return 'Add a ready material with useful content to $subject before creating a study session.';
  }

  @override
  String get examPrepRecommendation =>
      'Recommended: flashcards first, then a quick quiz.';

  @override
  String formattedMaterialSize(Object size) {
    return 'Size: $size';
  }

  @override
  String materialKindDate(Object date, Object kind) {
    return '$kind · $date';
  }

  @override
  String materialPastedDate(Object date, Object kind) {
    return '$date · $kind';
  }

  @override
  String errorUploadTooLarge(Object size) {
    return 'The selected file is too large. Maximum size: $size.';
  }

  @override
  String get materialActionsTooltip => 'Material actions';

  @override
  String get materialDetailsTitle => 'Details';

  @override
  String get materialDeleteDescription =>
      'Remove this source and its generated material-specific study content.';

  @override
  String get materialDeleting => 'Deleting material';

  @override
  String get subjectDeleteAction => 'Delete subject';

  @override
  String subjectDeleteTitle(Object subject) {
    return 'Delete $subject?';
  }

  @override
  String get subjectDeleteBody =>
      'This permanently deletes the subject, uploaded files, summaries, generated study content, quiz attempts, study sessions, and focus-topic history.';

  @override
  String subjectDeleteCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loaded materials',
      one: '1 loaded material',
      zero: 'No loaded materials',
    );
    return '$_temp0';
  }

  @override
  String get subjectDeleting => 'Deleting subject';

  @override
  String get subjectDeleted => 'Subject deleted.';

  @override
  String get accountDangerTitle => 'Danger zone';

  @override
  String get accountDangerSubtitle =>
      'Permanently delete your account and all study data.';

  @override
  String get accountDeleteAction => 'Delete account';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String get accountDeleteBody =>
      'This permanently deletes your profile, subjects, study history, generated content, and private uploaded files. This cannot be undone.';

  @override
  String get accountDeleteRecentAuth =>
      'For security, you may need to sign in again before deletion can begin.';

  @override
  String get accountDeleteTypePrompt => 'Type DELETE to confirm';

  @override
  String get accountDeleteConfirmationLabel => 'Confirmation';

  @override
  String get accountDeleting => 'Deleting account';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get accountDeleteReauth =>
      'Sign in again, then confirm account deletion once more.';

  @override
  String get deletionErrorInProgress => 'Deletion is already in progress.';

  @override
  String get deletionErrorStorage =>
      'Private files could not be removed. Try again.';

  @override
  String get deletionErrorDatabase =>
      'Study data cleanup could not finish. Try again.';

  @override
  String get deletionErrorAuth =>
      'Account removal could not finish. Try again.';

  @override
  String get deletionErrorRecentAuth =>
      'Please sign in again before deleting your account.';

  @override
  String get deletionErrorRecentAuthVerificationFailed =>
      'Your recent login could not be verified. Please try again manually.';

  @override
  String get deletionErrorUnauthorized => 'Your session is no longer valid.';

  @override
  String get deletionErrorRetry =>
      'Deletion cannot continue yet. Try again shortly.';

  @override
  String get deletionErrorUnknown =>
      'Deletion could not be completed. Try again.';

  @override
  String get deletionRetry => 'Retry deletion';

  @override
  String get generatedPreviewTitle => 'Prototype preview';

  @override
  String generatedPreviewSubtitle(Object subject) {
    return 'Mock generated output · $subject';
  }

  @override
  String get generatedPreviewEmptyTitle => 'No preview available';

  @override
  String get generatedPreviewEmptyMessage =>
      'Generated study output will appear here when available.';

  @override
  String generatedCountPreview(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return 'Generation preview: $_temp0';
  }

  @override
  String get generatedOpenFlashcards => 'Open flashcards';

  @override
  String generatedExplainMistake(Object explanation) {
    return 'Explanation: $explanation';
  }

  @override
  String get generatedExamPlan => 'Exam preparation plan';

  @override
  String get confidenceUnderstoodEverything => 'I understood everything';

  @override
  String get confidenceMostly => 'Mostly';

  @override
  String get confidenceAboutHalf => 'About half';

  @override
  String get confidenceCompletelyLost => 'I am completely lost';

  @override
  String get blockSummary => 'Summary';

  @override
  String get blockFlashcards => 'Flashcards';

  @override
  String get blockQuiz => 'Quiz';

  @override
  String get blockReviewMistakes => 'Review mistakes';

  @override
  String get blockSimpleExplanation => 'Simple explanation';

  @override
  String get blockGuidedFlashcards => 'Guided flashcards';

  @override
  String get blockQuickQuiz => 'Quick quiz';

  @override
  String searchMaterialSubtitle(Object date, Object subject) {
    return '$subject · $date';
  }

  @override
  String searchFlashcardSubtitle(Object subject, Object topic) {
    return '$subject · Flashcard · $topic';
  }

  @override
  String get uploadSelectMultiple => 'Select one or several files';

  @override
  String get uploadMaximumFiles => 'Select up to 20 files at once.';

  @override
  String get uploadQueued => 'Queued';

  @override
  String get uploadUploading => 'Uploading';

  @override
  String get uploadProcessing => 'Processing';

  @override
  String get uploadReady => 'Ready';

  @override
  String get uploadCompleted => 'Completed';

  @override
  String get uploadUserRetryRequired =>
      'Analysis needs your action before it can continue. Retry is available.';

  @override
  String get uploadTerminalFailureNoRetry =>
      'Analysis failed and cannot be retried from this upload.';

  @override
  String get uploadStaleMaterialRemoved =>
      'This material no longer exists. The stale upload entry was removed.';

  @override
  String get uploadFailed => 'Failed';

  @override
  String get materialRetry => 'Retry';

  @override
  String get uploadPartialSuccess =>
      'Some files succeeded while others need attention.';

  @override
  String get materialViewOriginal => 'View original';

  @override
  String get materialViewerTitle => 'Original file';

  @override
  String get materialPreviewLoading => 'Loading preview';

  @override
  String get materialPreviewUnavailable => 'Preview unavailable.';

  @override
  String get materialPreviewSessionExpired =>
      'Your session expired. Sign in again.';

  @override
  String get materialPreviewNotAuthorized =>
      'This file is not available to your account.';

  @override
  String get materialUnsupportedFile => 'Unsupported file.';

  @override
  String get materialUnsupportedFileType => 'Unsupported file type';

  @override
  String get materialFileTooLarge => 'File exceeds the 40 MiB limit';

  @override
  String get materialPdfPageLimitExceeded =>
      'The PDF contains more than the supported page limit';

  @override
  String get materialInvalidFile => 'Invalid file.';

  @override
  String get materialPreviewTooLarge => 'This file is too large to preview.';

  @override
  String materialPageOf(Object page, Object pageCount) {
    return 'Page $page of $pageCount';
  }

  @override
  String materialSelectedFiles(Object count) {
    return 'Selected $count files';
  }

  @override
  String materialBatchResult(Object failed, Object skipped, Object succeeded) {
    return '$succeeded uploaded / $skipped skipped / $failed failed';
  }

  @override
  String get materialPdfPreviewSemantics => 'Original PDF preview';

  @override
  String get materialImagePreviewSemantics =>
      'Original image preview. Pinch to zoom and drag to pan.';

  @override
  String get materialPreviousPage => 'Previous page';

  @override
  String get materialNextPage => 'Next page';

  @override
  String get materialProcessingConsentRequired =>
      'Open the material to review scanning options.';

  @override
  String get materialMaximumFilesError =>
      'You can select a maximum of 20 files.';

  @override
  String get analysisRecommended => 'Recommended';

  @override
  String get analysisRecommendedDescription =>
      'Best for formulas, diagrams, tables, and layout.';

  @override
  String get analysisEconomy => 'Economy';

  @override
  String get analysisAdvancedSettings => 'Advanced settings';

  @override
  String get analysisEconomyWarning =>
      'Formulas, diagrams, tables, and layout may be less accurate.';

  @override
  String analysisSourcePageNumber(Object page) {
    return 'Source page $page';
  }

  @override
  String analysisRetryAvailableIn(Object seconds) {
    return 'Retry available in $seconds seconds';
  }

  @override
  String get analysisCompleted => 'Completed';

  @override
  String get analysisPreparingDocument => 'Preparing document';

  @override
  String analysisPageProgress(Object completed, Object pageCount) {
    return 'Analyzing pages $completed of $pageCount';
  }

  @override
  String analysisFormulaProgress(Object completed, Object pageCount) {
    return 'Recognizing formulas and diagrams $completed of $pageCount';
  }

  @override
  String get analysisCombiningResults => 'Combining results';

  @override
  String get analysisCreatingSummary => 'Creating summary';

  @override
  String get analysisConfirmLargeTitle => 'Confirm large document';

  @override
  String get analysisConfirmLargeAction => 'Continue analysis';

  @override
  String get analysisLargeDocumentExplanation =>
      'This document is large. Analysis may take longer. Every page will be processed, formulas and diagrams may use visual analysis, and processing can resume when you reopen the app.';

  @override
  String get analysisDocumentTooLargeTitle => 'Document is too large';

  @override
  String get analysisDocumentTooLargeMessage =>
      'The PDF contains more than the supported page limit';

  @override
  String get analysisResumeProcessing =>
      'Processing can resume when you reopen the app.';

  @override
  String get analysisRetryProcessing => 'Retry processing';

  @override
  String get analysisRetryAvailableLater => 'Retry available later';

  @override
  String get analysisCompletedWithWarnings => 'Completed with warnings';

  @override
  String get analysisPartialPages => 'Partial pages';

  @override
  String get analysisMissingPages => 'Missing pages';

  @override
  String get analysisVerifyFormulas => 'Verify formulas';

  @override
  String get analysisUncertainFormula => 'Uncertain formula';

  @override
  String get analysisSourcePage => 'Source page';

  @override
  String get analysisViewOriginalPage => 'View original page';

  @override
  String get analysisCopyFormula => 'Copy formula';

  @override
  String get analysisMalformedFallback =>
      'The structured summary could not be displayed. Showing the available summary instead.';

  @override
  String get analysisUnableToExtractContent =>
      'The document could not be read. Try a clearer PDF or image.';

  @override
  String get analysisProviderUnavailable =>
      'The analysis service is temporarily unavailable. Try again later.';

  @override
  String get analysisStructuredOutputInvalid =>
      'The analysis finished, but the result could not be processed. You can retry.';

  @override
  String analysisEquationSemantics(String description, int page) {
    return 'Equation: $description. Source page $page.';
  }

  @override
  String get analysisFormulaCopied => 'Formula copied';

  @override
  String get analysisFormulaCopyFailed => 'Formula could not be copied';

  @override
  String analysisWarningSourcePage(int page) {
    return 'Warning source page $page';
  }

  @override
  String get analysisInvalidDocumentTitle => 'Document could not be analyzed';

  @override
  String get analysisInvalidDocumentMessage =>
      'The document is invalid, damaged, or unsupported.';

  @override
  String get analysisTemporaryFailure =>
      'Document analysis is temporarily unavailable. Try again later.';

  @override
  String analysisProgressSemantics(int completed, int pageCount) {
    return 'Analyzed $completed of $pageCount pages';
  }
}
