-- Phase C1 persistent analysis contracts. This migration is additive and keeps
-- legacy OCR metadata intact. It is not deployed by the C1 implementation.

do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'material_analysis_executor') then
    create role material_analysis_executor nologin nosuperuser noinherit nobypassrls;
  end if;
end
$$;

grant usage on schema public, auth, extensions to material_analysis_executor;

alter table public.materials
  add column if not exists summary_payload jsonb,
  add column if not exists summary_schema_version integer,
  add column if not exists summary_processing_mode text,
  add column if not exists summary_validation_version text,
  add column if not exists summary_validation_hash text;

alter table public.materials
  drop constraint if exists materials_summary_payload_contract,
  add constraint materials_summary_payload_contract check (
    (summary_payload is null and summary_schema_version is null and
      summary_processing_mode is null and summary_validation_version is null and
      summary_validation_hash is null)
    or
    (jsonb_typeof(summary_payload) = 'object' and summary_schema_version = 1 and
      summary_processing_mode in ('recommended', 'economy') and
      summary_validation_version = 'phase-c-validator-v2' and
      summary_validation_hash ~ '^[0-9a-f]{64}$' and
      octet_length(summary_payload::text) <= 1048576)
  );

alter table public.materials
  drop constraint if exists materials_id_user_unique,
  add constraint materials_id_user_unique unique (id, user_id);

create or replace function public.material_analysis_safe_warnings(p_value jsonb)
returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'array'
    and pg_catalog.jsonb_array_length(p_value) <= 100
    and pg_catalog.octet_length(p_value::text) <= 65536
    and not exists (
      select 1 from pg_catalog.jsonb_array_elements(p_value) as warning(value)
      where pg_catalog.jsonb_typeof(warning.value) <> 'object'
        or not (warning.value ?& array['code','detail','source_pages'])
        or (warning.value - array['code','detail','source_pages']) <> '{}'::jsonb
        or pg_catalog.length(pg_catalog.btrim(warning.value->>'code')) not between 1 and 64
        or (warning.value->>'code') !~ '^[a-z0-9_]+$'
        or pg_catalog.length(warning.value->>'detail') not between 1 and 500
        or pg_catalog.jsonb_typeof(warning.value->'source_pages') <> 'array'
        or pg_catalog.jsonb_array_length(warning.value->'source_pages') > 100
    )
$$;

create or replace function public.material_analysis_valid_page_payload(p_value jsonb)
returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'object'
    and pg_catalog.octet_length(p_value::text) <= 262144
    and p_value ?& array[
      'page_number','summary_markdown','key_concepts','equations',
      'confidence','warnings','trustworthy'
    ]
    and (p_value - array[
      'page_number','summary_markdown','key_concepts','equations',
      'confidence','warnings','trustworthy'
    ]) = '{}'::jsonb
    and pg_catalog.jsonb_typeof(p_value->'page_number') = 'number'
    and pg_catalog.jsonb_typeof(p_value->'summary_markdown') = 'string'
    and pg_catalog.length(p_value->>'summary_markdown') between 1 and 6000
    and pg_catalog.jsonb_typeof(p_value->'key_concepts') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'key_concepts') <= 50
    and pg_catalog.jsonb_typeof(p_value->'equations') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'equations') <= 100
    and pg_catalog.jsonb_typeof(p_value->'confidence') = 'number'
    and (p_value->>'confidence')::numeric between 0 and 1
    and public.material_analysis_safe_warnings(p_value->'warnings')
    and pg_catalog.jsonb_typeof(p_value->'trustworthy') = 'boolean'
$$;

create or replace function public.material_analysis_valid_summary_payload(p_value jsonb)
returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'object'
    and pg_catalog.octet_length(p_value::text) <= 1048576
    and p_value ?& array[
      'language','sections','key_concepts','equations','warnings','partial_extraction'
    ]
    and (p_value - array[
      'language','sections','key_concepts','equations','warnings','partial_extraction'
    ]) = '{}'::jsonb
    and pg_catalog.length(p_value->>'language') between 1 and 32
    and pg_catalog.jsonb_typeof(p_value->'sections') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'sections') between 1 and 24
    and pg_catalog.jsonb_typeof(p_value->'key_concepts') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'key_concepts') <= 50
    and pg_catalog.jsonb_typeof(p_value->'equations') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'equations') <= 100
    and public.material_analysis_safe_warnings(p_value->'warnings')
    and pg_catalog.jsonb_typeof(p_value->'partial_extraction') = 'object'
$$;

create or replace function public.material_analysis_valid_batch_payload(
  p_value jsonb, p_operation text
) returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'object'
    and pg_catalog.octet_length(p_value::text) <= 1048576
    and p_value ?& array['schema_version','operation','content']
    and (p_value - array['schema_version','operation','content']) = '{}'::jsonb
    and p_value->>'schema_version' = '1'
    and p_value->>'operation' = p_operation
    and pg_catalog.jsonb_typeof(p_value->'content') in ('object','array')
$$;

create or replace function public.material_analysis_valid_page_numbers(p_pages integer[])
returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_pages is not null
    and pg_catalog.cardinality(p_pages) between 1 and 10
    and not exists (select 1 from pg_catalog.unnest(p_pages) p where p not between 1 and 100)
    and (select pg_catalog.count(distinct p) from pg_catalog.unnest(p_pages) p) = pg_catalog.cardinality(p_pages)
$$;

create table public.material_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null,
  user_id uuid not null,
  page_count integer not null check (page_count between 1 and 100),
  completed_page_count integer not null default 0 check (completed_page_count between 0 and page_count),
  status text not null check (status in (
    'awaiting_confirmation','prepared','processing','reconciliation_required',
    'user_retry_required','completed','completed_with_warnings','failed'
  )),
  public_stage text not null check (public_stage in (
    'preparing_document','analyzing_pages',
    'recognizing_formulas_and_diagrams','creating_summary'
  )),
  processing_mode text not null check (processing_mode in ('recommended','economy')),
  confirmation_required boolean not null default false,
  confirmation_authorized_at timestamptz,
  domain_profile text not null check (domain_profile in ('general','stem')),
  router_version text not null,
  schema_version integer not null check (schema_version = 1),
  warning_payload jsonb not null default '[]'::jsonb,
  safe_error_code text check (safe_error_code is null or length(safe_error_code) between 1 and 64),
  next_retry_at timestamptz,
  budget_state text not null default 'unreserved' check (
    budget_state in ('unreserved','reserved','consumed','released')
  ),
  active_lease_token uuid,
  active_lease_expires_at timestamptz,
  last_user_retry_authorization_id uuid,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (material_id),
  unique (id, material_id, user_id),
  foreign key (material_id, user_id) references public.materials(id, user_id) on delete cascade,
  check (public.material_analysis_safe_warnings(warning_payload)),
  check ((active_lease_token is null) = (active_lease_expires_at is null)),
  check ((status in ('completed','completed_with_warnings','failed')) = (completed_at is not null)),
  check (not confirmation_required or page_count between 21 and 100)
);

