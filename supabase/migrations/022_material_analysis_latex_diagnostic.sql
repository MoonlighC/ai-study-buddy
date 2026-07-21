-- One-shot, staging-only diagnosis for the preserved final-summary response.
-- The target is bound by a non-reversible batch fingerprint; no caller ID is
-- accepted and no provider or document content is stored.

create or replace function public.material_analysis_latex_diagnostic_valid(
  p_value jsonb
) returns boolean language sql immutable
set search_path = pg_catalog, public
as $$
  select pg_catalog.jsonb_typeof(p_value) = 'object'
    and (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_value)) = 16
    and p_value ?& array[
      'provider_status','output_item_count','output_text_candidate_count',
      'validator_stage','equation_index','validator_rule_code','category',
      'string_length','unicode_code_point_count','maximum_nesting_depth',
      'command_count','environment_count','offending_syntax',
      'offending_unicode_code_point','equations_passing_before_failure',
      'total_equation_count'
    ]
    and p_value->>'provider_status' = 'completed'
    and p_value->>'validator_stage' = 'validateFinalSummaryLatex'
    and pg_catalog.jsonb_typeof(p_value->'output_item_count') = 'number'
    and (p_value->>'output_item_count')::integer = 1
    and pg_catalog.jsonb_typeof(p_value->'output_text_candidate_count') = 'number'
    and (p_value->>'output_text_candidate_count')::integer = 1
    and pg_catalog.jsonb_typeof(p_value->'total_equation_count') = 'number'
    and (p_value->>'total_equation_count')::integer between 0 and 100
    and pg_catalog.jsonb_typeof(p_value->'equations_passing_before_failure') = 'number'
    and (p_value->>'equations_passing_before_failure')::integer between 0 and 100
    and (
      (p_value->'equation_index' = 'null'::jsonb
        and p_value->'validator_rule_code' = 'null'::jsonb
        and p_value->'category' = 'null'::jsonb
        and p_value->'string_length' = 'null'::jsonb
        and p_value->'unicode_code_point_count' = 'null'::jsonb
        and p_value->'maximum_nesting_depth' = 'null'::jsonb
        and p_value->'command_count' = 'null'::jsonb
        and p_value->'environment_count' = 'null'::jsonb
        and p_value->'offending_syntax' = 'null'::jsonb
        and p_value->'offending_unicode_code_point' = 'null'::jsonb
        and (p_value->>'equations_passing_before_failure')::integer
          = (p_value->>'total_equation_count')::integer)
      or
      (pg_catalog.jsonb_typeof(p_value->'equation_index') = 'number'
        and (p_value->>'equation_index')::integer between 0 and 99
        and (p_value->>'equation_index')::integer
          = (p_value->>'equations_passing_before_failure')::integer
        and pg_catalog.jsonb_typeof(p_value->'validator_rule_code') = 'string'
        and p_value->>'validator_rule_code' in (
          'latex_length','latex_dollar_delimiter','latex_comments_forbidden',
          'latex_unicode_control','latex_unbalanced_groups',
          'latex_dangling_escape','latex_control_space',
          'latex_row_outside_environment','latex_control_symbol',
          'latex_environment_syntax','latex_environment_unsupported',
          'latex_environment_balance','latex_matrix_size',
          'latex_command_unsupported','latex_nesting_depth'
        )
        and pg_catalog.jsonb_typeof(p_value->'category') = 'string'
        and p_value->>'category' in (
          'unsupported_command','unsupported_environment',
          'forbidden_delimiter','malformed_braces','forbidden_comment',
          'forbidden_url_link_command','forbidden_package_macro_definition',
          'unsupported_unicode_character_class','control_spacing_syntax',
          'length_nesting_count_limit','another_bounded_enum'
        )
        and not exists (
          select 1 from (values
            ('string_length',0,5120),('unicode_code_point_count',0,5120),
            ('maximum_nesting_depth',0,1024),('command_count',0,1024),
            ('environment_count',0,256)
          ) bounds(key,minimum,maximum)
          where pg_catalog.jsonb_typeof(p_value->key) <> 'number'
            or (p_value->>key)::integer not between minimum and maximum
        )
        and (p_value->'offending_syntax' = 'null'::jsonb or (
          pg_catalog.jsonb_typeof(p_value->'offending_syntax') = 'string'
          and p_value->>'offending_syntax' ~ '^(begin:)?[A-Za-z]{1,32}$'))
        and (p_value->'offending_unicode_code_point' = 'null'::jsonb or (
          pg_catalog.jsonb_typeof(p_value->'offending_unicode_code_point') = 'string'
          and p_value->>'offending_unicode_code_point' ~ '^U\+[0-9A-F]{4,6}$')))
    )
