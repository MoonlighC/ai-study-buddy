-- Exact PostgREST authority for trusted Edge Functions on fresh projects where
-- automatic table exposure is disabled. RLS remains enabled and client grants
-- from migration 008 are intentionally unchanged.

grant usage on schema public to service_role;

-- Summary generation and selectable-text/OCR processing read material state,
-- filter on lifecycle/ownership columns, return rows, and update only these
-- server-managed output columns.
grant select on table public.materials to service_role;
grant update (summary, content_text, processing_status, metadata)
on table public.materials to service_role;

-- Generated flashcards are inserted by generate-flashcards and returned to the
-- caller. Review and lifecycle columns are populated by table defaults.
grant select on table public.flashcards to service_role;
grant insert (
  user_id,
  subject_id,
  material_id,
  front,
  back,
  topic,
  difficulty,
  metadata
) on table public.flashcards to service_role;

-- Quiz generation inserts a quiz and its questions, reads the inserted rows,
-- and deletes the just-created quiz only when question persistence fails.
grant select on table public.quizzes to service_role;
grant insert (
  user_id,
  subject_id,
  material_id,
  title,
  quiz_type,
  question_count,
  metadata
) on table public.quizzes to service_role;
grant delete on table public.quizzes to service_role;

grant select on table public.quiz_questions to service_role;
grant insert (
  user_id,
  quiz_id,
  subject_id,
  material_id,
  question,
  options,
  correct_answer,
  explanation,
  topic,
  difficulty,
  sort_order,
  metadata
) on table public.quiz_questions to service_role;

-- PostgreSQL grants function EXECUTE to PUBLIC by default. Reassert every
-- trusted-only boundary explicitly; operation tables remain inaccessible via
-- PostgREST and are mutated only inside these fixed-search-path definers.
revoke all on function public.begin_material_deletion_internal(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.mark_material_storage_cleanup_internal(
  uuid, uuid, text, text
) from public, anon, authenticated;
revoke all on function public.finalize_material_deletion_internal(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.begin_subject_deletion_internal(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.mark_subject_deletion_internal(
  uuid, uuid, text, text, integer, integer
) from public, anon, authenticated;
revoke all on function public.finalize_subject_deletion_internal(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.begin_account_deletion_internal(uuid)
from public, anon, authenticated;
revoke all on function public.mark_account_deletion_internal(
  uuid, text, text, integer, integer
) from public, anon, authenticated;

grant execute on function public.begin_material_deletion_internal(uuid, uuid)
to service_role;
grant execute on function public.mark_material_storage_cleanup_internal(
  uuid, uuid, text, text
) to service_role;
grant execute on function public.finalize_material_deletion_internal(uuid, uuid)
to service_role;
grant execute on function public.begin_subject_deletion_internal(uuid, uuid)
to service_role;
grant execute on function public.mark_subject_deletion_internal(
  uuid, uuid, text, text, integer, integer
) to service_role;
grant execute on function public.finalize_subject_deletion_internal(uuid, uuid)
to service_role;
grant execute on function public.begin_account_deletion_internal(uuid)
to service_role;
grant execute on function public.mark_account_deletion_internal(
  uuid, text, text, integer, integer
) to service_role;

-- Keep every client-facing and server-owned table behind its existing RLS
-- policies. A service-role RLS bypass never substitutes for the grants above.
alter table public.materials enable row level security;
alter table public.flashcards enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.subject_deletion_operations enable row level security;
alter table public.account_deletion_operations enable row level security;

notify pgrst, 'reload schema';