create table public.material_processing_batches (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null,
  material_id uuid not null,
  user_id uuid not null,
  operation text not null check (operation in (
    'page_text','page_visual','page_recovery','reduction','final_summary'
  )),
  page_numbers integer[] not null,
  status text not null default 'prepared' check (status in (
    'prepared','submitted','response_known','dispatch_unknown',
    'reconciliation_required','user_retry_required','completed','failed'
  )),
  fingerprint text not null check (fingerprint ~ '^[0-9a-f]{64}$'),
  max_attempts integer not null check (max_attempts between 1 and 2),
  attempt_count integer not null default 0 check (attempt_count between 0 and max_attempts),
  budget_state text not null default 'unreserved' check (
    budget_state in ('unreserved','reserved','consumed','released')
  ),
  current_attempt_id uuid,
  pending_predecessor_attempt_id uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  upstream_response_id text check (
    upstream_response_id is null or length(btrim(upstream_response_id)) between 8 and 200
  ),
  retry_after timestamptz,
  ambiguous_since timestamptz,
  failure_code text check (failure_code is null or length(failure_code) between 1 and 64),
  result_payload jsonb,
  result_schema_version integer,
  validation_version text,
  validation_hash text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, job_id, material_id, user_id),
  unique (job_id, fingerprint),
  foreign key (job_id, material_id, user_id)
    references public.material_processing_jobs(id, material_id, user_id) on delete cascade,
  check (public.material_analysis_valid_page_numbers(page_numbers)),
  check ((lease_token is null) = (lease_expires_at is null)),
  check ((operation = 'page_visual' and cardinality(page_numbers) <= 5)
    or (operation <> 'page_visual' and cardinality(page_numbers) <= 10)),
  check ((operation = 'page_recovery' and max_attempts = 1)
    or (operation <> 'page_recovery' and max_attempts <= 2)),
  check ((status in ('response_known','reconciliation_required','completed') and upstream_response_id is not null)
    or status not in ('response_known','reconciliation_required','completed')),
  check ((status in ('dispatch_unknown','user_retry_required') and ambiguous_since is not null)
    or status not in ('dispatch_unknown','user_retry_required')),
  check ((status = 'completed' and result_payload is not null and result_schema_version = 1
      and validation_version = 'phase-c-validator-v2'
      and validation_hash ~ '^[0-9a-f]{64}$' and completed_at is not null)
    or status <> 'completed'),
  check ((status = 'failed' and completed_at is not null) or status <> 'failed')
);

create table public.material_processing_attempts (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  job_id uuid not null,
  material_id uuid not null,
  user_id uuid not null,
  attempt_number integer not null check (attempt_number between 1 and 3),
  predecessor_attempt_id uuid references public.material_processing_attempts(id),
  idempotency_key text not null unique check (idempotency_key ~ '^[0-9a-f]{64}$'),
  status text not null check (status in (
    'submitted','response_known','dispatch_unknown','reconciliation_required','completed','failed'
  )),
  upstream_response_id text check (
    upstream_response_id is null or length(btrim(upstream_response_id)) between 8 and 200
  ),
  budget_effect text not null check (budget_effect in ('consumed','retained','released')),
  ambiguity_state text not null check (ambiguity_state in ('none','unknown','reconcile','user_retry')),
  failure_code text check (failure_code is null or length(failure_code) between 1 and 64),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (batch_id, attempt_number),
  unique (id, batch_id),
  foreign key (batch_id, job_id, material_id, user_id)
    references public.material_processing_batches(id, job_id, material_id, user_id) on delete cascade,
  check ((status in ('response_known','reconciliation_required','completed') and upstream_response_id is not null)
    or status not in ('response_known','reconciliation_required','completed')),
  check ((status in ('completed','failed') and completed_at is not null)
    or status not in ('completed','failed'))
);

alter table public.material_processing_batches
  add constraint material_processing_batches_current_attempt_fk
    foreign key (current_attempt_id, id)
    references public.material_processing_attempts(id, batch_id),
  add constraint material_processing_batches_predecessor_attempt_fk
    foreign key (pending_predecessor_attempt_id, id)
    references public.material_processing_attempts(id, batch_id);

create table public.material_processing_pages (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null,
  material_id uuid not null,
  user_id uuid not null,
  page_number integer not null check (page_number between 1 and 100),
  route text check (route in ('text','visual')),
  status text not null default 'pending' check (status in (
    'pending','batched','processing','completed','partial','missing','failed'
  )),
  active_batch_id uuid,
  routing_signals jsonb not null default '{}'::jsonb check (
    jsonb_typeof(routing_signals) = 'object' and octet_length(routing_signals::text) <= 16384
  ),
  routing_confidence numeric(5,4) check (routing_confidence between 0 and 1),
  grouped_attempts integer not null default 0 check (grouped_attempts between 0 and 2),
  recovery_attempts integer not null default 0 check (recovery_attempts between 0 and 1),
  total_upstream_attempts integer not null default 0 check (total_upstream_attempts between 0 and 3),
  result_payload jsonb,
  result_schema_version integer,
  validation_version text,
  validation_hash text,
  warning_payload jsonb not null default '[]'::jsonb,
  terminal_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, page_number),
  unique (id, job_id, material_id, user_id),
  foreign key (job_id, material_id, user_id)
    references public.material_processing_jobs(id, material_id, user_id) on delete cascade,
  foreign key (active_batch_id, job_id, material_id, user_id)
    references public.material_processing_batches(id, job_id, material_id, user_id),
  check (public.material_analysis_safe_warnings(warning_payload)),
  check (total_upstream_attempts = grouped_attempts + recovery_attempts),
  check (
    (status = 'completed' and public.material_analysis_valid_page_payload(result_payload)
      and (result_payload->>'trustworthy')::boolean and result_schema_version = 1
      and validation_version = 'phase-c-validator-v2'
      and validation_hash ~ '^[0-9a-f]{64}$'
      and jsonb_array_length(warning_payload) <= 100 and active_batch_id is null and terminal_at is not null)
    or (status = 'partial' and public.material_analysis_valid_page_payload(result_payload)
      and (result_payload->>'trustworthy')::boolean and result_schema_version = 1
      and validation_version = 'phase-c-validator-v2'
      and validation_hash ~ '^[0-9a-f]{64}$'
      and jsonb_array_length(warning_payload) > 0 and active_batch_id is null and terminal_at is not null)
    or (status = 'missing' and result_payload is null and result_schema_version is null
      and validation_version = 'phase-c-validator-v2'
      and validation_hash ~ '^[0-9a-f]{64}$'
      and jsonb_array_length(warning_payload) > 0 and active_batch_id is null and terminal_at is not null)
    or (status not in ('completed','partial','missing') and terminal_at is null)
  )
);

