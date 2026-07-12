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
  String get actionDelete => 'Löschen';

  @override
  String get actionShowMore => 'Mehr anzeigen';

  @override
  String get actionShowLess => 'Weniger anzeigen';

  @override
  String get statusLoading => 'Laden';

  @override
  String get statusError => 'Fehler';

  @override
  String get commonEmail => 'E-Mail';

  @override
  String get commonName => 'Name';

  @override
  String get commonPassword => 'Passwort';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonErrorSemantics => 'Fehler';

  @override
  String get commonStatusSemantics => 'Status';

  @override
  String get commonAppStillUsable => 'Du kannst die App weiter verwenden.';

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
  String get settingsIntro => 'Mock-Einstellungen für den lokalen Prototyp.';

  @override
  String get settingsAccountTitle => 'Konto';

  @override
  String get settingsSupabaseAccount => 'Supabase-Konto';

  @override
  String get settingsLocalMockProfile => 'Lokales Mock-Profil';

  @override
  String get settingsEditName => 'Namen bearbeiten';

  @override
  String get settingsLogOut => 'Abmelden';

  @override
  String get settingsStudyPreferencesTitle => 'Lerneinstellungen';

  @override
  String get settingsStudyPreferencesSubtitle =>
      'Nur im lokalen AppState gespeichert';

  @override
  String get settingsDefaultFlashcardSessionSize =>
      'Standardgröße für Karteikarten-Sitzungen';

  @override
  String get settingsDailyStudyGoal => 'Tägliches Lernziel';

  @override
  String get settingsDefaultDifficulty => 'Standard-Schwierigkeit';

  @override
  String get settingsDifficultyEasy => 'leicht';

  @override
  String get settingsDifficultyMedium => 'mittel';

  @override
  String get settingsDifficultyExam => 'Prüfung';

  @override
  String settingsMinutesShort(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get settingsAppPreferencesTitle => 'App-Einstellungen';

  @override
  String get settingsAppearancePlanned => 'Darstellungsoptionen sind geplant';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsAppearanceUnavailable =>
      'Der Dunkelmodus ist noch nicht verfügbar.';

  @override
  String get settingsAppearanceDescription =>
      'Wähle die Darstellung der App. Die Systemeinstellung folgt deinem Gerät.';

  @override
  String get appearanceSystem => 'Systemeinstellung';

  @override
  String get appearanceLight => 'Hell';

  @override
  String get appearanceDark => 'Dunkel';

  @override
  String get settingsUsageTitle => 'Nutzung & Limits';

  @override
  String get settingsUsageUnavailable =>
      'Nutzungsverfolgung ist nicht verbunden';

  @override
  String get settingsViewUsage => 'Nutzungsinformationen anzeigen';

  @override
  String get settingsUsagePlanned => 'Limits und Durchsetzung sind geplant.';

  @override
  String get settingsSupportTitle => 'Support';

  @override
  String get settingsSupportSubtitle =>
      'Noch keine E-Mail- oder Netzwerkintegration';

  @override
  String get settingsReportBugPlaceholder => 'Platzhalter: Fehler melden';

  @override
  String get settingsContactSupportPlaceholder =>
      'Platzhalter: Support kontaktieren';

  @override
  String get settingsSendFeedbackPlaceholder => 'Platzhalter: Feedback senden';

  @override
  String get settingsAboutDebugTitle => 'Info / Debug';

  @override
  String get settingsAboutDebugSubtitle => 'Prototyp-Diagnose';

  @override
  String get settingsBackendMode => 'Backend-Modus';

  @override
  String get settingsSecurityNote => 'Sicherheitshinweis';

  @override
  String get settingsSecurityNoteValue =>
      'Keine Server-Secrets oder OpenAI-Schlüssel in Flutter.';

  @override
  String get comingLater => 'Kommt später';

  @override
  String get authWelcomeBackTitle => 'Willkommen zurück';

  @override
  String get authWelcomeBackSubtitle =>
      'Verwandle Unterrichtsmaterial in fokussierte Lerneinheiten.';

  @override
  String get authCreateAccountTitle => 'Konto erstellen';

  @override
  String get authCreateAccountSubtitle => 'Richte dein Lernprofil ein.';

  @override
  String get authLogIn => 'Anmelden';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authContinueWithEmail => 'Mit E-Mail fortfahren';

  @override
  String get authGoogleComingLater => 'Google kommt später';

  @override
  String get authAppleComingLater => 'Apple kommt später';

  @override
  String get authConfirmPassword => 'Passwort bestätigen';

  @override
  String get authAlreadyHaveAccount => 'Schon ein Konto? Anmelden';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort ausblenden';

  @override
  String get authPreparingStudySpace => 'Dein Lernbereich wird vorbereitet';

  @override
  String authResetNotice(String email) {
    return 'Falls ein Konto für $email existiert, ist eine E-Mail zum Zurücksetzen unterwegs.';
  }

  @override
  String get authCheckEmailNotice =>
      'Bestätige dein Konto per E-Mail und melde dich danach an.';

  @override
  String get homeSubtitle => 'Dein ruhiger Ort zum Lernen';

  @override
  String get homeRecentMaterials => 'Neueste Materialien';

  @override
  String get homeViewSubjects => 'Fächer anzeigen';

  @override
  String get homeNoMaterialsTitle => 'Noch keine Materialien';

  @override
  String get homeNoMaterialsMessage =>
      'Öffne ein Fach und füge dein erstes Lernmaterial hinzu.';

  @override
  String get homeYourSubjects => 'Deine Fächer';

  @override
  String get homeCreateFirstSubject => 'Erstes Fach erstellen';

  @override
  String get homeCreateFirstSubjectMessage =>
      'Fächer halten Materialien und Lernwerkzeuge zusammen.';

  @override
  String get homeStudyWorkspace => 'Lernbereich';

  @override
  String get homeHeroTitle => 'Bereit für deinen nächsten Lernschritt?';

  @override
  String get homeHeroWithMaterials =>
      'Mach mit einem aktuellen Material weiter oder wähle eine fokussierte Lernaktion.';

  @override
  String get homeHeroWithoutMaterials =>
      'Füge einem Fach Lernmaterial hinzu und erstelle danach Zusammenfassungen, Karteikarten und Quizze.';

  @override
  String get homeCreateSubject => 'Fach erstellen';

  @override
  String get homeOpenSubjects => 'Fächer öffnen';

  @override
  String get homeAfterLecture => 'Nach der Stunde';

  @override
  String get homeLatestProgress => 'Aktueller Fortschritt';

  @override
  String get homeNoQuizAttemptsTitle => 'Noch keine Quizversuche';

  @override
  String get homeNoQuizAttemptsMessage =>
      'Schließe ein Quiz ab, um dein neuestes Ergebnis zu sehen.';

  @override
  String homeCorrectCount(int correct, int total) {
    return '$correct von $total richtig';
  }

  @override
  String get homeFocusTopics => 'Themen zum Wiederholen';

  @override
  String get homeFocusTopicsEmpty =>
      'Schließe Quizze ab, um Themen zum Wiederholen zu sehen.';

  @override
  String homeMissesWithSubject(String subject, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
      one: '1 Fehler',
    );
    return '$subject · $_temp0';
  }

  @override
  String get homeQuickActions => 'Schnellaktionen';

  @override
  String get homePrepareForExam => 'Auf Prüfung vorbereiten';

  @override
  String get homeContinueStudying => 'Weiterlernen';

  @override
  String get subjectsTitle => 'Fächer';

  @override
  String get subjectsSubtitle => 'Lernbereich';

  @override
  String get subjectsLoading => 'Synchronisierte Fächer werden geladen';

  @override
  String get subjectsShowingAvailable =>
      'Die aktuell verfügbaren Fächer werden angezeigt.';

  @override
  String get subjectsNoSubjectsTitle => 'Noch keine Fächer';

  @override
  String get subjectsNoSubjectsMessage =>
      'Erstelle ein Fach, um Materialien, Zusammenfassungen, Karteikarten und Quizze zu bündeln.';

  @override
  String get subjectsCreateSubject => 'Fach erstellen';

  @override
  String get subjectsCreatingSubject => 'Fach wird erstellt';

  @override
  String get subjectsHeaderTitle => 'Deine Fächer';

  @override
  String get subjectsHeaderMessage =>
      'Erstelle fokussierte Bereiche für Vorlesungsnotizen, Zusammenfassungen, Quizze und Prüfungsvorbereitung.';

  @override
  String get subjectsNoDescription => 'Noch keine Beschreibung';

  @override
  String get subjectsExamPrep => 'Prüfungsvorbereitung';

  @override
  String subjectsOpenSubject(String subject) {
    return '$subject öffnen';
  }

  @override
  String get subjectsCreateDialogTitle => 'Fach erstellen';

  @override
  String get subjectsNameLabel => 'Fachname';

  @override
  String get subjectsNameHint => 'Biologie, Mathe, Geschichte...';

  @override
  String get subjectsDescriptionLabel => 'Beschreibung';

  @override
  String get subjectsColor => 'Farbe';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorGreen => 'Grün';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorAmber => 'Bernstein';

  @override
  String subjectsColorSemantics(String color) {
    return 'Farbe für Fach: $color';
  }

  @override
  String get subjectsDefaultDescription =>
      'Lernmaterialien und Übungen für dieses Fach.';

  @override
  String materialsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Materialien',
      one: '1 Material',
      zero: '0 Materialien',
    );
    return '$_temp0';
  }

  @override
  String subjectItemsInSubject(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge in diesem Fach',
      one: '1 Eintrag in diesem Fach',
      zero: '0 Einträge in diesem Fach',
    );
    return '$_temp0';
  }

  @override
  String summariesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zusammenfassungen',
      one: '1 Zusammenfassung',
      zero: '0 Zusammenfassungen',
    );
    return '$_temp0';
  }

  @override
  String get subjectWorkspaceSubtitle => 'Fachbereich';

  @override
  String get subjectMaterials => 'Materialien';

  @override
  String get subjectSummaries => 'Zusammenfassungen';

  @override
  String get subjectSummariesSubtitle =>
      'Generierte Erklärungen aus deinen Materialien';

  @override
  String get subjectStudyActions => 'Lernaktionen';

  @override
  String get subjectStudyActionsSubtitle =>
      'Aus Notizen in diesem Fach erstellen';

  @override
  String get subjectAddPastedText => 'Eingefügten Text hinzufügen';

  @override
  String get subjectCreateStudySession => 'Lerneinheit erstellen';

  @override
  String get subjectAddMaterialForSession =>
      'Füge ein Material hinzu, um eine Lerneinheit zu erstellen.';

  @override
  String get subjectUploadMaterials => 'Materialien hochladen';

  @override
  String get subjectUploadMaterialsSubtitle => 'Private PDFs und Bilder';

  @override
  String get subjectUploadPdf => 'PDF hochladen';

  @override
  String get subjectUploadImage => 'Bild hochladen';

  @override
  String get subjectFocusTopicsSubtitle => 'Kumulative Fehler aus Quizzen';

  @override
  String missesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
      one: '1 Fehler',
    );
    return '$_temp0';
  }

  @override
  String get subjectLoadingMaterials =>
      'Synchronisierte Materialien werden geladen';

  @override
  String get subjectStillUsable => 'Du kannst dieses Fach weiter verwenden.';

  @override
  String get subjectNoMaterialsTitle => 'Noch keine Materialien';

  @override
  String get subjectNoMaterialsMessage =>
      'Füge Text ein oder lade eine Datei hoch, um mit dem Lernen zu beginnen.';

  @override
  String get subjectNoSummariesTitle => 'Noch keine Zusammenfassungen';

  @override
  String get subjectNoSummariesMessage =>
      'Erstelle eine Zusammenfassung aus einem Material, dann erscheint sie hier.';

  @override
  String get subjectFavoriteMaterialTooltip => 'Material favorisieren';

  @override
  String get subjectUnfavoriteMaterialTooltip =>
      'Material aus Favoriten entfernen';

  @override
  String get materialAddTitle => 'Eingefügten Text hinzufügen';

  @override
  String get materialAddIntro =>
      'Füge Notizen, Transkripte oder Textbuchauszüge ein. Behalte die Originalsprache der Quelle bei.';

  @override
  String get materialTitleLabel => 'Materialtitel';

  @override
  String get materialPasteTextLabel => 'Unterrichtstext einfügen';

  @override
  String get materialPastedTextKind => 'Eingefügter Text';

  @override
  String get materialUploadedStatus => 'Hochgeladen';

  @override
  String get materialWaitingForProcessing => 'Wartet auf Verarbeitung';

  @override
  String get materialUnknownSize => 'Unbekannt';

  @override
  String get materialSaveMaterial => 'Material speichern';

  @override
  String get materialSavingMaterial => 'Material wird gespeichert';

  @override
  String get materialSaved => 'Material gespeichert.';

  @override
  String get materialUploaded => 'Material hochgeladen.';

  @override
  String get uploadPdfTitle => 'PDF hochladen';

  @override
  String get uploadImageTitle => 'Bild hochladen';

  @override
  String get uploadPdfGuidance => 'PDF-Dateien bis 10 MiB.';

  @override
  String get uploadImageGuidance =>
      'PNG-, JPG-, JPEG- oder WEBP-Bilder bis 8 MiB.';

  @override
  String get uploadChoosePdf => 'PDF auswählen';

  @override
  String get uploadChooseImage => 'Bild auswählen';

  @override
  String get uploadPdfKind => 'PDF';

  @override
  String get uploadImageKind => 'Bild';

  @override
  String get uploadMaterial => 'Material hochladen';

  @override
  String get uploadingMaterial => 'Material wird hochgeladen';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get favoritesSubtitle => 'Nur Favoriten lernen';

  @override
  String get favoritesMaterials => 'Materialien';

  @override
  String get favoritesFlashcards => 'Karteikarten';

  @override
  String get favoritesLoading => 'Synchronisierte Favoriten werden geladen';

  @override
  String get favoritesStillUsable => 'Die App bleibt nutzbar.';

  @override
  String get favoritesNoFavoritesTitle => 'Noch keine Favoriten';

  @override
  String get favoritesNoFavoritesMessage =>
      'Markiere Materialien oder Karteikarten als Favoriten, um sie hier zu finden.';

  @override
  String get favoritesUnfavorite => 'Aus Favoriten entfernen';

  @override
  String get favoritesUnfavoriteMaterial => 'Material aus Favoriten entfernen';

  @override
  String get searchTitle => 'Suchen';

  @override
  String get searchFieldLabel => 'Lernbereich durchsuchen';

  @override
  String get searchClear => 'Suche löschen';

  @override
  String get searchStartTitle => 'Tippe, um zu suchen';

  @override
  String get searchStartMessage =>
      'Finde Fächer, Materialien, Zusammenfassungen und Karteikarten.';

  @override
  String get searchNoResultsTitle => 'Keine Ergebnisse';

  @override
  String get searchNoResultsMessage =>
      'Versuche ein anderes Wort oder füge mehr Lernmaterial hinzu.';

  @override
  String searchSubjectsGroup(int count) {
    return 'Fächer ($count)';
  }

  @override
  String searchMaterialsGroup(int count) {
    return 'Materialien ($count)';
  }

  @override
  String searchFlashcardsGroup(int count) {
    return 'Karteikarten ($count)';
  }

  @override
  String get usageTitle => 'Nutzung';

  @override
  String get usageUnavailableTitle =>
      'Nutzungsverfolgung ist noch nicht verbunden';

  @override
  String get usageUnavailableMessage =>
      'Dieser Prototyp zeigt keine Tokenzahlen, Kontingente oder Abrechnungsdaten.';

  @override
  String get materialDetailTitle => 'Material';

  @override
  String get materialDeletingTitle => 'Material wird gelöscht';

  @override
  String get materialDeletingMessage =>
      'Quelle und materialspezifische Lerninhalte werden entfernt.';

  @override
  String get materialGeneratingStudyContentTitle =>
      'Lerninhalte werden erstellt';

  @override
  String get materialGeneratingStudyContentMessage =>
      'Materialbezogene Lerninhalte werden erstellt…';

  @override
  String get materialPartialResultTitle => 'Teilergebnis';

  @override
  String get materialPartialScannedMessage =>
      'Einige Seiten konnten nicht gelesen werden. Der verfügbare Lerntext kann weiter verwendet werden.';

  @override
  String get materialFileMetadataTitle => 'Dateimetadaten';

  @override
  String get materialFilenameLabel => 'Dateiname';

  @override
  String get materialTypeLabel => 'Typ';

  @override
  String get materialSizeLabel => 'Größe';

  @override
  String get materialMimeLabel => 'MIME';

  @override
  String get materialStatusLabel => 'Status';

  @override
  String get materialCreatedLabel => 'Erstellt';

  @override
  String get materialSummaryTitle => 'Zusammenfassung';

  @override
  String get materialFlashcardsTitle => 'Karteikarten';

  @override
  String get materialQuizTitle => 'Quiz';

  @override
  String get materialStudySessionTitle => 'Lerneinheit';

  @override
  String get materialDeleteDialogTitle => 'Material löschen?';

  @override
  String get materialDeleteMaterial => 'Material löschen';

  @override
  String get materialDeleted => 'Material gelöscht.';

  @override
  String get materialDeleteRemoved => 'Entfernt:';

  @override
  String get materialDeletePreserved => 'Beibehalten:';

  @override
  String get materialDeleteSourceMaterial => 'Quellmaterial';

  @override
  String get materialDeleteUploadedFile =>
      'Hochgeladene Datei, falls vorhanden';

  @override
  String get materialDeleteSummary => 'Zusammenfassung';

  @override
  String get materialDeleteFlashcards => 'Materialspezifische Karteikarten';

  @override
  String get materialDeleteQuizzes => 'Materialspezifische Quizze';

  @override
  String get materialDeleteQuizResults => 'Abgeschlossene Quiz-Ergebnisse';

  @override
  String get materialDeleteProgressHistory => 'Fortschrittsverlauf';

  @override
  String get materialDeleteWeakTopics => 'Kumulative Schwachstellen';

  @override
  String get materialDeleteStudyHistory => 'Lernverlauf';

  @override
  String get materialTextExtracted => 'Text extrahiert';

  @override
  String get materialTextExtractedWithOcr => 'Text mit OCR extrahiert';

  @override
  String materialPagesProgress(int processed, int total) {
    return '$processed/$total Seiten';
  }

  @override
  String materialPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten',
      one: '1 Seite',
    );
    return '$_temp0';
  }

  @override
  String get materialProcessingStatus => 'Wird verarbeitet';

  @override
  String get materialFailedStatus => 'Fehlgeschlagen';

  @override
  String get materialProcessingTitle => 'Material wird verarbeitet';

  @override
  String get materialStuckTitle => 'Die Verarbeitung scheint festzuhängen';

  @override
  String get materialStuckMessage =>
      'Setze dieses Material zurück und versuche die Verarbeitung erneut.';

  @override
  String get materialResetTryAgain => 'Zurücksetzen und erneut versuchen';

  @override
  String get imageExtractionFailedTitle => 'Bildtexterkennung fehlgeschlagen';

  @override
  String get imageExtractionTitle => 'Bildtexterkennung';

  @override
  String get imageReadingText => 'Bildtext wird gelesen…';

  @override
  String get imageExtractHelper =>
      'Extrahiere lesbaren Lerntext aus diesem Bild.';

  @override
  String get imageRetryExtraction => 'Bildtexterkennung erneut versuchen';

  @override
  String get imageExtractText => 'Text aus Bild extrahieren';

  @override
  String get pdfSomePagesNeedOcr => 'Einige Seiten benötigen OCR';

  @override
  String get pdfNoSelectableText => 'Kein nutzbarer auswählbarer Text gefunden';

  @override
  String get pdfReadingScannedPages => 'Gescannte PDF-Seiten werden gelesen…';

  @override
  String pdfRequiresOcrCount(int candidateCount, int pageCount) {
    return '$candidateCount von $pageCount Seiten benötigen OCR.';
  }

  @override
  String get pdfRequiresOcrMessage =>
      'Dieses PDF benötigt OCR, bevor Lernwerkzeuge verfügbar sind.';

  @override
  String get pdfScanWithOcr => 'PDF mit OCR scannen';

  @override
  String get pdfTextExtractionFailedTitle => 'Textextraktion fehlgeschlagen';

  @override
  String get pdfTextExtractionTitle => 'PDF-Textextraktion';

  @override
  String get pdfExtractingSelectable => 'Auswählbarer Text wird extrahiert…';

  @override
  String get pdfCouldNotExtract =>
      'Text konnte nicht extrahiert werden. Versuche es erneut.';

  @override
  String get pdfExtractHelper => 'Extrahiere auswählbaren Text aus diesem PDF.';

  @override
  String get pdfRetryTextExtraction => 'Textextraktion erneut versuchen';

  @override
  String get pdfExtractText => 'Text extrahieren';

  @override
  String get pdfScanDialogTitle => 'PDF mit OCR scannen?';

  @override
  String pdfScanDialogMessage(int pageCount, int candidateCount) {
    return 'Dieses PDF hat $pageCount Seiten. $candidateCount Seiten benötigen OCR.\n\nDiese Version unterstützt bis zu 10 Seiten insgesamt. KI-OCR kann länger dauern und nutzt kostenpflichtige Verarbeitung.';
  }

  @override
  String get pdfStartOcr => 'OCR starten';

  @override
  String get summaryNoSummary => 'Noch keine Zusammenfassung.';

  @override
  String get summaryRegenerate => 'Zusammenfassung neu erstellen';

  @override
  String get summaryWithAi => 'Mit KI zusammenfassen';

  @override
  String get summaryGenerateMock => 'Mock-Zusammenfassung erstellen';

  @override
  String get summaryGenerating => 'Zusammenfassung wird erstellt';

  @override
  String flashcardsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karteikarten bereit.',
      one: '1 Karteikarte bereit.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsNoFlashcards => 'Noch keine Karteikarten.';

  @override
  String get flashcardsTooShort =>
      'Füge mehr Unterrichtstext hinzu, bevor du Karteikarten erstellst.';

  @override
  String get flashcardsStartTraining => 'Training starten';

  @override
  String get flashcardsReviewThese => 'Diese Karteikarten ansehen';

  @override
  String get flashcardsGenerate => 'Karteikarten erstellen';

  @override
  String get flashcardsGenerating => 'Karteikarten werden erstellt';

  @override
  String get flashcardsNoNewGenerated =>
      'Es wurden keine neuen eindeutigen Karteikarten erstellt.';

  @override
  String flashcardsNewGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Karteikarten erstellt.',
      one: '1 neue Karteikarte erstellt.',
    );
    return '$_temp0';
  }

  @override
  String quizQuestionsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fragen bereit.',
      one: '1 Frage bereit.',
    );
    return '$_temp0';
  }

  @override
  String get quizNoQuiz => 'Noch kein Quiz.';

  @override
  String get quizTakeQuiz => 'Quiz starten';

  @override
  String get quizGenerate => 'Quiz erstellen';

  @override
  String get quizGenerateMock => 'Mock-Quiz erstellen';

  @override
  String get quizGenerating => 'Quiz wird erstellt';

  @override
  String get genericLocalizedError =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get errorEnterName => 'Gib deinen Namen ein.';

  @override
  String get errorEnterValidEmail => 'Gib eine gültige E-Mail-Adresse ein.';

  @override
  String get errorPasswordTooShort =>
      'Das Passwort muss mindestens 6 Zeichen lang sein.';

  @override
  String get errorConfirmPassword => 'Bestätige dein Passwort.';

  @override
  String get errorPasswordsDoNotMatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get errorLoginToEditProfile =>
      'Melde dich an, um dein Profil zu bearbeiten.';

  @override
  String get errorAccountAlreadyExists =>
      'Für diese E-Mail existiert bereits ein Konto. Versuche dich anzumelden.';

  @override
  String get errorCouldNotUpdateProfile =>
      'Das Kontoprofil konnte nicht aktualisiert werden.';

  @override
  String get errorCouldNotLogOut => 'Abmelden fehlgeschlagen.';

  @override
  String get errorCouldNotSyncSubjects =>
      'Fächer konnten nicht synchronisiert werden. Versuche es erneut.';

  @override
  String get errorEnterSubjectName => 'Gib einen Fachnamen ein.';

  @override
  String get errorLoginToSyncSubjects =>
      'Melde dich an, um Fächer zu synchronisieren.';

  @override
  String get errorCouldNotSyncMaterials =>
      'Materialien konnten nicht synchronisiert werden. Versuche es erneut.';

  @override
  String get errorEnterTitleAndText =>
      'Gib einen Titel und eingefügten Text ein.';

  @override
  String get errorLoginToSyncMaterials =>
      'Melde dich an, um Materialien zu synchronisieren.';

  @override
  String get errorChoosePdfOrImage =>
      'Wähle ein PDF oder Bild zum Hochladen aus.';

  @override
  String get errorLoginToUploadMaterials =>
      'Melde dich an, um Materialien hochzuladen.';

  @override
  String get errorCouldNotUploadFile =>
      'Die ausgewählte Datei konnte nicht hochgeladen werden.';

  @override
  String get errorUnsupportedFile =>
      'Wähle eine unterstützte PDF-, PNG-, JPG-, JPEG- oder WEBP-Datei.';

  @override
  String get errorEmptyFile => 'Die ausgewählte Datei ist leer.';

  @override
  String get errorFileTypeMismatch =>
      'Der Dateiinhalt passt nicht zum ausgewählten Dateityp.';

  @override
  String get errorCouldNotOpenFilePicker =>
      'Die Dateiauswahl konnte nicht geöffnet werden.';

  @override
  String get errorMaterialUnavailable => 'Material nicht verfügbar.';

  @override
  String get errorCouldNotUpdateFavorite =>
      'Favorit konnte nicht aktualisiert werden.';

  @override
  String get errorCouldNotSyncFavorites =>
      'Favoriten konnten nicht synchronisiert werden. Versuche es erneut.';

  @override
  String get errorCouldNotDeleteMaterial =>
      'Das Material konnte nicht gelöscht werden. Versuche es erneut.';

  @override
  String get errorLoginToDeleteMaterial =>
      'Melde dich an, um dieses Material zu löschen.';

  @override
  String get errorCouldNotResetProcessing =>
      'Die Verarbeitung konnte nicht zurückgesetzt werden.';

  @override
  String get errorPdfCannotBeExtracted =>
      'Dieses PDF kann nicht extrahiert werden.';

  @override
  String get errorLoginToExtractPdf =>
      'Melde dich an, um PDF-Text zu extrahieren.';

  @override
  String get errorCouldNotExtractText =>
      'Text konnte nicht extrahiert werden. Versuche es erneut.';

  @override
  String get errorImageCannotBeProcessed =>
      'Dieses Bild kann nicht verarbeitet werden.';

  @override
  String get errorLoginToExtractImage =>
      'Melde dich an, um Bildtext zu extrahieren.';

  @override
  String get errorCouldNotExtractImageText =>
      'Bildtext konnte nicht extrahiert werden. Versuche es erneut.';

  @override
  String get errorPdfCannotBeScanned =>
      'Dieses PDF kann nicht mit OCR gelesen werden.';

  @override
  String get errorLoginToScanPdf => 'Melde dich an, um dieses PDF zu scannen.';

  @override
  String get errorCouldNotScanPdf =>
      'Dieses PDF konnte nicht gescannt werden. Versuche es erneut.';

  @override
  String get errorPdfOcrPageLimit =>
      'Diese Version kann PDFs bis zu 10 Seiten scannen. Teile das PDF und lade eine kleinere Datei hoch.';

  @override
  String get errorNoSelectablePdfText =>
      'Es wurde kein auswählbarer Text gefunden. Gescannte PDFs werden in der OCR-Phase unterstützt.';

  @override
  String get errorNoReadableImageText =>
      'In diesem Bild wurde kein lesbarer Text gefunden.';

  @override
  String get errorInvalidPdf => 'Die hochgeladene Datei ist kein gültiges PDF.';

  @override
  String get errorCouldNotReadPdf =>
      'Das hochgeladene PDF konnte nicht gelesen werden.';

  @override
  String get errorCouldNotReadImage =>
      'Das hochgeladene Bild konnte nicht gelesen werden.';

  @override
  String get errorInvalidImage =>
      'Die hochgeladene Datei ist kein gültiges unterstütztes Bild.';

  @override
  String get errorCouldNotGenerateSummary =>
      'Zusammenfassung konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get errorAddMoreLectureText =>
      'Füge mehr Unterrichtstext hinzu, bevor du eine Zusammenfassung erstellst.';

  @override
  String get errorCouldNotGenerateFlashcards =>
      'Karteikarten konnten nicht erstellt werden. Versuche es erneut.';

  @override
  String get errorCouldNotGenerateQuiz =>
      'Quiz konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String studyCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return '$_temp0';
  }

  @override
  String studyQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fragen',
      one: '1 Frage',
    );
    return '$_temp0';
  }

  @override
  String studyAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Versuche',
      one: '1 Versuch',
    );
    return '$_temp0';
  }

  @override
  String studyMisses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
      one: '1 Fehler',
    );
    return '$_temp0';
  }

  @override
  String get studyProgress => 'Lernfortschritt';

  @override
  String studyProgressValue(int current, int total) {
    return '$current von $total';
  }

  @override
  String get studyQuestion => 'Frage';

  @override
  String get studyAnswer => 'Antwort';

  @override
  String get studyShowAnswer => 'Antwort anzeigen';

  @override
  String get studyHideAnswer => 'Antwort ausblenden';

  @override
  String get studyFlashcardQuestionSemantics =>
      'Lernkartenfrage. Aktivieren, um die Antwort anzuzeigen.';

  @override
  String get studyFlashcardAnswerSemantics =>
      'Lernkartenantwort. Aktivieren, um die Antwort auszublenden.';

  @override
  String get studyMissedAction => 'Nicht gewusst';

  @override
  String get studyKnownAction => 'Gewusst';

  @override
  String get studyCorrect => 'Richtig';

  @override
  String get studyIncorrect => 'Falsch';

  @override
  String studyCorrectAnswer(String answer) {
    return 'Richtige Antwort: $answer';
  }

  @override
  String studyChoiceCorrectSemantics(String choice) {
    return '$choice, richtige Antwort';
  }

  @override
  String studyChoiceIncorrectSemantics(String choice) {
    return '$choice, falsche Antwort';
  }

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonReturn => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonCustom => 'Benutzerdefiniert';

  @override
  String get commonPrototype => 'Prototyp';

  @override
  String get commonGenerate => 'Erstellen';

  @override
  String get flashcardsTitle => 'Lernkarten';

  @override
  String flashcardsAllTitle(Object subject) {
    return 'Alle Lernkarten — $subject';
  }

  @override
  String flashcardsMaterialTitle(Object material) {
    return 'Lernkarten — $material';
  }

  @override
  String flashcardsScopeMaterial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten aus diesem Material',
      one: '1 Karte aus diesem Material',
    );
    return '$_temp0';
  }

  @override
  String flashcardsScopeSubject(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten in diesem Fach',
      one: '1 Karte in diesem Fach',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsSessionSize => 'Größe der Lerneinheit';

  @override
  String flashcardsAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten sind für diese Auswahl verfügbar.',
      one: '1 Karte ist für diese Auswahl verfügbar.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsGenerateMoreGuidance =>
      'Erstelle weitere Lernkarten aus einem Material, um größere Einheiten freizuschalten.';

  @override
  String get flashcardsLoading => 'Synchronisierte Lernkarten werden geladen';

  @override
  String get flashcardsEmptyTitle => 'Noch keine Lernkarten';

  @override
  String get flashcardsEmptyMessage =>
      'Füge Karten hinzu oder erstelle sie, um mit dem Wiederholen zu beginnen.';

  @override
  String get flashcardsEmptyCloudMessage =>
      'Erstelle sie aus einem Material mit eingefügtem Text.';

  @override
  String get flashcardsReviewFocus => 'Wiederholungsfokus';

  @override
  String get flashcardsFilterSemantics => 'Lernkartenfilter';

  @override
  String get flashcardsFilterAll => 'Alle';

  @override
  String get flashcardsFilterWeak => 'Zum Wiederholen';

  @override
  String get flashcardsFilterDue => 'Fällig zur Wiederholung';

  @override
  String flashcardsStartTrainingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return 'Training starten ($_temp0)';
  }

  @override
  String get flashcardsTrainWeak => 'Karten zum Wiederholen trainieren';

  @override
  String get flashcardsReviewDue => 'Fällige Karten wiederholen';

  @override
  String get flashcardsNoWeak =>
      'Derzeit müssen keine Karten zusätzlich wiederholt werden.';

  @override
  String get flashcardsNoDue => 'Derzeit sind keine Karten fällig.';

  @override
  String get flashcardsCustomSessionTitle => 'Benutzerdefinierte Einheit';

  @override
  String get flashcardsCardsField => 'Karten';

  @override
  String flashcardsMaximum(Object count) {
    return 'Maximum: $count';
  }

  @override
  String get flashcardsChooseAtLeastOne => 'Wähle mindestens 1 Karte.';

  @override
  String flashcardsOnlyAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sind nur $count Karten verfügbar',
      one: 'ist nur 1 Karte verfügbar',
    );
    return 'Für diese Auswahl $_temp0.';
  }

  @override
  String flashcardsTopicDifficulty(String topic, String difficulty) {
    return 'Thema: $topic · $difficulty';
  }

  @override
  String flashcardsReviewStats(Object known, Object missed) {
    return 'Gewusst $known · Nicht gewusst $missed';
  }

  @override
  String get flashcardGenerationTitle => 'Neue Lernkarten erstellen';

  @override
  String get flashcardGenerationGuidance =>
      'Wähle, wie viele neue Lernkarten hinzugefügt werden sollen.';

  @override
  String flashcardGenerationCurrent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return 'Aktuell: $_temp0';
  }

  @override
  String flashcardGenerationAdd(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return 'Hinzufügen: $_temp0';
  }

  @override
  String flashcardGenerationProjected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return 'Voraussichtlich insgesamt: $_temp0';
  }

  @override
  String get flashcardGenerationNewField => 'Neue Lernkarten';

  @override
  String get flashcardGenerationRangeError =>
      'Wähle zwischen 1 und 30 neuen Lernkarten.';

  @override
  String get flashcardGenerationMaxError => 'Wähle höchstens 30 Lernkarten.';

  @override
  String get trainingTitle => 'Lernkartentraining';

  @override
  String get trainingEmptyTitle => 'Keine Lernkarten zum Trainieren';

  @override
  String get trainingEmptyMessage => 'Erstelle zuerst Lernkarten.';

  @override
  String get trainingProgress => 'Lernkartenfortschritt';

  @override
  String get trainingComplete => 'Training abgeschlossen';

  @override
  String trainingReviewed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten wiederholt',
      one: '1 Karte wiederholt',
    );
    return '$_temp0';
  }

  @override
  String trainingKnown(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten gewusst',
      one: '1 Karte gewusst',
    );
    return '$_temp0';
  }

  @override
  String trainingMissed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten nicht gewusst',
      one: '1 Karte nicht gewusst',
    );
    return '$_temp0';
  }

  @override
  String get trainingReviewMissed => 'Nicht gewusste Karten wiederholen';

  @override
  String get trainingReviewAgain => 'Erneut wiederholen';

  @override
  String get errorCouldNotSaveReview =>
      'Wiederholungsfortschritt konnte nicht gespeichert werden.';

  @override
  String get quizUiTitle => 'Quiz';

  @override
  String get quizEmptyTitle => 'Keine Fragen verfügbar';

  @override
  String get quizEmptyMessage =>
      'Kehre zum Material zurück und erstelle zuerst ein Quiz.';

  @override
  String get quizProgress => 'Fragenfortschritt';

  @override
  String get quizShowScore => 'Ergebnis anzeigen';

  @override
  String get quizMissedReview => 'Falsch beantwortete Fragen wiederholen';

  @override
  String get quizFinishReview => 'Wiederholung beenden';

  @override
  String get quizResult => 'Ergebnis';

  @override
  String quizScore(Object percent) {
    return 'Ergebnis: $percent%';
  }

  @override
  String quizCorrectCount(num correct, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct richtige Antworten von $total',
      one: '1 richtige Antwort von $total',
    );
    return '$_temp0';
  }

  @override
  String get quizMissedTopics => 'Themen zum Wiederholen';

  @override
  String get quizNoMissedTopics => 'Keine Themen zum Wiederholen. Sehr gut!';

  @override
  String get quizSaving => 'Quizversuch wird gespeichert…';

  @override
  String get quizUnsyncedWarning =>
      'Dieses Ergebnis wurde lokal berechnet und nicht synchronisiert.';

  @override
  String get quizReviewMissed => 'Falsch beantwortete Fragen wiederholen';

  @override
  String get quizReviewMaterial => 'Material wiederholen';

  @override
  String get quizRetry => 'Quiz wiederholen';

  @override
  String get errorCouldNotSaveQuizAttempt =>
      'Dieser Quizversuch konnte nicht gespeichert werden.';

  @override
  String get progressLatestQuiz => 'Letztes Quiz';

  @override
  String get progressAttemptsCompleted => 'Abgeschlossene Versuche';

  @override
  String get progressFocusTopics => 'Themen zum Wiederholen';

  @override
  String get progressHistoryExplanation =>
      'Gesammelte Fehler aus abgeschlossenen Quizzen.';

  @override
  String get progressNoAttempts =>
      'Schließe ein Quiz ab, um hier Ergebnisse zu sehen.';

  @override
  String get progressLoading => 'Fortschritt wird geladen';

  @override
  String get progressEmptyTitle => 'Noch keine Quizversuche';

  @override
  String get progressEmptyMessage =>
      'Schließe ein Quiz ab, um deinen Fortschrittsverlauf aufzubauen.';

  @override
  String get afterLectureTitle => 'Nach der Vorlesung';

  @override
  String get examPrepTitle => 'Prüfungsvorbereitung';

  @override
  String get continueStudyingTitle => 'Weiterlernen';

  @override
  String get aiTeacherTitle => 'KI-Lehrkraft';

  @override
  String get studySessionTitle => 'Lerneinheit';

  @override
  String get studyLocalPrototype => 'Lokaler Prototyp';

  @override
  String get studyLocalMockCoaching => 'Lokales Probe-Coaching';

  @override
  String get studyChooseSubject => 'Fach auswählen';

  @override
  String get studyChooseMaterial => 'Material auswählen';

  @override
  String get studyCreateSession => 'Lerneinheit erstellen';

  @override
  String get studyNoSubjectsTitle => 'Noch keine Fächer';

  @override
  String get studyOpenSubjects => 'Fächer öffnen';

  @override
  String get studyNoMaterialsTitle => 'Noch keine Materialien';

  @override
  String get studyContinueSession => 'Lerneinheit fortsetzen';

  @override
  String get studyNotCompleted => 'Nicht abgeschlossen';

  @override
  String get studyBackToSubject => 'Zurück zum Fach';

  @override
  String get studyUnavailableTitle => 'Kein Lernmaterial verfügbar';

  @override
  String get studySessionOverview => 'Übersicht der Lerneinheit';

  @override
  String get studyEstimatedTime => 'Geschätzte Lernzeit';

  @override
  String get studySummary => 'Zusammenfassung';

  @override
  String get studyFlashcardsAction => 'Lernkarten';

  @override
  String get studyAiTeacherAction => 'KI-Lehrkraft';

  @override
  String studyMinutes(Object count) {
    return '$count Min.';
  }

  @override
  String get studySelectSubject => 'Fach auswählen';

  @override
  String get studySelectSubjectMessage =>
      'Wähle das Fach der Vorlesung aus, um fortzufahren.';

  @override
  String get studyNoMaterialsMessage =>
      'Füge ein nutzbares Material hinzu, bevor du diese Lerneinheit erstellst.';

  @override
  String get afterLecturePrototype => 'Lokale Prototyp-Anleitung';

  @override
  String get afterLectureNoSubjectsMessage =>
      'Erstelle ein Fach, bevor du eine Einheit nach der Vorlesung startest.';

  @override
  String get afterLectureConfidence => 'Wie sicher fühlst du dich?';

  @override
  String get afterLectureSchedule => 'Prototyp-Lernplan';

  @override
  String get afterLectureScheduleHelp =>
      'Lokal geschätzt; dies ist keine erfasste Lernzeit.';

  @override
  String get examPrepPrototype => 'Lokaler Prototyp-Plan';

  @override
  String get examPrepHeading => 'Auf eine Prüfung vorbereiten';

  @override
  String get examPrepHelp =>
      'Erstelle aus Fach, Materialien und Wiederholungsthemen einen lokalen Lernplan.';

  @override
  String get examPrepNoSubjectsMessage =>
      'Erstelle ein Fach, bevor du einen Prüfungsplan vorbereitest.';

  @override
  String get examPrepDatePreview => 'Vorschau des Prüfungstermins';

  @override
  String get examPrepDateUnavailable =>
      'Die Datumsauswahl ist in diesem Prototyp nicht verfügbar.';

  @override
  String get examPrepDate => 'Prüfungstermin';

  @override
  String get examPrepMockDate => 'Beispieldatum: in 2 Wochen';

  @override
  String get examPrepMaterialsPreview => 'Vorschau ausgewählter Materialien';

  @override
  String get examPrepMaterialsEmptyHelp =>
      'Der Plan kann trotzdem mit dem gewählten Fach beginnen.';

  @override
  String get examPrepIncluded => 'Im Plan enthalten';

  @override
  String get examPrepTopicsPreview => 'Vorschau der Wiederholungsthemen';

  @override
  String get examPrepTopicsHelp =>
      'Lokal erstellte Prototyp-Anleitung; kein Beherrschungswert.';

  @override
  String get examPrepPlanPreview => 'Vorschau des Vorbereitungsplans';

  @override
  String get examPrepPlanHelp => 'Lokal erstellte Prototyp-Anleitung.';

  @override
  String get continueEmptyTitle => 'Nichts zum Fortsetzen';

  @override
  String get continueEmptyMessage =>
      'Starte eine Lerneinheit in einem deiner Fächer.';

  @override
  String get continueUnavailableMessage =>
      'Das Fach oder die Quelle der letzten Lerneinheit ist nicht mehr verfügbar.';

  @override
  String continueFrom(Object material) {
    return 'Fortsetzen mit $material';
  }

  @override
  String get continueLatest => 'Letzte Lerneinheit';

  @override
  String get continueSummary => 'Zusammenfassung der Lerneinheit';

  @override
  String get continueQuickQuiz => 'Kurzquiz';

  @override
  String continueLastScore(Object percent) {
    return 'Letztes Ergebnis: $percent%';
  }

  @override
  String get continueNoTopics =>
      'Für diese Lerneinheit wurden keine Wiederholungsthemen erfasst.';

  @override
  String get aiTeacherStatus => 'Lokales Probe-Coaching · Prototyp';

  @override
  String get aiTeacherNoLive =>
      'Vorgefertigte lokale Antworten; keine Live-KI-Verbindung.';

  @override
  String get aiTeacherHelp =>
      'Wähle einen Coaching-Stil. Die Antwort bleibt vollständig lokal und verwendet Beispieltext.';

  @override
  String get aiTeacherPrompt => 'Coaching-Anweisung';

  @override
  String get aiTeacherPromptSimple => 'Einfacher erklären';

  @override
  String get aiTeacherPromptExample => 'Weiteres Beispiel geben';

  @override
  String get aiTeacherPromptQuestion => 'Frage stellen';

  @override
  String get aiTeacherAnswer => 'Prototyp-Antwort';

  @override
  String get aiTeacherTryNext => 'Als Nächstes';

  @override
  String get aiTeacherAnotherExample => 'Weiteres Beispiel anzeigen';

  @override
  String get aiTeacherQuizMe => 'Dazu abfragen';

  @override
  String sessionGeneratedFrom(Object material) {
    return 'Erstellt aus: $material';
  }

  @override
  String get sessionLocal => 'Lokale Lerneinheit';

  @override
  String get sessionNoAnswer => 'Keine Antwort abgegeben.';

  @override
  String get sessionNoFlashcards => 'Keine Lernkarten in dieser Einheit.';

  @override
  String get sessionQuickQuiz => 'Kurzquiz';

  @override
  String get sessionFocusTopics => 'Themen zum Wiederholen';

  @override
  String get sessionNoTopics => 'Keine Themen zum Wiederholen erfasst.';

  @override
  String get sessionPrototypeExplanation => 'Prototyp-Erklärung';

  @override
  String get sessionPrototypeHelp =>
      'Lokale Beispielhilfe; keine Live-KI-Antwort.';

  @override
  String get sessionMoreFlashcards => 'Weitere Lernkarten erstellen';

  @override
  String get sessionAskTeacher => 'KI-Lehrkraft fragen';

  @override
  String get relativeJustNow => 'Gerade eben';

  @override
  String get relativeToday => 'Heute';

  @override
  String get relativeYesterday => 'Gestern';

  @override
  String get relativeSynced => 'Synchronisiert';

  @override
  String get relativeRecent => 'Kürzlich';

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
  String get favoriteAction => 'Zu Favoriten hinzufügen';

  @override
  String get unfavoriteAction => 'Aus Favoriten entfernen';

  @override
  String sessionTopic(Object topic) {
    return 'Thema: $topic';
  }

  @override
  String sessionCorrectOption(Object option) {
    return '$option — richtig';
  }

  @override
  String sessionIncorrectOption(Object option) {
    return '$option — falsch';
  }

  @override
  String sessionUnavailableForSubject(Object subject) {
    return 'Füge dem Fach $subject ein bereites Material mit nutzbarem Inhalt hinzu, bevor du eine Lerneinheit erstellst.';
  }

  @override
  String get examPrepRecommendation =>
      'Empfohlen: zuerst Lernkarten, dann ein Kurzquiz.';

  @override
  String formattedMaterialSize(Object size) {
    return 'Größe: $size';
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
    return 'Die ausgewählte Datei ist zu groß. Maximale Größe: $size.';
  }

  @override
  String get materialActionsTooltip => 'Materialaktionen';

  @override
  String get materialDetailsTitle => 'Details';

  @override
  String get materialDeleteDescription =>
      'Diese Quelle und ihre materialspezifischen generierten Lerninhalte entfernen.';

  @override
  String get materialDeleting => 'Material wird gelöscht';

  @override
  String get subjectDeleteAction => 'Fach löschen';

  @override
  String subjectDeleteTitle(Object subject) {
    return '$subject löschen?';
  }

  @override
  String get subjectDeleteBody =>
      'Dadurch werden das Fach, hochgeladene Dateien, Zusammenfassungen, generierte Lerninhalte, Quizversuche, Lernsitzungen und Schwerpunktthemen dauerhaft gelöscht.';

  @override
  String subjectDeleteCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geladene Materialien',
      one: '1 geladenes Material',
      zero: 'Keine geladenen Materialien',
    );
    return '$_temp0';
  }

  @override
  String get subjectDeleting => 'Fach wird gelöscht';

  @override
  String get subjectDeleted => 'Fach gelöscht.';

  @override
  String get accountDangerTitle => 'Gefahrenbereich';

  @override
  String get accountDangerSubtitle =>
      'Konto und alle Lerndaten dauerhaft löschen.';

  @override
  String get accountDeleteAction => 'Konto löschen';

  @override
  String get accountDeleteTitle => 'Konto löschen?';

  @override
  String get accountDeleteBody =>
      'Profil, Fächer, Lernverlauf, generierte Inhalte und private Uploads werden dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get accountDeleteRecentAuth =>
      'Zur Sicherheit musst du dich möglicherweise erneut anmelden.';

  @override
  String get accountDeleteTypePrompt => 'Zum Bestätigen DELETE eingeben';

  @override
  String get accountDeleteConfirmationLabel => 'Bestätigung';

  @override
  String get accountDeleting => 'Konto wird gelöscht';

  @override
  String get accountDeleted => 'Konto gelöscht.';

  @override
  String get accountDeleteReauth =>
      'Melde dich erneut an und bestätige die Kontolöschung noch einmal.';

  @override
  String get deletionErrorInProgress => 'Die Löschung läuft bereits.';

  @override
  String get deletionErrorStorage =>
      'Private Dateien konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String get deletionErrorDatabase =>
      'Die Lerndaten konnten nicht vollständig gelöscht werden. Versuche es erneut.';

  @override
  String get deletionErrorAuth =>
      'Das Konto konnte nicht vollständig entfernt werden. Versuche es erneut.';

  @override
  String get deletionErrorRecentAuth =>
      'Melde dich erneut an, bevor du dein Konto löschst.';

  @override
  String get deletionErrorUnauthorized =>
      'Deine Sitzung ist nicht mehr gültig.';

  @override
  String get deletionErrorRetry =>
      'Die Löschung kann noch nicht fortgesetzt werden. Versuche es später erneut.';

  @override
  String get deletionErrorUnknown =>
      'Die Löschung konnte nicht abgeschlossen werden. Versuche es erneut.';

  @override
  String get deletionRetry => 'Löschung wiederholen';

  @override
  String get generatedPreviewTitle => 'Prototyp-Vorschau';

  @override
  String generatedPreviewSubtitle(Object subject) {
    return 'Generierte Beispielausgabe · $subject';
  }

  @override
  String get generatedPreviewEmptyTitle => 'Keine Vorschau verfügbar';

  @override
  String get generatedPreviewEmptyMessage =>
      'Generierte Lerninhalte werden hier angezeigt, sobald sie verfügbar sind.';

  @override
  String generatedCountPreview(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lernkarten',
      one: '1 Lernkarte',
    );
    return 'Erstellungsvorschau: $_temp0';
  }

  @override
  String get generatedOpenFlashcards => 'Lernkarten öffnen';

  @override
  String generatedExplainMistake(Object explanation) {
    return 'Erklärung: $explanation';
  }

  @override
  String get generatedExamPlan => 'Prüfungsvorbereitungsplan';

  @override
  String get confidenceUnderstoodEverything => 'Ich habe alles verstanden';

  @override
  String get confidenceMostly => 'Größtenteils';

  @override
  String get confidenceAboutHalf => 'Etwa die Hälfte';

  @override
  String get confidenceCompletelyLost => 'Ich habe nichts verstanden';

  @override
  String get blockSummary => 'Zusammenfassung';

  @override
  String get blockFlashcards => 'Lernkarten';

  @override
  String get blockQuiz => 'Quiz';

  @override
  String get blockReviewMistakes => 'Fehler wiederholen';

  @override
  String get blockSimpleExplanation => 'Einfache Erklärung';

  @override
  String get blockGuidedFlashcards => 'Geführte Lernkarten';

  @override
  String get blockQuickQuiz => 'Kurzquiz';

  @override
  String searchMaterialSubtitle(Object date, Object subject) {
    return '$subject · $date';
  }

  @override
  String searchFlashcardSubtitle(Object subject, Object topic) {
    return '$subject · Lernkarte · $topic';
  }
}
