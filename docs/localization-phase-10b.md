# Phase 10B Localization Notes

Phase 10B.1 adds the localization foundation for English, German, and Russian.
Phase 10B.2 migrates core workspace and utility UI chrome for Auth, Home, Subjects, Subject Detail, Material Detail, pasted-text entry, PDF/image upload, Favorites, Search, Settings/Profile, and Usage.
Phase 10B.3 migrates Flashcards, Training, Quiz, Progress, After Lecture, Exam Prep, Continue Studying, AI Teacher, Study Session Result, and shared study components.

## 10B.3 study terminology and plurals

German draft terms include **Lernkarten**, **Zum Wiederholen**, **Fällig zur Wiederholung**, **Nicht gewusst**, **Gewusst**, and **Themen zum Wiederholen**. Russian draft terms include **Карточки**, **Для повторения**, **По расписанию**, **Не знал**, **Знал**, **Тест**, and **Темы для повторения**.

Card, question, correct-answer, attempt, miss, review, topic, and session-item counts use ICU messages. Russian messages explicitly provide `one`, `few`, `many`, and `other`; 0, 1, 2, and 5 remain the required review cases.

Native-speaker review candidates include the tone of German training actions, Russian wording for due/review scheduling, prototype disclaimers, and whether AI Teacher should use a more formal product term. Stored card/quiz/session/coaching content and subject, material, and topic names intentionally remain in their source language.

Deferred to 10B.4: repository-wide untranslated-string audit, final consistency review, and native-speaker approval of all German and Russian drafts.

The German and Russian ARB text is a reviewed draft prepared for implementation. It has not been approved by native-speaker review, and no legal, educational, or product-quality claim should be made from the draft translations alone.

Phase 10B.4 should audit uncertain terminology before final localization completion, especially:

- authentication terminology
- study workflow terminology
- errors and destructive actions
- plural messages and placeholders
- any string where context affects the natural German or Russian phrasing

## 10B.2 terminology choices

German draft terms:

- Subjects: Fächer
- Materials: Materialien
- Favorites: Favoriten
- Progress: Fortschritt
- Settings: Einstellungen
- Study session: Lerneinheit
- Focus topics: Themen zum Wiederholen

Russian draft terms:

- Subjects: Предметы
- Materials: Материалы
- Favorites: Избранное
- Progress: Прогресс
- Settings: Настройки
- Study session: Занятие
- Focus topics: Темы для повторения

## Review focus for 10B.4

- Destructive-action wording: material deletion now explains removed and preserved data; confirm tone, legal clarity, and whether “preserved” is the right product term.
- Auth wording: sign-in, reset, provider-placeholder, and validation strings are localized drafts; review for formal/informal voice consistency.
- OCR and extraction statuses: German/Russian strings should be checked by native speakers with product context, especially OCR wording.
- Deferred areas: Flashcards/Training/Quiz/Progress flows beyond shared Material Detail controls, After Lecture, Exam Prep, Continue Studying, AI Teacher, and Session Result remain for 10B.3/10B.4.
- No claim is made that the German or Russian copy is native-speaker-approved.
