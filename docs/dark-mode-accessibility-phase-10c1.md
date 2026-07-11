# Phase 10C.1: Dark Mode and Accessibility Foundation

## Appearance persistence

Appearance is a local preference independent from locale. Stable values are `system`, `light`, and `dark`; null, invalid, or failed reads fall back to `system`. Changes update `AppState` immediately and are persisted asynchronously. System mode remains `ThemeMode.system`, so platform brightness changes continue to update the app without a restart or stored brightness snapshot.

## Semantic palettes and Liquid Glass

The existing light palette remains the baseline. The dark palette uses a `#0B1220` canvas, `#111B2C` elevated surface, high-contrast cool-white text, light blue primary, teal secondary, warm amber accent, and distinct success, warning, error, and info colors.

Dark glass is a dedicated recipe rather than an inversion. Subtle, standard, and prominent depths use progressively more opaque blue-charcoal surfaces, bright restrained borders, and deep shadows. Reading, form, navigation, and dialog surfaces are near-opaque where readability takes priority. Atmospheric backgrounds use low-intensity indigo, teal, and violet glows; subject colors are clamped before use.

Low-effects mode removes `BackdropFilter` and blends toward a theme-specific opaque tint with a clear border. Reduced motion controls transition duration only and does not disable blur. Blur remains clipped and bounded; there is no row-level or animated blur.

## Accessibility audit and contrast scope

Phase 10C.1 prioritizes root navigation, Settings appearance/language groups, shared glass controls, loading and error states, study progress, flashcard reveal/rating controls, quiz correctness, dialogs, icon tooltips, and the brand mark. Interactive shared controls retain 48 logical-pixel minimum targets and keyboard activation. Focus is visible in both themes, while semantics expose selected, enabled, progress, reveal, and correctness state without relying on color alone.

Deterministic tests cover representative opaque and composited pairs: canvas text, reading glass text, primary controls, status colors, and focus rings. Targets are 4.5:1 for normal text and 3:1 for large text and essential boundaries. These checks are representative design-system safeguards, not a runtime contrast engine.

## Deferred to Phase 10C.2

- Manual assistive-technology passes with TalkBack, VoiceOver, Narrator, and platform high-contrast modes.
- Broader device-specific accessibility behavior and mobile release polish.
- Any product-level navigation or layout redesign.
- Formal third-party accessibility certification.

Phase 10C.1 establishes and tests an accessibility foundation; it does not claim full accessibility certification.
