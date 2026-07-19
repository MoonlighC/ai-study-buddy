-- Temporary staging-only correlation for one deterministic diagnostic fixture.
-- The correlation is generated internally, never accepted from a caller, and
-- can attach only to the pre-committed one-page vector fixture content hash.

create table public.material_analysis_diagnostic_correlations (
  correlation_id uuid primary key default gen_random_uuid(),
  material_id uuid references public.materials(id) on delete cascade,
  job_id uuid references public.material_processing_jobs(id) on delete cascade,
  final_batch_id uuid references public.material_processing_batches(id) on delete cascade,
  status text not null default 'awaiting_fixture' check (
    status in ('awaiting_fixture','attached','ready','consumed')
  ),
  created_at timestamptz not null default now(),
  consumed_at timestamptz,
  check (
    (status = 'awaiting_fixture' and material_id is null and job_id is null
      and final_batch_id is null and consumed_at is null)
    or (status = 'attached' and material_id is not null and job_id is not null
      and final_batch_id is null and consumed_at is null)
    or (status = 'ready' and material_id is not null and job_id is not null
      and final_batch_id is not null and consumed_at is null)
    or (status = 'consumed' and material_id is not null and job_id is not null
      and final_batch_id is not null and consumed_at is not null)
  )
);

create unique index material_analysis_diagnostic_one_active_correlation
  on public.material_analysis_diagnostic_correlations ((consumed_at is null))
  where consumed_at is null;

alter table public.material_analysis_diagnostic_correlations enable row level security;
alter table public.material_analysis_diagnostic_correlations force row level security;
revoke all on table public.material_analysis_diagnostic_correlations
  from public, anon, authenticated, service_role;

insert into public.material_analysis_diagnostic_correlations default values
on conflict do nothing;

create or replace function public.attach_material_analysis_diagnostic_job_internal()
returns trigger language plpgsql volatile security definer
set search_path = pg_catalog, public
as $$
declare
  v_count integer;
begin
  if new.source_hash <> '9c4df300f7bff18e8522322f3973b36bdc3186122af01ffdbc5852669b40f46a'
    or new.page_count <> 1
    or new.processing_mode <> 'recommended'
    or new.generation <> 1
  then
    return new;
  end if;

  if not exists (
    select 1
    from public.materials m
    where m.id = new.material_id
      and m.user_id = new.user_id
      and m.deleted_at is null
      and m.kind = 'pdf'
      and m.source_kind = 'upload'
      and m.storage_bucket is not null
      and m.storage_path is not null
  ) then
    return new;
  end if;

  select pg_catalog.count(*) into v_count
  from public.material_analysis_diagnostic_correlations c
  where c.status = 'awaiting_fixture'
    and c.consumed_at is null
    and c.created_at <= new.created_at
    and exists (
      select 1 from public.materials m
      where m.id = new.material_id and m.created_at >= c.created_at
    );
  if v_count <> 1 then
    raise exception 'diagnostic_target_unavailable';
  end if;

  update public.material_analysis_diagnostic_correlations c
  set material_id = new.material_id,
      job_id = new.id,
      status = 'attached'
  where c.status = 'awaiting_fixture'
    and c.consumed_at is null
    and c.created_at <= new.created_at
    and exists (
      select 1 from public.materials m
      where m.id = new.material_id and m.created_at >= c.created_at
    );
  get diagnostics v_count = row_count;
  if v_count <> 1 then
    raise exception 'diagnostic_target_unavailable';
  end if;
  return new;
end
$$;

create trigger attach_material_analysis_diagnostic_job
after update of source_hash on public.material_processing_jobs
for each row
when (old.source_hash is distinct from new.source_hash)
execute function public.attach_material_analysis_diagnostic_job_internal();

create or replace function public.attach_material_analysis_diagnostic_final_batch_internal()
returns trigger language plpgsql volatile security definer
set search_path = pg_catalog, public
as $$
declare
  v_count integer;
begin
  if new.operation <> 'final_summary' then return new; end if;
  update public.material_analysis_diagnostic_correlations c
  set final_batch_id = new.id,
      status = 'ready'
  where c.status = 'attached'
    and c.consumed_at is null
    and c.material_id = new.material_id
    and c.job_id = new.job_id;
  get diagnostics v_count = row_count;
  if v_count > 1 then raise exception 'diagnostic_target_unavailable'; end if;
  return new;
