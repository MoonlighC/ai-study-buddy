-- Terminalize prepared jobs whose page recovery is exhausted and which have
-- no usable page output from which a reduction can be formed.

create or replace function public.claim_next_material_analysis_operation_internal(
  p_material_id uuid
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_job public.material_processing_jobs%rowtype; v_batch public.material_processing_batches%rowtype;
  v_artifact public.material_processing_artifacts%rowtype;
  v_claim record; v_pages integer[]; v_operation text; v_fingerprint text; v_batch_id uuid;
  v_route text; v_chars integer:=0; v_page record; v_level integer; v_inputs uuid[];
  v_token uuid:=gen_random_uuid();
begin
  select j.* into v_job from public.material_processing_jobs j join public.materials m
    on m.id=j.material_id and m.user_id=j.user_id
    where j.material_id=p_material_id and m.deleted_at is null
    order by j.generation desc limit 1 for update of j;
  if not found then raise exception 'analysis_unavailable'; end if;
  if v_job.active_lease_token is not null and v_job.active_lease_expires_at<=now() then
    select * into v_batch from public.material_processing_batches
      where job_id=v_job.id and lease_token=v_job.active_lease_token limit 1;
    if found then perform public.recover_expired_material_processing_batch_internal(v_batch.id); end if;
    select * into v_job from public.material_processing_jobs where id=v_job.id for update;
  end if;
  if v_job.active_lease_token is not null and v_job.active_lease_expires_at>now() then
    return jsonb_build_object('kind','none','material_id',p_material_id);
  end if;
  update public.material_processing_artifacts a set state='cleanup_pending',lease_token=null,
    lease_expires_at=null,cleanup_retry_after=null,updated_at=now()
  from public.material_processing_batches b where a.job_id=v_job.id and a.batch_id=b.id
    and a.state='uploaded' and a.lease_expires_at<=now() and b.status='prepared';
  update public.material_processing_artifacts set state='manual_cleanup_required',lease_token=null,
    lease_expires_at=null,updated_at=now() where job_id=v_job.id and state='upload_intent'
    and lease_expires_at<=now();
  update public.material_processing_artifacts set state='manual_cleanup_required',lease_token=null,
    lease_expires_at=null,updated_at=now() where job_id=v_job.id and state='cleanup_pending'
    and cleanup_attempt_count>=10;
  select * into v_artifact from public.material_processing_artifacts where job_id=v_job.id
    and state='cleanup_pending' and cleanup_attempt_count<10
    and (cleanup_retry_after is null or cleanup_retry_after<=now())
    order by updated_at limit 1 for update skip locked;
  if found then
    update public.material_processing_jobs set active_lease_token=v_token,
      active_lease_expires_at=now()+interval '120 seconds',updated_at=now() where id=v_job.id;
    update public.material_processing_artifacts set lease_token=v_token,
      lease_expires_at=now()+interval '120 seconds',cleanup_attempt_count=least(10,cleanup_attempt_count+1),
      updated_at=now() where id=v_artifact.id;
    return jsonb_build_object('kind','cleanup','material_id',p_material_id,
      'batch_id',v_artifact.batch_id,'artifact_id',v_artifact.id,
      'lease_token',v_token,'temporary_file_id',v_artifact.provider_file_id);
  end if;
  if v_job.status in ('awaiting_confirmation','user_retry_required','completed','completed_with_warnings','failed') then
    return jsonb_build_object('kind','none','material_id',p_material_id);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_job.user_id::text,0));
  if (select count(*) from public.material_processing_jobs
      where user_id=v_job.user_id and active_lease_expires_at>now())>=2 then
    return jsonb_build_object('kind','none','material_id',p_material_id);
  end if;
  if v_job.status='reconciliation_required' then
    select operation into v_operation from public.material_processing_batches
      where job_id=v_job.id and status='reconciliation_required' order by created_at limit 1;
    select * into v_claim from public.claim_material_processing_batch_internal(v_job.id,v_operation);
    return jsonb_set(public.material_analysis_work_payload(v_claim.batch_id,v_claim.lease_token),'{kind}','"reconciliation"');
  end if;
  select * into v_batch from public.material_processing_batches where job_id=v_job.id
    and status='prepared' and (retry_after is null or retry_after<=now()) order by created_at limit 1;
  if not found then
    select route into v_route from public.material_processing_pages where job_id=v_job.id and status='pending'
      order by page_number limit 1;
    if found then
      v_pages:='{}';
      for v_page in select * from public.material_processing_pages where job_id=v_job.id
        and status='pending' and route=v_route order by page_number loop
        v_operation := case when v_page.grouped_attempts>=2 then 'page_recovery'
          when v_route='visual' then 'page_visual' else 'page_text' end;
        if cardinality(v_pages)>=(case when v_operation in ('page_visual','page_recovery') then 5 else 10 end) then
          exit;
        end if;
        if v_operation='page_text' and v_chars+length(v_page.normalized_text)+64>40000 then exit; end if;
        v_pages:=array_append(v_pages,v_page.page_number);v_chars:=v_chars+length(v_page.normalized_text)+64;
      end loop;
      select encode(extensions.digest(
        v_job.version_fingerprint||':'||v_operation||':'||v_job.id::text||':'||
        array_to_string(v_pages,',')||':'||string_agg(input_hash,':' order by page_number)||
        case when max(grouped_attempts+recovery_attempts)=0 then '' else
          ':logical_generation:'||string_agg(
            page_number::text||'='||grouped_attempts::text||'/'||recovery_attempts::text,
            ':' order by page_number
          )
        end,
        'sha256'
      ),'hex') into v_fingerprint
      from public.material_processing_pages where job_id=v_job.id and page_number=any(v_pages);
      v_batch_id:=public.create_material_processing_batch_internal(v_job.id,v_operation,v_pages,v_fingerprint);
    elsif not exists(select 1 from public.material_processing_pages where job_id=v_job.id
      and status not in ('completed','partial','missing')) then
      select array_agg(page_number order by page_number) into v_pages from (
        select p.page_number from public.material_processing_pages p where p.job_id=v_job.id
          and p.status in ('completed','partial') and not exists(
            select 1 from public.material_processing_batches b where b.job_id=v_job.id
              and b.operation='reduction' and b.reduction_level=1 and p.page_number=any(b.page_numbers))
        order by p.page_number limit 10) s;
      if not exists(select 1 from public.material_processing_pages
        where job_id=v_job.id and status in ('completed','partial')) then
        update public.material_processing_jobs set status='failed',
          safe_error_code='unable_to_extract_content',budget_state='released',
          active_lease_token=null,active_lease_expires_at=null,completed_at=now(),updated_at=now()
        where id=v_job.id and status='prepared';
        update public.materials set processing_status='failed',updated_at=now()
        where id=v_job.material_id and user_id=v_job.user_id
          and processing_status in ('pending','processing');
        return jsonb_build_object('kind','none','material_id',p_material_id);
      elsif cardinality(v_pages)>0 then
        select encode(extensions.digest(v_job.version_fingerprint||':reduction:1:'||v_job.id::text||':'||array_to_string(v_pages,',')||':'||
          string_agg(validation_hash,':' order by page_number),'sha256'),'hex') into v_fingerprint
        from public.material_processing_pages where job_id=v_job.id and page_number=any(v_pages);
        v_batch_id:=public.create_material_processing_batch_internal(v_job.id,'reduction',v_pages,v_fingerprint);
        update public.material_processing_batches set reduction_level=1 where id=v_batch_id;
      elsif exists(select 1 from public.material_processing_pages where job_id=v_job.id and status in ('completed','partial'))
        and not exists(select 1 from public.material_processing_batches where job_id=v_job.id
          and operation='reduction' and status<>'completed') then
        select max(reduction_level) into v_level from public.material_processing_batches
          where job_id=v_job.id and operation='reduction' and status='completed';
        select array_agg(id order by created_at) into v_inputs from (
          select id,created_at from public.material_processing_batches b where b.job_id=v_job.id
            and b.operation='reduction' and b.status='completed' and b.reduction_level=v_level
            and not exists(select 1 from public.material_processing_batches parent
              where parent.job_id=v_job.id and parent.reduction_level=v_level+1 and b.id=any(parent.input_batch_ids))
          order by created_at limit 10) s;
        if cardinality(v_inputs)>1 then
          select array_agg(distinct p order by p) into v_pages from public.material_processing_batches b,
            unnest(b.page_numbers) p where b.id=any(v_inputs);
          select encode(extensions.digest(v_job.version_fingerprint||':reduction:'||(v_level+1)::text||':'||v_job.id::text||':'||
            array_to_string(v_inputs,','),'sha256'),'hex') into v_fingerprint;
          v_batch_id:=public.create_material_processing_batch_internal(v_job.id,'reduction',v_pages,v_fingerprint);
          update public.material_processing_batches set reduction_level=v_level+1,input_batch_ids=v_inputs where id=v_batch_id;
        elsif cardinality(v_inputs)=1 and not exists(select 1 from public.material_processing_batches
          where job_id=v_job.id and operation='final_summary') then
          select page_numbers into v_pages from public.material_processing_batches where id=v_inputs[1];
          select encode(extensions.digest(v_job.version_fingerprint||':final:'||v_job.id::text||':'||v_inputs[1]::text,'sha256'),'hex') into v_fingerprint;
          v_batch_id:=public.create_material_processing_batch_internal(v_job.id,'final_summary',v_pages,v_fingerprint);
          update public.material_processing_batches set input_batch_ids=v_inputs,reduction_level=v_level+1 where id=v_batch_id;
        end if;
      end if;
    end if;
    if v_batch_id is null then return jsonb_build_object('kind','none','material_id',p_material_id); end if;
    select * into v_batch from public.material_processing_batches where id=v_batch_id;
  end if;
  select * into v_claim from public.claim_material_processing_batch_internal(v_job.id,v_batch.operation);
  update public.material_processing_jobs set public_stage=case
    when v_batch.operation='page_text' then 'analyzing_pages'
    when v_batch.operation in ('page_visual','page_recovery') then 'recognizing_formulas_and_diagrams'
    else 'creating_summary' end where id=v_job.id;
  return public.material_analysis_work_payload(v_claim.batch_id,v_claim.lease_token);
exception when lock_not_available then
  return jsonb_build_object('kind','none','material_id',p_material_id);
end
$$;

revoke all on function public.claim_next_material_analysis_operation_internal(uuid)
  from public,anon,authenticated;
grant execute on function public.claim_next_material_analysis_operation_internal(uuid)
  to service_role;
