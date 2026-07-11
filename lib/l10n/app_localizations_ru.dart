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
  String get statusLoading => 'Загрузка';

  @override
  String get statusError => 'Ошибка';

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
  String get settingsAppearanceUnavailable => 'Темная тема пока недоступна.';

  @override
  String get settingsUsageUnavailable =>
      'Отслеживание использования не подключено';

  @override
  String get comingLater => 'Будет позже';

  @override
  String get genericLocalizedError =>
      'Что-то пошло не так. Попробуйте еще раз.';
}
