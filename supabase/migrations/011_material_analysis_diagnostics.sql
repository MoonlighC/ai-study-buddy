-- Additive, internal-only diagnostics for preserved Phase C visual responses.
-- This migration does not alter public status, processing state, attempts,
-- budgets, leases, ambiguity, or cleanup behavior.

create or replace function public.material_analysis_valid_diagnostic_metadata(
  p_value jsonb
) returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'object'
    and pg_catalog.octet_length(p_value::text) <= 8192
    and not exists (
      select 1 from pg_catalog.jsonb_object_keys(p_value) key
      where key not in (
        'response_status','error_present','incomplete_details_present',
        'refusal_count','output_item_count','structured_candidate_count',
        'parsed_json_byte_length','top_level_key_count',
        'requested_page_number','returned_page_number','warning_count',
        'equation_count','source_page_count','validator_stage'
      )
    )
    and (
      not p_value ? 'response_status' or (
        pg_catalog.jsonb_typeof(p_value->'response_status') = 'string'
        and p_value->>'response_status' in (
          'queued','in_progress','completed','incomplete','failed',
          'cancelled','unknown'
        )
      )
    )
    and (
      not p_value ? 'validator_stage' or (
        pg_catalog.jsonb_typeof(p_value->'validator_stage') = 'string'
        and p_value->>'validator_stage' in (
          'validateResponseEnvelope','extractSingleStructuredCandidate',
          'parseStructuredJson','validatePageSchema','validatePageSemantics',
          'validatePageMarkdown','validatePageLatex',
          'validatePageProvenance','persistValidatedPage'
        )
      )
    )
    and not exists (
      select 1 from (values
        ('error_present'),('incomplete_details_present')
      ) boolean_key(key)
      where p_value ? key and pg_catalog.jsonb_typeof(p_value->key) <> 'boolean'
    )
    and not exists (
      select 1 from (values
        ('refusal_count',0,100),('output_item_count',0,100),
        ('structured_candidate_count',0,100),
        ('parsed_json_byte_length',0,262144),('top_level_key_count',0,100),
        ('warning_count',0,100),('equation_count',0,100),
        ('source_page_count',0,100)
      ) numeric_key(key,minimum,maximum)
      where p_value ? key and (
        pg_catalog.jsonb_typeof(p_value->key) <> 'number'
        or (p_value->>key) !~ '^[0-9]+$'
        or (p_value->>key)::numeric not between minimum and maximum
      )
    )
    and not exists (
      select 1 from (values
        ('requested_page_number'),('returned_page_number')
      ) page_key(key)
      where p_value ? key and (
        pg_catalog.jsonb_typeof(p_value->key) <> 'number'
        or (p_value->>key) !~ '^[0-9]+$'
        or (p_value->>key)::numeric not between 1 and 100
      )
    )
$$;

alter table public.material_processing_batches
  add column diagnostic_code text,
  add column diagnostic_metadata jsonb,
  add column diagnostic_version integer,
  add column diagnostic_recorded_at timestamptz,
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
      'page_persistence_failed','validation_unknown'
    )
  ),
  add constraint material_processing_batches_diagnostic_metadata_check check (
    diagnostic_metadata is null
    or public.material_analysis_valid_diagnostic_metadata(diagnostic_metadata)
  ),
  add constraint material_processing_batches_diagnostic_coherence_check check (
    (diagnostic_code is null and diagnostic_metadata is null
      and diagnostic_version is null and diagnostic_recorded_at is null)
    or (diagnostic_code is not null and diagnostic_metadata is not null
      and diagnostic_version = 1 and diagnostic_recorded_at is not null)
  );

create or replace function public.load_material_analysis_diagnostic_target_internal(
  p_batch_id uuid
) returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
  v_page_count integer;
