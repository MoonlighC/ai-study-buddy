-- Schedule one durable, single-page recovery operation for an initially
-- missing page or a low-confidence partial page before reduction starts.
-- The initial terminal page row is never reopened or overwritten. Recovery
-- intent, source snapshot, and the optional validated replacement are kept in
-- a separate generation-scoped row.

create table public.material_processing_page_recoveries(
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null unique references
    public.material_processing_batches(id) on delete cascade,
  job_id uuid not null,
  page_number integer not null check(page_number between 1 and 100),
  source_status text not null check(source_status in ('partial','missing')),
  source_result_payload jsonb,
  source_warning_payload jsonb not null,
  source_validation_version text not null check(
    source_validation_version in (
      'phase-c-validator-v2','phase-c-validator-v3'
    )
  ),
  source_validation_hash text not null check(
    source_validation_hash~'^[0-9a-f]{64}$'
  ),
  result_status text check(
    result_status is null or result_status in (
      'completed','partial','missing'
    )
  ),
  result_payload jsonb,
  result_warning_payload jsonb,
  result_validation_version text,
  result_validation_hash text,
  reconciled_at timestamptz,
  created_at timestamptz not null default now(),
  unique(job_id,page_number),
  foreign key(job_id,page_number) references
    public.material_processing_pages(job_id,page_number) on delete cascade,
  check(
    (
      source_status='partial'
      and public.material_analysis_valid_page_payload(
        source_result_payload
      )
    ) or (
      source_status='missing' and source_result_payload is null
    )
  ),
  check(public.material_analysis_safe_warnings_v2(
    source_warning_payload
  )),
  check(
    (
      result_status is null
      and result_payload is null
      and result_warning_payload is null
      and result_validation_version is null
      and result_validation_hash is null
      and reconciled_at is null
    ) or (
      result_status in ('completed','partial')
      and public.material_analysis_valid_page_payload(result_payload)
      and public.material_analysis_safe_warnings_v2(
        result_warning_payload
      )
      and result_validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      )
      and result_validation_hash~'^[0-9a-f]{64}$'
      and reconciled_at is not null
    ) or (
      result_status='missing'
      and result_payload is null
      and public.material_analysis_safe_warnings_v2(
        result_warning_payload
      )
      and result_validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      )
      and result_validation_hash~'^[0-9a-f]{64}$'
      and reconciled_at is not null
    )
  )
);

alter table public.material_processing_page_recoveries
  enable row level security;
alter table public.material_processing_page_recoveries
  force row level security;
revoke all on table public.material_processing_page_recoveries
  from public,anon,authenticated,service_role;

create or replace function
  public.enforce_material_processing_page_recovery_row()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.job_id<>new.job_id
    or old.page_number<>new.page_number
    or old.batch_id<>new.batch_id
    or old.source_status<>new.source_status
    or old.source_result_payload is distinct from new.source_result_payload
    or old.source_warning_payload is distinct from
      new.source_warning_payload
    or old.source_validation_version<>new.source_validation_version
    or old.source_validation_hash<>new.source_validation_hash
  then
    raise exception 'page_recovery_source_immutable';
  end if;
  if old.reconciled_at is not null
    or new.reconciled_at is null
  then
    raise exception 'terminal_page_recovery_immutable';
  end if;
  return new;
end
$$;

create trigger enforce_material_processing_page_recovery_row
before update on public.material_processing_page_recoveries
for each row execute function
  public.enforce_material_processing_page_recovery_row();

create view public.material_processing_effective_pages
with (security_barrier=true)
as
select
  page.job_id,
  page.page_number,
  case
    when recovery.reconciled_at is null then page.status
    when page.status='partial' and recovery.result_status='missing'
      then page.status
    else recovery.result_status
  end as status,
  case
    when recovery.reconciled_at is null then page.result_payload
    when page.status='partial' and recovery.result_status='missing'
      then page.result_payload
    else recovery.result_payload
  end as result_payload,
  case
    when recovery.reconciled_at is null then page.warning_payload
    when page.status='partial' and recovery.result_status='missing'
      then page.warning_payload
    else recovery.result_warning_payload
  end as warning_payload,
  case
    when recovery.reconciled_at is null then page.validation_version
    when page.status='partial' and recovery.result_status='missing'
      then page.validation_version
    else recovery.result_validation_version
  end as validation_version,
  case
    when recovery.reconciled_at is null then page.validation_hash
    when page.status='partial' and recovery.result_status='missing'
      then page.validation_hash
    else recovery.result_validation_hash
  end as validation_hash,
  page.route
