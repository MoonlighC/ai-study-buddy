# AI Study Buddy Architecture

## Phase 1 Shape

AI Study Buddy starts as a Flutter app with mock local data. The first app shell is clickable and demo-ready, but it does not connect to Supabase or OpenAI yet.

## Client

- Flutter owns the mobile, web, and Windows debug UI.
- Feature folders keep screens grouped by user workflow.
- `lib/core/models` contains simple data models that can later map to Supabase rows.
- `lib/mock` contains in-memory demo data and the mock AI service.

## Backend Boundary

Supabase will later provide:

- Auth for email, Google, and Apple sign-in.
- Postgres tables for subjects, materials, generated outputs, flashcards, quiz questions, favorites, and usage logs.
- Storage for photos and PDFs.
- Edge Functions for all OpenAI calls.

The Flutter app must never include `OPENAI_API_KEY`. OpenAI requests must go through Supabase Edge Functions so usage can be logged and limited per account.

## Planned AI Logging

Every real AI call should log:

- `user_id`
- feature name
- model
- input tokens
- output tokens
- estimated cost
- timestamp

## Planned Daily Limits

- 120 generated flashcards per user
- 80 quiz questions per user
- 3 uploads per user
- $0.25 estimated OpenAI cost per user by default
## Phase B upload queue and original previews

Phase B keeps upload orchestration in a session-owned, in-memory queue. The
queue is independently observable, preserves FIFO order, and runs no more than
two upload/processing workers. Inactive items retain only picker metadata and a
deferred read handle where the platform supports it; full file bytes are read
when a worker starts and are released after authoritative material creation.
The queue is cleared on authenticated-session changes and is not restored after
application termination.

Every item receives one planned material UUID. Retries reconcile that exact ID
and the canonical owner/material Storage location before resuming upload,
material creation, or extraction. A processing retry always uses the existing
authoritative material and cannot create a second row. Existing scanned and
mixed-PDF consent remains in material detail, including the 10-page limit.

Original previews resolve an exact material ID through authenticated RLS,
validate uploaded-source metadata internally, and download bytes directly from
private Storage. PDF rendering uses only in-memory `PdfViewer.data`; image
rendering uses only `Image.memory` inside `InteractiveViewer`. No Storage
identifier, URL, token, or document byte buffer enters public route/queue
models, persistence, logs, analytics, semantics, or user-facing errors.
