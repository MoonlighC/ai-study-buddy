# AI Study Buddy MVP Roadmap

## Phase 1: Mock App Shell

- Scaffold Flutter for Android, iOS, web, and Windows.
- Replace the counter app with a clean clickable study workspace.
- Add placeholder auth, subjects, pasted materials, generated outputs, study modes, flashcards, favorites, and usage limit screens.
- Keep all data in memory with mock services.

## Phase 2: Local MVP Flows

- Make subject creation and pasted text materials interactive.
- Add local state for generated outputs and flashcard favorites.
- Expand study sessions for all flashcards and favorites-only review.

## Phase 3: Supabase Integration

- Add Supabase Auth with email first.
- Persist subjects, materials, favorites, and generated outputs.
- Add row-level security policies.
- Keep Supabase credentials out of source control.

## Phase 4: Edge Functions And OpenAI

- Add Supabase Edge Functions for summaries, flashcards, quizzes, and exam plans.
- Store OpenAI usage logs with model, tokens, estimated cost, feature, and user ID.
- Enforce daily usage limits before each AI call.

## Deferred

- Image and photo upload.
- PDF upload and extraction.
- Google and Apple sign-in.
- Payments.
- Google Calendar integration.
- App Store or Play Store publishing.
