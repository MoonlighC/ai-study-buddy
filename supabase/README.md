# Supabase Placeholder

This folder is reserved for future Supabase schema notes, Edge Functions, and storage configuration.

Phase 1 intentionally does not include:

- Real Supabase URL or anon key.
- Service role key.
- OpenAI API key.
- Edge Function implementation.
- Database migrations.

Future Edge Functions will be the only place that can call OpenAI. Flutter should call Supabase, Supabase should enforce account limits, and each AI request should be logged before returning generated study content.

## Phase 8A: Generate Summary Edge Function

The `generate-summary` Edge Function summarizes synced pasted-text materials. It requires an authenticated Supabase user and reads `OPENAI_API_KEY` only from Supabase function secrets.

Set the function secret with a placeholder value replaced locally:

```powershell
supabase secrets set OPENAI_API_KEY=<your-openai-api-key>
```

Deploy the function:

```powershell
supabase functions deploy generate-summary
```

Run Flutter in Supabase mode with public client configuration:

```powershell
C:\src\flutter\bin\flutter.bat run --dart-define=APP_BACKEND_MODE=supabase --dart-define=SUPABASE_URL=<your-project-url> --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

After signing in, create a pasted-text material, open the material detail screen, and use `Summarize with AI`.

## Phase 8B: Generate Flashcards Edge Function

The `generate-flashcards` Edge Function creates study flashcards for synced pasted-text materials. It requires an authenticated Supabase user and reuses the existing `OPENAI_API_KEY` function secret.

Set the function secret with a placeholder value replaced locally:

```powershell
supabase secrets set OPENAI_API_KEY=<your-openai-api-key>
```

Deploy the function:

```powershell
supabase functions deploy generate-flashcards
```

After signing in, create a pasted-text material, open the material detail screen, and use `Generate flashcards`.

## Phase 8D: Generate Quiz Edge Function

The `generate-quiz` Edge Function creates multiple-choice quiz questions for synced pasted-text materials. It requires an authenticated Supabase user and reuses the existing `OPENAI_API_KEY` function secret.

Quiz definitions are immutable to Flutter clients. The function verifies the
JWT and material ownership with the authenticated anon client, then uses the
Supabase-provided `SUPABASE_SERVICE_ROLE_KEY` only inside the Edge Function for
trusted quiz/question inserts. Never copy, log, or expose that credential in
Flutter, app configuration, prompts, or client-visible documentation.

Set the function secret with a placeholder value replaced locally:

```powershell
supabase secrets set OPENAI_API_KEY=<your-openai-api-key>
```

Deploy the function:

```powershell
supabase functions deploy generate-quiz
```

After signing in, create a pasted-text material, open the material detail screen, and use `Generate quiz`.

## Phase 8D.2: Authoritative Quiz Attempts and Weak Topics

Review `migrations/003_quiz_attempt_weak_topics_rpc.sql`, then apply pending
migrations manually from the linked repository:

```powershell
supabase db push
```

Alternatively, execute that migration once in Dashboard > SQL Editor. Codex
does not apply this migration remotely.

In Dashboard > Integrations > Data API, confirm that:

- the `public` schema is exposed;
- authenticated clients can read `weak_topics`;
- `save_quiz_attempt_with_weak_topics` is exposed;
- only `authenticated`, not `anon`, can execute the RPC.

The RPC is `SECURITY DEFINER`, owned by the privileged migration role, and
retains explicit `auth.uid()` plus quiz/question ownership validation. The
authenticated and anonymous API roles have no direct `INSERT`, `UPDATE`, or
`DELETE` privileges on `quizzes`, `quiz_questions`, `quiz_attempts`, or
`weak_topics`; authenticated clients receive `SELECT` access only. Quiz
creation remains inside `generate-quiz`, and attempts must use the scoring RPC.
The database sets `completed_at` and weak-topic recency with its own `now()`
value; Flutter sends only the attempt UUID, quiz UUID, start time, and selected
answers.

Run the app with the existing public client configuration:

```powershell
C:\src\flutter\bin\flutter.bat run --dart-define=APP_BACKEND_MODE=supabase --dart-define=SUPABASE_URL=<project-url> --dart-define=SUPABASE_ANON_KEY=<public-key>
```

Complete two quizzes, restart the app, and sign in again. Confirm that attempts
and cumulative focus topics reload. Retrying the RPC with the same attempt UUID
must leave both the attempt count and cumulative miss counts unchanged. Invalid
duplicate, missing, or foreign question IDs must create no attempt or weak-topic
updates.

The service-role credential and OpenAI secret remain server-side only. Apply the
migration and deploy the updated `generate-quiz` function manually when this
phase is approved; neither action is performed by Codex here.