from public.material_processing_pages page
left join public.material_processing_page_recoveries recovery
  on recovery.job_id=page.job_id
  and recovery.page_number=page.page_number;

revoke all on table public.material_processing_effective_pages
  from public,anon,authenticated,service_role;

create or replace function public.prepare_material_analysis_page_recoveries_internal(
  p_material_id uuid
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_job public.material_processing_jobs%rowtype;
  v_page public.material_processing_pages%rowtype;
  v_batch_id uuid;
  v_fingerprint text;
  v_candidates integer := 0;
  v_duplicates integer := 0;
begin
  select job.* into v_job
  from public.material_processing_jobs job
  join public.materials material
    on material.id=job.material_id
    and material.user_id=job.user_id
    and material.kind='pdf'
  where job.material_id=p_material_id
    and material.deleted_at is null
  order by job.generation desc
  limit 1
  for update of job;

  if not found
    or v_job.status<>'prepared'
    or v_job.active_lease_token is not null
    or exists(
      select 1 from public.material_processing_pages page
      where page.job_id=v_job.id
        and page.status not in ('completed','partial','missing')
    )
    or exists(
      select 1 from public.material_processing_batches batch
      where batch.job_id=v_job.id and batch.operation in (
        'reduction','final_summary'
      )
    )
  then
    return jsonb_build_object(
      'recovery_candidate_count',0,
      'recovery_submitted_count',0,
      'recovery_completed_count',0,
      'recovery_partial_count',0,
      'recovery_still_missing_count',0,
      'recovery_duplicate_submission_count',0
    );
  end if;

  for v_page in
    select page.*
    from public.material_processing_pages page
    where page.job_id=v_job.id
      and page.recovery_attempts=0
      and page.routing_signals->'source_render_exists'='true'::jsonb
      and coalesce(
        (page.routing_signals->>'blank_page_conclusive')::boolean,
        false
      ) is false
      and (
        page.status='missing'
        or (
          page.status='partial'
          and (page.result_payload->>'confidence')::numeric<0.5
        )
      )
      and not exists(
        select 1
        from public.material_processing_page_recoveries prior
        where prior.job_id=page.job_id
          and prior.page_number=page.page_number
      )
      and not exists(
        select 1 from public.material_processing_batches prior_batch
        where prior_batch.job_id=page.job_id
          and prior_batch.operation='page_recovery'
          and page.page_number=any(prior_batch.page_numbers)
      )
    order by page.page_number
    for update
  loop
    v_candidates:=v_candidates+1;
    v_fingerprint:=encode(extensions.digest(
      v_job.version_fingerprint||':post-page-recovery-v1:'||
      v_job.id::text||':'||v_page.page_number::text||':'||
      v_page.input_hash||':'||v_page.validation_hash,
      'sha256'
    ),'hex');
    insert into public.material_processing_batches(
      id,job_id,material_id,user_id,operation,page_numbers,fingerprint,
      max_attempts
    ) values (
      gen_random_uuid(),v_job.id,v_job.material_id,v_job.user_id,
      'page_recovery',
      array[v_page.page_number],v_fingerprint,1
    )
    on conflict (job_id,fingerprint) do nothing
    returning id into v_batch_id;
    if v_batch_id is null then
      v_duplicates:=v_duplicates+1;
      continue;
    end if;
    insert into public.material_processing_page_recoveries(
      batch_id,job_id,page_number,source_status,source_result_payload,
      source_warning_payload,source_validation_version,
      source_validation_hash
    ) values (
      v_batch_id,v_job.id,v_page.page_number,v_page.status,
      v_page.result_payload,v_page.warning_payload,
      v_page.validation_version,v_page.validation_hash
    )
    on conflict(job_id,page_number) do nothing;
    if not found then
      delete from public.material_processing_batches
      where id=v_batch_id;
      v_duplicates:=v_duplicates+1;
    end if;
    v_batch_id:=null;
  end loop;

  return jsonb_build_object(
    'recovery_candidate_count',v_candidates,
    'recovery_submitted_count',0,
    'recovery_completed_count',0,
    'recovery_partial_count',0,
    'recovery_still_missing_count',0,
    'recovery_duplicate_submission_count',v_duplicates
  );
end
$$;

create or replace function public.claim_next_material_analysis_operation_internal(
  p_material_id uuid
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_job public.material_processing_jobs%rowtype;
  v_batch public.material_processing_batches%rowtype;
  v_artifact public.material_processing_artifacts%rowtype;
  v_claim record;
  v_pages integer[];
  v_operation text;
  v_fingerprint text;
  v_batch_id uuid;
  v_route text;
  v_chars integer:=0;
  v_page record;
  v_level integer;
  v_inputs uuid[];
  v_token uuid:=gen_random_uuid();
begin
  select job.* into v_job
  from public.material_processing_jobs job
  join public.materials material
    on material.id=job.material_id and material.user_id=job.user_id
  where job.material_id=p_material_id and material.deleted_at is null
  order by job.generation desc
  limit 1
  for update of job;
  if not found then raise exception 'analysis_unavailable'; end if;

  if v_job.active_lease_token is not null
    and v_job.active_lease_expires_at<=now()
  then
    select * into v_batch
    from public.material_processing_batches
    where job_id=v_job.id and lease_token=v_job.active_lease_token
    limit 1;
    if found then
      perform public.recover_expired_material_processing_batch_internal(
        v_batch.id
      );
    end if;
    select * into v_job
    from public.material_processing_jobs
    where id=v_job.id
    for update;
  end if;
  if v_job.active_lease_token is not null
    and v_job.active_lease_expires_at>now()
  then
    return jsonb_build_object(
      'kind','none','material_id',p_material_id
    );
  end if;

  update public.material_processing_artifacts artifact
  set state='cleanup_pending',lease_token=null,lease_expires_at=null,
    cleanup_retry_after=null,updated_at=now()
  from public.material_processing_batches batch
  where artifact.job_id=v_job.id and artifact.batch_id=batch.id
    and artifact.state='uploaded'
    and artifact.lease_expires_at<=now()
    and batch.status='prepared';
  update public.material_processing_artifacts
  set state='manual_cleanup_required',lease_token=null,
    lease_expires_at=null,updated_at=now()
  where job_id=v_job.id and state='upload_intent'
    and lease_expires_at<=now();
  update public.material_processing_artifacts
  set state='manual_cleanup_required',lease_token=null,
    lease_expires_at=null,updated_at=now()
  where job_id=v_job.id and state='cleanup_pending'
    and cleanup_attempt_count>=10;
  select * into v_artifact
  from public.material_processing_artifacts
  where job_id=v_job.id and state='cleanup_pending'
    and cleanup_attempt_count<10
    and (cleanup_retry_after is null or cleanup_retry_after<=now())
  order by updated_at
  limit 1
  for update skip locked;
  if found then
    update public.material_processing_jobs
    set active_lease_token=v_token,
      active_lease_expires_at=now()+interval '120 seconds',
      updated_at=now()
    where id=v_job.id;
    update public.material_processing_artifacts
    set lease_token=v_token,
      lease_expires_at=now()+interval '120 seconds',
      cleanup_attempt_count=least(10,cleanup_attempt_count+1),
      updated_at=now()
    where id=v_artifact.id;
    return jsonb_build_object(
      'kind','cleanup','material_id',p_material_id,
      'batch_id',v_artifact.batch_id,'artifact_id',v_artifact.id,
      'lease_token',v_token,
      'temporary_file_id',v_artifact.provider_file_id
    );
  end if;
  if v_job.status in (
    'awaiting_confirmation','user_retry_required','completed',
    'completed_with_warnings','failed'
  ) then
    return jsonb_build_object(
      'kind','none','material_id',p_material_id
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_job.user_id::text,0)
  );
  if (
    select count(*)
    from public.material_processing_jobs
    where user_id=v_job.user_id and active_lease_expires_at>now()
  )>=2 then
    return jsonb_build_object(
      'kind','none','material_id',p_material_id
    );
  end if;

  if v_job.status='reconciliation_required' then
    select operation into v_operation
    from public.material_processing_batches
    where job_id=v_job.id and status='reconciliation_required'
    order by created_at
    limit 1;
    select * into v_claim
    from public.claim_material_processing_batch_internal(
      v_job.id,v_operation
    );
    return jsonb_set(
      public.material_analysis_work_payload(
        v_claim.batch_id,v_claim.lease_token
      ),
      '{kind}','"reconciliation"'
    );
  end if;

  select * into v_batch
  from public.material_processing_batches
  where job_id=v_job.id and status='prepared'
    and (retry_after is null or retry_after<=now())
  order by created_at
  limit 1;
  if not found then
    select route into v_route
    from public.material_processing_pages
    where job_id=v_job.id and status='pending'
    order by page_number
    limit 1;
    if found then
      v_pages:='{}';
      for v_page in
        select *
        from public.material_processing_pages
        where job_id=v_job.id and status='pending' and route=v_route
        order by page_number
      loop
        v_operation:=case
          when v_page.grouped_attempts>=2 then 'page_recovery'
          when v_route='visual' then 'page_visual'
          else 'page_text'
        end;
        if cardinality(v_pages)>=(
          case
            when v_operation in ('page_visual','page_recovery') then 5
            else 10
          end
        ) then
          exit;
        end if;
        if v_operation='page_text'
          and v_chars+length(v_page.normalized_text)+64>40000
        then
          exit;
        end if;
        v_pages:=array_append(v_pages,v_page.page_number);
        v_chars:=v_chars+length(v_page.normalized_text)+64;
      end loop;
      select encode(extensions.digest(
        v_job.version_fingerprint||':'||v_operation||':'||
        v_job.id::text||':'||array_to_string(v_pages,',')||':'||
        string_agg(input_hash,':' order by page_number)||
        case
          when max(grouped_attempts+recovery_attempts)=0 then ''
          else ':logical_generation:'||string_agg(
            page_number::text||'='||grouped_attempts::text||'/'||
            recovery_attempts::text,
            ':' order by page_number
          )
        end,
        'sha256'
      ),'hex') into v_fingerprint
      from public.material_processing_pages
      where job_id=v_job.id and page_number=any(v_pages);
      v_batch_id:=public.create_material_processing_batch_internal(
        v_job.id,v_operation,v_pages,v_fingerprint
      );
    elsif not exists(
      select 1
      from public.material_processing_pages
      where job_id=v_job.id
        and status not in ('completed','partial','missing')
    ) then
      select array_agg(page_number order by page_number)
      into v_pages
      from (
        select effective.page_number
        from public.material_processing_effective_pages effective
        where effective.job_id=v_job.id
          and effective.status in ('completed','partial')
          and not exists(
            select 1
            from public.material_processing_batches prior
            where prior.job_id=v_job.id
              and prior.operation='reduction'
              and prior.reduction_level=1
              and effective.page_number=any(prior.page_numbers)
          )
        order by effective.page_number
        limit 10
      ) usable;
      if not exists(
        select 1
        from public.material_processing_effective_pages effective
        where effective.job_id=v_job.id
          and effective.status in ('completed','partial')
      ) then
        update public.material_processing_jobs
        set status='failed',
          safe_error_code='unable_to_extract_content',
          budget_state='released',active_lease_token=null,
          active_lease_expires_at=null,completed_at=now(),
          updated_at=now()
        where id=v_job.id and status='prepared';
        update public.materials
        set processing_status='failed',updated_at=now()
        where id=v_job.material_id and user_id=v_job.user_id
          and processing_status in ('pending','processing');
        return jsonb_build_object(
          'kind','none','material_id',p_material_id
        );
      elsif cardinality(v_pages)>0 then
        select encode(extensions.digest(
          v_job.version_fingerprint||':reduction:1:'||
          v_job.id::text||':'||array_to_string(v_pages,',')||':'||
          string_agg(validation_hash,':' order by page_number),
          'sha256'
        ),'hex') into v_fingerprint
        from public.material_processing_effective_pages
        where job_id=v_job.id and page_number=any(v_pages);
        v_batch_id:=public.create_material_processing_batch_internal(
          v_job.id,'reduction',v_pages,v_fingerprint
        );
        update public.material_processing_batches
        set reduction_level=1
        where id=v_batch_id;
      elsif exists(
        select 1
        from public.material_processing_effective_pages effective
        where effective.job_id=v_job.id
          and effective.status in ('completed','partial')
      ) and not exists(
        select 1
        from public.material_processing_batches
        where job_id=v_job.id and operation='reduction'
          and status<>'completed'
      ) then
        select max(reduction_level) into v_level
        from public.material_processing_batches
        where job_id=v_job.id and operation='reduction'
          and status='completed';
        select array_agg(id order by created_at)
        into v_inputs
        from (
          select id,created_at
          from public.material_processing_batches batch
          where batch.job_id=v_job.id
            and batch.operation='reduction'
            and batch.status='completed'
            and batch.reduction_level=v_level
            and not exists(
              select 1
              from public.material_processing_batches parent
              where parent.job_id=v_job.id
                and parent.reduction_level=v_level+1
                and batch.id=any(parent.input_batch_ids)
            )
          order by created_at
          limit 10
        ) inputs;
        if cardinality(v_inputs)>1 then
          select array_agg(distinct page_number order by page_number)
          into v_pages
          from public.material_processing_batches batch,
            unnest(batch.page_numbers) page_number
          where batch.id=any(v_inputs);
          select encode(extensions.digest(
            v_job.version_fingerprint||':reduction:'||
            (v_level+1)::text||':'||v_job.id::text||':'||
            array_to_string(v_inputs,','),
            'sha256'
          ),'hex') into v_fingerprint;
          v_batch_id:=public.create_material_processing_batch_internal(
            v_job.id,'reduction',v_pages,v_fingerprint
          );
          update public.material_processing_batches
          set reduction_level=v_level+1,input_batch_ids=v_inputs
          where id=v_batch_id;
        elsif cardinality(v_inputs)=1 and not exists(
          select 1
          from public.material_processing_batches
          where job_id=v_job.id and operation='final_summary'
        ) then
          select page_numbers into v_pages
          from public.material_processing_batches
          where id=v_inputs[1];
          select encode(extensions.digest(
            v_job.version_fingerprint||':final:'||v_job.id::text||':'||
            v_inputs[1]::text,
            'sha256'
          ),'hex') into v_fingerprint;
          v_batch_id:=public.create_material_processing_batch_internal(
            v_job.id,'final_summary',v_pages,v_fingerprint
          );
          update public.material_processing_batches
          set input_batch_ids=v_inputs,reduction_level=v_level+1
          where id=v_batch_id;
        end if;
      end if;
    end if;
    if v_batch_id is null then
      return jsonb_build_object(
        'kind','none','material_id',p_material_id
      );
    end if;
    select * into v_batch
    from public.material_processing_batches
    where id=v_batch_id;
  end if;

  select * into v_claim
  from public.claim_material_processing_batch_internal(
    v_job.id,v_batch.operation
  );
  update public.material_processing_jobs
  set public_stage=case
    when v_batch.operation='page_text' then 'analyzing_pages'
    when v_batch.operation in ('page_visual','page_recovery')
      then 'recognizing_formulas_and_diagrams'
    else 'creating_summary'
  end
  where id=v_job.id;
  return public.material_analysis_work_payload(
    v_claim.batch_id,v_claim.lease_token
  );
exception
  when lock_not_available then
    return jsonb_build_object(
      'kind','none','material_id',p_material_id
    );
end
$$;

create or replace function public.complete_material_analysis_operation_internal(
  p_batch_id uuid,
  p_lease_token uuid,
  p_validated_result jsonb,
  p_validation_version text,
  p_validation_hash text,
  p_summary_markdown text default null,
  p_cleanup_complete boolean default true
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
  v_existing public.material_processing_pages%rowtype;
  v_page jsonb;
  v_persisted_page jsonb;
  v_status text;
  v_post_recovery boolean;
begin
  select * into v_batch
  from public.material_processing_batches
  where id=p_batch_id and lease_token=p_lease_token
  for update;
  if not found then raise exception 'operation_completion_conflict'; end if;

  if v_batch.operation in ('page_text','page_visual','page_recovery') then
    if jsonb_typeof(p_validated_result->'pages')<>'array'
      or jsonb_array_length(p_validated_result->'pages')<>
        cardinality(v_batch.page_numbers)
    then raise exception 'invalid_page_batch_result'; end if;

    for v_page in
      select value from jsonb_array_elements(p_validated_result->'pages')
    loop
      v_status:=v_page->>'content_status';
      if v_status not in ('completed','partial','missing')
        or (v_page->>'trustworthy')::boolean is not true
        or not public.material_analysis_safe_warnings_v2(v_page->'warnings')
        or (v_status='completed' and exists(
          select 1
          from jsonb_array_elements(v_page->'warnings') warning(value)
          where warning.value->>'code' in (
            'page_content_partial','page_content_missing'
          )
        ))
        or (v_status='partial' and not exists(
          select 1
          from jsonb_array_elements(v_page->'warnings') warning(value)
          where warning.value->>'code'='page_content_partial'
        ))
        or (v_status='missing' and (
          coalesce(v_page->>'summary_markdown','')<>''
          or jsonb_array_length(v_page->'key_concepts')<>0
          or jsonb_array_length(v_page->'equations')<>0
          or (v_page->>'confidence')::numeric<>0
          or not exists(
            select 1
            from jsonb_array_elements(v_page->'warnings') warning(value)
            where warning.value->>'code'='page_content_missing'
          )
        ))
      then raise exception 'invalid_page_content_contract'; end if;

      select exists(
        select 1
        from public.material_processing_page_recoveries recovery
        where recovery.batch_id=v_batch.id
      ) into v_post_recovery;
      if v_post_recovery then
        if cardinality(v_batch.page_numbers)<>1
          or (v_page->>'page_number')::integer<>
            v_batch.page_numbers[1]
        then
          raise exception 'page_recovery_provenance_conflict';
        end if;
        v_persisted_page:=case
          when v_status='missing' then null
          else v_page-'content_status'
        end;
        update public.material_processing_page_recoveries recovery
        set result_status=v_status,
          result_payload=v_persisted_page,
          result_warning_payload=v_page->'warnings',
          result_validation_version=p_validation_version,
          result_validation_hash=encode(
            extensions.digest(v_page::text,'sha256'),'hex'
          ),
          reconciled_at=now()
        where recovery.batch_id=v_batch.id
          and recovery.reconciled_at is null;
        if not found then
          raise exception 'page_recovery_completion_conflict';
        end if;
      else
        select * into v_existing
        from public.material_processing_pages
        where job_id=v_batch.job_id
          and page_number=(v_page->>'page_number')::integer
          and active_batch_id=v_batch.id
          and status='processing'
        for update;
        if not found then
          raise exception 'page_completion_conflict';
        end if;
        v_persisted_page:=case
          when v_status='missing' then null
          else v_page-'content_status'
        end;
        perform public.complete_material_processing_page_internal(
          v_batch.job_id,
          v_existing.page_number,
          p_lease_token,
          v_status,
          v_persisted_page,
          v_page->'warnings',
          p_validation_version,
          encode(extensions.digest(v_page::text,'sha256'),'hex')
        );
      end if;
    end loop;
    perform public.complete_material_processing_batch_internal(
      p_batch_id,
      p_lease_token,
      jsonb_build_object(
        'schema_version',1,
        'operation',v_batch.operation,
        'content',p_validated_result
      ),
      p_validation_version,
      p_validation_hash
    );
  elsif v_batch.operation='reduction' then
    if not public.material_analysis_safe_warnings_v2(
      p_validated_result->'warnings'
    ) then
      raise exception 'invalid_analysis_warning_code';
    end if;
    perform public.complete_material_processing_batch_internal(
      p_batch_id,
      p_lease_token,
      jsonb_build_object(
        'schema_version',1,
        'operation','reduction',
        'content',p_validated_result
      ),
      p_validation_version,
      p_validation_hash
    );
  else
    if not public.material_analysis_safe_warnings_v2(
      p_validated_result->'warnings'
    ) then
      raise exception 'invalid_analysis_warning_code';
    end if;
    perform public.finalize_material_processing_job_internal(
      v_batch.job_id,
      p_lease_token,
      p_validated_result,
      p_summary_markdown,
      p_validation_version,
      p_validation_hash
    );
  end if;

  if v_batch.temporary_file_id is not null then
    update public.material_processing_artifacts
    set state='cleanup_pending',
      lease_token=null,
      lease_expires_at=null,
      cleanup_retry_after=null,
      updated_at=now()
    where batch_id=p_batch_id and state='uploaded';
  end if;
end
$$;

create or replace function public.material_analysis_work_payload(
  p_batch_id uuid,p_lease_token uuid
) returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
  v_job public.material_processing_jobs%rowtype;
  v_payload jsonb;
  v_key text;
begin
  select * into v_batch
  from public.material_processing_batches
  where id=p_batch_id and lease_token=p_lease_token;
  if not found then raise exception 'work_lease_invalid'; end if;
  select * into v_job
  from public.material_processing_jobs
  where id=v_batch.job_id;
  select attempt.idempotency_key into v_key
  from public.material_processing_attempts attempt
  where attempt.id=v_batch.current_attempt_id;

  if v_batch.operation='page_text' then
    select jsonb_build_object(
      'pages',jsonb_agg(jsonb_build_object(
        'page_number',page.page_number,
        'normalized_text',page.normalized_text
      ) order by page.page_number)
    ) into v_payload
    from public.material_processing_pages page
    where page.job_id=v_batch.job_id
      and page.page_number=any(v_batch.page_numbers);
  elsif v_batch.operation in ('page_visual','page_recovery') then
    v_payload:=jsonb_build_object(
      'operation',v_batch.operation,
      'page_numbers',to_jsonb(v_batch.page_numbers)
    );
  elsif v_batch.operation='reduction' then
    if cardinality(v_batch.input_batch_ids)>0 then
      select jsonb_build_object(
        'inputs',jsonb_agg(
          batch.result_payload->'content' order by batch.created_at
        ),
        'equation_ids',coalesce(jsonb_agg(
          batch.result_payload->'content'->'equation_ids'
        ),'[]'::jsonb)
      ) into v_payload
      from public.material_processing_batches batch
      where batch.id=any(v_batch.input_batch_ids);
    else
      select jsonb_build_object(
        'inputs',jsonb_agg(
          page.result_payload order by page.page_number
        ),
        'equation_ids',coalesce(jsonb_agg(
          page.result_payload->'equations'
        ),'[]'::jsonb)
      ) into v_payload
      from public.material_processing_effective_pages page
      where page.job_id=v_batch.job_id
        and page.page_number=any(v_batch.page_numbers)
        and page.status in ('completed','partial');
    end if;
  else
    select jsonb_build_object(
      'operation','final_summary',
      'validated_reduction',top.result_payload->'content',
      'authoritative_equations',coalesce((
        select jsonb_agg(
          equation.value order by page.page_number,equation.ordinality
        )
        from public.material_processing_effective_pages page
        cross join lateral jsonb_array_elements(
          page.result_payload->'equations'
        ) with ordinality as equation(value,ordinality)
        where page.job_id=top.job_id
          and page.status in ('completed','partial')
      ),'[]'::jsonb),
      'manifest',jsonb_agg(jsonb_build_object(
        'page_number',page.page_number,
        'status',page.status,
        'route',page.route,
        'warnings',page.warning_payload
      ) order by page.page_number)
    ) into v_payload
    from public.material_processing_batches top
    join public.material_processing_effective_pages page
      on page.job_id=top.job_id
    where top.id=v_batch.input_batch_ids[1]
    group by top.id,top.result_payload;
  end if;
  return jsonb_build_object(
    'kind',v_batch.operation,
    'operation',v_batch.operation,
    'material_id',v_batch.material_id,
    'job_id',v_batch.job_id,
    'batch_id',v_batch.id,
    'lease_token',p_lease_token,
    'idempotency_key',v_key,
    'page_count',v_job.page_count,
    'page_numbers',to_jsonb(v_batch.page_numbers),
    'input_payload',coalesce(v_payload,'{}'::jsonb),
    'validation_version',
      v_job.version_contract->>'validator_version',
    'response_id',v_batch.upstream_response_id,
    'temporary_file_id',v_batch.temporary_file_id
  );
end
$$;

create or replace function public.finalize_material_processing_job_internal(
  p_job_id uuid,p_lease_token uuid,p_summary_payload jsonb,
  p_summary_markdown text,p_validation_version text,
  p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_job public.material_processing_jobs%rowtype;
  v_count integer;
  v_min integer;
  v_max integer;
  v_distinct integer;
  v_terminal integer;
  v_nonterminal integer;
  v_warn integer;
  v_batch public.material_processing_batches%rowtype;
begin
  if p_validation_version not in (
      'phase-c-validator-v2','phase-c-validator-v3'
    )
    or p_validation_hash!~'^[0-9a-f]{64}$'
    or not public.material_analysis_valid_summary_payload(
      p_summary_payload
    )
    or p_summary_markdown is null
    or length(p_summary_markdown)>100000
  then
    raise exception 'invalid_summary_payload';
  end if;
  select * into v_job
  from public.material_processing_jobs
  where id=p_job_id and status='processing'
    and active_lease_token=p_lease_token
  for update;
  if not found
    or v_job.version_contract->>'validator_version'<>
      p_validation_version
  then
    raise exception 'job_unavailable';
  end if;
  select count(*),min(page_number),max(page_number),
    count(distinct page_number),
    count(*) filter(
      where status in ('completed','partial','missing')
    ),
    count(*) filter(
      where status not in ('completed','partial','missing')
    ),
    count(*) filter(where status in ('partial','missing'))
  into v_count,v_min,v_max,v_distinct,v_terminal,v_nonterminal,v_warn
  from public.material_processing_effective_pages
  where job_id=v_job.id;
  if v_count<>v_job.page_count
    or v_min<>1
    or v_max<>v_job.page_count
    or v_distinct<>v_job.page_count
    or v_terminal<>v_job.page_count
    or v_nonterminal<>0
  then
    raise exception 'page_manifest_incomplete';
  end if;
  select * into v_batch
  from public.material_processing_batches
  where job_id=v_job.id and operation='final_summary'
    and lease_token=p_lease_token
    and status in ('response_known','reconciliation_required')
    and upstream_response_id is not null
  for update;
  if not found then
    raise exception 'final_summary_batch_required';
  end if;
  update public.material_processing_attempts
  set status='completed',budget_effect='retained',
    completed_at=now(),updated_at=now()
  where id=v_batch.current_attempt_id;
  update public.material_processing_batches
  set status='completed',
    result_payload=jsonb_build_object(
      'schema_version',1,
      'operation','final_summary',
      'content',p_summary_payload
    ),
    result_schema_version=1,
    validation_version=p_validation_version,
    validation_hash=p_validation_hash,
    completed_at=now(),lease_token=null,
    lease_expires_at=null,updated_at=now()
  where id=v_batch.id;
  update public.materials
  set summary=p_summary_markdown,
    summary_payload=p_summary_payload,
    summary_schema_version=1,
    summary_processing_mode=v_job.processing_mode,
    summary_validation_version=p_validation_version,
    summary_validation_hash=p_validation_hash
  where id=v_job.material_id and user_id=v_job.user_id;
  update public.material_processing_jobs
  set status=case
      when v_warn>0 then 'completed_with_warnings'
      else 'completed'
    end,
    completed_at=now(),budget_state='consumed',
    active_lease_token=null,active_lease_expires_at=null,
    updated_at=now()
  where id=v_job.id;
end
$$;

alter table public.material_processing_page_recoveries owner to postgres;
alter view public.material_processing_effective_pages owner to postgres;
alter function public.enforce_material_processing_page_recovery_row()
  owner to postgres;
alter function public.prepare_material_analysis_page_recoveries_internal(uuid)
  owner to postgres;
alter function public.claim_next_material_analysis_operation_internal(uuid)
  owner to postgres;
alter function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) owner to postgres;
alter function public.material_analysis_work_payload(uuid,uuid)
  owner to postgres;
alter function public.finalize_material_processing_job_internal(
  uuid,uuid,jsonb,text,text,text
) owner to postgres;

revoke all on function
  public.enforce_material_processing_page_recovery_row()
  from public,anon,authenticated,service_role;
revoke all on function
  public.prepare_material_analysis_page_recoveries_internal(uuid)
  from public,anon,authenticated,service_role;
grant execute on function
  public.prepare_material_analysis_page_recoveries_internal(uuid)
  to service_role;
revoke all on function
  public.claim_next_material_analysis_operation_internal(uuid)
  from public,anon,authenticated,service_role;
grant execute on function
  public.claim_next_material_analysis_operation_internal(uuid)
  to service_role;
revoke all on function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) from public,anon,authenticated,service_role;
grant execute on function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) to service_role;
revoke all on function public.material_analysis_work_payload(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.material_analysis_work_payload(uuid,uuid)
  to service_role;
revoke all on function public.finalize_material_processing_job_internal(
  uuid,uuid,jsonb,text,text,text
) from public,anon,authenticated,service_role;
grant execute on function public.finalize_material_processing_job_internal(
  uuid,uuid,jsonb,text,text,text
) to service_role;

notify pgrst,'reload schema';
