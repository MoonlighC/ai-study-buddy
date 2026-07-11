// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AI Study Buddy';

  @override
  String get navHome => 'Главная';

  @override
  String get navSubjects => 'Предметы';

  @override
  String get navFavorites => 'Избранное';

  @override
  String get navProgress => 'Прогресс';

  @override
  String get navSettings => 'Настройки';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionBack => 'Назад';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionShowMore => 'Показать больше';

  @override
  String get actionShowLess => 'Показать меньше';

  @override
  String get statusLoading => 'Загрузка';

  @override
  String get statusError => 'Ошибка';

  @override
  String get commonEmail => 'Эл. почта';

  @override
  String get commonName => 'Имя';

  @override
  String get commonPassword => 'Пароль';

  @override
  String get commonUnknown => 'Неизвестно';

  @override
  String get commonStatus => 'Статус';

  @override
  String get commonErrorSemantics => 'Ошибка';

  @override
  String get commonStatusSemantics => 'Статус';

  @override
  String get commonAppStillUsable => 'Приложением всё ещё можно пользоваться.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguageTitle => 'Язык';

  @override
  String get settingsDisplayLanguage => 'Язык интерфейса';

  @override
  String get settingsDisplayLanguageDescription =>
      'Выберите язык навигации и элементов управления приложения.';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsIntro => 'Тестовые настройки для локального прототипа.';

  @override
  String get settingsAccountTitle => 'Аккаунт';

  @override
  String get settingsSupabaseAccount => 'Аккаунт Supabase';

  @override
  String get settingsLocalMockProfile => 'Локальный тестовый профиль';

  @override
  String get settingsEditName => 'Изменить имя';

  @override
  String get settingsLogOut => 'Выйти';

  @override
  String get settingsStudyPreferencesTitle => 'Учебные настройки';

  @override
  String get settingsStudyPreferencesSubtitle =>
      'Хранятся только в локальном AppState';

  @override
  String get settingsDefaultFlashcardSessionSize =>
      'Размер сессии карточек по умолчанию';

  @override
  String get settingsDailyStudyGoal => 'Дневная цель обучения';

  @override
  String get settingsDefaultDifficulty => 'Сложность по умолчанию';

  @override
  String get settingsDifficultyEasy => 'легко';

  @override
  String get settingsDifficultyMedium => 'средне';

  @override
  String get settingsDifficultyExam => 'экзамен';

  @override
  String settingsMinutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get settingsAppPreferencesTitle => 'Настройки приложения';

  @override
  String get settingsAppearancePlanned =>
      'Настройки внешнего вида запланированы';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsAppearanceUnavailable => 'Темная тема пока недоступна.';

  @override
  String get settingsUsageTitle => 'Использование и лимиты';

  @override
  String get settingsUsageUnavailable =>
      'Отслеживание использования не подключено';

  @override
  String get settingsViewUsage => 'Посмотреть сведения об использовании';

  @override
  String get settingsUsagePlanned => 'Лимиты и их применение запланированы.';

  @override
  String get settingsSupportTitle => 'Поддержка';

  @override
  String get settingsSupportSubtitle =>
      'Интеграция с почтой и сетью пока отсутствует';

  @override
  String get settingsReportBugPlaceholder => 'Заглушка: сообщить об ошибке';

  @override
  String get settingsContactSupportPlaceholder =>
      'Заглушка: связаться с поддержкой';

  @override
  String get settingsSendFeedbackPlaceholder => 'Заглушка: отправить отзыв';

  @override
  String get settingsAboutDebugTitle => 'О приложении / отладка';

  @override
  String get settingsAboutDebugSubtitle => 'Диагностика прототипа';

  @override
  String get settingsBackendMode => 'Режим backend';

  @override
  String get settingsSecurityNote => 'Заметка о безопасности';

  @override
  String get settingsSecurityNoteValue =>
      'В Flutter нет серверных секретов или ключа OpenAI.';

  @override
  String get comingLater => 'Будет позже';

  @override
  String get authWelcomeBackTitle => 'С возвращением';

  @override
  String get authWelcomeBackSubtitle =>
      'Превращайте учебные материалы в сфокусированные занятия.';

  @override
  String get authCreateAccountTitle => 'Создать аккаунт';

  @override
  String get authCreateAccountSubtitle => 'Настройте свой учебный профиль.';

  @override
  String get authLogIn => 'Войти';

  @override
  String get authForgotPassword => 'Забыли пароль?';

  @override
  String get authContinueWithEmail => 'Продолжить с эл. почтой';

  @override
  String get authGoogleComingLater => 'Google будет позже';

  @override
  String get authAppleComingLater => 'Apple будет позже';

  @override
  String get authConfirmPassword => 'Подтвердите пароль';

  @override
  String get authAlreadyHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get authPreparingStudySpace => 'Готовим ваше учебное пространство';

  @override
  String authResetNotice(String email) {
    return 'Если аккаунт для $email существует, письмо для сброса пароля уже отправляется.';
  }

  @override
  String get authCheckEmailNotice =>
      'Подтвердите аккаунт по электронной почте, затем войдите.';

  @override
  String get homeSubtitle => 'Спокойное место для учебы';

  @override
  String get homeRecentMaterials => 'Недавние материалы';

  @override
  String get homeViewSubjects => 'Открыть предметы';

  @override
  String get homeNoMaterialsTitle => 'Материалов пока нет';

  @override
  String get homeNoMaterialsMessage =>
      'Откройте предмет и добавьте первый учебный материал.';

  @override
  String get homeYourSubjects => 'Ваши предметы';

  @override
  String get homeCreateFirstSubject => 'Создайте первый предмет';

  @override
  String get homeCreateFirstSubjectMessage =>
      'Предметы объединяют материалы и учебные инструменты.';

  @override
  String get homeStudyWorkspace => 'Учебное пространство';

  @override
  String get homeHeroTitle => 'Готовы к следующему шагу в учебе?';

  @override
  String get homeHeroWithMaterials =>
      'Продолжите с недавним материалом или выберите учебное действие.';

  @override
  String get homeHeroWithoutMaterials =>
      'Добавьте учебный материал к предмету, а затем создавайте конспекты, карточки и тесты.';

  @override
  String get homeCreateSubject => 'Создать предмет';

  @override
  String get homeOpenSubjects => 'Открыть предметы';

  @override
  String get homeAfterLecture => 'После лекции';

  @override
  String get homeLatestProgress => 'Последний прогресс';

  @override
  String get homeNoQuizAttemptsTitle => 'Попыток теста пока нет';

  @override
  String get homeNoQuizAttemptsMessage =>
      'Завершите тест, чтобы увидеть последний результат.';

  @override
  String homeCorrectCount(int correct, int total) {
    return '$correct из $total правильно';
  }

  @override
  String get homeFocusTopics => 'Темы для повторения';

  @override
  String get homeFocusTopicsEmpty =>
      'Проходите тесты, чтобы увидеть темы для повторения.';

  @override
  String homeMissesWithSubject(String subject, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ошибки',
      many: '$count ошибок',
      few: '$count ошибки',
      one: '1 ошибка',
    );
    return '$subject · $_temp0';
  }

  @override
  String get homeQuickActions => 'Быстрые действия';

  @override
  String get homePrepareForExam => 'Подготовиться к экзамену';

  @override
  String get homeContinueStudying => 'Продолжить учебу';

  @override
  String get subjectsTitle => 'Предметы';

  @override
  String get subjectsSubtitle => 'Учебное пространство';

  @override
  String get subjectsLoading => 'Загрузка синхронизированных предметов';

  @override
  String get subjectsShowingAvailable => 'Показаны предметы, доступные сейчас.';

  @override
  String get subjectsNoSubjectsTitle => 'Предметов пока нет';

  @override
  String get subjectsNoSubjectsMessage =>
      'Создайте предмет, чтобы объединять материалы, конспекты, карточки и тесты.';

  @override
  String get subjectsCreateSubject => 'Создать предмет';

  @override
  String get subjectsCreatingSubject => 'Создание предмета';

  @override
  String get subjectsHeaderTitle => 'Ваши предметы';

  @override
  String get subjectsHeaderMessage =>
      'Создавайте отдельные пространства для конспектов, резюме, тестов и подготовки к экзаменам.';

  @override
  String get subjectsNoDescription => 'Описание пока не добавлено';

  @override
  String get subjectsExamPrep => 'Подготовка к экзамену';

  @override
  String subjectsOpenSubject(String subject) {
    return 'Открыть $subject';
  }

  @override
  String get subjectsCreateDialogTitle => 'Создать предмет';

  @override
  String get subjectsNameLabel => 'Название предмета';

  @override
  String get subjectsNameHint => 'Биология, математика, история...';

  @override
  String get subjectsDescriptionLabel => 'Описание';

  @override
  String get subjectsColor => 'Цвет';

  @override
  String get colorBlue => 'Синий';

  @override
  String get colorGreen => 'Зелёный';

  @override
  String get colorPink => 'Розовый';

  @override
  String get colorAmber => 'Янтарный';

  @override
  String subjectsColorSemantics(String color) {
    return 'Цвет предмета: $color';
  }

  @override
  String get subjectsDefaultDescription =>
      'Учебные материалы и практика для этого предмета.';

  @override
  String materialsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count материала',
      many: '$count материалов',
      few: '$count материала',
      one: '1 материал',
      zero: '0 материалов',
    );
    return '$_temp0';
  }

  @override
  String subjectItemsInSubject(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента в этом предмете',
      many: '$count элементов в этом предмете',
      few: '$count элемента в этом предмете',
      one: '1 элемент в этом предмете',
      zero: '0 элементов в этом предмете',
    );
    return '$_temp0';
  }

  @override
  String summariesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count конспекта',
      many: '$count конспектов',
      few: '$count конспекта',
      one: '1 конспект',
      zero: '0 конспектов',
    );
    return '$_temp0';
  }

  @override
  String get subjectWorkspaceSubtitle => 'Рабочее пространство предмета';

  @override
  String get subjectMaterials => 'Материалы';

  @override
  String get subjectSummaries => 'Конспекты';

  @override
  String get subjectSummariesSubtitle =>
      'Объяснения, созданные из ваших материалов';

  @override
  String get subjectStudyActions => 'Учебные действия';

  @override
  String get subjectStudyActionsSubtitle =>
      'Создавайте на основе заметок этого предмета';

  @override
  String get subjectAddPastedText => 'Добавить вставленный текст';

  @override
  String get subjectCreateStudySession => 'Создать занятие';

  @override
  String get subjectAddMaterialForSession =>
      'Добавьте материал, чтобы создать занятие.';

  @override
  String get subjectUploadMaterials => 'Загрузить материалы';

  @override
  String get subjectUploadMaterialsSubtitle => 'Личные PDF и изображения';

  @override
  String get subjectUploadPdf => 'Загрузить PDF';

  @override
  String get subjectUploadImage => 'Загрузить изображение';

  @override
  String get subjectFocusTopicsSubtitle => 'Накопленные ошибки из тестов';

  @override
  String missesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ошибки',
      many: '$count ошибок',
      few: '$count ошибки',
      one: '1 ошибка',
    );
    return '$_temp0';
  }

  @override
  String get subjectLoadingMaterials =>
      'Загрузка синхронизированных материалов';

  @override
  String get subjectStillUsable => 'Этим предметом всё ещё можно пользоваться.';

  @override
  String get subjectNoMaterialsTitle => 'Материалов пока нет';

  @override
  String get subjectNoMaterialsMessage =>
      'Вставьте текст или загрузите файл, чтобы начать учебу.';

  @override
  String get subjectNoSummariesTitle => 'Конспектов пока нет';

  @override
  String get subjectNoSummariesMessage =>
      'Создайте конспект из материала, и он появится здесь.';

  @override
  String get subjectFavoriteMaterialTooltip => 'Добавить материал в избранное';

  @override
  String get subjectUnfavoriteMaterialTooltip =>
      'Убрать материал из избранного';

  @override
  String get materialAddTitle => 'Добавить вставленный текст';

  @override
  String get materialAddIntro =>
      'Вставьте заметки, расшифровки или фрагменты учебника. Сохраняйте язык исходного материала.';

  @override
  String get materialTitleLabel => 'Название материала';

  @override
  String get materialPasteTextLabel => 'Вставьте текст лекции';

  @override
  String get materialPastedTextKind => 'Вставленный текст';

  @override
  String get materialUploadedStatus => 'Загружено';

  @override
  String get materialWaitingForProcessing => 'Ожидает обработки';

  @override
  String get materialUnknownSize => 'Размер неизвестен';

  @override
  String get materialSaveMaterial => 'Сохранить материал';

  @override
  String get materialSavingMaterial => 'Сохранение материала';

  @override
  String get materialSaved => 'Материал сохранен.';

  @override
  String get materialUploaded => 'Материал загружен.';

  @override
  String get uploadPdfTitle => 'Загрузить PDF';

  @override
  String get uploadImageTitle => 'Загрузить изображение';

  @override
  String get uploadPdfGuidance => 'PDF-файлы до 10 МиБ.';

  @override
  String get uploadImageGuidance =>
      'Изображения PNG, JPG, JPEG или WEBP до 8 МиБ.';

  @override
  String get uploadChoosePdf => 'Выбрать PDF';

  @override
  String get uploadChooseImage => 'Выбрать изображение';

  @override
  String get uploadPdfKind => 'PDF';

  @override
  String get uploadImageKind => 'Изображение';

  @override
  String get uploadMaterial => 'Загрузить материал';

  @override
  String get uploadingMaterial => 'Загрузка материала';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesSubtitle => 'Учите только избранное';

  @override
  String get favoritesMaterials => 'Материалы';

  @override
  String get favoritesFlashcards => 'Карточки';

  @override
  String get favoritesLoading => 'Загрузка синхронизированного избранного';

  @override
  String get favoritesStillUsable => 'Приложением все еще можно пользоваться.';

  @override
  String get favoritesNoFavoritesTitle => 'Избранного пока нет';

  @override
  String get favoritesNoFavoritesMessage =>
      'Добавляйте материалы или карточки в избранное, чтобы находить их здесь.';

  @override
  String get favoritesUnfavorite => 'Убрать из избранного';

  @override
  String get favoritesUnfavoriteMaterial => 'Убрать материал из избранного';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get searchFieldLabel => 'Искать в учебном пространстве';

  @override
  String get searchClear => 'Очистить поиск';

  @override
  String get searchStartTitle => 'Начните вводить запрос';

  @override
  String get searchStartMessage =>
      'Ищите предметы, материалы, конспекты и карточки.';

  @override
  String get searchNoResultsTitle => 'Ничего не найдено';

  @override
  String get searchNoResultsMessage =>
      'Попробуйте другое слово или добавьте больше учебных материалов.';

  @override
  String searchSubjectsGroup(int count) {
    return 'Предметы ($count)';
  }

  @override
  String searchMaterialsGroup(int count) {
    return 'Материалы ($count)';
  }

  @override
  String searchFlashcardsGroup(int count) {
    return 'Карточки ($count)';
  }

  @override
  String get usageTitle => 'Использование';

  @override
  String get usageUnavailableTitle =>
      'Отслеживание использования пока не подключено';

  @override
  String get usageUnavailableMessage =>
      'Этот прототип не показывает токены, квоты или данные об оплате.';

  @override
  String get materialDetailTitle => 'Материал';

  @override
  String get materialDeletingTitle => 'Удаление материала';

  @override
  String get materialDeletingMessage =>
      'Удаляем источник и учебный контент, связанный с этим материалом.';

  @override
  String get materialGeneratingStudyContentTitle =>
      'Создание учебного контента';

  @override
  String get materialGeneratingStudyContentMessage =>
      'Создаём учебный контент для этого материала…';

  @override
  String get materialPartialResultTitle => 'Частичный результат';

  @override
  String get materialPartialScannedMessage =>
      'Некоторые страницы не удалось прочитать. Доступный учебный текст всё равно можно использовать.';

  @override
  String get materialFileMetadataTitle => 'Метаданные файла';

  @override
  String get materialFilenameLabel => 'Имя файла';

  @override
  String get materialTypeLabel => 'Тип';

  @override
  String get materialSizeLabel => 'Размер';

  @override
  String get materialMimeLabel => 'MIME';

  @override
  String get materialStatusLabel => 'Статус';

  @override
  String get materialCreatedLabel => 'Создано';

  @override
  String get materialSummaryTitle => 'Резюме';

  @override
  String get materialFlashcardsTitle => 'Карточки';

  @override
  String get materialQuizTitle => 'Тест';

  @override
  String get materialStudySessionTitle => 'Занятие';

  @override
  String get materialDeleteDialogTitle => 'Удалить материал?';

  @override
  String get materialDeleteMaterial => 'Удалить материал';

  @override
  String get materialDeleted => 'Материал удалён.';

  @override
  String get materialDeleteRemoved => 'Будет удалено:';

  @override
  String get materialDeletePreserved => 'Сохранится:';

  @override
  String get materialDeleteSourceMaterial => 'Исходный материал';

  @override
  String get materialDeleteUploadedFile => 'Загруженный файл, если он есть';

  @override
  String get materialDeleteSummary => 'Резюме';

  @override
  String get materialDeleteFlashcards => 'Карточки этого материала';

  @override
  String get materialDeleteQuizzes => 'Тесты этого материала';

  @override
  String get materialDeleteQuizResults => 'Завершённые результаты тестов';

  @override
  String get materialDeleteProgressHistory => 'История прогресса';

  @override
  String get materialDeleteWeakTopics => 'Накопленные слабые темы';

  @override
  String get materialDeleteStudyHistory => 'История занятий';

  @override
  String get materialTextExtracted => 'Текст извлечён';

  @override
  String get materialTextExtractedWithOcr => 'Текст извлечён через OCR';

  @override
  String materialPagesProgress(int processed, int total) {
    return '$processed/$total стр.';
  }

  @override
  String materialPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count страницы',
      many: '$count страниц',
      few: '$count страницы',
      one: '1 страница',
    );
    return '$_temp0';
  }

  @override
  String get materialProcessingStatus => 'Обработка';

  @override
  String get materialFailedStatus => 'Ошибка';

  @override
  String get materialProcessingTitle => 'Материал обрабатывается';

  @override
  String get materialStuckTitle => 'Похоже, обработка зависла';

  @override
  String get materialStuckMessage =>
      'Сбросьте этот материал и попробуйте обработать его снова.';

  @override
  String get materialResetTryAgain => 'Сбросить и повторить';

  @override
  String get imageExtractionFailedTitle =>
      'Не удалось извлечь текст изображения';

  @override
  String get imageExtractionTitle => 'Извлечение текста изображения';

  @override
  String get imageReadingText => 'Читаем текст изображения…';

  @override
  String get imageExtractHelper =>
      'Извлеките читаемый учебный текст из этого изображения.';

  @override
  String get imageRetryExtraction => 'Повторить извлечение текста изображения';

  @override
  String get imageExtractText => 'Извлечь текст из изображения';

  @override
  String get pdfSomePagesNeedOcr => 'Некоторым страницам нужен OCR';

  @override
  String get pdfNoSelectableText => 'Пригодный выделяемый текст не найден';

  @override
  String get pdfReadingScannedPages => 'Читаем сканированные страницы PDF…';

  @override
  String pdfRequiresOcrCount(int candidateCount, int pageCount) {
    return '$candidateCount из $pageCount страниц требуют OCR.';
  }

  @override
  String get pdfRequiresOcrMessage =>
      'Этому PDF нужен OCR, прежде чем учебные инструменты станут доступны.';

  @override
  String get pdfScanWithOcr => 'Сканировать PDF через OCR';

  @override
  String get pdfTextExtractionFailedTitle => 'Не удалось извлечь текст';

  @override
  String get pdfTextExtractionTitle => 'Извлечение текста PDF';

  @override
  String get pdfExtractingSelectable => 'Извлекаем выделяемый текст…';

  @override
  String get pdfCouldNotExtract =>
      'Не удалось извлечь текст. Попробуйте снова.';

  @override
  String get pdfExtractHelper => 'Извлеките выделяемый текст из этого PDF.';

  @override
  String get pdfRetryTextExtraction => 'Повторить извлечение текста';

  @override
  String get pdfExtractText => 'Извлечь текст';

  @override
  String get pdfScanDialogTitle => 'Сканировать PDF через OCR?';

  @override
  String pdfScanDialogMessage(int pageCount, int candidateCount) {
    return 'В этом PDF $pageCount страниц. $candidateCount страниц требуют OCR.\n\nЭта версия поддерживает до 10 страниц всего. ИИ-OCR может занять больше времени и использует платную обработку.';
  }

  @override
  String get pdfStartOcr => 'Запустить OCR';

  @override
  String get summaryNoSummary => 'Резюме пока нет.';

  @override
  String get summaryRegenerate => 'Создать резюме заново';

  @override
  String get summaryWithAi => 'Сделать резюме с ИИ';

  @override
  String get summaryGenerateMock => 'Создать тестовое резюме';

  @override
  String get summaryGenerating => 'Создание резюме';

  @override
  String flashcardsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки готовы.',
      many: '$count карточек готовы.',
      few: '$count карточки готовы.',
      one: '1 карточка готова.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsNoFlashcards => 'Карточек пока нет.';

  @override
  String get flashcardsTooShort =>
      'Добавьте больше текста лекции перед созданием карточек.';

  @override
  String get flashcardsStartTraining => 'Начать тренировку';

  @override
  String get flashcardsReviewThese => 'Посмотреть эти карточки';

  @override
  String get flashcardsGenerate => 'Создать карточки';

  @override
  String get flashcardsGenerating => 'Создание карточек';

  @override
  String get flashcardsNoNewGenerated =>
      'Новые уникальные карточки не были созданы.';

  @override
  String flashcardsNewGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Созданы $count новые карточки.',
      many: 'Создано $count новых карточек.',
      few: 'Созданы $count новые карточки.',
      one: 'Создана 1 новая карточка.',
    );
    return '$_temp0';
  }

  @override
  String quizQuestionsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса готовы.',
      many: '$count вопросов готовы.',
      few: '$count вопроса готовы.',
      one: '1 вопрос готов.',
    );
    return '$_temp0';
  }

  @override
  String get quizNoQuiz => 'Теста пока нет.';

  @override
  String get quizTakeQuiz => 'Пройти тест';

  @override
  String get quizGenerate => 'Создать тест';

  @override
  String get quizGenerateMock => 'Создать тестовый тест';

  @override
  String get quizGenerating => 'Создание теста';

  @override
  String get genericLocalizedError =>
      'Что-то пошло не так. Попробуйте еще раз.';

  @override
  String get errorEnterName => 'Введите имя.';

  @override
  String get errorEnterValidEmail => 'Введите действительный адрес эл. почты.';

  @override
  String get errorPasswordTooShort =>
      'Пароль должен содержать минимум 6 символов.';

  @override
  String get errorConfirmPassword => 'Подтвердите пароль.';

  @override
  String get errorPasswordsDoNotMatch => 'Пароли не совпадают.';

  @override
  String get errorLoginToEditProfile => 'Войдите, чтобы редактировать профиль.';

  @override
  String get errorAccountAlreadyExists =>
      'Аккаунт для этой эл. почты уже существует. Попробуйте войти.';

  @override
  String get errorCouldNotUpdateProfile =>
      'Не удалось обновить профиль аккаунта.';

  @override
  String get errorCouldNotLogOut => 'Не удалось выйти.';

  @override
  String get errorCouldNotSyncSubjects =>
      'Не удалось синхронизировать предметы. Попробуйте еще раз.';

  @override
  String get errorEnterSubjectName => 'Введите название предмета.';

  @override
  String get errorLoginToSyncSubjects =>
      'Войдите, чтобы синхронизировать предметы.';

  @override
  String get errorCouldNotSyncMaterials =>
      'Не удалось синхронизировать материалы. Попробуйте еще раз.';

  @override
  String get errorEnterTitleAndText => 'Введите название и вставленный текст.';

  @override
  String get errorLoginToSyncMaterials =>
      'Войдите, чтобы синхронизировать материалы.';

  @override
  String get errorChoosePdfOrImage =>
      'Выберите PDF или изображение для загрузки.';

  @override
  String get errorLoginToUploadMaterials =>
      'Войдите, чтобы загружать материалы.';

  @override
  String get errorCouldNotUploadFile => 'Не удалось загрузить выбранный файл.';

  @override
  String get errorUnsupportedFile =>
      'Выберите поддерживаемый файл PDF, PNG, JPG, JPEG или WEBP.';

  @override
  String get errorEmptyFile => 'Выбранный файл пуст.';

  @override
  String get errorFileTypeMismatch =>
      'Содержимое файла не соответствует выбранному типу.';

  @override
  String get errorCouldNotOpenFilePicker => 'Не удалось открыть выбор файла.';

  @override
  String get errorMaterialUnavailable => 'Материал недоступен.';

  @override
  String get errorCouldNotUpdateFavorite => 'Не удалось обновить избранное.';

  @override
  String get errorCouldNotSyncFavorites =>
      'Не удалось синхронизировать избранное. Попробуйте еще раз.';

  @override
  String get errorCouldNotDeleteMaterial =>
      'Не удалось удалить материал. Попробуйте еще раз.';

  @override
  String get errorLoginToDeleteMaterial =>
      'Войдите, чтобы удалить этот материал.';

  @override
  String get errorCouldNotResetProcessing => 'Не удалось сбросить обработку.';

  @override
  String get errorPdfCannotBeExtracted => 'Из этого PDF нельзя извлечь текст.';

  @override
  String get errorLoginToExtractPdf => 'Войдите, чтобы извлечь текст PDF.';

  @override
  String get errorCouldNotExtractText =>
      'Не удалось извлечь текст. Попробуйте еще раз.';

  @override
  String get errorImageCannotBeProcessed =>
      'Это изображение нельзя обработать.';

  @override
  String get errorLoginToExtractImage =>
      'Войдите, чтобы извлечь текст изображения.';

  @override
  String get errorCouldNotExtractImageText =>
      'Не удалось извлечь текст изображения. Попробуйте еще раз.';

  @override
  String get errorPdfCannotBeScanned => 'Этот PDF нельзя просканировать с OCR.';

  @override
  String get errorLoginToScanPdf => 'Войдите, чтобы просканировать этот PDF.';

  @override
  String get errorCouldNotScanPdf =>
      'Не удалось просканировать PDF. Попробуйте еще раз.';

  @override
  String get errorPdfOcrPageLimit =>
      'Эта версия может сканировать PDF до 10 страниц. Разделите PDF и загрузите файл меньшего размера.';

  @override
  String get errorNoSelectablePdfText =>
      'Выделяемый текст не найден. Сканированные PDF будут поддержаны на этапе OCR.';

  @override
  String get errorNoReadableImageText =>
      'В этом изображении не найден читаемый текст.';

  @override
  String get errorInvalidPdf =>
      'Загруженный файл не является действительным PDF.';

  @override
  String get errorCouldNotReadPdf => 'Не удалось прочитать загруженный PDF.';

  @override
  String get errorCouldNotReadImage =>
      'Не удалось прочитать загруженное изображение.';

  @override
  String get errorInvalidImage =>
      'Загруженный файл не является поддерживаемым изображением.';

  @override
  String get errorCouldNotGenerateSummary =>
      'Не удалось создать конспект. Попробуйте еще раз.';

  @override
  String get errorAddMoreLectureText =>
      'Добавьте больше текста лекции перед созданием конспекта.';

  @override
  String get errorCouldNotGenerateFlashcards =>
      'Не удалось создать карточки. Попробуйте еще раз.';

  @override
  String get errorCouldNotGenerateQuiz =>
      'Не удалось создать тест. Попробуйте еще раз.';

  @override
  String studyCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return '$_temp0';
  }

  @override
  String studyQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса',
      many: '$count вопросов',
      few: '$count вопроса',
      one: '$count вопрос',
    );
    return '$_temp0';
  }

  @override
  String studyAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count попытки',
      many: '$count попыток',
      few: '$count попытки',
      one: '$count попытка',
    );
    return '$_temp0';
  }

  @override
  String studyMisses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ошибки',
      many: '$count ошибок',
      few: '$count ошибки',
      one: '$count ошибка',
    );
    return '$_temp0';
  }

  @override
  String get studyProgress => 'Прогресс обучения';

  @override
  String studyProgressValue(int current, int total) {
    return '$current из $total';
  }

  @override
  String get studyQuestion => 'Вопрос';

  @override
  String get studyAnswer => 'Ответ';

  @override
  String get studyShowAnswer => 'Показать ответ';

  @override
  String get studyHideAnswer => 'Скрыть ответ';

  @override
  String get studyFlashcardQuestionSemantics =>
      'Вопрос на карточке. Активируйте, чтобы показать ответ.';

  @override
  String get studyFlashcardAnswerSemantics =>
      'Ответ на карточке. Активируйте, чтобы скрыть ответ.';

  @override
  String get studyMissedAction => 'Не знал';

  @override
  String get studyKnownAction => 'Знал';

  @override
  String get studyCorrect => 'Верно';

  @override
  String get studyIncorrect => 'Неверно';

  @override
  String studyCorrectAnswer(String answer) {
    return 'Правильный ответ: $answer';
  }

  @override
  String studyChoiceCorrectSemantics(String choice) {
    return '$choice, правильный ответ';
  }

  @override
  String studyChoiceIncorrectSemantics(String choice) {
    return '$choice, неправильный ответ';
  }

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonReturn => 'Назад';

  @override
  String get commonNext => 'Далее';

  @override
  String get commonCustom => 'Другое';

  @override
  String get commonPrototype => 'Прототип';

  @override
  String get commonGenerate => 'Создать';

  @override
  String get flashcardsTitle => 'Карточки';

  @override
  String flashcardsAllTitle(Object subject) {
    return 'Все карточки — $subject';
  }

  @override
  String flashcardsMaterialTitle(Object material) {
    return 'Карточки — $material';
  }

  @override
  String flashcardsScopeMaterial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки из этого материала',
      many: '$count карточек из этого материала',
      few: '$count карточки из этого материала',
      one: '$count карточка из этого материала',
    );
    return '$_temp0';
  }

  @override
  String flashcardsScopeSubject(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки по этому предмету',
      many: '$count карточек по этому предмету',
      few: '$count карточки по этому предмету',
      one: '$count карточка по этому предмету',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsSessionSize => 'Размер занятия';

  @override
  String flashcardsAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Для этого выбора доступны $count карточки.',
      many: 'Для этого выбора доступно $count карточек.',
      few: 'Для этого выбора доступны $count карточки.',
      one: 'Для этого выбора доступна $count карточка.',
    );
    return '$_temp0';
  }

  @override
  String get flashcardsGenerateMoreGuidance =>
      'Создайте дополнительные карточки из материала, чтобы открыть занятия большего размера.';

  @override
  String get flashcardsLoading => 'Загрузка синхронизированных карточек';

  @override
  String get flashcardsEmptyTitle => 'Карточек пока нет';

  @override
  String get flashcardsEmptyMessage =>
      'Добавьте или создайте карточки, чтобы начать повторение.';

  @override
  String get flashcardsEmptyCloudMessage =>
      'Создайте их из материала со вставленным текстом.';

  @override
  String get flashcardsReviewFocus => 'Фокус повторения';

  @override
  String get flashcardsFilterSemantics => 'Фильтр карточек';

  @override
  String get flashcardsFilterAll => 'Все';

  @override
  String get flashcardsFilterWeak => 'Для повторения';

  @override
  String get flashcardsFilterDue => 'По расписанию';

  @override
  String flashcardsStartTrainingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return 'Начать тренировку ($_temp0)';
  }

  @override
  String get flashcardsTrainWeak => 'Тренировать карточки для повторения';

  @override
  String get flashcardsReviewDue => 'Повторить карточки по расписанию';

  @override
  String get flashcardsNoWeak =>
      'Сейчас нет карточек для дополнительного повторения.';

  @override
  String get flashcardsNoDue => 'Сейчас нет карточек по расписанию.';

  @override
  String get flashcardsCustomSessionTitle => 'Другой размер занятия';

  @override
  String get flashcardsCardsField => 'Карточки';

  @override
  String flashcardsMaximum(Object count) {
    return 'Максимум: $count';
  }

  @override
  String get flashcardsChooseAtLeastOne => 'Выберите хотя бы 1 карточку.';

  @override
  String flashcardsOnlyAvailable(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'доступны только $count карточки',
      many: 'доступно только $count карточек',
      few: 'доступны только $count карточки',
      one: 'доступна только $count карточка',
    );
    return 'Для этого выбора $_temp0.';
  }

  @override
  String flashcardsTopicDifficulty(String topic, String difficulty) {
    return 'Тема: $topic · $difficulty';
  }

  @override
  String flashcardsReviewStats(Object known, Object missed) {
    return 'Знал: $known · Не знал: $missed';
  }

  @override
  String get flashcardGenerationTitle => 'Создать новые карточки';

  @override
  String get flashcardGenerationGuidance =>
      'Выберите, сколько новых карточек добавить.';

  @override
  String flashcardGenerationCurrent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return 'Сейчас: $_temp0';
  }

  @override
  String flashcardGenerationAdd(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточку',
    );
    return 'Добавить: $_temp0';
  }

  @override
  String flashcardGenerationProjected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '$count карточка',
    );
    return 'Будет всего: $_temp0';
  }

  @override
  String get flashcardGenerationNewField => 'Новые карточки';

  @override
  String get flashcardGenerationRangeError =>
      'Выберите от 1 до 30 новых карточек.';

  @override
  String get flashcardGenerationMaxError => 'Выберите не более 30 карточек.';

  @override
  String get trainingTitle => 'Тренировка карточек';

  @override
  String get trainingEmptyTitle => 'Нет карточек для тренировки';

  @override
  String get trainingEmptyMessage => 'Сначала создайте карточки.';

  @override
  String get trainingProgress => 'Прогресс по карточкам';

  @override
  String get trainingComplete => 'Тренировка завершена';

  @override
  String trainingReviewed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Повторены $count карточки',
      many: 'Повторено $count карточек',
      few: 'Повторены $count карточки',
      one: 'Повторена $count карточка',
    );
    return '$_temp0';
  }

  @override
  String trainingKnown(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Знакомы $count карточки',
      many: 'Знакомо $count карточек',
      few: 'Знакомы $count карточки',
      one: 'Знакома $count карточка',
    );
    return '$_temp0';
  }

  @override
  String trainingMissed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Неизвестны $count карточки',
      many: 'Неизвестно $count карточек',
      few: 'Неизвестны $count карточки',
      one: 'Неизвестна $count карточка',
    );
    return '$_temp0';
  }

  @override
  String get trainingReviewMissed => 'Повторить незнакомые карточки';

  @override
  String get trainingReviewAgain => 'Повторить снова';

  @override
  String get errorCouldNotSaveReview =>
      'Не удалось сохранить прогресс повторения.';

  @override
  String get quizUiTitle => 'Тест';

  @override
  String get quizEmptyTitle => 'Нет доступных вопросов';

  @override
  String get quizEmptyMessage =>
      'Вернитесь к материалу и сначала создайте тест.';

  @override
  String get quizProgress => 'Прогресс теста';

  @override
  String get quizShowScore => 'Показать результат';

  @override
  String get quizMissedReview => 'Повторение вопросов с ошибками';

  @override
  String get quizFinishReview => 'Завершить повторение';

  @override
  String get quizResult => 'Результат';

  @override
  String quizScore(Object percent) {
    return 'Результат: $percent%';
  }

  @override
  String quizCorrectCount(num correct, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct правильного ответа из $total',
      many: '$correct правильных ответов из $total',
      few: '$correct правильных ответа из $total',
      one: '$correct правильный ответ из $total',
    );
    return '$_temp0';
  }

  @override
  String get quizMissedTopics => 'Темы для повторения';

  @override
  String get quizNoMissedTopics => 'Нет тем для повторения. Отличная работа!';

  @override
  String get quizSaving => 'Сохранение попытки…';

  @override
  String get quizUnsyncedWarning =>
      'Этот результат рассчитан локально и не синхронизирован.';

  @override
  String get quizReviewMissed => 'Повторить вопросы с ошибками';

  @override
  String get quizReviewMaterial => 'Повторить материал';

  @override
  String get quizRetry => 'Пройти тест снова';

  @override
  String get errorCouldNotSaveQuizAttempt =>
      'Не удалось сохранить эту попытку.';

  @override
  String get progressLatestQuiz => 'Последний тест';

  @override
  String get progressAttemptsCompleted => 'Завершённые попытки';

  @override
  String get progressFocusTopics => 'Темы для повторения';

  @override
  String get progressHistoryExplanation =>
      'Общее число ошибок в завершённых тестах.';

  @override
  String get progressNoAttempts =>
      'Пройдите тест, чтобы увидеть здесь результаты.';

  @override
  String get progressLoading => 'Загрузка прогресса';

  @override
  String get progressEmptyTitle => 'Попыток пока нет';

  @override
  String get progressEmptyMessage =>
      'Пройдите тест, чтобы начать историю прогресса.';

  @override
  String get afterLectureTitle => 'После лекции';

  @override
  String get examPrepTitle => 'Подготовка к экзамену';

  @override
  String get continueStudyingTitle => 'Продолжить обучение';

  @override
  String get aiTeacherTitle => 'ИИ-преподаватель';

  @override
  String get studySessionTitle => 'Занятие';

  @override
  String get studyLocalPrototype => 'Локальный прототип';

  @override
  String get studyLocalMockCoaching => 'Локальная тестовая помощь';

  @override
  String get studyChooseSubject => 'Выберите предмет';

  @override
  String get studyChooseMaterial => 'Выберите материал';

  @override
  String get studyCreateSession => 'Создать занятие';

  @override
  String get studyNoSubjectsTitle => 'Предметов пока нет';

  @override
  String get studyOpenSubjects => 'Открыть предметы';

  @override
  String get studyNoMaterialsTitle => 'Материалов пока нет';

  @override
  String get studyContinueSession => 'Продолжить занятие';

  @override
  String get studyNotCompleted => 'Не завершено';

  @override
  String get studyBackToSubject => 'Назад к предмету';

  @override
  String get studyUnavailableTitle => 'Учебный материал недоступен';

  @override
  String get studySessionOverview => 'Обзор занятия';

  @override
  String get studyEstimatedTime => 'Примерное время';

  @override
  String get studySummary => 'Конспект';

  @override
  String get studyFlashcardsAction => 'Карточки';

  @override
  String get studyAiTeacherAction => 'ИИ-преподаватель';

  @override
  String studyMinutes(Object count) {
    return '$count мин';
  }

  @override
  String get studySelectSubject => 'Выберите предмет';

  @override
  String get studySelectSubjectMessage =>
      'Выберите предмет лекции, чтобы продолжить.';

  @override
  String get studyNoMaterialsMessage =>
      'Добавьте подходящий материал перед созданием занятия.';

  @override
  String get afterLecturePrototype => 'Локальные рекомендации прототипа';

  @override
  String get afterLectureNoSubjectsMessage =>
      'Создайте предмет перед началом занятия после лекции.';

  @override
  String get afterLectureConfidence => 'Насколько уверенно вы себя чувствуете?';

  @override
  String get afterLectureSchedule => 'План занятия в прототипе';

  @override
  String get afterLectureScheduleHelp =>
      'Локальная оценка; это время не отслеживается.';

  @override
  String get examPrepPrototype => 'Локальный план-прототип';

  @override
  String get examPrepHeading => 'Подготовка к экзамену';

  @override
  String get examPrepHelp =>
      'Создайте локальный план по предмету, материалам и темам для повторения.';

  @override
  String get examPrepNoSubjectsMessage =>
      'Создайте предмет перед подготовкой плана к экзамену.';

  @override
  String get examPrepDatePreview => 'Предварительная дата экзамена';

  @override
  String get examPrepDateUnavailable =>
      'Выбор даты недоступен в этом прототипе.';

  @override
  String get examPrepDate => 'Дата экзамена';

  @override
  String get examPrepMockDate => 'Примерная дата: через 2 недели';

  @override
  String get examPrepMaterialsPreview => 'Выбранные материалы';

  @override
  String get examPrepMaterialsEmptyHelp =>
      'План всё равно можно начать с выбранного предмета.';

  @override
  String get examPrepIncluded => 'Включено в план';

  @override
  String get examPrepTopicsPreview => 'Темы для повторения';

  @override
  String get examPrepTopicsHelp =>
      'Локальные рекомендации прототипа; это не оценка знаний.';

  @override
  String get examPrepPlanPreview => 'Предварительный план подготовки';

  @override
  String get examPrepPlanHelp => 'Локальные рекомендации прототипа.';

  @override
  String get continueEmptyTitle => 'Нечего продолжать';

  @override
  String get continueEmptyMessage => 'Начните занятие по одному из предметов.';

  @override
  String get continueUnavailableMessage =>
      'Предмет или источник последнего занятия больше недоступен.';

  @override
  String continueFrom(Object material) {
    return 'Продолжить с материалом: $material';
  }

  @override
  String get continueLatest => 'Последнее занятие';

  @override
  String get continueSummary => 'Итоги занятия';

  @override
  String get continueQuickQuiz => 'Короткий тест';

  @override
  String continueLastScore(Object percent) {
    return 'Последний результат: $percent%';
  }

  @override
  String get continueNoTopics => 'Для этого занятия нет тем для повторения.';

  @override
  String get aiTeacherStatus => 'Локальная тестовая помощь · Прототип';

  @override
  String get aiTeacherNoLive =>
      'Готовые локальные ответы; подключения к ИИ нет.';

  @override
  String get aiTeacherHelp =>
      'Выберите стиль помощи. Ответ ниже остаётся локальным и использует тестовый текст.';

  @override
  String get aiTeacherPrompt => 'Запрос преподавателю';

  @override
  String get aiTeacherPromptSimple => 'Объяснить проще';

  @override
  String get aiTeacherPromptExample => 'Привести другой пример';

  @override
  String get aiTeacherPromptQuestion => 'Задать вопрос';

  @override
  String get aiTeacherAnswer => 'Ответ прототипа';

  @override
  String get aiTeacherTryNext => 'Попробуйте дальше';

  @override
  String get aiTeacherAnotherExample => 'Показать другой пример';

  @override
  String get aiTeacherQuizMe => 'Проверить мои знания';

  @override
  String sessionGeneratedFrom(Object material) {
    return 'Создано из материала: $material';
  }

  @override
  String get sessionLocal => 'Локальное занятие';

  @override
  String get sessionNoAnswer => 'Ответ не дан.';

  @override
  String get sessionNoFlashcards => 'В этом занятии нет карточек.';

  @override
  String get sessionQuickQuiz => 'Короткий тест';

  @override
  String get sessionFocusTopics => 'Темы для повторения';

  @override
  String get sessionNoTopics => 'Темы для повторения не записаны.';

  @override
  String get sessionPrototypeExplanation => 'Объяснение прототипа';

  @override
  String get sessionPrototypeHelp =>
      'Локальная тестовая рекомендация; это не ответ ИИ.';

  @override
  String get sessionMoreFlashcards => 'Создать больше карточек';

  @override
  String get sessionAskTeacher => 'Спросить ИИ-преподавателя';
}
