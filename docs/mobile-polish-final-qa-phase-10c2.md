# Phase 10C.2: Mobile Polish and Final QA

## Baseline

The preflight worktree was clean. `HEAD` and `origin/main` both resolved to
`04c221ca2303d058b5adf2f1636b0480bb17eb9a` (Phase 10C.1). The repository
contained 304 statically declared `test`/`testWidgets` cases. The unmodified
full-suite baseline did not finish within the 600.3-second external runner
allowance and emitted no test failure; this is recorded as a baseline timeout,
not as a pass. The project-wide test timeout was not changed.

## Automated matrix

The audit is representative rather than Cartesian:

| Coverage | Automated cases |
| --- | --- |
| Widths | 320, 360, 390, 599, 600, 800, 1023, 1024, 1280 |
| Text scale | 1.0 across the width matrix; 1.5 at 800/Windows; 2.0 in all mandatory compact cases |
| Locales | en in shell/inset/dialog tests; de and ru in compact worst cases |
| Themes | light in the width, inset, dialog, and structural tests; light and dark for de/ru compact worst cases |
| Mandatory worst cases | 320/de/2.0/light, 320/de/2.0/dark, 320/ru/2.0/light, 320/ru/2.0/dark |
| Live resize | 599 to 600 and 1023 to 1024 in one mounted shell |
| Insets | left 18, top 24, right 22, bottom 28; keyboard bottom inset 240 |
| Effects | normal clipped/bounded blur and low-effects zero-blur structure |

Existing suites continue to cover representative dashboard, Subjects, Subject
Detail, generation dialog, keyboard navigation, selected semantics, and 200%
text behavior.

## Defects reproduced and fixed

- At 200% text on a 320-wide German or Russian phone, five forced single-line
  navigation labels competed for less than one readable label width. The phone
  bar now changes to icon presentation at the demonstrated large-text threshold
  while retaining localized button semantics and tooltip text. Text is not
  reduced below its design size.
- Phone navigation and content padding used fixed horizontal insets without the
  landscape display cutout padding. The responsive shell now adds the left and
  right system padding once to the overlay and default content gutter.
- Dialog maximum height was based on the full display height, so an open keyboard
  could leave actions below the visible region. `GlassDialog` now constrains
  itself to the keyboard-reduced, safe-area-reduced height, uses compact phone
  margins/padding, and provides one shared scroll owner.
- Auth forms already reacted to `viewInsets`, used Next/Done actions, guarded
  duplicate submission, and unfocused before submission. The auth layout now
  dismisses focus when the user taps unused background space.

## Audited with no production change

- The existing 600 and 1024 breakpoints already implement phone bottom
  navigation, compact tablet rail, and extended desktop rail without recreating
  navigator state.
- Top bars already own the status-bar safe area, phone scroll content already
  reserves bottom-navigation plus gesture clearance, and rail placement already
  includes top/left system padding.
- Login and sign-up fields already expose sensible Next/Done actions, 48-pixel
  password visibility controls, scrollable form layout, keyboard bottom padding,
  focus dismissal before async submission, and duplicate-submit guards.
- Long workspace and completion screens use scrollable roots. Material Detail,
  Upload, Flashcards, Training, Quiz, Progress, Settings, After Lecture, Exam
  Prep, AI Teacher, and Study Session Result showed no structural unbounded-height
  or nested-scroll deadlock in code inspection and existing widget coverage.
- Dialog callers already use modal-first Navigator behavior. No failing evidence
  justified broad `PopScope` additions or new confirmation workflows.
- Quiz choices and shared navigation/buttons already expose full-row or minimum
  48-by-48 interaction regions. Icon-only shared actions retain tooltips and
  semantics.
- Processing, retry, stale recovery, save warnings, offline-safe states, and
  localized error hardening retain their existing repository and backend
  semantics. No synchronization copy was changed.

## Insets, keyboard, navigation, and dialogs

The responsive shell owns root display padding and navigation/gesture clearance.
Screens own only workflow spacing. `GlassDialog` owns modal margins, keyboard
avoidance, and modal scrolling. Auth owns form scrolling and background focus
dismissal. Tests assert side and bottom padding numerically to prevent double
application.

The selected route is supplied to a stable shell and remains selected while the
mounted layout crosses 599/600 and 1023/1024. Theme, locale, and text-scale
changes rebuild presentation without changing route contracts. Modal routes
retain Flutter's built-in Android back and desktop Escape dismissal. No
meaningful-state loss or double-pop defect was demonstrated, so no `PopScope`
was added.

## Performance structure

- Every retained `BackdropFilter` in the audited shell is inside a finite
  `ClipRRect`; tests also assert a finite render size.
- Low-effects mode produces zero `BackdropFilter` widgets.
- No row-level or animated blur was found in the audited list structures.
- Atmospheric gradients are static. Reduced motion already removes transition
  duration without incorrectly disabling readability effects.
- No meaningfully large eager collection or repeated parsing/formatting defect
  was demonstrated, so no list or caching architecture was rewritten.
- These are structural/debug observations, not precise release-performance
  measurements.

## Accessibility regression

Automated checks cover localized root-navigation semantics in compact German and
Russian layouts, selected destinations, keyboard rail activation, large text,
minimum shared control sizing, dialog scrolling, and light/dark rendering. The
existing accessibility suite continues to cover contrast, selected/disabled
states, progress, flashcard reveal/rating state, quiz correctness, favorites,
retry/recovery, loading, dialogs, and keyboard focus. The large-text navigation
adaptation preserves one semantic button label per destination and avoids a
duplicate broad semantic wrapper.

This work is not complete accessibility certification and does not certify
physical devices.

## Known limitations and manual checklist

- [ ] Compact Android phone: portrait/landscape, gesture navigation, keyboard,
  system back, TalkBack spot check.
- [ ] Modern iPhone-sized device: portrait/landscape, home indicator, cutout,
  keyboard, VoiceOver spot check.
- [ ] Tablet: rotation, compact rail, split keyboard, 200% text.
- [ ] Desktop: resize through both breakpoints, keyboard-only traversal, Escape,
  mouse hover/focus, Narrator spot check.
- [ ] Repeat sign-in, create subject, paste/upload, processing, summary,
  flashcards, training, quiz, progress, delete/recovery, language, and appearance
  flows in en/de/ru and light/dark.
- [ ] Spot-check low-effects and reduced-motion platform settings on real
  hardware.
- [ ] Validate offline transitions and interrupted processing against a staged
  backend without changing synchronization semantics.

Release engineering still owns signing, store builds, launcher assets,
platform-specific profiling, physical-device certification, and formal
assistive-technology/accessibility review.

## Final verification

- `flutter gen-l10n`: passed. The existing deprecation notice for
  `synthetic-package` in `l10n.yaml` remains unchanged and was not part of this
  phase.
- `flutter analyze`: passed with no issues.
- Complete `flutter test`: 322 tests passed.
- Combined localization generation, analysis, and test duration: 32.974 seconds.
- `git diff --check`: passed.
- Changed-path inspection found no backend, Supabase, migration, native platform,
  dependency, route-contract, repository-interface, or security-fixture changes.
- The Phase 10C.2 worktree remains uncommitted and unpushed.
