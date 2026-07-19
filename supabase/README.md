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

The `generate-summary` Edge Function summarizes eligible manual pasted text and keeps its concise legacy behavior. Uploaded PDFs and images are rejected there and must use the Phase C material-analysis path, preventing a second paid summary route. The legacy function summarizes at most the first 12,000 stored characters, requires an authenticated Supabase user, and reads `OPENAI_API_KEY` only from Supabase function secrets.

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

## Phase 9A: Private PDF and Image Uploads

The Flutter app uses `file_picker` for PDF, PNG, JPEG, and WEBP selection. PDFs
are limited to 10 MiB and images to 8 MiB. The client checks the extension,
reported and actual byte sizes, canonical MIME type, and a basic file signature
before uploading. These client checks are UX and basic filtering, not a complete
trust boundary.

Review `migrations/004_material_upload_storage.sql` and confirm the existing
`study-materials` and `study-images` buckets are present. Migrations 001-003 do
not create any `storage.objects` policies, but policies created manually in the
Dashboard are not visible in this repository. Before applying migration 004,
run this preflight in Dashboard > SQL Editor:

```sql
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;
```

PostgreSQL permissive RLS policies combine with `OR`. Verify that no policy
other than the three Phase 9A policies grants INSERT, SELECT, UPDATE, or DELETE
access to `study-materials` or `study-images`. Pay particular attention to
policies that name either bucket and broad policies with no bucket restriction.
If one exists, stop: review it and drop it by its exact policy name in a
separate, deliberate SQL change before applying migration 004. Do not blindly
drop policies for unrelated buckets.

Only after that preflight is clean, apply the migration manually:

```powershell
supabase db push
```

Alternatively, execute the migration once in Dashboard > SQL Editor. Codex does
not apply it remotely. Afterwards, confirm both buckets remain private, their
MIME/size restrictions are configured, and authenticated users have only
INSERT, SELECT, and DELETE access at the exact private path
`{auth.uid()}/{material_uuid}/{filename}`. The path policies require exactly
two folder segments, a UUID second segment, and a non-empty basename; extra
nested folders are rejected.

Run Flutter with the existing public client configuration and upload one file
from each of two test accounts. Confirm each account sees only its own material
metadata and cannot read or delete the other account's object. No Edge Function,
OpenAI secret, service-role credential, signed URL, or public bucket is needed.

## Phase 9B: Selectable PDF Text Extraction

`extract-pdf-text` verifies the caller, derives all storage metadata from the
owned material row, downloads the private object with the caller's authenticated
context, and extracts selectable text with the pinned serverless `unpdf` build.
It does not perform OCR, process images, create URLs, or call OpenAI. A hard
runtime termination can leave a row in `processing`; automatic stale-claim
recovery is deferred and requires deliberate manual recovery.

Deploy the updated functions before applying migration 005, in this order:

```powershell
supabase functions deploy generate-summary
supabase functions deploy generate-flashcards
supabase functions deploy generate-quiz
supabase functions deploy extract-pdf-text
```

Then review and apply `005_material_processing_authority.sql` manually:

```powershell
supabase db push
```

The migration removes direct authenticated/anonymous `UPDATE` authority from
`public.materials`; it does not revoke SELECT, INSERT, or DELETE. Extraction and
summary writes use the Supabase-provided server-only service-role environment
credential. No new custom secret is required and no such credential belongs in
Flutter.

Manually verify a selectable-text PDF becomes `ready`, shows safe extraction
status without exposing raw extracted text, and can use summary/flashcard/quiz generation. Verify an image-only/scanned PDF
becomes `failed` with: “No selectable text was found. Scanned PDFs will be
supported in the OCR phase.” Images must remain metadata-only and ineligible.
# Phase 9C.1 image OCR rollout

Image OCR is synchronous and server-only. Configure `OPENAI_API_KEY` and, optionally,
`IMAGE_OCR_MODEL` (default `gpt-4.1-mini-2025-04-14`) as Edge Function secrets.
Never expose these values to Flutter.

Deploy in this order:

1. `extract-image-text`
2. `generate-summary`
3. `generate-flashcards`
4. `generate-quiz`

No migration is required for Phase 9C.1. Test a typed note, screenshot, handwritten
note, rotated photo, blurry/no-text image, cross-user denial, and successful downstream
summary/flashcard/quiz generation. OCR uses one high-detail Responses API request with
a 6,000-token output limit and no retry. Actual cost depends on processed image
dimensions and tokens. Before production, review the OpenAI project privacy and data
control settings. Scanned PDFs, preprocessing, quotas, usage logging, and stuck-claim
recovery remain deferred.

## Phase 9C.2: Scanned and mixed PDF OCR

Selectable extraction remains the first step. Scanned or mixed PDFs require explicit
confirmation before `extract-scanned-pdf-text` makes one paid, high-detail OpenAI PDF
request. The synchronous MVP accepts private uploaded PDFs from 1 through 10 MiB and
1 through 10 total pages; larger documents must be split. Cost varies with page content.

Configure `OPENAI_API_KEY` and optionally server-only `SCANNED_PDF_OCR_MODEL`, then:

```powershell
supabase functions deploy extract-pdf-text
supabase functions deploy extract-scanned-pdf-text
```

No migration is required. Confirm staging completes under 120 seconds and review
privacy/data controls. Stale claims remain deferred; use a queue/worker in a later
phase if the runtime gate fails rather than raising synchronous limits.
# Phase 9D material lifecycle rollout