end
$$;

create trigger attach_material_analysis_diagnostic_final_batch
after insert on public.material_processing_batches
for each row
execute function public.attach_material_analysis_diagnostic_final_batch_internal();

create or replace function public.select_material_analysis_diagnostic_target_internal()
returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare
  v_targets jsonb[];
begin
  select pg_catalog.array_agg(candidate.target order by candidate.created_at)
  into v_targets
  from (
    select b.created_at, pg_catalog.jsonb_build_object(
      'operation', b.operation,
      'status', b.status,
      'response_id', b.upstream_response_id,
      'page_numbers', pg_catalog.to_jsonb(b.page_numbers),
      'page_count', j.page_count,
      'cleanup_state', b.cleanup_state
    ) as target
    from public.material_analysis_diagnostic_correlations c
    join public.material_processing_batches b
      on b.id = c.final_batch_id
      and b.job_id = c.job_id
      and b.material_id = c.material_id
    join public.material_processing_jobs j
      on j.id = c.job_id
      and j.id = b.job_id
      and j.material_id = c.material_id
      and j.material_id = b.material_id
      and j.user_id = b.user_id
    join public.materials m
      on m.id = c.material_id
      and m.id = b.material_id
      and m.user_id = b.user_id
      and m.deleted_at is null
    join auth.users u on u.id = b.user_id
    join public.material_processing_batches reduction
      on reduction.id = b.input_batch_ids[1]
      and reduction.job_id = b.job_id
      and reduction.material_id = b.material_id
      and reduction.user_id = b.user_id
    join public.material_processing_pages page
      on page.job_id = b.job_id
      and page.material_id = b.material_id
      and page.user_id = b.user_id
      and page.page_number = 1
    join public.material_processing_batches visual
      on visual.job_id = b.job_id
      and visual.material_id = b.material_id
      and visual.user_id = b.user_id
      and visual.page_numbers = array[page.page_number]
    join public.material_processing_attempts visual_attempt
      on visual_attempt.id = visual.current_attempt_id
      and visual_attempt.batch_id = visual.id
      and visual_attempt.job_id = b.job_id
      and visual_attempt.material_id = b.material_id
      and visual_attempt.user_id = b.user_id
    join public.material_processing_attempts reduction_attempt
      on reduction_attempt.id = reduction.current_attempt_id
      and reduction_attempt.batch_id = reduction.id
      and reduction_attempt.job_id = b.job_id
      and reduction_attempt.material_id = b.material_id
      and reduction_attempt.user_id = b.user_id
    join public.material_processing_attempts final_attempt
      on final_attempt.id = b.current_attempt_id
      and final_attempt.batch_id = b.id
      and final_attempt.job_id = b.job_id
      and final_attempt.material_id = b.material_id
      and final_attempt.user_id = b.user_id
    where c.status = 'ready'
      and c.consumed_at is null
      and b.operation = 'final_summary'
      and b.status = 'failed'
      and b.failure_code = 'non_retryable'
      and b.upstream_response_id is not null
      and pg_catalog.length(pg_catalog.btrim(b.upstream_response_id)) between 8 and 200
      and b.page_numbers = array[1]
      and b.reduction_level = 2
      and pg_catalog.cardinality(b.input_batch_ids) = 1
      and b.attempt_count = 1
      and b.cleanup_state = 'not_required'
      and b.diagnostic_code is null
      and b.diagnostic_metadata is null
      and b.diagnostic_version is null
      and b.diagnostic_recorded_at is null
      and j.page_count = 1
      and j.processing_mode = 'recommended'
      and j.status = 'failed'
      and j.completed_at is not null
      and m.kind = 'pdf'
      and m.source_kind = 'upload'
      and m.storage_bucket is not null
      and m.storage_path is not null
      and page.route = 'visual'
      and page.status = 'completed'
      and page.total_upstream_attempts = 1
      and reduction.operation = 'reduction'
      and reduction.status = 'completed'
      and reduction.page_numbers = array[1]
      and reduction.reduction_level = 1
      and pg_catalog.cardinality(reduction.input_batch_ids) = 0
      and reduction.attempt_count = 1
      and reduction.completed_at is not null
      and visual.operation = 'page_visual'
      and visual.status = 'completed'
      and visual.page_numbers = array[1]
      and visual.attempt_count = 1
      and visual.completed_at is not null
      and visual_attempt.status = 'completed'
      and visual_attempt.attempt_number = 1
      and visual_attempt.completed_at is not null
      and reduction_attempt.status = 'completed'
      and reduction_attempt.attempt_number = 1
      and reduction_attempt.completed_at is not null
      and final_attempt.status = 'failed'
      and final_attempt.failure_code = 'non_retryable'
      and final_attempt.attempt_number = 1
      and final_attempt.upstream_response_id = b.upstream_response_id
      and final_attempt.completed_at is not null
      and visual.created_at <= reduction.created_at
      and reduction.created_at <= b.created_at
      and visual_attempt.submitted_at <= reduction_attempt.submitted_at
      and reduction_attempt.submitted_at <= final_attempt.submitted_at
      and visual_attempt.completed_at <= reduction_attempt.submitted_at
      and reduction_attempt.completed_at <= final_attempt.submitted_at
      and (
        select pg_catalog.count(*)
        from public.material_processing_batches job_batch
        where job_batch.job_id = b.job_id
          and job_batch.material_id = b.material_id
          and job_batch.user_id = b.user_id
      ) = 3
      and (
        select pg_catalog.count(*)
        from public.material_processing_attempts attempt
        where attempt.job_id = b.job_id
          and attempt.material_id = b.material_id
          and attempt.user_id = b.user_id
      ) = 3
  ) candidate;

  if coalesce(pg_catalog.cardinality(v_targets), 0) <> 1 then
    raise exception 'diagnostic_target_unavailable';
  end if;
  return v_targets[1];
