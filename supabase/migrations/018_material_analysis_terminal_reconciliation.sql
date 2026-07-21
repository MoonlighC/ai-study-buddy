-- Terminalize provider responses that are already terminal and expose only a
-- bounded safe error code to authenticated clients.

create or replace function public.terminalize_material_analysis_operation_internal(
  p_batch_id uuid,p_lease_token uuid,p_failure_class text
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype; v_safe_code text;
begin
  v_safe_code := case p_failure_class
    when 'terminal_provider_incomplete' then 'provider_temporarily_unavailable'
    when 'terminal_provider_failed' then 'provider_temporarily_unavailable'
    when 'terminal_structured_output_invalid' then 'structured_output_invalid'
    else null
  end;
  if v_safe_code is null then raise exception 'invalid_terminal_failure_class'; end if;
  select b.* into v_batch from public.material_processing_batches b
  join public.material_processing_jobs j on j.id=b.job_id
  where b.id=p_batch_id and b.lease_token=p_lease_token
    and j.active_lease_token=p_lease_token
    and b.status in ('response_known','reconciliation_required')
    and b.upstream_response_id is not null
  for update of b;
  if not found then raise exception 'terminalization_conflict'; end if;
  update public.material_processing_attempts
  set status='failed',failure_code=v_safe_code,budget_effect='released',
    ambiguity_state='none',completed_at=now(),updated_at=now()
  where id=v_batch.current_attempt_id;
  update public.material_processing_batches
  set status='failed',failure_code=v_safe_code,budget_state='released',
    completed_at=now(),lease_token=null,lease_expires_at=null,updated_at=now()
  where id=v_batch.id;
  update public.material_processing_artifacts
  set state='cleanup_pending',lease_token=null,lease_expires_at=null,
    cleanup_retry_after=null,updated_at=now()
  where batch_id=v_batch.id and state='uploaded';
  update public.material_processing_jobs
  set status='failed',safe_error_code=v_safe_code,budget_state='released',
    active_lease_token=null,active_lease_expires_at=null,completed_at=now(),
    updated_at=now()
  where id=v_batch.job_id and active_lease_token=p_lease_token;
  if not found then raise exception 'job_terminalization_conflict'; end if;
  update public.materials
  set processing_status='failed',updated_at=now()
  where id=v_batch.material_id and user_id=v_batch.user_id
    and processing_status in ('pending','processing');
end
$$;

drop function public.get_material_analysis_status(uuid);

create function public.get_material_analysis_status(p_material_id uuid)
returns table(
  material_id uuid,processing_mode text,state text,public_stage text,page_count integer,
  completed_pages integer,confirmation_required boolean,can_retry boolean,
  retry_after_seconds integer,warnings jsonb,summary_schema_version integer,
  summary_payload jsonb,safe_error_code text,active_operation text
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,j.processing_mode,case when j.status='prepared' then 'processing' else j.status end,
    j.public_stage,j.page_count,j.completed_page_count,
    (j.status='awaiting_confirmation' and j.confirmation_required),
    (j.status='user_retry_required' and exists(
      select 1 from public.material_processing_batches retry_batch
      where retry_batch.job_id=j.id and retry_batch.status='user_retry_required'
        and retry_batch.attempt_count<retry_batch.max_attempts
    )),
    case when j.next_retry_at is null then null
      else greatest(0,least(900,extract(epoch from (j.next_retry_at-now()))::integer)) end,
    case when m.summary_payload is not null and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload->'warnings' else j.warning_payload end,m.summary_schema_version,
    case when m.summary_validation_version='phase-c-validator-v2'
      and m.summary_validation_hash ~ '^[0-9a-f]{64}$'
      and public.material_analysis_valid_summary_payload(m.summary_payload)
      then m.summary_payload else null end,
    case when j.safe_error_code in (
      'unable_to_extract_content','provider_temporarily_unavailable',
      'structured_output_invalid'
    ) then j.safe_error_code else null end,
    (select b.operation from public.material_processing_batches b
      where b.job_id=j.id and b.status not in ('completed','failed')
      order by b.created_at limit 1)
  from public.materials m join lateral (
    select latest.* from public.material_processing_jobs latest
    where latest.material_id=m.id and latest.user_id=m.user_id
    order by latest.generation desc limit 1
  ) j on true
  where m.id=p_material_id and m.user_id=auth.uid() and m.deleted_at is null;
$$;

do $$
begin
  if (select proowner from pg_proc where oid=
      'public.terminalize_material_analysis_operation_internal(uuid,uuid,text)'::regprocedure)
      <> 'postgres'::regrole then
    raise exception 'unexpected_material_analysis_terminalization_owner';
  end if;
end
$$;

revoke all on function public.terminalize_material_analysis_operation_internal(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.terminalize_material_analysis_operation_internal(uuid,uuid,text)
  to service_role;
revoke all on function public.get_material_analysis_status(uuid)
  from public,anon,service_role;
grant execute on function public.get_material_analysis_status(uuid)
  to authenticated;
