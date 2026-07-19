\set ON_ERROR_STOP on

do $$
begin
  if to_regclass('public.material_analysis_diagnostic_correlations') is not null
    or to_regprocedure(
      'public.select_material_analysis_diagnostic_target_internal()'
    ) is not null
    or to_regprocedure(
      'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)'
    ) is not null
    or to_regprocedure(
      'public.attach_material_analysis_diagnostic_job_internal()'
    ) is not null
    or to_regprocedure(
      'public.attach_material_analysis_diagnostic_final_batch_internal()'
    ) is not null
    or exists (
      select 1 from pg_trigger
      where not tgisinternal
        and tgname in (
          'attach_material_analysis_diagnostic_job',
          'attach_material_analysis_diagnostic_final_batch'
        )
    )
  then
    raise exception 'diagnostic_cleanup_incomplete';
  end if;
end
$$;

select 'phase_c_diagnostic_cleanup_passed' as result;
