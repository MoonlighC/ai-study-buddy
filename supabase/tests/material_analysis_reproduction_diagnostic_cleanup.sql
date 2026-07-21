\set ON_ERROR_STOP on

create or replace function pg_temp.assert_reproduction_cleanup(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'reproduction_cleanup_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_reproduction_cleanup(
  to_regclass('public.material_analysis_reproduction_diagnostics') is null
  and to_regprocedure(
    'public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)'
  ) is null
  and to_regprocedure(
    'public.attach_material_analysis_reproduction_job_internal()'
  ) is null
  and to_regprocedure(
    'public.material_analysis_reproduction_metadata_valid(jsonb)'
  ) is null
  and not exists (
    select 1 from pg_trigger
    where tgname='attach_material_analysis_reproduction_job' and not tgisinternal
  ),
  'all migration-020-only objects are removed'
);

select pg_temp.assert_reproduction_cleanup(
  to_regclass('public.materials') is not null
  and to_regclass('public.material_processing_jobs') is not null
  and to_regclass('public.material_processing_batches') is not null
  and to_regclass('public.material_processing_attempts') is not null
  and to_regprocedure(
    'public.terminalize_material_analysis_operation_internal(uuid,uuid,text)'
  ) is not null
  and exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='materials'
      and column_name='summary_payload'
  )
  and exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='material_processing_batches'
      and column_name='upstream_response_id'
  ),
  'normal summaries, response identities, and reconciliation remain intact'
);

select pg_temp.assert_reproduction_cleanup(
  exists (
    select 1 from public.materials
    where id='20202020-2020-4020-8020-202020202001'
  )
  and exists (
    select 1 from public.material_processing_jobs
    where material_id='20202020-2020-4020-8020-202020202001'
  )
  and exists (
    select 1 from public.material_processing_batches
    where material_id='20202020-2020-4020-8020-202020202001'
  ),
  'cleanup preserves the correlated material and normal processing rows'
);
