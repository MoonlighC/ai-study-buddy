-- Phase C real-output reliability: authoritative equations and explicit,
-- immutable analysis generations. Existing generations are never reopened.

alter table public.materials
  drop constraint if exists materials_summary_payload_contract,
  add constraint materials_summary_payload_contract check (
    (summary_payload is null and summary_schema_version is null and
      summary_processing_mode is null and summary_validation_version is null and
      summary_validation_hash is null)
    or
    (jsonb_typeof(summary_payload)='object' and summary_schema_version=1 and
      summary_processing_mode in ('recommended','economy') and
      summary_validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      ) and summary_validation_hash~'^[0-9a-f]{64}$' and
      octet_length(summary_payload::text)<=1048576)
  );

do $$
declare v_constraint name;
begin
  select constraint_row.conname into strict v_constraint
  from pg_catalog.pg_constraint constraint_row
  where constraint_row.conrelid='public.material_processing_batches'::regclass
    and constraint_row.contype='c'
    and pg_catalog.pg_get_constraintdef(constraint_row.oid)
      like '%validation_version = ''phase-c-validator-v2''%';
  execute pg_catalog.format(
    'alter table public.material_processing_batches drop constraint %I',
    v_constraint
  );

  select constraint_row.conname into strict v_constraint
  from pg_catalog.pg_constraint constraint_row
  where constraint_row.conrelid='public.material_processing_pages'::regclass
    and constraint_row.contype='c'
    and pg_catalog.pg_get_constraintdef(constraint_row.oid)
      like '%validation_version = ''phase-c-validator-v2''%';
  execute pg_catalog.format(
    'alter table public.material_processing_pages drop constraint %I',
    v_constraint
  );
end
$$;

alter table public.material_processing_batches
  add constraint material_processing_batches_validation_contract check (
    (status='completed' and result_payload is not null and
      result_schema_version=1 and validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      ) and validation_hash~'^[0-9a-f]{64}$' and completed_at is not null)
    or status<>'completed'
  );

alter table public.material_processing_pages
  add constraint material_processing_pages_validation_contract check (
    (status='completed' and
      public.material_analysis_valid_page_payload(result_payload) and
      (result_payload->>'trustworthy')::boolean and result_schema_version=1 and
      validation_version in ('phase-c-validator-v2','phase-c-validator-v3') and
      validation_hash~'^[0-9a-f]{64}$' and
      jsonb_array_length(warning_payload)<=100 and active_batch_id is null and
      terminal_at is not null)
    or (status='partial' and
      public.material_analysis_valid_page_payload(result_payload) and
      (result_payload->>'trustworthy')::boolean and result_schema_version=1 and
      validation_version in ('phase-c-validator-v2','phase-c-validator-v3') and
      validation_hash~'^[0-9a-f]{64}$' and
      jsonb_array_length(warning_payload)>0 and active_batch_id is null and
      terminal_at is not null)
    or (status='missing' and result_payload is null and
      result_schema_version is null and
      validation_version in ('phase-c-validator-v2','phase-c-validator-v3') and
      validation_hash~'^[0-9a-f]{64}$' and
      jsonb_array_length(warning_payload)>0 and active_batch_id is null and
      terminal_at is not null)
    or (status not in ('completed','partial','missing') and terminal_at is null)
  );

