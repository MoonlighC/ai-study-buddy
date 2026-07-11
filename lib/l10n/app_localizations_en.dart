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
  String get settingsUsageTitle => 'Usage & Limits';

  @override
  String get settingsUsageUnavailable => 'Usage tracking is not connected';

  @override
  String get settingsViewUsage => 'View usage information';

  @override
  String get settingsUsagePlanned => 'Limits and enforcement are planned.';

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
  String get materialUnknownSize => 'Unknown size';

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
  String get uploadPdfGuidance => 'PDF files up to 10 MiB.';

  @override
  String get uploadImageGuidance =>
      'PNG, JPG, JPEG, or WEBP images up to 8 MiB.';

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
  String get usageUnavailableTitle => 'Usage tracking is not connected yet';

  @override
  String get usageUnavailableMessage =>
      'This prototype does not show token counts, quotas, or billing data.';

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
}
