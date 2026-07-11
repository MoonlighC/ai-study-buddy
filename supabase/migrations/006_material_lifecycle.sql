-- Phase 9D: server-authoritative material deletion and stale processor recovery.

alter table public.materials
  add column cleanup_status text,
  add column cleanup_started_at timestamptz,
  add column cleanup_updated_at timestamptz,
  add column cleanup_error_code text,
  add constraint materials_cleanup_status_check check (
    cleanup_status is null or cleanup_status in (
      'pending_storage', 'storage_failed', 'storage_removed', 'not_required'
    )
  ),
  add constraint materials_cleanup_error_code_check check (
    cleanup_error_code is null or cleanup_error_code in (
      'storage_delete_failed', 'storage_response_invalid'
    )
  );

create index materials_cleanup_pending_idx
on public.materials (cleanup_updated_at)
where deleted_at is not null and cleanup_status is not null;

revoke delete on table public.materials from public, anon, authenticated;
drop policy if exists "Users can delete own materials" on public.materials;

drop policy if exists "Users can read own materials" on public.materials;
create policy "Users can read own active materials"
on public.materials for select
to authenticated
using (user_id = (select auth.uid()) and deleted_at is null);

create or replace function public.begin_material_deletion_internal(p_user_id uuid, p_material_id uuid)
returns table (
  outcome text,
  material_kind text,
  source_kind text,
  storage_bucket text,
  storage_path text,
  cleanup_status text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target public.materials%rowtype;
  flashcard_ids uuid[];
  quiz_ids uuid[];
begin
  if p_user_id is null then raise exception 'user_required' using errcode = '22023'; end if;

  select * into target from public.materials
  where id = p_material_id and user_id = p_user_id
  for update;

  if not found then
    return query select 'not_found'::text, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;

  select coalesce(array_agg(id), '{}'::uuid[]) into flashcard_ids
  from public.flashcards where material_id = target.id and user_id = p_user_id;
  select coalesce(array_agg(id), '{}'::uuid[]) into quiz_ids
  from public.quizzes where material_id = target.id and user_id = p_user_id;

  update public.materials set
    deleted_at = coalesce(deleted_at, statement_timestamp()),
    processing_status = case when target.processing_status = 'processing' then 'failed' else target.processing_status end,
    metadata = target.metadata - 'pdf_extraction_claim' - 'image_ocr_claim' - 'scanned_pdf_ocr_claim',
    cleanup_status = case when target.source_kind = 'upload' then
      case when target.cleanup_status in ('storage_removed', 'storage_failed') then target.cleanup_status else 'pending_storage' end
      else 'not_required' end,
    cleanup_started_at = coalesce(target.cleanup_started_at, statement_timestamp()),
    cleanup_updated_at = statement_timestamp(),
    cleanup_error_code = case when target.cleanup_status = 'storage_failed' then target.cleanup_error_code else null end
  where id = target.id;

  delete from public.favorites
  where user_id = p_user_id and (
    (entity_type = 'material' and entity_id = target.id)
    or (entity_type = 'flashcard' and entity_id = any(flashcard_ids))
    or (entity_type = 'quiz' and entity_id = any(quiz_ids))
  );
  delete from public.flashcards where user_id = p_user_id and material_id = target.id;
  delete from public.quizzes where user_id = p_user_id and material_id = target.id;

  return query
  select 'pending'::text, m.kind, m.source_kind, m.storage_bucket, m.storage_path, m.cleanup_status
  from public.materials m where m.id = target.id;
end;
$$;

create or replace function public.mark_material_storage_cleanup_internal(
  p_user_id uuid,
  p_material_id uuid,
  p_outcome text,
  p_safe_error_code text default null
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare target public.materials%rowtype;
begin
  if p_user_id is null then raise exception 'user_required' using errcode = '22023'; end if;
  if p_outcome not in ('removed', 'failed') then raise exception 'invalid_outcome' using errcode = '22023'; end if;
  if p_outcome = 'failed' and p_safe_error_code not in ('storage_delete_failed', 'storage_response_invalid') then
    raise exception 'invalid_error_code' using errcode = '22023';
  end if;
  select * into target from public.materials
  where id = p_material_id and user_id = p_user_id and deleted_at is not null for update;
  if not found then return 'not_found'; end if;
  if target.source_kind <> 'upload' then return 'not_required'; end if;
  update public.materials set
    cleanup_status = case when p_outcome = 'removed' then 'storage_removed' else 'storage_failed' end,
    cleanup_error_code = case when p_outcome = 'failed' then p_safe_error_code else null end,
    cleanup_updated_at = statement_timestamp()
  where id = target.id;
  return case when p_outcome = 'removed' then 'storage_removed' else 'storage_failed' end;
end;
$$;

create or replace function public.finalize_material_deletion_internal(p_user_id uuid, p_material_id uuid)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare target public.materials%rowtype; flashcard_ids uuid[]; quiz_ids uuid[];
begin
  if p_user_id is null then raise exception 'user_required' using errcode = '22023'; end if;
  select * into target from public.materials
  where id = p_material_id and user_id = p_user_id and deleted_at is not null for update;
  if not found then return 'not_found'; end if;
  if target.cleanup_status not in ('storage_removed', 'not_required') then
    raise exception 'cleanup_incomplete' using errcode = '55000';
  end if;
  select coalesce(array_agg(id), '{}'::uuid[]) into flashcard_ids from public.flashcards where material_id = target.id and user_id = p_user_id;
  select coalesce(array_agg(id), '{}'::uuid[]) into quiz_ids from public.quizzes where material_id = target.id and user_id = p_user_id;
  delete from public.favorites where user_id = p_user_id and (
    (entity_type = 'material' and entity_id = target.id)
    or (entity_type = 'flashcard' and entity_id = any(flashcard_ids))
    or (entity_type = 'quiz' and entity_id = any(quiz_ids))
  );
  delete from public.flashcards where user_id = p_user_id and material_id = target.id;
  delete from public.quizzes where user_id = p_user_id and material_id = target.id;
  delete from public.materials where id = target.id and user_id = p_user_id;
  return 'deleted';
end;
$$;

create or replace function public.inspect_material_recovery(p_material_id uuid)
returns table (eligible boolean, processor text, reason text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid(); target public.materials%rowtype; claim_count integer; claim_key text;
  claim_value jsonb; claimed_at timestamptz;
begin
  if caller is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into target from public.materials
  where id = p_material_id and user_id = caller and deleted_at is null;
  if not found then return query select false, null::text, 'unavailable'::text; return; end if;
  if target.processing_status <> 'processing' then return query select false, null::text, 'not_processing'::text; return; end if;
  if nullif(btrim(coalesce(target.content_text, '')), '') is not null then return query select false, null::text, 'content_available'::text; return; end if;
  select count(*), min(key) into claim_count, claim_key
  from jsonb_each(target.metadata) where key in ('pdf_extraction_claim', 'image_ocr_claim', 'scanned_pdf_ocr_claim');
  if claim_count <> 1 then return query select false, null::text, 'ambiguous_claim'::text; return; end if;
  claim_value := target.metadata -> claim_key;
  begin
    claimed_at := case
      when jsonb_typeof(claim_value) = 'object' then nullif(claim_value ->> 'claimed_at', '')::timestamptz
      when jsonb_typeof(claim_value) = 'string' then target.updated_at
      else null end;
  exception when others then claimed_at := null;
  end;
  if claimed_at is null then return query select false, null::text, 'invalid_claim'::text; return; end if;
  if claimed_at > statement_timestamp() - interval '15 minutes' then
    return query select false, replace(claim_key, '_claim', ''), 'not_stale'::text; return;
  end if;
  if (claim_key = 'pdf_extraction_claim' and target.metadata ? 'pdf_extraction'
      and coalesce(target.metadata#>>'{pdf_extraction,character_count}', '') ~ '^[0-9]+$'
      and length(target.metadata#>>'{pdf_extraction,character_count}') <= 9
      and (target.metadata#>>'{pdf_extraction,character_count}')::integer > 0)
    or (claim_key = 'image_ocr_claim' and target.metadata ? 'image_ocr')
    or (claim_key = 'scanned_pdf_ocr_claim' and target.metadata ? 'scanned_pdf_ocr') then
    return query select false, replace(claim_key, '_claim', ''), 'completed_metadata'::text; return;
  end if;
  return query select true, replace(claim_key, '_claim', ''), 'stale'::text;
end;
$$;

create or replace function public.recover_stale_material(p_material_id uuid, p_processor text)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare caller uuid := auth.uid(); target public.materials%rowtype; check_row record; claim_key text;
begin
  if caller is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  if p_processor not in ('pdf_extraction', 'image_ocr', 'scanned_pdf_ocr') then raise exception 'invalid_processor' using errcode = '22023'; end if;
  select * into target from public.materials where id = p_material_id and user_id = caller and deleted_at is null for update;
  if not found then return 'unavailable'; end if;
  select * into check_row from public.inspect_material_recovery(p_material_id);
  if not coalesce(check_row.eligible, false) or check_row.processor is distinct from p_processor then return coalesce(check_row.reason, 'unavailable'); end if;
  claim_key := p_processor || '_claim';
  update public.materials set
    processing_status = 'failed',
    metadata = metadata - claim_key,
    updated_at = statement_timestamp()
  where id = target.id and user_id = caller and deleted_at is null and processing_status = 'processing';
  return 'recovered';
end;
$$;

revoke all on function public.begin_material_deletion_internal(uuid, uuid) from public, anon, authenticated;
revoke all on function public.mark_material_storage_cleanup_internal(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.finalize_material_deletion_internal(uuid, uuid) from public, anon, authenticated;
revoke all on function public.inspect_material_recovery(uuid) from public, anon;
revoke all on function public.recover_stale_material(uuid, text) from public, anon;
grant execute on function public.begin_material_deletion_internal(uuid, uuid) to service_role;
grant execute on function public.mark_material_storage_cleanup_internal(uuid, uuid, text, text) to service_role;
grant execute on function public.finalize_material_deletion_internal(uuid, uuid) to service_role;
grant execute on function public.inspect_material_recovery(uuid) to authenticated;
grant execute on function public.recover_stale_material(uuid, text) to authenticated;