create table public.material_processing_retry_authorizations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null,
  batch_id uuid not null,
  material_id uuid not null,
  user_id uuid not null,
  predecessor_attempt_id uuid not null references public.material_processing_attempts(id),
  authorized_at timestamptz not null default now(),
  consumed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '15 minutes'),
  unique (id, job_id, batch_id, material_id, user_id),
  unique (id, job_id, material_id, user_id),
  foreign key (batch_id, job_id, material_id, user_id)
    references public.material_processing_batches(id, job_id, material_id, user_id) on delete cascade
);

alter table public.material_processing_jobs
  add constraint material_processing_jobs_retry_authorization_fk
  foreign key (last_user_retry_authorization_id, id, material_id, user_id)
  references public.material_processing_retry_authorizations(id, job_id, material_id, user_id);

create index material_processing_jobs_owner_status_idx
  on public.material_processing_jobs(user_id, status);
create index material_processing_jobs_active_lease_idx
  on public.material_processing_jobs(user_id, active_lease_expires_at)
  where active_lease_token is not null;
create index material_processing_pages_job_status_idx
  on public.material_processing_pages(job_id, status, page_number);
create index material_processing_batches_claim_idx
  on public.material_processing_batches(job_id, operation, status, retry_after, created_at);
create index material_processing_batches_expired_lease_idx
  on public.material_processing_batches(lease_expires_at)
  where lease_token is not null;
create index material_processing_attempts_batch_idx
  on public.material_processing_attempts(batch_id, attempt_number desc);
create index material_processing_retry_authorizations_owner_idx
  on public.material_processing_retry_authorizations(user_id, material_id, consumed_at, expires_at);

alter table public.material_processing_jobs enable row level security;
alter table public.material_processing_jobs force row level security;
alter table public.material_processing_pages enable row level security;
alter table public.material_processing_pages force row level security;
alter table public.material_processing_batches enable row level security;
alter table public.material_processing_batches force row level security;
alter table public.material_processing_attempts enable row level security;
alter table public.material_processing_attempts force row level security;
alter table public.material_processing_retry_authorizations enable row level security;
alter table public.material_processing_retry_authorizations force row level security;

create policy material_analysis_executor_jobs on public.material_processing_jobs
  for all to material_analysis_executor using (true) with check (true);
create policy material_analysis_executor_pages on public.material_processing_pages
  for all to material_analysis_executor using (true) with check (true);
create policy material_analysis_executor_batches on public.material_processing_batches
  for all to material_analysis_executor using (true) with check (true);
create policy material_analysis_executor_attempts on public.material_processing_attempts
  for all to material_analysis_executor using (true) with check (true);
create policy material_analysis_executor_retry_authorizations on public.material_processing_retry_authorizations
  for all to material_analysis_executor using (true) with check (true);
create policy material_analysis_executor_materials on public.materials
  for all to material_analysis_executor using (true) with check (true);

alter table public.material_processing_jobs owner to postgres;
alter table public.material_processing_pages owner to postgres;
alter table public.material_processing_batches owner to postgres;
alter table public.material_processing_attempts owner to postgres;
alter table public.material_processing_retry_authorizations owner to postgres;

revoke all on table public.material_processing_jobs from public, anon, authenticated, service_role;
revoke all on table public.material_processing_pages from public, anon, authenticated, service_role;
revoke all on table public.material_processing_batches from public, anon, authenticated, service_role;
revoke all on table public.material_processing_attempts from public, anon, authenticated, service_role;
revoke all on table public.material_processing_retry_authorizations from public, anon, authenticated, service_role;

grant select, insert, update, delete on public.material_processing_jobs to material_analysis_executor;
grant select, insert, update, delete on public.material_processing_pages to material_analysis_executor;
grant select, insert, update, delete on public.material_processing_batches to material_analysis_executor;
grant select, insert, update, delete on public.material_processing_attempts to material_analysis_executor;
grant select, insert, update, delete on public.material_processing_retry_authorizations to material_analysis_executor;
grant select on public.materials to material_analysis_executor;
grant update (summary, summary_payload, summary_schema_version, summary_processing_mode,
  summary_validation_version, summary_validation_hash) on public.materials to material_analysis_executor;

create or replace function public.enforce_material_processing_job_row()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
declare v_terminal integer;
begin
  select count(*) into v_terminal from public.material_processing_pages
  where job_id = new.id and status in ('completed','partial','missing');
  if new.completed_page_count <> v_terminal then raise exception 'completed_page_count_drift'; end if;
  if tg_op = 'UPDATE' and old.status = new.status and old.status in ('completed','completed_with_warnings','failed') then
    raise exception 'terminal_job_immutable';
  end if;
  if tg_op = 'UPDATE' and old.status <> new.status then
    if not ((old.status,new.status) in (
      ('awaiting_confirmation','prepared'),('awaiting_confirmation','failed'),
      ('prepared','processing'),('prepared','failed'),
      ('processing','prepared'),('processing','reconciliation_required'),
      ('processing','user_retry_required'),('processing','completed'),
      ('processing','completed_with_warnings'),('processing','failed'),
      ('reconciliation_required','processing'),('reconciliation_required','completed'),
      ('reconciliation_required','completed_with_warnings'),('reconciliation_required','failed'),
      ('user_retry_required','prepared'),('user_retry_required','failed')
    )) then raise exception 'forbidden_job_transition'; end if;
    if old.status = 'awaiting_confirmation' and new.status = 'prepared'
      and new.confirmation_authorized_at is null then raise exception 'explicit_confirmation_required'; end if;
    if new.status = 'processing' and (new.active_lease_token is null or new.active_lease_expires_at <= now()) then
      raise exception 'lease_required'; end if;
    if old.status = 'prepared' and new.status = 'processing' and new.budget_state <> 'reserved' then
      raise exception 'budget_reservation_required'; end if;
    if old.status = 'user_retry_required' and new.status = 'prepared'
      and (new.last_user_retry_authorization_id is null
        or new.last_user_retry_authorization_id is not distinct from old.last_user_retry_authorization_id) then
      raise exception 'explicit_user_retry_required'; end if;
    if new.status in ('completed','completed_with_warnings','failed') and new.completed_at is null then
      raise exception 'terminal_time_required'; end if;
  end if;
  return new;
end
$$;

