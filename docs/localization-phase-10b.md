# Phase 10B localization review

Phase 10B supports English, German, and Russian. Locale changes update the open Flutter widget tree immediately and persist through the existing preference mechanism. Phase 10B.4 is a quality audit, not native-speaker certification.

## Terminology decisions

| Product concept | German | Russian |
| --- | --- | --- |
| Subjects | Fächer | Предметы |
| Materials | Materialien | Материалы |
| Favorites | Favoriten | Избранное |
| Progress | Fortschritt | Прогресс |
| Settings | Einstellungen | Настройки |
| Study session | Lerneinheit | Занятие |
| Flashcards | Lernkarten | Карточки |
| Focus/review topics | Themen zum Wiederholen | Темы для повторения |

German review actions consistently use *wiederholen/Wiederholung*. Russian review actions consistently use *повторить/повторение*. Training language remains action-oriented and distinct from generated educational content.

## Formatting and plurals

- Material timestamps are formatted at presentation time from `createdAt`. The compatible legacy `createdLabel` path recognizes only `Just now`, `Today`, `Yesterday`, `Synced`, `Not synced`, and ISO timestamps; unknown text becomes a localized neutral “recently” label.
- Dates, date/times, decimals, percentages, and IEC file sizes use the active locale through `intl`. Stored scores, timestamps, and byte counts are unchanged. IEC symbols remain stable while decimal separators localize.
- Whole ICU phrases cover material, page, summary, miss, card, question, attempt, training, generated-card, and selection counts. Tests exercise 0, 1, 2, 5, and 21. Russian messages use `one`, `few`, `many`, and `other` where Russian morphology requires them.

## Accessibility wording

Tooltips and semantic output use the active localization during `build`, including favorite/remove, delete, reveal/hide, correctness, progress, retry/recovery, and loading/error states. Correct and incorrect answer announcements frame the stored answer without translating it. Product names and source content remain unchanged when the locale switches.

## Intentionally untranslated boundaries

The app does not translate subject names, material titles, user-entered text, OCR/extracted text, summaries, flashcard fronts/backs/topics, quiz questions/options/explanations, weak-topic names/reasons, generated coaching, or generated study-plan sentences. MIME types, file extensions, route names, payload/database keys, enum wire values, storage identifiers, logs, assertions, and test identifiers are technical data rather than UI translations.

## Safe-message mapping

`BuildContext.localizedSafeMessage` is the single bounded mapper. Unknown text always returns `genericLocalizedError`; backend text is never displayed directly.

| Known source family | Localized destination |
| --- | --- |
| Name/email/password validation and password mismatch | Corresponding `error…` ARB validation message |
| Reset notice `If an account exists for …` | Parameterized `authResetNotice` |
| Profile, logout, and authentication requirements | Corresponding profile/authentication ARB error |
| Subject/material/favorite synchronization and validation | Corresponding bounded synchronization ARB error |
| File selection, empty/type mismatch, picker, upload, and `exceeds N KiB/MiB/GiB` | Corresponding file ARB error; size limit remains a parameter |
| Material availability, deletion, and processing reset | Corresponding material lifecycle ARB error |
| PDF/image extraction and OCR safe messages | Corresponding extraction/OCR ARB error |
| Summary, flashcard, quiz generation, review saving, and quiz-attempt saving | Corresponding study-generation ARB error |
| Any other value | `genericLocalizedError` |

The exact accepted literals remain in the single switch/parameter match in `lib/l10n/l10n_extensions.dart`; screens do not duplicate comparisons.

## Heuristic literal audit

The deterministic test scans `lib/app`, `lib/shared`, and `lib/features` for string literals in high-confidence `Text`, `Tooltip`, `tooltip`, `semanticLabel`, `labelText`, `hintText`, `helperText`, and `errorText` contexts. It ignores comments and fails for both a new suspicious literal and a stale allowlist entry. This is conservative heuristic evidence, not mathematical proof or a full Dart parser.

Current result: **5 findings, 5 explicitly allowlisted, 0 unallowlisted, 0 stale**.

| Path/pattern | Category | Reason |
| --- | --- | --- |
| `study_components.dart`: `$current / $total` | Numeric presentation | Locale-neutral progress value; localized semantic label surrounds it |
| `auth_layout.dart`: `AI Study Buddy` | Product name | Intentionally invariant registered product name |
| `flashcards_screen.dart`: `$size` | Numeric presentation | Locale-neutral integer choice |
| `flashcard_generation_dialog.dart`: `$count` | Numeric presentation | Locale-neutral integer choice |
| `material_presentation.dart`: metadata label/value interpolation | Localized composition | Both components are already presentation/localized values |

## Native-speaker review checklist

- Confirm formal/informal voice across authentication, recovery, and destructive actions.
- Review German training actions and the distinction between *Wiederholen* and *Training*.
- Review Russian due/review scheduling and correctness announcements.
- Review OCR/extraction terminology with actual PDF and image contexts.
- Review destructive deletion wording for removed versus preserved study history.
- Review plural phrasing at 0, 1, 2, 5, and 21, including generated-card counts.
- Review semantic labels with VoiceOver/TalkBack in all three locales.

## Remaining limitations

- The literal audit intentionally does not parse arbitrary Dart expressions or prove complete localization.
- Legacy material labels lack an exact timestamp and therefore use bounded relative/neutral fallbacks.
- Mock/generated educational content remains in its stored source language by design.
- German and Russian text is an implementation review draft and has not been certified by native speakers.