create or replace function public.complete_material_processing_page_internal(
  p_job_id uuid,p_page_number integer,p_lease_token uuid,
  p_terminal_status text,p_result jsonb,p_warnings jsonb,
  p_validation_version text,p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if p_terminal_status not in ('completed','partial','missing')
    or p_validation_version not in (
      'phase-c-validator-v2','phase-c-validator-v3'
    ) or p_validation_hash!~'^[0-9a-f]{64}$'
    or not public.material_analysis_safe_warnings(p_warnings)
    or (p_terminal_status in ('completed','partial') and
      not public.material_analysis_valid_page_payload(p_result))
    or (p_terminal_status='partial' and (
      (p_result->>'trustworthy')::boolean is not true or
      jsonb_array_length(p_warnings)=0))
    or (p_terminal_status='completed' and
      (p_result->>'trustworthy')::boolean is not true)
    or (p_terminal_status='missing' and (
      p_result is not null or jsonb_array_length(p_warnings)=0))
  then raise exception 'invalid_terminal_page_payload'; end if;
  if p_result is not null and
    (p_result->>'page_number')::integer<>p_page_number
  then raise exception 'page_payload_mismatch'; end if;
  update public.material_processing_pages page
  set status=p_terminal_status,result_payload=p_result,
    result_schema_version=case when p_result is null then null else 1 end,
    validation_version=p_validation_version,validation_hash=p_validation_hash,
    warning_payload=p_warnings,active_batch_id=null,terminal_at=now(),
    updated_at=now()
  from public.material_processing_batches batch,
    public.material_processing_jobs job
  where page.job_id=p_job_id and page.page_number=p_page_number
    and page.status='processing' and batch.id=page.active_batch_id
    and batch.lease_token=p_lease_token and job.id=page.job_id
    and job.active_lease_token=p_lease_token
    and job.version_contract->>'validator_version'=p_validation_version;
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
  if p_validation_version not in (
    'phase-c-validator-v2','phase-c-validator-v3'
  ) or p_validation_hash!~'^[0-9a-f]{64}$'
  then raise exception 'invalid_result'; end if;
  select b.* into v_batch
  from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id
  where b.id=p_batch_id and b.lease_token=p_lease_token
    and j.active_lease_token=p_lease_token
    and j.version_contract->>'validator_version'=p_validation_version
    and b.status in ('response_known','reconciliation_required')
    and b.upstream_response_id is not null
  for update of b;
  if not found then raise exception 'batch_completion_conflict'; end if;
  if not public.material_analysis_valid_batch_payload(
    p_validated_result,v_batch.operation
  ) then raise exception 'invalid_result'; end if;
  update public.material_processing_attempts
  set status='completed',budget_effect='retained',completed_at=now(),
    updated_at=now()
  where id=v_batch.current_attempt_id;
  update public.material_processing_batches
  set status='completed',result_payload=p_validated_result,
    result_schema_version=1,validation_version=p_validation_version,
    validation_hash=p_validation_hash,completed_at=now(),lease_token=null,
    lease_expires_at=null,updated_at=now()
  where id=v_batch.id;
  update public.material_processing_jobs
  set status='prepared',active_lease_token=null,active_lease_expires_at=null,
    updated_at=now()
  where id=v_batch.job_id and active_lease_token=p_lease_token;
end
$$;

create or replace function public.finalize_material_processing_job_internal(
  p_job_id uuid,p_lease_token uuid,p_summary_payload jsonb,
  p_summary_markdown text,p_validation_version text,p_validation_hash text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype;
  v_count integer; v_min integer; v_max integer; v_distinct integer;
  v_terminal integer; v_nonterminal integer; v_warn integer;
  v_batch public.material_processing_batches%rowtype;
begin
  if p_validation_version not in (
      'phase-c-validator-v2','phase-c-validator-v3'
    ) or p_validation_hash!~'^[0-9a-f]{64}$'
    or not public.material_analysis_valid_summary_payload(p_summary_payload)
    or p_summary_markdown is null or length(p_summary_markdown)>100000
  then raise exception 'invalid_summary_payload'; end if;
  select * into v_job from public.material_processing_jobs
  where id=p_job_id and status='processing'
    and active_lease_token=p_lease_token for update;
  if not found or
    v_job.version_contract->>'validator_version'<>p_validation_version
  then raise exception 'job_unavailable'; end if;
  select count(*),min(page_number),max(page_number),
    count(distinct page_number),
    count(*) filter(where status in ('completed','partial','missing')),
    count(*) filter(where status not in ('completed','partial','missing')),
    count(*) filter(where status in ('partial','missing'))
  into v_count,v_min,v_max,v_distinct,v_terminal,v_nonterminal,v_warn
  from public.material_processing_pages where job_id=v_job.id;
  if v_count<>v_job.page_count or v_min<>1 or v_max<>v_job.page_count
    or v_distinct<>v_job.page_count or v_terminal<>v_job.page_count
    or v_nonterminal<>0
  then raise exception 'page_manifest_incomplete'; end if;
  select * into v_batch from public.material_processing_batches
  where job_id=v_job.id and operation='final_summary'
    and lease_token=p_lease_token
    and status in ('response_known','reconciliation_required')
    and upstream_response_id is not null for update;
  if not found then raise exception 'final_summary_batch_required'; end if;
  update public.material_processing_attempts
  set status='completed',budget_effect='retained',completed_at=now(),
    updated_at=now() where id=v_batch.current_attempt_id;
  update public.material_processing_batches
  set status='completed',result_payload=jsonb_build_object(
      'schema_version',1,'operation','final_summary',
      'content',p_summary_payload),
    result_schema_version=1,validation_version=p_validation_version,
    validation_hash=p_validation_hash,completed_at=now(),lease_token=null,
    lease_expires_at=null,updated_at=now() where id=v_batch.id;
  update public.materials
  set summary=p_summary_markdown,summary_payload=p_summary_payload,
    summary_schema_version=1,summary_processing_mode=v_job.processing_mode,
    summary_validation_version=p_validation_version,
    summary_validation_hash=p_validation_hash
  where id=v_job.material_id and user_id=v_job.user_id;
  update public.material_processing_jobs
  set status=case when v_warn>0
      then 'completed_with_warnings' else 'completed' end,
    completed_at=now(),budget_state='consumed',active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_job.id;
end
$$;

create or replace function public.material_analysis_work_payload(
  p_batch_id uuid,p_lease_token uuid
) returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype;
  v_job public.material_processing_jobs%rowtype; v_payload jsonb; v_key text;
begin
  select * into v_batch from public.material_processing_batches
  where id=p_batch_id and lease_token=p_lease_token;
  if not found then raise exception 'work_lease_invalid'; end if;
  select * into v_job from public.material_processing_jobs where id=v_batch.job_id;
  select a.idempotency_key into v_key from public.material_processing_attempts a
    where a.id=v_batch.current_attempt_id;
  if v_batch.operation='page_text' then
    select jsonb_build_object('pages',jsonb_agg(jsonb_build_object(
      'page_number',p.page_number,'normalized_text',p.normalized_text) order by p.page_number))
    into v_payload from public.material_processing_pages p
    where p.job_id=v_batch.job_id and p.page_number=any(v_batch.page_numbers);
  elsif v_batch.operation in ('page_visual','page_recovery') then
    v_payload:=jsonb_build_object(
      'operation',v_batch.operation,'page_numbers',to_jsonb(v_batch.page_numbers));
  elsif v_batch.operation='reduction' then
    if cardinality(v_batch.input_batch_ids)>0 then
      select jsonb_build_object(
        'inputs',jsonb_agg(b.result_payload->'content' order by b.created_at),
        'equation_ids',coalesce(jsonb_agg(
          b.result_payload->'content'->'equation_ids'),'[]'::jsonb))
      into v_payload from public.material_processing_batches b
      where b.id=any(v_batch.input_batch_ids);
    else
      select jsonb_build_object(
        'inputs',jsonb_agg(p.result_payload order by p.page_number),
        'equation_ids',coalesce(jsonb_agg(p.result_payload->'equations'),'[]'::jsonb))
      into v_payload from public.material_processing_pages p
      where p.job_id=v_batch.job_id and p.page_number=any(v_batch.page_numbers)
        and p.status in ('completed','partial');
    end if;
  else
    select jsonb_build_object(
      'operation','final_summary',
      'validated_reduction',top.result_payload->'content',
      'authoritative_equations',coalesce((
        select jsonb_agg(e.equation order by page.page_number,e.ordinality)
        from public.material_processing_pages page
        cross join lateral jsonb_array_elements(page.result_payload->'equations')
          with ordinality as e(equation,ordinality)
        where page.job_id=top.job_id and page.status in ('completed','partial')
      ),'[]'::jsonb),
      'manifest',jsonb_agg(jsonb_build_object(
        'page_number',p.page_number,'status',p.status,'route',p.route,
        'warnings',p.warning_payload) order by p.page_number))
    into v_payload from public.material_processing_batches top
    join public.material_processing_pages p on p.job_id=top.job_id
    where top.id=v_batch.input_batch_ids[1] group by top.id,top.result_payload;
  end if;
  return jsonb_build_object(
    'kind',v_batch.operation,'operation',v_batch.operation,
    'material_id',v_batch.material_id,'job_id',v_batch.job_id,
    'batch_id',v_batch.id,'lease_token',p_lease_token,
    'idempotency_key',v_key,'page_count',v_job.page_count,
    'page_numbers',to_jsonb(v_batch.page_numbers),
    'input_payload',coalesce(v_payload,'{}'::jsonb),
    'validation_version',v_job.version_contract->>'validator_version',
    'response_id',v_batch.upstream_response_id,
    'temporary_file_id',v_batch.temporary_file_id);
end
$$;

create or replace function public.prepare_material_analysis_internal(
  p_material_id uuid,p_processing_mode text,p_confirmation boolean,
  p_page_count integer,p_source_hash text,p_version_contract jsonb,
  p_version_fingerprint text,p_page_plans jsonb,p_analyze_again boolean
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_material public.materials%rowtype;
  v_job public.material_processing_jobs%rowtype; v_previous_failed boolean;
  v_job_id uuid; v_manifest integer[]; v_plan jsonb; v_generation integer:=1;
begin
  if p_analyze_again is null
    or p_processing_mode not in ('recommended','economy')
    or p_page_count not between 1 and 100
    or p_source_hash !~ '^[0-9a-f]{64}$'
    or jsonb_typeof(p_page_plans)<>'array'
    or jsonb_array_length(p_page_plans)<>p_page_count
    or jsonb_typeof(p_version_contract)<>'object'
    or (p_version_contract-array[
      'fingerprint_version','source_content_hash','source_metadata_hash',
      'processing_mode','page_count','router_version','prompt_version',
      'page_schema_version','reduction_schema_version',
      'final_summary_schema_version','validator_version',
      'openai_configuration_version','mini_pdf_version'])<>'{}'::jsonb
    or (select count(*) from jsonb_object_keys(p_version_contract))<>13
    or p_version_contract->>'fingerprint_version'<>'phase-c-fingerprint-v2'
    or p_version_contract->>'router_version'<>'phase-c-router-v1'
    or p_version_contract->>'reduction_schema_version'<>
      'phase-c-reduction-schema-v2'
    or p_version_contract->>'mini_pdf_version'<>'phase-c-mini-pdf-v1'
    or not (
      (
        p_version_contract->>'prompt_version'='phase-c-prompts-v2'
        and p_version_contract->>'page_schema_version'=
          'phase-c-page-schema-v2'
        and p_version_contract->>'final_summary_schema_version'=
          'phase-c-final-schema-v2'
        and p_version_contract->>'validator_version'=
          'phase-c-validator-v2'
        and p_version_contract->>'openai_configuration_version'=
          'phase-c-server-v1'
      ) or (
        p_version_contract->>'prompt_version'='phase-c-prompts-v3'
        and p_version_contract->>'page_schema_version'=
          'phase-c-page-schema-v3'
        and p_version_contract->>'final_summary_schema_version'=
          'phase-c-final-schema-v3'
        and p_version_contract->>'validator_version'=
          'phase-c-validator-v3'
        and p_version_contract->>'openai_configuration_version'=
          'phase-c-server-v2'
      )
    )
    or (p_analyze_again and
      p_version_contract->>'validator_version'<>'phase-c-validator-v3')
    or p_version_contract->>'source_content_hash'<>p_source_hash
    or p_version_contract->>'processing_mode'<>p_processing_mode
    or (p_version_contract->>'page_count')::integer<>p_page_count
    or p_version_fingerprint<>
      public.material_analysis_version_fingerprint(p_version_contract)
  then raise exception 'invalid_preparation'; end if;
  select * into v_material from public.materials
  where id=p_material_id and deleted_at is null and source_kind='upload'
    and kind in ('pdf','image') for update;
  if not found then raise exception 'material_unavailable'; end if;
  select array_agg((value->>'page_number')::integer
    order by (value->>'page_number')::integer)
  into v_manifest from jsonb_array_elements(p_page_plans);
  if v_manifest<>array(select generate_series(1,p_page_count)) or exists(
    select 1 from jsonb_array_elements(p_page_plans) p(value)
    where jsonb_typeof(value)<>'object'
      or value->>'route' not in ('text','visual')
      or value->>'input_hash' !~ '^[0-9a-f]{64}$'
      or jsonb_typeof(value->'routing_signals')<>'object'
      or length(coalesce(value->>'normalized_text',''))>40000
      or (value->>'routing_confidence')::numeric not between 0 and 1
  ) then raise exception 'invalid_page_plan'; end if;
  select * into v_job from public.material_processing_jobs
  where material_id=p_material_id order by generation desc limit 1 for update;
  if found then
    if v_job.user_id<>v_material.user_id then
      raise exception 'incompatible_existing_analysis';
    end if;
    if p_analyze_again then
      select exists(
        select 1 from public.material_processing_jobs previous
        where previous.material_id=v_job.material_id
          and previous.generation=v_job.generation-1
          and previous.status='failed'
          and previous.safe_error_code='structured_output_invalid'
      ) into v_previous_failed;
      if v_job.version_fingerprint=p_version_fingerprint
        and v_job.status in ('awaiting_confirmation','prepared','processing')
        and v_previous_failed
      then return v_job.id;
      end if;
      if v_job.status<>'failed'
        or v_job.safe_error_code<>'structured_output_invalid'
      then raise exception 'analysis_again_not_allowed'; end if;
    elsif v_job.version_fingerprint=p_version_fingerprint then
      if v_job.status='awaiting_confirmation' and p_confirmation then
        update public.material_processing_jobs
        set status='prepared',confirmation_authorized_at=now(),updated_at=now()
        where id=v_job.id;
      end if;
      return v_job.id;
    elsif v_job.status not in ('completed','completed_with_warnings') then
      raise exception 'incompatible_existing_analysis';
    end if;
    v_generation:=v_job.generation+1;
  elsif p_analyze_again then
    raise exception 'analysis_again_not_allowed';
  end if;
  v_job_id:=public.create_material_processing_job_internal(
    p_material_id,p_processing_mode,p_confirmation,p_page_count,
    case when exists(
      select 1 from jsonb_array_elements(p_page_plans) p(value)
      where coalesce(value->>'normalized_text','')~*
        '\m(theorem|equation|algorithm|matrix|physics|calculus)\M'
    ) then 'stem' else 'general' end,
    v_generation,p_version_contract,p_version_fingerprint);
  update public.material_processing_jobs set source_hash=p_source_hash
  where id=v_job_id;
  for v_plan in select value from jsonb_array_elements(p_page_plans) loop
    update public.material_processing_pages
    set route=v_plan->>'route',
      normalized_text=coalesce(v_plan->>'normalized_text',''),
      input_hash=v_plan->>'input_hash',
      routing_signals=v_plan->'routing_signals',
      routing_confidence=(v_plan->>'routing_confidence')::numeric
    where job_id=v_job_id
      and page_number=(v_plan->>'page_number')::integer;
  end loop;
  update public.materials set processing_status='pending',updated_at=now()
  where id=p_material_id and user_id=v_material.user_id;
  return v_job_id;
end
$$;

create or replace function public.prepare_material_analysis_internal(
  p_material_id uuid,p_processing_mode text,p_confirmation boolean,
  p_page_count integer,p_source_hash text,p_version_contract jsonb,
  p_version_fingerprint text,p_page_plans jsonb
) returns uuid language sql security definer
set search_path = pg_catalog, public
as $$
  select public.prepare_material_analysis_internal(
    p_material_id,p_processing_mode,p_confirmation,p_page_count,p_source_hash,
    p_version_contract,p_version_fingerprint,p_page_plans,false)
$$;

create or replace function public.get_material_analysis_status(
  p_material_id uuid
)
returns table(
  material_id uuid,processing_mode text,state text,public_stage text,
  page_count integer,completed_pages integer,confirmation_required boolean,
  can_retry boolean,retry_after_seconds integer,warnings jsonb,
  summary_schema_version integer,summary_payload jsonb,safe_error_code text,
  active_operation text
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,j.processing_mode,
    case when j.status='prepared' then 'processing' else j.status end,
    j.public_stage,j.page_count,j.completed_page_count,
    (j.status='awaiting_confirmation' and j.confirmation_required),
    (j.status='user_retry_required' and exists(
      select 1 from public.material_processing_batches retry_batch
      where retry_batch.job_id=j.id
        and retry_batch.status='user_retry_required'
        and retry_batch.attempt_count<retry_batch.max_attempts)),
    case when j.next_retry_at is null then null else greatest(
      0,least(900,extract(epoch from (j.next_retry_at-now()))::integer)) end,
    case when m.summary_payload is not null
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload->'warnings' else j.warning_payload end,
    m.summary_schema_version,
    case when m.summary_validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      )
      and m.summary_validation_hash~'^[0-9a-f]{64}$'
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload else null end,
    case when j.safe_error_code in(
      'unable_to_extract_content','provider_temporarily_unavailable',
      'structured_output_invalid') then j.safe_error_code else null end,
    (select b.operation from public.material_processing_batches b
      where b.job_id=j.id and b.status not in ('completed','failed')
      order by b.created_at limit 1)
  from public.materials m join lateral(
    select latest.* from public.material_processing_jobs latest
    where latest.material_id=m.id and latest.user_id=m.user_id
    order by latest.generation desc limit 1
  ) j on true
  where m.id=p_material_id and m.user_id=auth.uid() and m.deleted_at is null;
$$;

create function public.get_material_analysis_status_v2(p_material_id uuid)
returns table(
  material_id uuid,processing_mode text,state text,public_stage text,
  page_count integer,completed_pages integer,confirmation_required boolean,
  can_retry boolean,can_analyze_again boolean,retry_after_seconds integer,
  warnings jsonb,summary_schema_version integer,summary_payload jsonb,
  safe_error_code text,active_operation text
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,j.processing_mode,
    case when j.status='prepared' then 'processing' else j.status end,
    j.public_stage,j.page_count,j.completed_page_count,
    (j.status='awaiting_confirmation' and j.confirmation_required),
    (j.status='user_retry_required' and exists(
      select 1 from public.material_processing_batches retry_batch
      where retry_batch.job_id=j.id
        and retry_batch.status='user_retry_required'
        and retry_batch.attempt_count<retry_batch.max_attempts)),
    (j.status='failed' and j.safe_error_code='structured_output_invalid'
      and j.version_contract->>'validator_version' in (
        'phase-c-validator-v2','phase-c-validator-v3'
      ) and not exists(
        select 1 from public.material_processing_artifacts artifact
        where artifact.job_id=j.id
          and artifact.state in (
            'upload_intent','uploaded','cleanup_pending'
          ))),
    case when j.next_retry_at is null then null else greatest(
      0,least(900,extract(epoch from (j.next_retry_at-now()))::integer)) end,
    case when m.summary_payload is not null
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload->'warnings' else j.warning_payload end,
    m.summary_schema_version,
    case when m.summary_validation_version in (
        'phase-c-validator-v2','phase-c-validator-v3'
      )
      and m.summary_validation_hash~'^[0-9a-f]{64}$'
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload else null end,
    case when j.safe_error_code in(
      'unable_to_extract_content','provider_temporarily_unavailable',
      'structured_output_invalid') then j.safe_error_code else null end,
    (select b.operation from public.material_processing_batches b
      where b.job_id=j.id and b.status not in ('completed','failed')
      order by b.created_at limit 1)
  from public.materials m join lateral(
    select latest.* from public.material_processing_jobs latest
    where latest.material_id=m.id and latest.user_id=m.user_id
    order by latest.generation desc limit 1
  ) j on true
  where m.id=p_material_id and m.user_id=auth.uid() and m.deleted_at is null;
$$;

create or replace function public.load_study_generation_source_internal(
  p_user_id uuid,p_material_id uuid
) returns table(
  id uuid,user_id uuid,subject_id uuid,kind text,source_kind text,
  processing_status text,content_text text,summary_payload jsonb,
  summary_schema_version integer,summary_validation_version text,
  summary_validation_hash text,analysis_status text,
  analysis_page_count integer
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,m.user_id,m.subject_id,m.kind,m.source_kind,
    m.processing_status,m.content_text,m.summary_payload,
    m.summary_schema_version,m.summary_validation_version,
    m.summary_validation_hash,j.status,j.page_count
  from public.materials m
  left join lateral(
    select latest.status,latest.page_count
    from public.material_processing_jobs latest
    where latest.material_id=m.id and latest.user_id=m.user_id
    order by latest.generation desc limit 1
  ) j on true
  where m.id=p_material_id and m.user_id=p_user_id and m.deleted_at is null
    and (
      (nullif(pg_catalog.btrim(m.content_text),'') is not null and (
        (m.kind='pasted_text' and m.source_kind='manual') or
        (m.kind in ('pdf','image') and m.source_kind='upload'
          and m.processing_status='ready')
      )) or (
        j.status in ('completed','completed_with_warnings')
        and m.summary_schema_version=1
        and m.summary_validation_version in (
          'phase-c-validator-v2','phase-c-validator-v3'
        )
        and m.summary_validation_hash~'^[0-9a-f]{64}$'
        and public.material_analysis_valid_summary_payload(m.summary_payload)
      )
    );
$$;

alter function public.material_analysis_work_payload(uuid,uuid) owner to postgres;
alter function public.complete_material_processing_page_internal(
  uuid,integer,uuid,text,jsonb,jsonb,text,text) owner to postgres;
alter function public.complete_material_processing_batch_internal(
  uuid,uuid,jsonb,text,text) owner to postgres;
alter function public.finalize_material_processing_job_internal(
  uuid,uuid,jsonb,text,text,text) owner to postgres;
alter function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean) owner to postgres;
alter function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb) owner to postgres;
alter function public.get_material_analysis_status(uuid) owner to postgres;
alter function public.get_material_analysis_status_v2(uuid) owner to postgres;
alter function public.load_study_generation_source_internal(
  uuid,uuid) owner to postgres;

revoke all on function public.material_analysis_work_payload(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.material_analysis_work_payload(uuid,uuid)
  to service_role;
revoke all on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)
  from public,anon,authenticated,service_role;
grant execute on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean) to service_role;
revoke all on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb) to service_role;
revoke all on function public.get_material_analysis_status(uuid)
  from public,anon,service_role;
grant execute on function public.get_material_analysis_status(uuid)
  to authenticated;
revoke all on function public.get_material_analysis_status_v2(uuid)
  from public,anon,service_role;
grant execute on function public.get_material_analysis_status_v2(uuid)
  to authenticated;

notify pgrst,'reload schema';