create or replace function public.enforce_material_processing_page_row()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
declare v_page_count integer;
begin
  select page_count into v_page_count from public.material_processing_jobs where id = new.job_id;
  if v_page_count is null or new.page_number > v_page_count then raise exception 'page_outside_manifest'; end if;
  if tg_op = 'UPDATE' and old.status = new.status and old.status in ('completed','partial','missing') then
    raise exception 'terminal_page_immutable';
  end if;
  if tg_op = 'UPDATE' and old.status <> new.status then
    if not ((old.status,new.status) in (
      ('pending','batched'),('pending','failed'),('batched','processing'),
      ('batched','pending'),('processing','completed'),('processing','partial'),
      ('processing','missing'),('processing','pending'),('processing','failed')
    )) then raise exception 'forbidden_page_transition'; end if;
    if old.status = 'batched' and new.status = 'processing' then
      if new.active_batch_id is null or new.total_upstream_attempts <> old.total_upstream_attempts + 1 then
        raise exception 'page_attempt_required'; end if;
    end if;
  end if;
  if new.grouped_attempts > 2 or new.recovery_attempts > 1 or new.total_upstream_attempts > 3
    or new.total_upstream_attempts <> new.grouped_attempts + new.recovery_attempts then
    raise exception 'page_attempt_budget_exhausted';
  end if;
  return new;
end
$$;

create or replace function public.enforce_material_processing_batch_row()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status = new.status then
    if old.status in ('completed','failed') then raise exception 'terminal_batch_immutable'; end if;
    raise exception 'batch_status_self_transition';
  end if;
  if not ((old.status,new.status) in (
    ('prepared','submitted'),('prepared','failed'),
    ('submitted','prepared'),('submitted','response_known'),('submitted','dispatch_unknown'),
    ('submitted','reconciliation_required'),('submitted','user_retry_required'),('submitted','failed'),
    ('response_known','reconciliation_required'),('response_known','completed'),('response_known','failed'),
    ('dispatch_unknown','response_known'),('dispatch_unknown','reconciliation_required'),
    ('dispatch_unknown','user_retry_required'),
    ('reconciliation_required','response_known'),('reconciliation_required','completed'),
    ('reconciliation_required','failed'),('user_retry_required','prepared'),('user_retry_required','failed')
  )) then raise exception 'forbidden_batch_transition'; end if;
  if old.status = 'prepared' and new.status = 'submitted' then
    if old.lease_token is null or new.lease_token <> old.lease_token
      or new.attempt_count <> old.attempt_count + 1 or new.current_attempt_id is null
      or new.budget_state <> 'consumed' then raise exception 'batch_submission_invariant'; end if;
  end if;
  if new.status in ('response_known','reconciliation_required','completed')
    and (new.upstream_response_id is null or length(btrim(new.upstream_response_id)) < 8) then
    raise exception 'response_id_required';
  end if;
  if old.status = 'dispatch_unknown' and new.status = 'prepared' then
    raise exception 'ambiguous_dispatch_requires_user_retry';
  end if;
  if old.status = 'user_retry_required' and new.status = 'prepared'
    and new.pending_predecessor_attempt_id is null then raise exception 'retry_predecessor_required'; end if;
  return new;
end
$$;

create or replace function public.enforce_material_processing_attempt_row()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.batch_id <> new.batch_id or old.attempt_number <> new.attempt_number
    or old.predecessor_attempt_id is distinct from new.predecessor_attempt_id
    or old.idempotency_key <> new.idempotency_key or old.submitted_at <> new.submitted_at then
    raise exception 'attempt_identity_immutable';
  end if;
  if old.status in ('completed','failed') then raise exception 'terminal_attempt_immutable'; end if;
  if old.status = new.status then
    if old.status in ('completed','failed') then raise exception 'terminal_attempt_immutable'; end if;
    return new;
  end if;
  if not ((old.status,new.status) in (
    ('submitted','response_known'),('submitted','dispatch_unknown'),
    ('submitted','reconciliation_required'),('submitted','failed'),
    ('response_known','reconciliation_required'),('response_known','completed'),('response_known','failed'),
    ('dispatch_unknown','response_known'),('dispatch_unknown','reconciliation_required'),('dispatch_unknown','failed'),
    ('reconciliation_required','response_known'),('reconciliation_required','completed'),('reconciliation_required','failed')
  )) then raise exception 'forbidden_attempt_transition'; end if;
  return new;
end
$$;

create or replace function public.reject_material_processing_status_self_transition()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status = new.status then raise exception 'status_self_transition'; end if;
  return new;
end
$$;

create trigger enforce_material_processing_job_row_trigger
before update on public.material_processing_jobs for each row
execute function public.enforce_material_processing_job_row();
create trigger reject_material_processing_job_status_self_transition_trigger
before update of status on public.material_processing_jobs for each row
execute function public.reject_material_processing_status_self_transition();
create trigger enforce_material_processing_page_row_trigger
before insert or update on public.material_processing_pages for each row
execute function public.enforce_material_processing_page_row();
create trigger reject_material_processing_page_status_self_transition_trigger
before update of status on public.material_processing_pages for each row
execute function public.reject_material_processing_status_self_transition();
create trigger enforce_material_processing_batch_row_trigger
before update of status on public.material_processing_batches for each row
execute function public.enforce_material_processing_batch_row();
create trigger enforce_material_processing_attempt_row_trigger
before update on public.material_processing_attempts for each row
execute function public.enforce_material_processing_attempt_row();

create or replace function public.refresh_material_processing_progress()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
  update public.material_processing_jobs set
    completed_page_count = (
      select count(*) from public.material_processing_pages
      where job_id = coalesce(new.job_id,old.job_id) and status in ('completed','partial','missing')
    ), updated_at = now()
  where id = coalesce(new.job_id,old.job_id);
  return coalesce(new,old);
end
$$;
create trigger refresh_material_processing_progress_trigger
after insert or update of status or delete on public.material_processing_pages for each row
execute function public.refresh_material_processing_progress();

