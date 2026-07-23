-- Narrow cancellation for an accidentally started, entirely empty flashcard session.

create or replace function public.cancel_empty_study_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_session public.study_sessions%rowtype;
begin
  if v_user is null or p_session_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select * into v_session
  from public.study_sessions
  where id = p_session_id and user_id = v_user
  for update;

  if not found then
    if exists(select 1 from public.study_sessions where id = p_session_id) then
      raise exception 'study_session_unavailable' using errcode = '42501';
    end if;
    return true;
  end if;

  if v_session.session_type <> 'flashcards'
    or v_session.ended_at is not null
    or v_session.deleted_at is not null
    or v_session.items_completed <> 0
    or jsonb_typeof(v_session.metadata) <> 'object'
    or v_session.metadata->>'status' <> 'active'
    or v_session.metadata->>'mode' <> 'all'
    or coalesce((v_session.metadata->>'current_index')::integer, -1) <> 0
    or coalesce((v_session.metadata->>'known_count')::integer, -1) <> 0
    or coalesce((v_session.metadata->>'not_known_count')::integer, -1) <> 0
    or coalesce((v_session.metadata->>'answer_visible')::boolean, true)
    or jsonb_typeof(v_session.metadata->'graded_card_ids') <> 'array'
    or jsonb_array_length(v_session.metadata->'graded_card_ids') <> 0
  then
    raise exception 'study_session_not_empty' using errcode = '22023';
  end if;

  delete from public.study_sessions
  where id = p_session_id and user_id = v_user;
  return true;
end
$$;

alter function public.cancel_empty_study_session(uuid) owner to postgres;
revoke all on function public.cancel_empty_study_session(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.cancel_empty_study_session(uuid)
  to authenticated;
