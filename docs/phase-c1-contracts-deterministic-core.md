# Phase C1: Contracts and deterministic core

Phase C1 is an implementation checkpoint, not a deployment. Migration 010 is a
review-only draft and no callable processing Edge Function exists yet.

## Security and compatibility

- Migration 010 is additive. Existing `materials.summary`, `content_text`,
  `metadata`, OCR metadata, upload state, private buckets, and lifecycle paths
  remain untouched.
- New code must stop writing provider, model, token, price, response, routing,
  or budget telemetry into material metadata. Flutter and public RPCs must
  ignore legacy private metadata defensively; cleanup is deferred to a later,
  separately approved migration.
- Hosted Supabase does not expose a true-superuser migration path. PostgreSQL 17
  also gives a non-superuser role creator an automatic administrator membership
  in a role it creates, with the bootstrap superuser as grantor; the managed
  migration role cannot reliably revoke that membership. Phase C therefore
  creates no custom executor role.
- Processing tables force RLS and grant `PUBLIC`, `anon`, `authenticated`, and
  `service_role` no direct table access. RLS remains defense in depth for
  non-bypass roles, but authorization never depends on it: every Phase C
  `SECURITY DEFINER` is explicitly owned by the managed `postgres` role, which
  has `BYPASSRLS`. Every definer has the fixed `pg_catalog, public` search path,
  explicit narrow grants, and authoritative relationship checks. The three
  authenticated RPCs derive identity solely from `auth.uid()`; the internal
  RPCs accept no authoritative user identifier, derive ownership through
  material/job relationships, validate composite identities and leases, lock
  exact rows, and are executable only by `service_role`.
- The two-material claim limit is serialized with a transaction-scoped advisory
  lock derived from the authoritative job owner. Submitted and ambiguous work
  can never return to submission through lease expiry: it becomes
  reconciliation-only when a response ID is known, or requires an authenticated
  retry authorization otherwise.

## Deterministic contracts

The pure TypeScript core defines closed public/internal DTOs, explicit job/page/
batch transition tables, exact attempt ceilings, stable fingerprints, and
retry/ambiguity classification. Routing is local and versioned; identical
signals and router version produce an identical decision and fingerprint.

Recommended mode sends unusable, uncertain, layout-sensitive, visual, and
STEM-complex pages through the visual route. Economy uses visual processing only
when usable page text cannot safely continue, while original images are always
visual. There is no OpenAI routing call.

Ambiguous dispatch is charge-safe: post-dispatch failure with a response ID can
only be reconciled; without an ID it becomes `user_retry_required`. Each paid
submission creates a durable attempt with a unique attempt-specific idempotency
key. Explicit retry creates a successor linked to the unchanged ambiguous
predecessor. Attempts and budget remain consumed, and the internal retry RPC can
proceed only after consuming a short-lived authorization created by an
authenticated owner action.

## Content safety

Strict schemas cover page analysis, reduction, final structured summaries, and
public status. They use the documented OpenAI Structured Outputs subset and
closed `anyOf` branches. Runtime validation rejects unknown fields and enforces
exact analyzed/partial/missing partitions, page bounds, equation references,
partial/missing trust rules, and source integrity.

Markdown is parsed to an AST and permits only headings, paragraphs, emphasis,
lists, blockquotes, and code. It rejects HTML/comments, definitions, media,
links, reference links, autolinks, email links, active raw URLs, and
dollar-delimited math. LaTeX uses a strict scanner with environment-stack and
per-matrix accounting. The accepted subset is intentionally narrower than
KaTeX/flutter_math_fork: comments, command aliases, control spaces, Unicode
slash lookalikes, and unknown control sequences are rejected. Input is bounded
to 512 characters, nesting depth 16, and 12-by-12 matrices. Unsafe equations
become uncertain escaped plain text with a warning.

## Mini-PDF proof gate

The proof uses pure synthetic PDFs and `pdf-lib` in a Deno-compatible module.
It copies one to five selected pages in memory, embeds a deterministic original-
page mapping, and validates output independently with `unpdf`. Tests cover text,
vector, raster, and mixed documents, repeatability, output fingerprints, elapsed
time, observed heap delta, and output size. The heap measurement is a sampled V8
heap delta, not peak RSS, total process memory, or a production-size guarantee.

The proof must pass and its measurements must be reviewed before C2. If it is
unreliable under the Edge runtime constraints, C2 stops and a private temporary
derived-artifact design is proposed without implementation.

## Deferred work

C1 does not include callable prepare/advance/retry functions, OpenAI or Supabase
network activity, migration application, Storage changes, Flutter integration,
the math-renderer dependency, deployment, or production access. Those remain
behind C2, C3, and C4 approval gates.

## Rollback and forward-fix policy

- Before any Phase C data exists, rollback is permitted only in an explicitly
  approved maintenance window: disable Phase C entry points, revoke public and
  service function execution, drop retry authorizations, pages, attempts,
  batches, then jobs in foreign-key order, drop Phase C functions/policies, and
  finally remove only the new `materials.summary_*` columns. Legacy metadata is
  never rewritten or deleted.
- After attempts or results exist, migration 010 is treated as forward-only.
  Attempt rows and predecessor/idempotency history are audit evidence and must
  not be destroyed. Corrections use a new migration that first disables Phase C
  entry points, reconciles schema/function versions, preserves attempt history,
  and re-enables entry points only after executable database tests pass.
- Function rollback order is caller before callee: authenticated status/retry/
  confirmation functions, service mutation functions, trigger functions, then
  pure validation helpers. Grants are revoked before functions are replaced or
  removed.
- Destructive rollback after data exists risks losing charge, ambiguity,
  provenance, and retry evidence and is not an approved recovery mechanism.
  If deployed schema, function, router, or validator versions diverge, all Phase
  C prepare/advance/retry entry points remain disabled while legacy pasted-text
  summary and Phase B private upload/viewer behavior continue unchanged.