create or replace function public.create_material_processing_job_internal(
  p_material_id uuid, p_processing_mode text, p_confirmation boolean,
  p_page_count integer, p_domain_profile text
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_material public.materials%rowtype; v_job_id uuid; v_requires boolean;
begin
  if p_processing_mode not in ('recommended','economy') or p_page_count not between 1 and 100
    or p_domain_profile not in ('general','stem') then raise exception 'invalid_job_contract'; end if;
  select * into v_material from public.materials
  where id = p_material_id and deleted_at is null for update;
  if not found then raise exception 'material_unavailable'; end if;
  v_requires := v_material.kind = 'pdf' and p_page_count between 21 and 100;
  if v_requires and not p_confirmation then
    insert into public.material_processing_jobs(
      material_id,user_id,page_count,status,public_stage,processing_mode,
      confirmation_required,domain_profile,router_version,schema_version
    ) values (
      v_material.id,v_material.user_id,p_page_count,'awaiting_confirmation','preparing_document',
      p_processing_mode,true,p_domain_profile,'phase-c-router-v1',1
    ) returning id into v_job_id;
  else
    insert into public.material_processing_jobs(
      material_id,user_id,page_count,status,public_stage,processing_mode,
      confirmation_required,confirmation_authorized_at,domain_profile,router_version,schema_version
    ) values (
      v_material.id,v_material.user_id,p_page_count,'prepared','preparing_document',
      p_processing_mode,v_requires,case when v_requires then now() end,
      p_domain_profile,'phase-c-router-v1',1
    ) returning id into v_job_id;
  end if;
  insert into public.material_processing_pages(job_id,material_id,user_id,page_number)
  select v_job_id,v_material.id,v_material.user_id,page
  from pg_catalog.generate_series(1,p_page_count) page;
  return v_job_id;
end
$$;

create or replace function public.confirm_material_analysis(p_material_id uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  update public.material_processing_jobs j set status='prepared', confirmation_authorized_at=now(), updated_at=now()
  from public.materials m where j.material_id=p_material_id and m.id=j.material_id
    and m.user_id=auth.uid() and j.user_id=m.user_id and j.status='awaiting_confirmation';
  if not found then raise exception 'confirmation_not_allowed'; end if;
end
$$;

create or replace function public.create_material_processing_batch_internal(
  p_job_id uuid, p_operation text, p_page_numbers integer[], p_fingerprint text
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype; v_batch_id uuid; v_max integer;
begin
  select * into v_job from public.material_processing_jobs where id=p_job_id for update;
  if not found or v_job.status <> 'prepared' or p_operation not in (
    'page_text','page_visual','page_recovery','reduction','final_summary'
  ) or p_fingerprint !~ '^[0-9a-f]{64}$' or not public.material_analysis_valid_page_numbers(p_page_numbers)
  then raise exception 'invalid_batch_contract'; end if;
  if p_operation='page_visual' and cardinality(p_page_numbers)>5 then raise exception 'visual_batch_limit'; end if;
  if exists (
    select 1 from unnest(p_page_numbers) p
    left join public.material_processing_pages page on page.job_id=v_job.id and page.page_number=p
    where page.id is null
  ) then raise exception 'batch_page_outside_manifest'; end if;
  v_max := case when p_operation='page_recovery' then 1 else 2 end;
  insert into public.material_processing_batches(
    job_id,material_id,user_id,operation,page_numbers,fingerprint,max_attempts
  ) values (v_job.id,v_job.material_id,v_job.user_id,p_operation,p_page_numbers,p_fingerprint,v_max)
  returning id into v_batch_id;
  if p_operation in ('page_text','page_visual','page_recovery') then
    update public.material_processing_pages set status='batched',active_batch_id=v_batch_id,updated_at=now()
    where job_id=v_job.id and page_number=any(p_page_numbers) and status='pending';
    if not found then raise exception 'batch_pages_not_available'; end if;
  end if;
  return v_batch_id;
end
$$;

create or replace function public.claim_material_processing_batch_internal(
  p_job_id uuid, p_operation text
) returns table(batch_id uuid, lease_token uuid) language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype; v_batch public.material_processing_batches%rowtype;
  v_token uuid := gen_random_uuid(); v_reconcile boolean;
begin
  select * into v_job from public.material_processing_jobs where id=p_job_id for update;
  if not found or v_job.status not in ('prepared','reconciliation_required') then raise exception 'job_not_claimable'; end if;
  if v_job.active_lease_token is not null and v_job.active_lease_expires_at > now() then raise exception 'job_already_leased'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_job.user_id::text,0));
  if (select count(*) from public.material_processing_jobs
      where user_id=v_job.user_id and active_lease_expires_at>now()) >= 2 then
    raise exception 'user_concurrency_limit';
  end if;
  v_reconcile := v_job.status='reconciliation_required';
  select * into v_batch from public.material_processing_batches
  where job_id=v_job.id and operation=p_operation
    and status=case when v_reconcile then 'reconciliation_required' else 'prepared' end
    and (retry_after is null or retry_after<=now())
  order by created_at for update skip locked limit 1;
  if not found then raise exception 'batch_unavailable'; end if;
  update public.material_processing_jobs set status='processing',active_lease_token=v_token,
    active_lease_expires_at=now()+interval '120 seconds',
    budget_state=case when v_reconcile then budget_state else 'reserved' end,updated_at=now()
  where id=v_job.id;
  update public.material_processing_batches set lease_token=v_token,
    lease_expires_at=now()+interval '120 seconds',
    budget_state=case when v_reconcile then budget_state else 'reserved' end,updated_at=now()
  where id=v_batch.id;
  return query select v_batch.id,v_token;
end
$$;

create or replace function public.mark_material_processing_batch_submitted_internal(
  p_batch_id uuid, p_lease_token uuid
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype; v_attempt_id uuid; v_key text;
begin
  select b.* into v_batch from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id and j.material_id=b.material_id and j.user_id=b.user_id
  where b.id=p_batch_id and b.lease_token=p_lease_token and j.active_lease_token=p_lease_token
    and b.status='prepared' and b.attempt_count<b.max_attempts for update of b;
  if not found then raise exception 'batch_submit_conflict'; end if;
  v_key := encode(extensions.digest(v_batch.fingerprint || ':' || (v_batch.attempt_count+1)::text || ':' || gen_random_uuid()::text,'sha256'),'hex');
  insert into public.material_processing_attempts(
    batch_id,job_id,material_id,user_id,attempt_number,predecessor_attempt_id,
    idempotency_key,status,budget_effect,ambiguity_state
  ) values (
    v_batch.id,v_batch.job_id,v_batch.material_id,v_batch.user_id,v_batch.attempt_count+1,
    v_batch.pending_predecessor_attempt_id,v_key,'submitted','consumed','none'
  ) returning id into v_attempt_id;
  update public.material_processing_batches set status='submitted',attempt_count=attempt_count+1,
    current_attempt_id=v_attempt_id,pending_predecessor_attempt_id=null,budget_state='consumed',
    lease_expires_at=now()+interval '120 seconds',updated_at=now() where id=v_batch.id;
  update public.material_processing_jobs set budget_state='consumed',updated_at=now()
  where id=v_batch.job_id and active_lease_token=p_lease_token;
  if v_batch.operation in ('page_text','page_visual','page_recovery') then
    update public.material_processing_pages set status='processing',
      grouped_attempts=grouped_attempts+case when v_batch.operation='page_recovery' then 0 else 1 end,
      recovery_attempts=recovery_attempts+case when v_batch.operation='page_recovery' then 1 else 0 end,
      total_upstream_attempts=total_upstream_attempts+1,updated_at=now()
    where job_id=v_batch.job_id and active_batch_id=v_batch.id and status='batched';
  end if;
  return v_attempt_id;
end
$$;

create or replace function public.mark_material_processing_dispatch_unknown_internal(
  p_batch_id uuid,p_lease_token uuid
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_attempt uuid;
begin
  update public.material_processing_batches b set status='dispatch_unknown',ambiguous_since=now(),updated_at=now()
  from public.material_processing_jobs j where b.id=p_batch_id and b.status='submitted'
    and b.lease_token=p_lease_token and j.id=b.job_id and j.active_lease_token=p_lease_token
  returning b.current_attempt_id into v_attempt;
  if not found then raise exception 'dispatch_unknown_conflict'; end if;
  update public.material_processing_attempts set status='dispatch_unknown',ambiguity_state='unknown',
    budget_effect='retained',updated_at=now() where id=v_attempt;
end
$$;

create or replace function public.mark_material_processing_response_known_internal(
  p_batch_id uuid,p_lease_token uuid,p_response_id text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_attempt uuid;
begin
  if length(btrim(p_response_id)) not between 8 and 200 then raise exception 'invalid_response_id'; end if;
  update public.material_processing_batches b set status='response_known',upstream_response_id=btrim(p_response_id),updated_at=now()
  from public.material_processing_jobs j where b.id=p_batch_id
    and b.status in ('submitted','dispatch_unknown','reconciliation_required')
    and b.lease_token=p_lease_token and j.id=b.job_id and j.active_lease_token=p_lease_token
  returning b.current_attempt_id into v_attempt;
  if not found then raise exception 'response_known_conflict'; end if;
  update public.material_processing_attempts set status='response_known',upstream_response_id=btrim(p_response_id),
    ambiguity_state='none',budget_effect='retained',updated_at=now() where id=v_attempt;
end
$$;

create or replace function public.complete_material_processing_page_internal(
  p_job_id uuid,p_page_number integer,p_lease_token uuid,p_terminal_status text,p_result jsonb,p_warnings jsonb,
  p_validation_version text,p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if p_terminal_status not in ('completed','partial','missing')
    or p_validation_version <> 'phase-c-validator-v2' or p_validation_hash !~ '^[0-9a-f]{64}$'
    or not public.material_analysis_safe_warnings(p_warnings)
    or (p_terminal_status in ('completed','partial') and not public.material_analysis_valid_page_payload(p_result))
    or (p_terminal_status='partial' and ((p_result->>'trustworthy')::boolean is not true or jsonb_array_length(p_warnings)=0))
    or (p_terminal_status='completed' and (p_result->>'trustworthy')::boolean is not true)
    or (p_terminal_status='missing' and (p_result is not null or jsonb_array_length(p_warnings)=0))
  then raise exception 'invalid_terminal_page_payload'; end if;
  if p_result is not null and (p_result->>'page_number')::integer <> p_page_number then
    raise exception 'page_payload_mismatch'; end if;
  update public.material_processing_pages page set status=p_terminal_status,result_payload=p_result,
    result_schema_version=case when p_result is null then null else 1 end,
    validation_version=p_validation_version,validation_hash=p_validation_hash,
    warning_payload=p_warnings,active_batch_id=null,terminal_at=now(),updated_at=now()
  from public.material_processing_batches batch,public.material_processing_jobs job
  where page.job_id=p_job_id and page.page_number=p_page_number and page.status='processing'
    and batch.id=page.active_batch_id and batch.lease_token=p_lease_token
    and job.id=page.job_id and job.active_lease_token=p_lease_token;
  if not found then raise exception 'page_completion_conflict'; end if;
end
$$;

create or replace function public.complete_material_processing_batch_internal(
  p_batch_id uuid,p_lease_token uuid,p_validated_result jsonb,
  p_validation_version text,p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype;
begin
  if p_validation_version <> 'phase-c-validator-v2' or p_validation_hash !~ '^[0-9a-f]{64}$'
    then raise exception 'invalid_result'; end if;
  select b.* into v_batch from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id
  where b.id=p_batch_id and b.lease_token=p_lease_token and j.active_lease_token=p_lease_token
    and b.status in ('response_known','reconciliation_required') and b.upstream_response_id is not null
  for update of b;
  if not found then raise exception 'batch_completion_conflict'; end if;
  if not public.material_analysis_valid_batch_payload(p_validated_result,v_batch.operation)
    then raise exception 'invalid_result'; end if;
  update public.material_processing_attempts set status='completed',budget_effect='retained',completed_at=now(),updated_at=now()
  where id=v_batch.current_attempt_id;
  update public.material_processing_batches set status='completed',result_payload=p_validated_result,
    result_schema_version=1,validation_version=p_validation_version,validation_hash=p_validation_hash,
    completed_at=now(),lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  update public.material_processing_jobs set status='prepared',active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_batch.job_id and active_lease_token=p_lease_token;
end
$$;

create or replace function public.fail_material_processing_batch_internal(
  p_batch_id uuid,p_lease_token uuid,p_failure_class text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype; v_new text; v_job text;
begin
  if p_failure_class not in ('pre_dispatch_retryable','retryable_response','non_retryable','reconcile_only','user_retry_required')
    then raise exception 'invalid_failure_class'; end if;
  select b.* into v_batch from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id
  where b.id=p_batch_id and b.lease_token=p_lease_token and j.active_lease_token=p_lease_token
  for update of b;
  if not found then raise exception 'batch_failure_conflict'; end if;
  if p_failure_class='pre_dispatch_retryable' and v_batch.status<>'prepared' then raise exception 'dispatch_already_started'; end if;
  if p_failure_class='retryable_response' and v_batch.status<>'submitted' then raise exception 'response_retry_not_allowed'; end if;
  if p_failure_class='reconcile_only' and v_batch.upstream_response_id is null then raise exception 'response_id_required'; end if;
  v_new := case p_failure_class when 'pre_dispatch_retryable' then 'prepared'
    when 'retryable_response' then 'prepared' when 'reconcile_only' then 'reconciliation_required'
    when 'user_retry_required' then 'user_retry_required' else 'failed' end;
  v_job := case p_failure_class when 'reconcile_only' then 'reconciliation_required'
    when 'user_retry_required' then 'user_retry_required' when 'non_retryable' then 'failed' else 'prepared' end;
  if v_batch.current_attempt_id is not null then
    update public.material_processing_attempts set status=case
      when p_failure_class='reconcile_only' then 'reconciliation_required'
      when p_failure_class='user_retry_required' then status else 'failed' end,
      failure_code=p_failure_class,budget_effect=case when p_failure_class='non_retryable' then 'released' else 'retained' end,
      ambiguity_state=case when p_failure_class='user_retry_required' then 'user_retry'
        when p_failure_class='reconcile_only' then 'reconcile' else ambiguity_state end,
      completed_at=case when p_failure_class in ('retryable_response','non_retryable') then now() end,
      updated_at=now() where id=v_batch.current_attempt_id;
  end if;
  if p_failure_class='pre_dispatch_retryable' then
    update public.material_processing_batches set failure_code=p_failure_class,
      lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  else
    update public.material_processing_batches set status=v_new,
      pending_predecessor_attempt_id=case when p_failure_class='retryable_response' then current_attempt_id else pending_predecessor_attempt_id end,
      current_attempt_id=case when p_failure_class='retryable_response' then null else current_attempt_id end,
      ambiguous_since=case when p_failure_class='user_retry_required' then coalesce(ambiguous_since,now()) else ambiguous_since end,
      failure_code=p_failure_class,budget_state=case when p_failure_class='non_retryable' then 'released' else budget_state end,
      completed_at=case when p_failure_class='non_retryable' then now() end,
      lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  end if;
  update public.material_processing_jobs set status=v_job,
    budget_state=case when p_failure_class='non_retryable' then 'released' else budget_state end,
    active_lease_token=null,active_lease_expires_at=null,
    completed_at=case when p_failure_class='non_retryable' then now() end,updated_at=now()
  where id=v_batch.job_id and active_lease_token=p_lease_token;
end
$$;

create or replace function public.recover_expired_material_processing_batch_internal(p_batch_id uuid)
returns text language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype; v_new text; v_job text;
begin
  select * into v_batch from public.material_processing_batches where id=p_batch_id for update;
  if not found or v_batch.status in ('completed','failed') then raise exception 'batch_not_recoverable'; end if;
  if v_batch.lease_token is not null and v_batch.lease_expires_at>now() then raise exception 'lease_still_valid'; end if;
  if v_batch.status='prepared' then v_new:='prepared'; v_job:='prepared';
  elsif v_batch.status in ('submitted','response_known','dispatch_unknown') and v_batch.upstream_response_id is not null then
    v_new:='reconciliation_required';v_job:='reconciliation_required';
  elsif v_batch.status in ('submitted','dispatch_unknown') then
    v_new:='user_retry_required';v_job:='user_retry_required';
  elsif v_batch.status='response_known' then raise exception 'response_id_required';
  elsif v_batch.status='reconciliation_required' then v_new:='reconciliation_required';v_job:='reconciliation_required';
  else v_new:='user_retry_required';v_job:='user_retry_required'; end if;
  if v_batch.current_attempt_id is not null and v_new in ('reconciliation_required','user_retry_required') then
    update public.material_processing_attempts set
      status=case when v_new='reconciliation_required' then 'reconciliation_required'
        when status='submitted' then 'dispatch_unknown' else status end,
      ambiguity_state=case when v_new='reconciliation_required' then 'reconcile' else 'user_retry' end,
      budget_effect='retained',updated_at=now() where id=v_batch.current_attempt_id;
  end if;
  if v_batch.status<>v_new then
    update public.material_processing_batches set status=v_new,
      ambiguous_since=case when v_new='user_retry_required' then coalesce(ambiguous_since,now()) else ambiguous_since end,
      lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  else
    update public.material_processing_batches set lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  end if;
  update public.material_processing_jobs set status=v_job,active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_batch.job_id
    and status<>v_job and (active_lease_token is null or active_lease_expires_at<=now());
  if not found then
    update public.material_processing_jobs set active_lease_token=null,
      active_lease_expires_at=null,updated_at=now() where id=v_batch.job_id and status=v_job
      and (active_lease_token is null or active_lease_expires_at<=now());
  end if;
  return v_new;
end
$$;

create or replace function public.authorize_material_analysis_retry(p_material_id uuid)
returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype; v_batch public.material_processing_batches%rowtype; v_id uuid;
begin
  select j.* into v_job from public.material_processing_jobs j join public.materials m
    on m.id=j.material_id and m.user_id=j.user_id
  where j.material_id=p_material_id and m.user_id=auth.uid() and m.deleted_at is null
    and j.status='user_retry_required' for update of j;
  if not found then raise exception 'retry_not_allowed'; end if;
  select * into v_batch from public.material_processing_batches
  where job_id=v_job.id and status='user_retry_required' order by updated_at desc limit 1 for update;
  if not found or v_batch.current_attempt_id is null then raise exception 'retry_attempt_unavailable'; end if;
  insert into public.material_processing_retry_authorizations(
    job_id,batch_id,material_id,user_id,predecessor_attempt_id
  ) values (v_job.id,v_batch.id,v_job.material_id,v_job.user_id,v_batch.current_attempt_id)
  returning id into v_id;
  return v_id;
end
$$;

create or replace function public.request_material_processing_retry_internal(
  p_material_id uuid,p_authorization_id uuid
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_auth public.material_processing_retry_authorizations%rowtype;
begin
  select * into v_auth from public.material_processing_retry_authorizations
  where id=p_authorization_id and material_id=p_material_id and consumed_at is null and expires_at>now() for update;
  if not found then raise exception 'retry_authorization_invalid'; end if;
  update public.material_processing_retry_authorizations set consumed_at=now() where id=v_auth.id;
  update public.material_processing_batches set status='prepared',pending_predecessor_attempt_id=v_auth.predecessor_attempt_id,
    current_attempt_id=null,upstream_response_id=null,lease_token=null,lease_expires_at=null,updated_at=now()
  where id=v_auth.batch_id and job_id=v_auth.job_id and status='user_retry_required';
  if not found then raise exception 'retry_batch_conflict'; end if;
  update public.material_processing_pages set status='pending',active_batch_id=null,updated_at=now()
  where job_id=v_auth.job_id and active_batch_id=v_auth.batch_id and status='processing';
  update public.material_processing_pages page set status='batched',active_batch_id=v_auth.batch_id,updated_at=now()
  from public.material_processing_batches batch
  where batch.id=v_auth.batch_id and page.job_id=v_auth.job_id
    and page.page_number=any(batch.page_numbers) and page.status='pending';
  update public.material_processing_jobs set status='prepared',last_user_retry_authorization_id=v_auth.id,
    updated_at=now() where id=v_auth.job_id and status='user_retry_required';
  return v_auth.job_id;
end
$$;

create or replace function public.finalize_material_processing_job_internal(
  p_job_id uuid,p_lease_token uuid,p_summary_payload jsonb,p_summary_markdown text,
  p_validation_version text,p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype; v_count integer; v_min integer; v_max integer;
  v_distinct integer; v_terminal integer; v_nonterminal integer; v_warn integer;
  v_batch public.material_processing_batches%rowtype;
begin
  if p_validation_version<>'phase-c-validator-v2' or p_validation_hash !~ '^[0-9a-f]{64}$'
    or not public.material_analysis_valid_summary_payload(p_summary_payload)
    or p_summary_markdown is null or length(p_summary_markdown)>100000 then raise exception 'invalid_summary_payload'; end if;
  select * into v_job from public.material_processing_jobs
  where id=p_job_id and status='processing' and active_lease_token=p_lease_token for update;
  if not found then raise exception 'job_unavailable'; end if;
  select count(*),min(page_number),max(page_number),count(distinct page_number),
    count(*) filter(where status in ('completed','partial','missing')),
    count(*) filter(where status not in ('completed','partial','missing')),
    count(*) filter(where status in ('partial','missing'))
  into v_count,v_min,v_max,v_distinct,v_terminal,v_nonterminal,v_warn
  from public.material_processing_pages where job_id=v_job.id;
  if v_count<>v_job.page_count or v_min<>1 or v_max<>v_job.page_count
    or v_distinct<>v_job.page_count or v_terminal<>v_job.page_count or v_nonterminal<>0
  then raise exception 'page_manifest_incomplete'; end if;
  select * into v_batch from public.material_processing_batches
  where job_id=v_job.id and operation='final_summary' and lease_token=p_lease_token
    and status in ('response_known','reconciliation_required') and upstream_response_id is not null
  for update;
  if not found then raise exception 'final_summary_batch_required'; end if;
  update public.material_processing_attempts set status='completed',budget_effect='retained',
    completed_at=now(),updated_at=now() where id=v_batch.current_attempt_id;
  update public.material_processing_batches set status='completed',result_payload=jsonb_build_object(
      'schema_version',1,'operation','final_summary','content',p_summary_payload),
    result_schema_version=1,validation_version=p_validation_version,validation_hash=p_validation_hash,
    completed_at=now(),lease_token=null,lease_expires_at=null,updated_at=now() where id=v_batch.id;
  update public.materials set summary=p_summary_markdown,summary_payload=p_summary_payload,
    summary_schema_version=1,summary_processing_mode=v_job.processing_mode,
    summary_validation_version=p_validation_version,summary_validation_hash=p_validation_hash
  where id=v_job.material_id and user_id=v_job.user_id;
  update public.material_processing_jobs set
    status=case when v_warn>0 then 'completed_with_warnings' else 'completed' end,
    completed_at=now(),budget_state='consumed',active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_job.id;
end
$$;

create or replace function public.get_material_analysis_status(p_material_id uuid)
returns table(
  material_id uuid,processing_mode text,state text,public_stage text,page_count integer,
  completed_pages integer,confirmation_required boolean,can_retry boolean,
  retry_after_seconds integer,warnings jsonb,summary_schema_version integer,summary_payload jsonb
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,j.processing_mode,case when j.status='prepared' then 'processing' else j.status end,
    j.public_stage,j.page_count,j.completed_page_count,j.confirmation_required,
    j.status='user_retry_required',
    case when j.next_retry_at is null then null
      else greatest(0,least(900,extract(epoch from (j.next_retry_at-now()))::integer)) end,
    j.warning_payload,m.summary_schema_version,
    case when m.summary_validation_version='phase-c-validator-v2'
      and m.summary_validation_hash ~ '^[0-9a-f]{64}$'
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload else null end
  from public.materials m join public.material_processing_jobs j
    on j.material_id=m.id and j.user_id=m.user_id
  where m.id=p_material_id and m.user_id=auth.uid() and m.deleted_at is null;
$$;

do $$
declare f regprocedure;
begin
  foreach f in array array[
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text)'::regprocedure,
    'public.create_material_processing_batch_internal(uuid,text,integer[],text)'::regprocedure,
    'public.claim_material_processing_batch_internal(uuid,text)'::regprocedure,
    'public.mark_material_processing_batch_submitted_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_dispatch_unknown_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_response_known_internal(uuid,uuid,text)'::regprocedure,
    'public.complete_material_processing_page_internal(uuid,integer,uuid,text,jsonb,jsonb,text,text)'::regprocedure,
    'public.complete_material_processing_batch_internal(uuid,uuid,jsonb,text,text)'::regprocedure,
    'public.fail_material_processing_batch_internal(uuid,uuid,text)'::regprocedure,
    'public.recover_expired_material_processing_batch_internal(uuid)'::regprocedure,
    'public.request_material_processing_retry_internal(uuid,uuid)'::regprocedure,
    'public.finalize_material_processing_job_internal(uuid,uuid,jsonb,text,text,text)'::regprocedure
  ] loop
    execute format('alter function %s owner to material_analysis_executor',f);
    execute format('revoke all on function %s from public, anon, authenticated',f);
    execute format('grant execute on function %s to service_role',f);
  end loop;
end
$$;

alter function public.confirm_material_analysis(uuid) owner to material_analysis_executor;
alter function public.authorize_material_analysis_retry(uuid) owner to material_analysis_executor;
alter function public.get_material_analysis_status(uuid) owner to material_analysis_executor;
revoke all on function public.confirm_material_analysis(uuid) from public,anon,service_role;
revoke all on function public.authorize_material_analysis_retry(uuid) from public,anon,service_role;
revoke all on function public.get_material_analysis_status(uuid) from public,anon,service_role;
grant execute on function public.confirm_material_analysis(uuid) to authenticated;
grant execute on function public.authorize_material_analysis_retry(uuid) to authenticated;
grant execute on function public.get_material_analysis_status(uuid) to authenticated;

revoke all on function public.material_analysis_safe_warnings(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.material_analysis_valid_page_payload(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.material_analysis_valid_summary_payload(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.material_analysis_valid_batch_payload(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.material_analysis_valid_page_numbers(integer[]) from public,anon,authenticated,service_role;
grant execute on function public.material_analysis_safe_warnings(jsonb) to material_analysis_executor;
grant execute on function public.material_analysis_valid_page_payload(jsonb) to material_analysis_executor;
grant execute on function public.material_analysis_valid_summary_payload(jsonb) to material_analysis_executor;
grant execute on function public.material_analysis_valid_batch_payload(jsonb,text) to material_analysis_executor;
grant execute on function public.material_analysis_valid_page_numbers(integer[]) to material_analysis_executor;

revoke all on function public.enforce_material_processing_job_row() from public,anon,authenticated,service_role;
revoke all on function public.enforce_material_processing_page_row() from public,anon,authenticated,service_role;
revoke all on function public.enforce_material_processing_batch_row() from public,anon,authenticated,service_role;
revoke all on function public.enforce_material_processing_attempt_row() from public,anon,authenticated,service_role;
revoke all on function public.refresh_material_processing_progress() from public,anon,authenticated,service_role;
revoke all on function public.reject_material_processing_status_self_transition() from public,anon,authenticated,service_role;

-- Legacy OCR metadata remains readable by trusted legacy functions, but Phase C
-- adds no model/provider/token fields and exposes none through its public RPC.
notify pgrst,'reload schema';
