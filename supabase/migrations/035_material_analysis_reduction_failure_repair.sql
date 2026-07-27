-- Align Analyze Again with the authoritative 40 MiB PDF upload contract and
-- retain counts-only reduction validation diagnostics before terminalization.

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
          and m.file_size_bytes between 1 and 41943040)
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

create function public.material_analysis_valid_reduction_diagnostic_metadata(
  p_value jsonb
) returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select
    pg_catalog.jsonb_typeof(p_value)='object'
    and (p_value-array[
      'operation_kind','reduction_level','validator_stage',
      'safe_validator_code','input_concept_count',
      'accepted_concept_count','duplicate_concept_count',
      'oversized_concept_count','serialized_list_concept_count',
      'dropped_concept_count','source_page_count',
      'equation_id_count','warning_count'
    ])='{}'::jsonb
    and p_value ?& array[
      'operation_kind','reduction_level','validator_stage',
      'safe_validator_code','source_page_count',
      'equation_id_count','warning_count'
    ]
    and (
      (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_value))=7
      or (
        (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_value))=13
        and p_value ?& array[
          'input_concept_count','accepted_concept_count',
          'duplicate_concept_count','oversized_concept_count',
          'serialized_list_concept_count','dropped_concept_count'
        ]
      )
    )
    and p_value->>'operation_kind'='reduction'
    and p_value->>'reduction_level' in ('first_level','global')
    and (
      (p_value->>'validator_stage'='validateResponseEnvelope'
        and p_value->>'safe_validator_code'='reduction_response_invalid')
      or
      (p_value->>'validator_stage'='parseStructuredJson'
        and p_value->>'safe_validator_code'='reduction_json_parse_failed')
      or
      (p_value->>'validator_stage'='validateReductionMinimumShape'
        and p_value->>'safe_validator_code'='reduction_required_shape_invalid')
      or
      (p_value->>'validator_stage'='validateReductionSchema'
        and p_value->>'safe_validator_code'='reduction_schema_invalid')
      or
      (p_value->>'validator_stage'='validateReductionMarkdown'
        and p_value->>'safe_validator_code'='reduction_markdown_invalid')
      or
      (p_value->>'validator_stage'='validateReductionSourcePages'
        and p_value->>'safe_validator_code'='reduction_source_pages_mismatch')
      or
      (p_value->>'validator_stage'='validateReductionEquationReferences'
        and p_value->>'safe_validator_code'=
          'reduction_equation_references_invalid')
      or
      (p_value->>'validator_stage'='validateReductionWarningProvenance'
        and p_value->>'safe_validator_code'=
          'reduction_warning_provenance_invalid')
    )
    and not exists(
      select 1
      from pg_catalog.unnest(array[
        'source_page_count','equation_id_count','warning_count'
      ]) key
      where pg_catalog.jsonb_typeof(p_value->key)<>'number'
        or (p_value->>key)!~'^[0-9]+$'
        or (p_value->>key)::numeric not between 0 and 100
    )
    and (
      not (p_value ? 'input_concept_count')
      or (
        not exists(
          select 1
          from pg_catalog.unnest(array[
            'input_concept_count','accepted_concept_count',
            'duplicate_concept_count','oversized_concept_count',
            'serialized_list_concept_count','dropped_concept_count'
          ]) key
          where pg_catalog.jsonb_typeof(p_value->key)<>'number'
            or (p_value->>key)!~'^[0-9]+$'
            or (p_value->>key)::numeric not between 0 and 1000
        )
        and (p_value->>'accepted_concept_count')::integer<=24
        and (p_value->>'accepted_concept_count')::integer
          +(p_value->>'dropped_concept_count')::integer
          =(p_value->>'input_concept_count')::integer
        and (p_value->>'duplicate_concept_count')::integer
          <=(p_value->>'dropped_concept_count')::integer
        and (p_value->>'oversized_concept_count')::integer
          <=(p_value->>'dropped_concept_count')::integer
        and (p_value->>'serialized_list_concept_count')::integer
          <=(p_value->>'dropped_concept_count')::integer
      )
    )
$$;