begin
  select b.* into v_batch
  from public.material_processing_batches b
  where b.id = p_batch_id;
  if not found then raise exception 'diagnostic_target_unavailable'; end if;
  if v_batch.operation <> 'page_visual'
    or v_batch.status <> 'failed'
    or v_batch.failure_code <> 'validated_operation_failed'
    or pg_catalog.cardinality(v_batch.page_numbers) <> 1
    or v_batch.upstream_response_id is null
    or pg_catalog.length(pg_catalog.btrim(v_batch.upstream_response_id)) not between 8 and 200
  then
    raise exception 'diagnostic_target_unavailable';
  end if;
  select j.page_count into v_page_count
  from public.material_processing_jobs j
  where j.id = v_batch.job_id
    and j.material_id = v_batch.material_id
    and j.user_id = v_batch.user_id;
  if not found then raise exception 'diagnostic_target_unavailable'; end if;
  return pg_catalog.jsonb_build_object(
    'batch_id',v_batch.id,
    'operation',v_batch.operation,
    'status',v_batch.status,
    'response_id',v_batch.upstream_response_id,
    'page_numbers',pg_catalog.to_jsonb(v_batch.page_numbers),
    'page_count',v_page_count,
    'cleanup_state',v_batch.cleanup_state
  );
end
$$;

create or replace function public.record_material_analysis_diagnostic_internal(
  p_batch_id uuid,
  p_diagnostic_code text,
  p_diagnostic_metadata jsonb,
  p_diagnostic_version integer
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
begin
  if p_diagnostic_version is null or p_diagnostic_version <> 1
    or p_diagnostic_code is null or p_diagnostic_code not in (
      'response_status_not_completed','response_error_present',
      'response_incomplete','response_refusal','response_output_missing',
      'response_output_multiple','response_structured_text_missing',
      'response_json_parse_failed','page_schema_failed','page_unknown_field',
      'page_number_mismatch','page_provenance_failed',
      'page_confidence_failed','page_warning_failed',
      'page_equation_reference_failed','page_markdown_failed',
      'page_latex_failed','page_payload_too_large',
      'page_persistence_failed','validation_unknown'
    )
    or not public.material_analysis_valid_diagnostic_metadata(p_diagnostic_metadata)
  then
    raise exception 'invalid_material_analysis_diagnostic';
  end if;

  select b.* into v_batch
  from public.material_processing_batches b
  where b.id = p_batch_id
  for update;
  if not found
    or v_batch.operation <> 'page_visual'
    or v_batch.status <> 'failed'
    or v_batch.failure_code <> 'validated_operation_failed'
    or pg_catalog.cardinality(v_batch.page_numbers) <> 1
    or v_batch.upstream_response_id is null
  then
    raise exception 'diagnostic_target_unavailable';
  end if;

  if v_batch.diagnostic_code is not null then
    if v_batch.diagnostic_code = p_diagnostic_code
      and v_batch.diagnostic_metadata = p_diagnostic_metadata
      and v_batch.diagnostic_version = p_diagnostic_version
    then
      return;
    end if;
    raise exception 'diagnostic_conflict';
  end if;

  update public.material_processing_batches
  set diagnostic_code = p_diagnostic_code,
      diagnostic_metadata = p_diagnostic_metadata,
      diagnostic_version = p_diagnostic_version,
      diagnostic_recorded_at = pg_catalog.now()
  where id = v_batch.id;
end
$$;

do $$
declare
  f regprocedure;
begin
  if current_user <> 'postgres' then
    raise exception 'unexpected_material_analysis_diagnostic_migration_owner';
  end if;

  f := 'public.material_analysis_valid_diagnostic_metadata(jsonb)'::regprocedure;
  execute format('alter function %s owner to postgres',f);
  execute format(
    'revoke all on function %s from public, anon, authenticated, service_role',
    f
  );

  foreach f in array array[
    'public.load_material_analysis_diagnostic_target_internal(uuid)'::regprocedure,
    'public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres',f);
    execute format(
      'revoke all on function %s from public, anon, authenticated, service_role',
      f
    );
    execute format('grant execute on function %s to service_role',f);
  end loop;
end
$$;

-- Processing tables remain inaccessible directly to API roles. Diagnostics
-- can only be loaded and recorded through the two service-only RPCs above.
revoke all on table public.material_processing_batches
  from public, anon, authenticated, service_role;

notify pgrst,'reload schema';
