-- Fresh-project PostgREST privileges for the authenticated Flutter client.
-- RLS remains the row-ownership boundary; grants below only expose operations
-- that are present in the current client repositories.

grant usage on schema public to authenticated;
revoke usage on schema public from anon;

-- Remove accidental/public API authority before granting the exact client set.
revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.subjects from public, anon, authenticated;
revoke all on table public.materials from public, anon, authenticated;
revoke all on table public.favorites from public, anon, authenticated;
revoke all on table public.flashcards from public, anon, authenticated;
revoke all on table public.quizzes from public, anon, authenticated;
revoke all on table public.quiz_questions from public, anon, authenticated;
revoke all on table public.quiz_attempts from public, anon, authenticated;
revoke all on table public.weak_topics from public, anon, authenticated;
revoke all on table public.study_sessions from public, anon, authenticated;
revoke all on table public.daily_usage_limits from public, anon, authenticated;
revoke all on table public.usage_logs from public, anon, authenticated;

grant select on table public.profiles to authenticated;
grant insert (id, email, display_name) on table public.profiles to authenticated;
grant update (id, email, display_name) on table public.profiles to authenticated;

grant select on table public.subjects to authenticated;
grant insert (user_id, name, description, color_value, sort_order)
on table public.subjects to authenticated;
grant update (name, description, color_value, icon_name, sort_order)
on table public.subjects to authenticated;

grant select on table public.materials to authenticated;
grant insert (
  id,
  user_id,
  subject_id,
  title,
  kind,
  source_kind,
  content_text,
  storage_bucket,
  storage_path,
  mime_type,
  file_size_bytes,
  processing_status
) on table public.materials to authenticated;

grant select on table public.favorites to authenticated;
grant insert (user_id, entity_type, entity_id)
on table public.favorites to authenticated;
grant delete on table public.favorites to authenticated;

grant select on table public.flashcards to authenticated;
grant update (
  correct_count,
  incorrect_count,
  last_reviewed_at,
  next_review_at
) on table public.flashcards to authenticated;

grant select on table public.quizzes to authenticated;
grant select on table public.quiz_questions to authenticated;
grant select on table public.quiz_attempts to authenticated;
grant select on table public.weak_topics to authenticated;

-- No current Flutter repository directly accesses these server-owned tables.
revoke all on table public.study_sessions from authenticated;
revoke all on table public.daily_usage_limits from authenticated;
revoke all on table public.usage_logs from authenticated;

-- Deletion operation state is never part of the PostgREST client surface.
revoke all on table public.subject_deletion_operations
from public, anon, authenticated;
revoke all on table public.account_deletion_operations
from public, anon, authenticated;

-- PostgreSQL grants function EXECUTE to PUBLIC by default. Reassert every
-- trusted-only lifecycle boundary in this forward migration.
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

-- These are the only RPC functions invoked directly by Flutter.
revoke all on function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) from public, anon;
grant execute on function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) to authenticated;
revoke all on function public.inspect_material_recovery(uuid)
from public, anon;
revoke all on function public.recover_stale_material(uuid, text)
from public, anon;
grant execute on function public.inspect_material_recovery(uuid)
to authenticated;
grant execute on function public.recover_stale_material(uuid, text)
to authenticated;

-- All API-exposed tables continue to enforce the policies created earlier.
alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.materials enable row level security;
alter table public.favorites enable row level security;
alter table public.flashcards enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.weak_topics enable row level security;
alter table public.study_sessions enable row level security;
alter table public.daily_usage_limits enable row level security;
alter table public.usage_logs enable row level security;
alter table public.subject_deletion_operations enable row level security;
alter table public.account_deletion_operations enable row level security;

notify pgrst, 'reload schema';