Phase 9D adds `006_material_lifecycle.sql` and the `delete-material` Edge
Function. Apply the migration before deploying the function. The function first
verifies the caller JWT with `SUPABASE_URL` and `SUPABASE_ANON_KEY`, then uses
the server-only `SUPABASE_SERVICE_ROLE_KEY` for the three internal deletion
coordination RPCs and exact Storage removal. The service-role credential must
never be placed in Flutter, logged, or returned.

Rollout order:

1. Back up the database and inspect existing `materials` and `storage.objects`
   policies for unexpected permissive policies.
2. Apply migration 006 and verify authenticated users cannot directly delete or
   update `materials`; internal deletion RPCs are service-role-only, while only
   narrow recovery RPCs are authenticated-callable.
3. Deploy the updated extraction/generation functions, then `delete-material`.
4. Test pasted-text, PDF, and image deletion with two isolated users. Confirm
   attempts, weak topics, study sessions, and usage logs remain.
5. Exercise missing-object deletion, a forced Storage failure, repeated delete,
   and stale recovery before general availability.

## Manual orphan reconciliation

Do not expose these checks to Flutter. Run them only with privileged admin
access, first as a read-only report:

```sql
-- Tombstones awaiting cleanup.
select id, user_id, kind, cleanup_status, cleanup_updated_at
from public.materials
where deleted_at is not null
order by cleanup_updated_at;

-- Active upload rows whose expected object metadata is absent.
select m.id, m.user_id, m.storage_bucket, m.storage_path
from public.materials m
left join storage.objects o
  on o.bucket_id = m.storage_bucket and o.name = m.storage_path
where m.source_kind = 'upload' and m.deleted_at is null and o.id is null;

-- Objects without a matching material row. Review age before any deletion.
select o.bucket_id, o.name, o.created_at
from storage.objects o
left join public.materials m
  on m.storage_bucket = o.bucket_id and m.storage_path = o.name
where o.bucket_id in ('study-materials', 'study-images') and m.id is null;
```

For a future scheduled worker, require a conservative age threshold, dry-run
mode, exact owner/material/filename validation, bounded batches, protection for
recent uploads, and reports containing identifiers/statuses only—never file or
extracted content. Lifecycle-created tombstones are reconciled by retrying the
normal authenticated delete operation.

## Explicit authenticated PostgREST privileges

Migration `008_client_api_privileges.sql` is required for fresh projects where
automatic table exposure/default API grants are disabled. RLS policies alone do
not grant table access: without explicit schema and table privileges, valid
authenticated sessions receive HTTP 403 for profile and workspace requests.

Apply migration 008 only after migrations 001 through 007, then reload the
PostgREST schema cache and smoke-test profile creation, subject/material sync,
favorites, flashcard review progress, quiz reads, and the quiz-attempt RPC with
an isolated staging user. The migration does not expose anon access, generated
data writes, lifecycle fields, deletion operation tables, or service-only
helpers. Existing generic Flutter synchronization errors remain appropriate;
raw PostgREST privilege errors must not be displayed.

## Phase C2 persistent analysis (not deployed)

Phase C2 adds three deployable Edge Function directories:

1. `prepare-material-analysis`
2. `advance-material-analysis`
3. `retry-material-analysis`

They require the reviewed migration `010_material_analysis_processing.sql`,
`OPENAI_API_KEY`, and optionally the server-only `MATERIAL_ANALYSIS_MODEL`.
Do not deploy the functions or apply migration 010 until the separate rollout
checkpoint is approved. The functions must be deployed only after migration
010, and the model secret/configuration must never be exposed to Flutter.

Migration 010 creates no custom executor role. Its Phase C `SECURITY DEFINER`
RPCs are explicitly owned by the managed `postgres` role and use a fixed
`pg_catalog, public` search path. RLS and FORCE RLS remain defense in depth;
authorization is enforced by authoritative row relationships because the owner
has `BYPASSRLS`. API roles have no direct processing-table DML: authenticated
users receive only the three public RPCs and `service_role` receives only the
internal RPCs.

See `docs/phase-c2-persistent-server-processing.md` for the trust boundary,
bounded operation design, retry semantics, and disposable verification command.

## Temporary staging final-response diagnostic

`diagnose-material-analysis-response` is a temporary staging-only operational
function. It must never be deployed to production or called by Flutter. It is
the only function configured with `verify_jwt = false`; authentication is
performed inside the handler by `@supabase/server` using the single named mode
`secret:material-analysis-diagnostic-staging`. The named key is accepted only
in the `apikey` header. Requests containing `Authorization` are rejected.

The function accepts only a `POST` with an `application/json` body containing
exactly `batch_id`. It calls only the existing service-only diagnostic target
and record RPCs, retrieves the RPC-provided persisted final-summary Response
once with `GET`, and returns only whether the bounded diagnostic was recorded.
It has no response-create, file-upload, retry, processing-state, Flutter, CORS,
or direct-table path.

Staging rollout requires a separately reviewed checkpoint:

1. Rotate or revoke any previously exposed operator credential; never reuse it.
2. Create the named staging key without displaying or persisting its value.
3. Deploy only `diagnose-material-analysis-response` and verify that only this
   function has `verify_jwt = false`.
4. Invoke once with the named key in `apikey` and the preserved batch UUID in
   the closed request body. Never send an `Authorization` header.
5. Read the bounded result through a service-only query, then delete the named
   key and prove it is rejected without reaching the handler.
6. Delete the deployed temporary function before resuming general C4C.
7. Remove this function directory, its `supabase/config.toml` entry, and this
   runbook in a separately reviewed cleanup commit.
