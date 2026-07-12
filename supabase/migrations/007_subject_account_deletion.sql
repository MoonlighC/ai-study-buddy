-- Phase 12.1: trusted, resumable subject and account deletion.

create table public.subject_deletion_operations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  stage text not null default 'pending_storage' check (stage in ('pending_storage','storage_failed','storage_verified','database_failed')),
  safe_error_code text check (safe_error_code is null or safe_error_code in ('storage_cleanup_failed','database_cleanup_failed','retry_later','unknown')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  objects_found integer not null default 0 check (objects_found between 0 and 1000000),
  objects_removed integer not null default 0 check (objects_removed between 0 and 1000000),
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, subject_id)
);

create table public.account_deletion_operations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  stage text not null default 'pending_storage' check (stage in ('pending_storage','storage_failed','storage_verified','database_ready','auth_failed')),
  safe_error_code text check (safe_error_code is null or safe_error_code in ('storage_cleanup_failed','database_cleanup_failed','auth_cleanup_failed','retry_later','unknown')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  objects_found integer not null default 0 check (objects_found between 0 and 1000000),
  objects_removed integer not null default 0 check (objects_removed between 0 and 1000000),
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create index subject_deletion_operations_stale_idx on public.subject_deletion_operations(updated_at) where completed_at is null;
create index account_deletion_operations_stale_idx on public.account_deletion_operations(updated_at) where completed_at is null;
alter table public.subject_deletion_operations enable row level security;
alter table public.account_deletion_operations enable row level security;
revoke all on public.subject_deletion_operations from public, anon, authenticated;
revoke all on public.account_deletion_operations from public, anon, authenticated;

-- Existing authenticated subject updates remain owner-scoped, but lifecycle
-- authority is removed by permitting only ordinary editable columns.
revoke update on public.subjects from authenticated;
grant update (name, description, color_value, icon_name, sort_order) on public.subjects to authenticated;

create or replace function public.begin_subject_deletion_internal(p_user_id uuid, p_subject_id uuid)
returns table(operation_id uuid, outcome text, stage text, material_ids uuid[], attempt_count integer)
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare target public.subjects%rowtype; op public.subject_deletion_operations%rowtype; ids uuid[];
begin
  if p_user_id is null then raise exception 'user_required' using errcode='22023'; end if;
  select * into target from public.subjects where id=p_subject_id and user_id=p_user_id for update;
  if not found then return query select null::uuid,'not_found'::text,null::text,'{}'::uuid[],0; return; end if;
  update public.subjects set deleted_at=coalesce(deleted_at,statement_timestamp()) where id=target.id;
  select * into op from public.subject_deletion_operations where user_id=p_user_id and subject_id=p_subject_id for update;
  if found and op.stage in ('pending_storage','storage_verified') and op.updated_at > statement_timestamp()-interval '15 minutes' then
    select coalesce(array_agg(id order by id),'{}'::uuid[]) into ids from public.materials where user_id=p_user_id and subject_id=p_subject_id;
    return query select op.id,'in_progress'::text,op.stage,ids,op.attempt_count; return;
  end if;
  insert into public.subject_deletion_operations(user_id,subject_id,attempt_count)
  values(p_user_id,p_subject_id,1)
  on conflict(user_id,subject_id) do update set attempt_count=subject_deletion_operations.attempt_count+1,updated_at=statement_timestamp(),safe_error_code=null
  returning * into op;
  select coalesce(array_agg(id order by id),'{}'::uuid[]) into ids from public.materials where user_id=p_user_id and subject_id=p_subject_id;
  return query select op.id,'pending'::text,op.stage,ids,op.attempt_count;
end; $$;

create or replace function public.mark_subject_deletion_internal(p_user_id uuid,p_subject_id uuid,p_stage text,p_safe_error_code text,p_found integer,p_removed integer)
returns text language plpgsql security definer set search_path = pg_catalog, public
as $$ begin
  if p_stage not in ('pending_storage','storage_failed','storage_verified','database_failed') then raise exception 'invalid_stage' using errcode='22023'; end if;
  if p_found < 0 or p_found > 1000000 or p_removed < 0 or p_removed > 1000000 then raise exception 'invalid_count' using errcode='22023'; end if;
  update public.subject_deletion_operations set stage=p_stage,safe_error_code=p_safe_error_code,objects_found=p_found,objects_removed=p_removed,updated_at=statement_timestamp()
  where user_id=p_user_id and subject_id=p_subject_id;
  return case when found then p_stage else 'not_found' end;
end; $$;

create or replace function public.finalize_subject_deletion_internal(p_user_id uuid,p_subject_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, public
as $$
declare mids uuid[]; fids uuid[]; qids uuid[];
begin
  perform 1 from public.subjects where id=p_subject_id and user_id=p_user_id and deleted_at is not null for update;
  if not found then return 'not_found'; end if;
  perform 1 from public.subject_deletion_operations where user_id=p_user_id and subject_id=p_subject_id and stage='storage_verified' for update;
  if not found then raise exception 'storage_not_verified' using errcode='55000'; end if;
  select coalesce(array_agg(id),'{}'::uuid[]) into mids from public.materials where user_id=p_user_id and subject_id=p_subject_id;
  select coalesce(array_agg(id),'{}'::uuid[]) into fids from public.flashcards where user_id=p_user_id and (subject_id=p_subject_id or material_id=any(mids));
  select coalesce(array_agg(id),'{}'::uuid[]) into qids from public.quizzes where user_id=p_user_id and (subject_id=p_subject_id or material_id=any(mids));
  delete from public.favorites where user_id=p_user_id and ((entity_type='subject' and entity_id=p_subject_id) or (entity_type='material' and entity_id=any(mids)) or (entity_type='flashcard' and entity_id=any(fids)) or (entity_type='quiz' and entity_id=any(qids)));
  delete from public.study_sessions where user_id=p_user_id and (subject_id=p_subject_id or material_id=any(mids));
  delete from public.weak_topics where user_id=p_user_id and (subject_id=p_subject_id or material_id=any(mids));
  delete from public.quiz_attempts where user_id=p_user_id and (subject_id=p_subject_id or quiz_id=any(qids));
  delete from public.quiz_questions where user_id=p_user_id and (subject_id=p_subject_id or material_id=any(mids) or quiz_id=any(qids));
  delete from public.quizzes where user_id=p_user_id and id=any(qids);
  delete from public.flashcards where user_id=p_user_id and id=any(fids);
  delete from public.materials where user_id=p_user_id and id=any(mids);
  delete from public.subjects where user_id=p_user_id and id=p_subject_id;
  return 'deleted';
end; $$;

create or replace function public.begin_account_deletion_internal(p_user_id uuid)
returns table(operation_id uuid,outcome text,stage text,attempt_count integer)
language plpgsql security definer set search_path = pg_catalog, public
as $$ declare op public.account_deletion_operations%rowtype; begin
  if p_user_id is null or not exists(select 1 from auth.users where id=p_user_id) then raise exception 'user_required' using errcode='22023'; end if;
  select * into op from public.account_deletion_operations where user_id=p_user_id for update;
  if found and op.stage in ('pending_storage','storage_verified','database_ready') and op.updated_at > statement_timestamp()-interval '15 minutes' then
    return query select op.id,'in_progress'::text,op.stage,op.attempt_count; return;
  end if;
  insert into public.account_deletion_operations(user_id,attempt_count) values(p_user_id,1)
  on conflict(user_id) do update set attempt_count=account_deletion_operations.attempt_count+1,updated_at=statement_timestamp(),safe_error_code=null
  returning * into op;
  return query select op.id,'pending'::text,op.stage,op.attempt_count;
end; $$;

create or replace function public.mark_account_deletion_internal(p_user_id uuid,p_stage text,p_safe_error_code text,p_found integer,p_removed integer)
returns text language plpgsql security definer set search_path = pg_catalog, public
as $$ begin
  if p_stage not in ('pending_storage','storage_failed','storage_verified','database_ready','auth_failed') then raise exception 'invalid_stage' using errcode='22023'; end if;
  if p_found < 0 or p_found > 1000000 or p_removed < 0 or p_removed > 1000000 then raise exception 'invalid_count' using errcode='22023'; end if;
  update public.account_deletion_operations set stage=p_stage,safe_error_code=p_safe_error_code,objects_found=p_found,objects_removed=p_removed,updated_at=statement_timestamp()
  where user_id=p_user_id;
  return case when found then p_stage else 'not_found' end;
end; $$;

revoke all on function public.begin_subject_deletion_internal(uuid,uuid) from public,anon,authenticated;
revoke all on function public.mark_subject_deletion_internal(uuid,uuid,text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.finalize_subject_deletion_internal(uuid,uuid) from public,anon,authenticated;
revoke all on function public.begin_account_deletion_internal(uuid) from public,anon,authenticated;
revoke all on function public.mark_account_deletion_internal(uuid,text,text,integer,integer) from public,anon,authenticated;
grant execute on function public.begin_subject_deletion_internal(uuid,uuid) to service_role;
grant execute on function public.mark_subject_deletion_internal(uuid,uuid,text,text,integer,integer) to service_role;
grant execute on function public.finalize_subject_deletion_internal(uuid,uuid) to service_role;
grant execute on function public.begin_account_deletion_internal(uuid) to service_role;
grant execute on function public.mark_account_deletion_internal(uuid,text,text,integer,integer) to service_role;