end
$$;

create or replace function public.record_correlated_material_analysis_diagnostic_internal(
  p_diagnostic_code text,
  p_diagnostic_metadata jsonb,
  p_diagnostic_version integer
) returns void language plpgsql volatile security definer
set search_path = pg_catalog, public
as $$
declare
  v_correlation_id uuid;
  v_batch_id uuid;
  v_count integer;
begin
  if (
    select pg_catalog.count(*)
    from public.material_analysis_diagnostic_correlations c
    join public.material_processing_batches b on b.id = c.final_batch_id
    where c.status = 'consumed'
      and c.consumed_at is not null
      and b.diagnostic_code = p_diagnostic_code
      and b.diagnostic_metadata = p_diagnostic_metadata
      and b.diagnostic_version = p_diagnostic_version
      and b.diagnostic_recorded_at is not null
  ) = 1 then
    return;
  end if;

  perform public.select_material_analysis_diagnostic_target_internal();
  select pg_catalog.count(*),
    (pg_catalog.array_agg(c.correlation_id))[1],
    (pg_catalog.array_agg(c.final_batch_id))[1]
  into v_count, v_correlation_id, v_batch_id
  from public.material_analysis_diagnostic_correlations c
  join public.material_processing_batches b on b.id = c.final_batch_id
  where c.status = 'ready'
    and c.consumed_at is null
    and b.diagnostic_code is null
    and b.diagnostic_metadata is null
    and b.diagnostic_version is null
    and b.diagnostic_recorded_at is null;
  if v_count <> 1 then raise exception 'diagnostic_target_unavailable'; end if;

  perform public.record_material_analysis_diagnostic_internal(
    v_batch_id,
    p_diagnostic_code,
    p_diagnostic_metadata,
    p_diagnostic_version
  );
  update public.material_analysis_diagnostic_correlations
  set status = 'consumed', consumed_at = now()
  where correlation_id = v_correlation_id
    and status = 'ready'
    and consumed_at is null;
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'diagnostic_target_unavailable'; end if;
end
$$;

do $$
declare
  f regprocedure;
begin
  if current_user <> 'postgres' then
    raise exception 'unexpected_material_analysis_diagnostic_owner';
  end if;
  foreach f in array array[
    'public.attach_material_analysis_diagnostic_job_internal()'::regprocedure,
    'public.attach_material_analysis_diagnostic_final_batch_internal()'::regprocedure,
    'public.select_material_analysis_diagnostic_target_internal()'::regprocedure,
    'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format(
      'revoke all on function %s from public, anon, authenticated, service_role',
      f
    );
  end loop;
  execute format(
    'grant execute on function %s to service_role',
    'public.select_material_analysis_diagnostic_target_internal()'::regprocedure
  );
  execute format(
    'grant execute on function %s to service_role',
    'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)'::regprocedure
  );
end
$$;

notify pgrst, 'reload schema';
