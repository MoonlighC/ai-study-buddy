-- One-shot staging-safe structured-output diagnostics. The singleton row is
-- armed by this migration and attaches automatically to the next processing
-- job. Provider content and public identifiers are never accepted or stored.

create or replace function public.material_analysis_reproduction_metadata_valid(
  p_metadata jsonb
) returns boolean
language plpgsql
immutable
set search_path = pg_catalog, public
as $$
declare
  v jsonb;
  k text;
  expected_keys constant text[] := array[
    'operation','provider_status','validator_stage','json_parse_success',
    'top_level_keys','observed_types','missing_required','unexpected_fields',
    'mismatches','array_object_counts','parsed_json_byte_length',
    'schema_version','safe_failure_code'
  ];
begin
  if jsonb_typeof(p_metadata) <> 'object'
    or (select count(*) from jsonb_object_keys(p_metadata)) <> 13
    or not p_metadata ?& expected_keys
    or jsonb_typeof(p_metadata->'operation') <> 'string'
    or p_metadata->>'operation' not in (
      'page_text','page_visual','page_recovery','reduction','final_summary'
    )
    or jsonb_typeof(p_metadata->'provider_status') <> 'string'
    or p_metadata->>'provider_status' not in (
      'queued','in_progress','completed','incomplete','failed','cancelled','unknown'
    )
    or jsonb_typeof(p_metadata->'validator_stage') <> 'string'
    or p_metadata->>'validator_stage' not in (
      'validateResponseEnvelope','extractSingleStructuredCandidate',
      'parseStructuredJson','validatePageSchema','validatePageSemantics',
      'validatePageMarkdown','validatePageLatex','validateReductionSchema',
      'validateReductionSemantics','validateReductionMarkdown',
      'validateReductionLatex','validateFinalSummarySchema',
      'validateFinalSummarySemantics','validateFinalSummaryMarkdown',
      'validateFinalSummaryLatex'
    )
    or jsonb_typeof(p_metadata->'json_parse_success') <> 'boolean'
    or jsonb_typeof(p_metadata->'top_level_keys') <> 'array'
    or jsonb_array_length(p_metadata->'top_level_keys') > 32
    or jsonb_typeof(p_metadata->'observed_types') <> 'object'
    or (select count(*) from jsonb_object_keys(p_metadata->'observed_types')) > 256
    or jsonb_typeof(p_metadata->'missing_required') <> 'array'
    or jsonb_array_length(p_metadata->'missing_required') > 256
    or jsonb_typeof(p_metadata->'unexpected_fields') <> 'array'
    or jsonb_array_length(p_metadata->'unexpected_fields') > 256
    or jsonb_typeof(p_metadata->'mismatches') <> 'array'
    or jsonb_array_length(p_metadata->'mismatches') > 256
    or jsonb_typeof(p_metadata->'array_object_counts') <> 'object'
    or (select count(*) from jsonb_object_keys(p_metadata->'array_object_counts')) > 256
    or jsonb_typeof(p_metadata->'parsed_json_byte_length') <> 'number'
    or (p_metadata->>'parsed_json_byte_length')::numeric < 0
    or (p_metadata->>'parsed_json_byte_length')::numeric > 262144
    or trunc((p_metadata->>'parsed_json_byte_length')::numeric)
      <> (p_metadata->>'parsed_json_byte_length')::numeric
    or jsonb_typeof(p_metadata->'schema_version') <> 'string'
    or p_metadata->>'schema_version' not in (
      'phase-c-page-schema-v1','phase-c-reduction-schema-v1',
      'phase-c-final-schema-v1'
    )
    or jsonb_typeof(p_metadata->'safe_failure_code') <> 'string'
    or p_metadata->>'safe_failure_code' !~ '^[a-z0-9_]{1,64}$'
  then return false; end if;

  for v in select value from jsonb_array_elements(p_metadata->'top_level_keys') loop
    if jsonb_typeof(v) <> 'string'
      or v#>>'{}' !~ '^_?[a-z][a-z0-9_]{0,63}$'
    then return false; end if;
  end loop;
  for v in
    select value from jsonb_array_elements(p_metadata->'missing_required')
    union all
    select value from jsonb_array_elements(p_metadata->'unexpected_fields')
  loop
    if jsonb_typeof(v) <> 'string'
      or v#>>'{}' !~ '^\$(\.[a-z_][a-z0-9_]{0,63}|\[\]){0,8}$'
    then return false; end if;
  end loop;
  for k,v in select key,value from jsonb_each(p_metadata->'observed_types') loop
    if k !~ '^\$(\.[a-z_][a-z0-9_]{0,63}|\[\]){0,8}$'
      or jsonb_typeof(v) <> 'string'
      or v#>>'{}' not in (
        'string','number','integer','boolean','object','array','null','missing'
      )
    then return false; end if;
  end loop;
  for k,v in select key,value from jsonb_each(p_metadata->'array_object_counts') loop
    if k !~ '^\$(\.[a-z_][a-z0-9_]{0,63}|\[\]){0,8}$'
      or jsonb_typeof(v) <> 'number'
      or (v#>>'{}')::numeric < 0 or (v#>>'{}')::numeric > 1000
      or trunc((v#>>'{}')::numeric) <> (v#>>'{}')::numeric
    then return false; end if;
  end loop;
  for v in select value from jsonb_array_elements(p_metadata->'mismatches') loop
    if jsonb_typeof(v) <> 'object'
      or (select count(*) from jsonb_object_keys(v)) <> 4
      or not v ?& array['path','code','expected_type','observed_type']
      or v->>'path' !~ '^\$(\.[a-z_][a-z0-9_]{0,63}|\[\]){0,8}$'
      or v->>'code' not in (
        'type_mismatch','nullability_mismatch','enum_mismatch','pattern_mismatch',
        'count_min','count_max','number_min','number_max'
      )
      or v->>'expected_type' not in (
        'string','number','integer','boolean','object','array','null','any','enum'
      )
      or v->>'observed_type' not in (
        'string','number','integer','boolean','object','array','null','missing'
      )
    then return false; end if;
  end loop;
  return true;
exception when others then
  return false;
end
$$;

create table public.material_analysis_reproduction_diagnostics (
  singleton boolean primary key default true check (singleton),
  armed_at timestamptz not null default now(),
  job_id uuid unique references public.material_processing_jobs(id) on delete restrict,
  batch_id uuid unique references public.material_processing_batches(id) on delete restrict,
  metadata jsonb,
  captured_at timestamptz,
  constraint material_analysis_reproduction_capture_shape check (
    (batch_id is null and metadata is null and captured_at is null)
    or (batch_id is not null and metadata is not null and captured_at is not null
      and public.material_analysis_reproduction_metadata_valid(metadata))
  )
);
alter table public.material_analysis_reproduction_diagnostics enable row level security;
alter table public.material_analysis_reproduction_diagnostics force row level security;
revoke all on table public.material_analysis_reproduction_diagnostics
  from public, anon, authenticated, service_role;
grant select on table public.material_analysis_reproduction_diagnostics
  to service_role;
insert into public.material_analysis_reproduction_diagnostics(singleton)
values (true);

create or replace function public.attach_material_analysis_reproduction_job_internal()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.material_analysis_reproduction_diagnostics
  set job_id = new.id
  where singleton and job_id is null and metadata is null;
  return new;
end
$$;

create trigger attach_material_analysis_reproduction_job
after insert on public.material_processing_jobs
for each row execute function public.attach_material_analysis_reproduction_job_internal();

create or replace function public.record_material_analysis_reproduction_diagnostic_internal(
  p_job_id uuid,
  p_batch_id uuid,
  p_metadata jsonb
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.material_analysis_reproduction_metadata_valid(p_metadata)
    or not exists (
      select 1 from public.material_processing_batches b
      where b.id=p_batch_id and b.job_id=p_job_id
    )
  then raise exception 'invalid_material_analysis_reproduction_diagnostic'; end if;

  update public.material_analysis_reproduction_diagnostics
  set batch_id=p_batch_id, metadata=p_metadata, captured_at=now()
  where singleton and job_id=p_job_id and metadata is null;
end
$$;

do $$
declare f regprocedure;
begin
  if current_user <> 'postgres' then
    raise exception 'unexpected_material_analysis_reproduction_diagnostic_owner';
  end if;
  foreach f in array array[
    'public.material_analysis_reproduction_metadata_valid(jsonb)'::regprocedure,
    'public.attach_material_analysis_reproduction_job_internal()'::regprocedure,
    'public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres',f);
    execute format(
      'revoke all on function %s from public,anon,authenticated,service_role',f
    );
  end loop;
  grant execute on function
    public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)
    to service_role;
end
$$;

notify pgrst, 'reload schema';
