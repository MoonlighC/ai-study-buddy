# Phase C2: Persistent server processing

Phase C2 implements the trusted server pipeline only. It does not add Flutter
processing UI, math rendering, application version changes, or any deployment.
Migration `010_material_analysis_processing.sql` remains unapplied outside
disposable local databases.

## Public Edge Functions

- `prepare-material-analysis` authenticates the caller, accepts only
  `material_id`, `processing_mode`, and `confirm_large_document`, validates the
  exact private source, rejects PDFs above 100 pages, and persists the exact
  page manifest and deterministic local routing plan. Pages 21 through 100 are
  prepared without a budget reservation or provider request until confirmed.
- `advance-material-analysis` authenticates ownership and claims at most one
  leased operation. Page text is bounded to 10 pages and 40,000 characters;
  visual PDF work is bounded to a five-page in-memory mini-PDF; images use the
  exact original private bytes. Reductions accept at most ten validated inputs.
- `retry-material-analysis` accepts only `material_id`, creates an authenticated
  short-lived authorization, and consumes it through a trusted RPC. It never
  accepts an attempt, provider, model, route, or user identifier.

All three functions return only the public status contract. Internal jobs,
batches, attempts, leases, routing signals, normalized text, budgets, Storage
identity, model configuration, provider response IDs, and temporary file IDs
remain service-only.

Phase C database access uses postgres-owned `SECURITY DEFINER` RPCs because
hosted Supabase provides no supported true-superuser migration path and
PostgreSQL 17 role creation introduces an automatic creator membership that a
managed migration role cannot portably remove. The processing tables retain RLS
and FORCE RLS as defense in depth, but the postgres-owned definers do not rely
on those policies. They use a fixed `pg_catalog, public` search path, explicit
row relationships and lease checks, and narrowly separated grants: authenticated
users receive only the three public RPCs, while `service_role` receives only the
internal RPCs. No API role receives direct processing-table DML.

## Provider and ambiguity behavior

The OpenAI adapter uses the Responses API with server-selected model and
high-detail visual configuration, strict Structured Outputs, and background
mode disabled. Mini-PDFs are uploaded with `purpose=user_data` and referenced
as `input_file`; original images are sent as exact-byte `input_image` data.
Before upload, the batch persists a stable artifact UUID and provider filename.
The returned OpenAI file ID is then persisted by a dedicated RPC before the
Responses request is allowed. Terminal handling schedules deletion as a
separate idempotent work unit; ten failed deletions transition to an explicit
`manual_cleanup_required` state without counter overflow.

An attempt is created immediately before the Responses request. Proven
pre-dispatch failures may back off without ambiguous resubmission. A provider
response ID is accepted only from a documented response body—never from
`x-request-id`. Any dispatched 408, 429, 5xx, timeout, or network failure with
no response ID is persisted as `dispatch_unknown`, then becomes
`user_retry_required`; only the authenticated retry function can create its
immutable successor attempt. A real response ID is reconciliation-only.

## Persistence and compatibility

Only a `completed` response with no error, incomplete details, or refusal and
exactly one valid structured payload can be persisted. Every page result and
reduction is validated before canonical persistence.
Reduction fingerprints and levels are deterministic, missing pages are not
authoritative sources, and finalization requires the complete `1..P` manifest
in terminal page states. Finalization stores the structured payload and a safe
Markdown compatibility projection without changing legacy OCR metadata.

Legacy `generate-summary` remains available for manual pasted text. Uploaded
PDFs and images are rejected there so flattened `content_text` cannot trigger a
second paid summary path.

Each job persists a canonical version contract and SHA-256 fingerprint covering
source bytes and metadata, mode, page count, router, prompts, all schemas,
validator, OpenAI configuration, fingerprint algorithm, and mini-PDF builder.
Exact matches reuse work; an incompatible completed job creates a new numbered
generation while preserving prior history. Batch fingerprints incorporate the
job fingerprint.

## Local verification

The Deno suite uses only fake OpenAI and database boundaries. The executable SQL
suites apply migrations `001` through `010` to a disposable in-memory database.
The PGlite runner supplies Supabase `auth`/`storage` fixtures and a deterministic
test-only `pgcrypto` compatibility digest; a release gate must still run the
same SQL with real PostgreSQL plus `pgcrypto` and the multi-connection
`phase_c1_concurrency_audit.ps1` script.

No function in this checkpoint has been deployed, no remote migration has been
applied, and no production system has been accessed.
