# Phase 12.1 subject and account deletion

## Approved deletion matrix

Subject deletion hard-deletes the subject after a recoverable tombstone. It removes all subject materials, exact private upload objects, content and summaries, flashcards, quizzes/questions, attempts, sessions, weak topics, and matching subject/material/flashcard/quiz favorites. It preserves no detached subject history. Account-wide usage and quota rows remain because the schema has no reliable subject relationship; this exception is a product decision, not legal approval.

Account deletion removes every object in the authenticated user's namespaces in `study-materials` and `study-images`, then deletes the Supabase Auth user last. Existing `auth.users` cascades remove profiles and all application-owned rows, including the account operation. No user-linked completion receipt remains. Device locale and appearance preferences remain. Provider/platform logs, OpenAI/Supabase retention, and backup/PITR behavior remain unresolved owner/legal/vendor questions.

## Trust boundary and lifecycle

Flutter calls `delete-subject` with only a subject UUID and `delete-account` with the fixed confirmation value. Each Edge Function verifies the bearer token, derives the user ID from Auth, and creates a service-role client only inside the function. Flutter never receives admin credentials, Storage paths, SQL errors, provider payloads, or raw backend errors.

Migration `007_subject_account_deletion.sql` adds RLS-protected, client-inaccessible operation tables and service-only fixed-search-path helpers. Subject lifecycle fields cannot be updated by authenticated clients; ordinary subject columns retain owner-scoped updates. Unique user/subject and per-user constraints serialize retries. Stale incomplete operations are indexed for conservative recovery.

Subject stages are `pending_storage`, `storage_failed`, `storage_verified`, and `database_failed`. Account stages are `pending_storage`, `storage_failed`, `storage_verified`, `database_ready`, and `auth_failed`. A recent active operation holds a 15-minute lease and concurrent callers receive `deletion_in_progress`; failed stages and expired leases resume the same stable operation. Tombstoned subjects are excluded by existing queries and are never restored while cleanup state is uncertain.

## Storage cleanup

Only `study-materials` and `study-images` are allowed. Subject deletion obtains material IDs from the trusted helper and enumerates `{user_id}/{material_id}`. Account deletion enumerates `{user_id}` and then each UUID material folder. Every removal path must contain exactly the derived user ID, trusted/validated material UUID, and non-empty filename. Listing and deletion use batches of 100, tolerate missing objects, and re-list before database or Auth cleanup. Malformed namespaces stop with a sanitized operator-review response.

The synchronous design is intentionally bounded. Staging must test the largest realistic account. If it cannot complete within Edge Function runtime, release is blocked pending a separately approved queue/worker design; synchronous limits must not be raised blindly.

## Recent authentication and Flutter UX

`delete-account` accepts only tokens whose `auth_time` is no more than ten minutes old. Missing or stale values return `recent_auth_required` before any destructive step. Flutter keeps only a pending deletion intent, signs out, uses the normal configured login flow, reopens Settings, and requires the `DELETE` confirmation again. It does not collect a password inside the deletion dialog.

Subject confirmation names the subject, reports the loaded material count, and lists the full deletion scope. Settings contains a separate danger zone. Both flows disable duplicate actions, expose safe progress/retry states, use en/de/ru localization, and support scrollable dialogs, keyboard operation, large text, themes, and semantic live regions.

Safe client codes are `deletion_in_progress`, `storage_cleanup_failed`, `database_cleanup_failed`, `auth_cleanup_failed`, `recent_auth_required`, `unauthorized`, `retry_later`, and `unknown`. Logs contain only operation ID, stage, safe code, bounded counts, timestamp, and status—never user IDs, paths, filenames, tokens, or content.

## Tests and manual QA

Handler tests use injected fakes for authentication, exact paths, missing/partial cleanup, recent authentication, ordering, retryable failures, and sanitized responses. Flutter tests use fake repositories for state purge, resumable failure, recent-auth continuation, and session clearing. Migration tests assert RLS, grants, fixed search paths, constraints, idempotency, stale indexes, and cascade coverage.

Manual staging QA must use isolated disposable accounts: zero/one/many objects, both buckets, foreign account denial, interrupted responses, retry after Storage/Auth failure, stale subject routes, Search/Favorites/Progress cleanup, three locales, light/dark, 200% text, keyboard, and screen reader. No real production account is used.

## Deployment and forward fix

Pending remote order: back up and inspect all database/Storage policies; apply migration 007; verify RLS/grants/helpers and private buckets; deploy `delete-subject`; deploy `delete-account`; deploy the matching Flutter client; then run isolated staging QA. No deployment or secret change occurred in Phase 12.1 implementation.

Applied migrations are immutable. Database corrections use a new forward-fix migration. Edge Functions/client may return to recorded compatible revisions only when schema compatibility is preserved. Incomplete tombstones remain inaccessible and resume through the same operation.

This document does not claim complete erasure, privacy-law compliance, legal retention approval, or store compliance. Provider logs, backups/PITR, anonymous aggregate criteria, and vendor retention controls remain explicit approval gates.
