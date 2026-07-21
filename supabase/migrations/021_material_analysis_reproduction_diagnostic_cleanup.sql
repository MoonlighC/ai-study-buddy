-- Remove only the one-shot staging reproduction diagnostics introduced by
-- migration 020. Normal analysis state, response identities, summaries, and
-- reconciliation functions remain untouched.

drop trigger if exists attach_material_analysis_reproduction_job
  on public.material_processing_jobs;
drop table if exists public.material_analysis_reproduction_diagnostics;
drop function if exists
  public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb);
drop function if exists
  public.attach_material_analysis_reproduction_job_internal();
drop function if exists
  public.material_analysis_reproduction_metadata_valid(jsonb);

notify pgrst, 'reload schema';
