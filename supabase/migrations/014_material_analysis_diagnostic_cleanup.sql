-- Follow-up cleanup after the staging controlled fixture completed.
-- It removes every capability introduced by temporary migration 013.

drop trigger if exists attach_material_analysis_diagnostic_final_batch
  on public.material_processing_batches;
drop trigger if exists attach_material_analysis_diagnostic_job
  on public.material_processing_jobs;

drop function if exists
  public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer);
drop function if exists
  public.select_material_analysis_diagnostic_target_internal();
drop function if exists
  public.attach_material_analysis_diagnostic_final_batch_internal();
drop function if exists
  public.attach_material_analysis_diagnostic_job_internal();

drop table if exists public.material_analysis_diagnostic_correlations;

notify pgrst, 'reload schema';