alter table public.material_processing_batches
  drop constraint material_processing_batches_diagnostic_code_check,
  add constraint material_processing_batches_diagnostic_code_check check (
    diagnostic_code is null or diagnostic_code in (
      'response_status_not_completed','response_error_present',
      'response_incomplete','response_refusal','response_output_missing',
      'response_output_multiple','response_structured_text_missing',
      'response_json_parse_failed','page_schema_failed','page_unknown_field',
      'page_number_mismatch','page_provenance_failed',
      'page_confidence_failed','page_warning_failed',
      'page_equation_reference_failed','page_markdown_failed',
      'page_latex_failed','page_payload_too_large',
      'page_persistence_failed','validation_unknown',
      'final_summary_schema_failed','final_summary_semantics_failed',
      'final_summary_markdown_failed','final_summary_latex_failed',
      'final_summary_payload_too_large','final_summary_persistence_failed',
      'final_validation_unknown','reduction_validation_failed'
    )
  ),
  drop constraint material_processing_batches_diagnostic_metadata_check,
  add constraint material_processing_batches_diagnostic_metadata_check check (
    diagnostic_metadata is null
    or (
      diagnostic_code='reduction_validation_failed'
      and public.material_analysis_valid_reduction_diagnostic_metadata(
        diagnostic_metadata
      )
    )
    or (
      diagnostic_code<>'reduction_validation_failed'
      and public.material_analysis_valid_diagnostic_metadata(
        diagnostic_metadata
      )
    )
  );

create function public.record_material_analysis_reduction_diagnostic_internal(
  p_batch_id uuid,
  p_lease_token uuid,
  p_diagnostic_metadata jsonb,
  p_diagnostic_version integer
) returns void language plpgsql volatile security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
begin
  if p_diagnostic_version<>1
    or not public.material_analysis_valid_reduction_diagnostic_metadata(
      p_diagnostic_metadata
    )
  then raise exception 'invalid_material_analysis_reduction_diagnostic'; end if;

  select batch.* into v_batch
  from public.material_processing_batches batch
  join public.material_processing_jobs job on job.id=batch.job_id
  where batch.id=p_batch_id
    and batch.lease_token=p_lease_token
    and job.active_lease_token=p_lease_token
    and batch.operation='reduction'
    and batch.status in ('response_known','reconciliation_required')
    and batch.upstream_response_id is not null
  for update of batch;
  if not found then raise exception 'reduction_diagnostic_target_unavailable'; end if;

  if v_batch.diagnostic_code is not null then
    if v_batch.diagnostic_code='reduction_validation_failed'
      and v_batch.diagnostic_metadata=p_diagnostic_metadata
      and v_batch.diagnostic_version=p_diagnostic_version
    then return; end if;
    raise exception 'diagnostic_conflict';
  end if;

  update public.material_processing_batches
  set diagnostic_code='reduction_validation_failed',
      diagnostic_metadata=p_diagnostic_metadata,
      diagnostic_version=p_diagnostic_version,
      diagnostic_recorded_at=pg_catalog.now()
  where id=v_batch.id;
end
$$;

create function public.load_material_analysis_reduction_diagnostic_internal(
  p_batch_id uuid
) returns jsonb language sql stable security definer
set search_path = pg_catalog, public
as $$
  select batch.diagnostic_metadata
  from public.material_processing_batches batch
  where batch.id=p_batch_id
    and batch.operation='reduction'
    and batch.status='failed'
    and batch.diagnostic_code='reduction_validation_failed'
    and batch.diagnostic_version=1
    and public.material_analysis_valid_reduction_diagnostic_metadata(
      batch.diagnostic_metadata
    )
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
    'reduction_level',v_batch.reduction_level,
    'response_id',v_batch.upstream_response_id,
    'temporary_file_id',v_batch.temporary_file_id
  );
end
$$;

alter function public.material_analysis_analyze_again_eligible(uuid,uuid)
  owner to postgres;
alter function public.material_analysis_valid_reduction_diagnostic_metadata(
  jsonb) owner to postgres;
alter function public.record_material_analysis_reduction_diagnostic_internal(
  uuid,uuid,jsonb,integer) owner to postgres;
alter function public.load_material_analysis_reduction_diagnostic_internal(
  uuid) owner to postgres;
alter function public.material_analysis_work_payload(uuid,uuid)
  owner to postgres;

revoke all on function public.material_analysis_analyze_again_eligible(
  uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.material_analysis_valid_reduction_diagnostic_metadata(
  jsonb) from public,anon,authenticated,service_role;
revoke all on function public.record_material_analysis_reduction_diagnostic_internal(
  uuid,uuid,jsonb,integer) from public,anon,authenticated,service_role;
grant execute on function public.record_material_analysis_reduction_diagnostic_internal(
  uuid,uuid,jsonb,integer) to service_role;
revoke all on function public.load_material_analysis_reduction_diagnostic_internal(
  uuid) from public,anon,authenticated,service_role;
grant execute on function public.load_material_analysis_reduction_diagnostic_internal(
  uuid) to service_role;
revoke all on function public.material_analysis_work_payload(
  uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.material_analysis_work_payload(
  uuid,uuid) to service_role;

notify pgrst,'reload schema';
