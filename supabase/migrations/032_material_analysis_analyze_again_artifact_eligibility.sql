-- Analyze Again is based on the durable original upload, not temporary
-- provider-file cleanup. Existing generations and provider artifacts remain
-- immutable.

create or replace function public.material_analysis_analyze_again_eligible(
  p_material_id uuid,
  p_job_id uuid
) returns boolean
language sql
stable
set search_path = pg_catalog, public
as $$
  select exists(
    select 1
    from public.materials m
    join public.material_processing_jobs j
      on j.id=p_job_id
      and j.material_id=m.id
      and j.user_id=m.user_id
    where m.id=p_material_id
      and m.deleted_at is null
      and m.cleanup_status is null
      and m.source_kind='upload'
      and m.kind in ('pdf','image')
      and m.storage_bucket=case
        when m.kind='pdf' then 'study-materials'
        else 'study-images'
      end
      and m.storage_path is not null
      and pg_catalog.split_part(m.storage_path,'/',1)=m.user_id::text
      and pg_catalog.split_part(m.storage_path,'/',2)=m.id::text
      and pg_catalog.split_part(m.storage_path,'/',3)<>''
      and pg_catalog.split_part(m.storage_path,'/',4)=''
      and (
        (m.kind='pdf'
          and m.mime_type='application/pdf'
          and m.file_size_bytes between 1 and 10485760)
        or
        (m.kind='image'
          and m.mime_type in ('image/png','image/jpeg','image/webp')
          and m.file_size_bytes between 1 and 8388608)
      )
      and exists(
        select 1
        from storage.objects source
        where source.bucket_id=m.storage_bucket
          and source.name=m.storage_path
          and source.owner_id=m.user_id::text
      )
      and j.generation=(
        select pg_catalog.max(latest.generation)
        from public.material_processing_jobs latest
        where latest.material_id=m.id
      )
      and j.status='failed'
      and j.safe_error_code='structured_output_invalid'
      and j.version_contract->>'validator_version' in (
        'phase-c-validator-v2','phase-c-validator-v3'
      )
      and not exists(
        select 1
        from public.material_processing_jobs active_job
        where active_job.material_id=m.id
          and active_job.status not in (
            'completed','completed_with_warnings','failed'
          )
      )
      and not exists(
        select 1
        from public.material_processing_jobs leased_job
        where leased_job.material_id=m.id
          and leased_job.active_lease_expires_at>pg_catalog.now()
      )
      and not exists(
        select 1
        from public.material_processing_batches active_batch
        where active_batch.material_id=m.id
          and active_batch.status not in ('completed','failed')
      )
      and not exists(
        select 1
        from public.material_processing_batches leased_batch
        where leased_batch.material_id=m.id
          and leased_batch.lease_expires_at>pg_catalog.now()
      )
  )
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
        or not public.material_analysis_analyze_again_eligible(
          v_material.id,v_job.id
        )
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

create or replace function public.get_material_analysis_status_v2(
  p_material_id uuid
)
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
    public.material_analysis_analyze_again_eligible(m.id,j.id),
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

alter function public.material_analysis_analyze_again_eligible(uuid,uuid)
  owner to postgres;
alter function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean) owner to postgres;
alter function public.get_material_analysis_status_v2(uuid) owner to postgres;

revoke all on function public.material_analysis_analyze_again_eligible(
  uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)
  from public,anon,authenticated,service_role;
grant execute on function public.prepare_material_analysis_internal(
  uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean) to service_role;
revoke all on function public.get_material_analysis_status_v2(uuid)
  from public,anon,service_role;
grant execute on function public.get_material_analysis_status_v2(uuid)
  to authenticated;

notify pgrst,'reload schema';