$$;

create table public.material_analysis_latex_diagnostics (
  singleton boolean primary key default true check (singleton),
  armed_at timestamptz not null default pg_catalog.now(),
  claimed_at timestamptz,
  metadata jsonb,
  captured_at timestamptz,
  constraint material_analysis_latex_diagnostic_state check (
    (claimed_at is null and metadata is null and captured_at is null)
    or (claimed_at is not null and metadata is null and captured_at is null)
    or (claimed_at is not null and metadata is not null and captured_at is not null
      and public.material_analysis_latex_diagnostic_valid(metadata))
  )
);
alter table public.material_analysis_latex_diagnostics enable row level security;
alter table public.material_analysis_latex_diagnostics force row level security;
revoke all on table public.material_analysis_latex_diagnostics
  from public, anon, authenticated, service_role;
grant select on table public.material_analysis_latex_diagnostics to service_role;
insert into public.material_analysis_latex_diagnostics(singleton) values (true);

create or replace function public.claim_material_analysis_latex_diagnostic_internal()
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_batch public.material_processing_batches%rowtype;
  v_page_count integer;
  v_count integer;
begin
  update public.material_analysis_latex_diagnostics
  set claimed_at = pg_catalog.now()
  where singleton and claimed_at is null and metadata is null;
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'latex_diagnostic_unavailable'; end if;

  select b.* into v_batch
  from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id
    and j.material_id=b.material_id and j.user_id=b.user_id
  where encode(extensions.digest(b.id::text,'sha256'),'hex') =
      'e2856abe86ca806e64bbd65e4f6a609f8954bdd36c8de399dd73348ebb3127d8'
    and b.operation='final_summary' and b.status='failed'
    and b.failure_code='structured_output_invalid'
    and b.upstream_response_id is not null
    and j.status='failed' and j.safe_error_code='structured_output_invalid';
  if not found then raise exception 'latex_diagnostic_unavailable'; end if;

  select j.page_count into v_page_count
  from public.material_processing_jobs j where j.id=v_batch.job_id;
  if v_page_count not between 1 and 100 then
    raise exception 'latex_diagnostic_unavailable';
  end if;
  return pg_catalog.jsonb_build_object(
    'response_id',v_batch.upstream_response_id,
    'page_count',v_page_count
  );
exception when others then
  if v_count = 1 then
    update public.material_analysis_latex_diagnostics set claimed_at=null
    where singleton and metadata is null;
  end if;
  raise;
end
$$;

create or replace function public.record_material_analysis_latex_diagnostic_internal(
  p_metadata jsonb
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_count integer;
begin
  if not public.material_analysis_latex_diagnostic_valid(p_metadata) then
    raise exception 'invalid_latex_diagnostic';
  end if;
  update public.material_analysis_latex_diagnostics
  set metadata=p_metadata,captured_at=pg_catalog.now()
  where singleton and claimed_at is not null and metadata is null;
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'latex_diagnostic_unavailable'; end if;
end
$$;

do $$
declare f regprocedure;
begin
  if current_user <> 'postgres' then
    raise exception 'unexpected_latex_diagnostic_owner';
  end if;
  foreach f in array array[
    'public.material_analysis_latex_diagnostic_valid(jsonb)'::regprocedure,
    'public.claim_material_analysis_latex_diagnostic_internal()'::regprocedure,
    'public.record_material_analysis_latex_diagnostic_internal(jsonb)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres',f);
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
  end loop;
  grant execute on function public.claim_material_analysis_latex_diagnostic_internal()
    to service_role;
  grant execute on function public.record_material_analysis_latex_diagnostic_internal(jsonb)
    to service_role;
end
$$;

notify pgrst, 'reload schema';
