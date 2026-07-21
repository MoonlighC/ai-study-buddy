-- Remove only the one-shot LaTeX diagnostic objects introduced by migration 022.
drop table if exists public.material_analysis_latex_diagnostics;
drop function if exists public.record_material_analysis_latex_diagnostic_internal(jsonb);
drop function if exists public.claim_material_analysis_latex_diagnostic_internal();
drop function if exists public.material_analysis_latex_diagnostic_valid(jsonb);
notify pgrst, 'reload schema';
