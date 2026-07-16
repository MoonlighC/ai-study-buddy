# Supabase Backend Architecture

Phase 5A defines the planned backend architecture for syncing AI Study Buddy across devices. It does not connect the Flutter app to Supabase yet, does not add packages, does not add keys, and does not implement Edge Functions.

## Goals

- Sync study data across devices for authenticated users.
- Preserve the current local mock app while backend support is added incrementally.
- Keep all user-owned data isolated by Supabase Auth user ID and Row Level Security.
- Keep OpenAI calls, model selection, and API keys out of Flutter.
- Enforce daily generation and cost limits server-side.

## Non-Goals For Phase 5A

- No Supabase project setup.
- No Flutter Supabase client.
- No Auth UI implementation.
- No storage bucket creation.
- No Edge Function implementation.
- No OpenAI calls.
- No service role key in the app or repo.

## Client And Backend Boundary

Flutter will eventually use Supabase with:

- Supabase project URL.
- Supabase publishable or anon key.
- The user's authenticated session.

Flutter must never store:

- Supabase service role key.
- `OPENAI_API_KEY`.
- OAuth provider secrets.
- Migration credentials.

All privileged work belongs on the server side. Future OpenAI calls should happen only in Supabase Edge Functions, which can validate the user session, check usage limits, call OpenAI with server-side secrets, and persist generated study data.

## Auth Plan

Initial Auth support:

- Email/password sign up and login.
- Email verification enabled for production.
- Password reset flow.
- Google OAuth login.

Later Auth support:

- Apple login for iOS readiness.

Planned profile behavior:

- Supabase Auth owns identity in `auth.users`.
- `public.profiles` stores app-specific account data.
- `profiles.id` matches `auth.users.id`.
- A future trigger or first-login upsert should create a profile row.
- Apple display names may need to be captured during first sign-in or onboarding because Apple may not return full names later.

## Data Ownership Model

Every user-owned app table should include `user_id uuid not null references auth.users(id)`. RLS policies should require `auth.uid() = user_id` for reads and writes.

The exception is `profiles`, where `id` is the Auth user ID. Profile policies should compare `auth.uid()` with `profiles.id`.

Server-accounted tables such as `usage_logs` and `daily_usage_limits` are readable by the user but should not be directly writable from Flutter. Future Edge Functions or database RPCs should perform quota checks and updates.

## Storage Plan

Storage is planned for later phases only. No buckets are created in Phase 5A.

Planned private buckets:

- `study-materials` for PDFs and text-derived source files.
- `study-images` for photo uploads.
- `generated-assets` only if future generated files need storage.

Planned object paths:

```text
{user_id}/materials/{material_id}/original/{filename}
{user_id}/materials/{material_id}/processed/{filename}
{user_id}/images/{image_id}/original/{filename}
{user_id}/images/{image_id}/processed/{filename}
```

Storage rules:

- Buckets should start private.
- Object paths should begin with the authenticated user's ID.
- Storage RLS should allow users to access only paths under their own ID.
- Downloads should use authenticated access or short-lived signed URLs.
- Uploads should be validated for file size, MIME type, extension, and processing status before AI extraction.

## Edge Function Plan

Future Edge Functions:

- `generate-flashcards`
- `generate-quiz`
- `summarize-material`
- `process-upload`

Each function should:

1. Validate the Supabase Auth JWT.
2. Resolve the authenticated `user_id`.
3. Check and reserve the user's daily quota before calling OpenAI.
4. Fetch only user-owned source rows.
5. Call OpenAI using server-side Edge Function secrets.
6. Store generated rows.
7. Append usage logs.
8. Update daily usage counters.
9. Return typed results and typed limit errors to Flutter.

## Usage Limits

Default daily limits:

- 120 generated flashcards per day.
- 80 generated quiz questions per day.
- 3 uploads per day.
- `$0.25` estimated OpenAI cost per day.

Flutter may display counters, but enforcement should happen server-side only. The planned `daily_usage_limits` table stores per-user, per-day counters and defaults. The planned `usage_logs` table records append-only usage events.

## Migration Strategy From Current AppState

The current app remains local-first during backend work. Supabase should be introduced behind repositories rather than directly into screens.

Suggested repository boundary:

- `StudyRepository`
- `SubjectRepository`
- `MaterialRepository`
- `FlashcardRepository`
- `QuizRepository`
- `FavoriteRepository`
- `UsageRepository`

Suggested implementations:

- `MockStudyRepository` for the current in-memory prototype.
- `SupabaseStudyRepository` for synced data in later phases.

Current model mapping:

- `Subject` maps to `subjects`.
- `StudyMaterial` maps to `materials`.
- `Flashcard` maps to `flashcards`.
- `QuizQuestion` maps to `quiz_questions`, grouped by `quizzes`.
- `StudySession` maps to `study_sessions`, `quiz_attempts`, generated `flashcards`, and `weak_topics`.
- Flashcard `isFavorite` maps to generic `favorites`.
- `WeakTopic` maps to `weak_topics`.
- `UsageLog` maps to `usage_logs`.

## Rollout Phases

### Phase 5A: Docs And SQL Schema Only

- Add architecture docs.
- Add schema plan.
- Add RLS plan.
- Add a planned initial SQL migration.
- Do not change Flutter runtime behavior.

### Phase 5B: Supabase Project Setup

- Create the Supabase project.
- Configure Auth providers and redirect URLs.
- Create private storage buckets.
- Apply reviewed migrations.

### Phase 5C: Flutter Supabase Connection

- Add the Supabase Flutter dependency.
- Add environment configuration for project URL and publishable key.
- Keep mock mode available.

### Phase 5D: Auth

- Implement email/password flows.
- Add Google OAuth.
- Add profile creation and profile sync.
- Add Apple login when preparing iOS release.

### Phase 5E: Sync Subjects, Materials, And Favorites

- Sync subjects.
- Sync material metadata and text content.
- Sync favorites.
- Keep generated AI data local until Edge Functions are ready.

### Phase 5F: Edge Function For AI Generation

- Start with flashcard generation.
- Add server-side usage limit checks.
- Store generated output.
- Add quiz generation and upload processing later.
## Phase B private original-file access

Phase B requires no schema migration, Storage-policy change, or Edge Function.
The Flutter repository resolves the exact owned, non-deleted `materials` row
under existing RLS and validates its source kind and canonical private Storage
metadata. It then performs an authenticated direct byte download from the
existing private bucket. It never creates a public URL or persists a signed URL,
object location, access token, or original byte buffer.

PDF previews are capped at 10 MiB and image previews at 8 MiB. The repository
checks authoritative row/object metadata before download where available and
always rechecks actual downloaded byte length and signature. Successful empty
queries, explicit authorization failures, expired sessions, missing objects,
and transport failures remain distinct typed outcomes with non-technical UI
messages.
