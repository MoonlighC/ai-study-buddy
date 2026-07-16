\set ON_ERROR_STOP on

create or replace function pg_temp.assert_recovery(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'recovery_assertion_failed: %',message; end if;
end
$$;

insert into auth.users(id,email)
values('44444444-4444-4444-4444-444444444444','recovery@example.test');

create or replace function pg_temp.make_recovery_case(
  p_material uuid,p_digit text,out p_job uuid,out p_batch uuid
) language plpgsql as $$
begin
  insert into public.materials(id,user_id,title,kind)
  values(p_material,'44444444-4444-4444-4444-444444444444','Recovery '||p_digit,'pdf');
  p_job := public.create_material_processing_job_internal(
    p_material,'recommended',false,1,'general');
  p_batch := public.create_material_processing_batch_internal(
    p_job,'page_text',array[1],repeat(p_digit,64));
end
$$;

do $$
declare j uuid; b uuid; claimed uuid; token uuid; attempt uuid; v_authorization uuid; recovered text;
begin
  -- Prepared: a valid lease cannot be stolen; an expired lease is safely
  -- released and the stale token cannot submit afterward.
  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444401','1');
  select batch_id,lease_token into claimed,token
    from public.claim_material_processing_batch_internal(j,'page_text');
  begin
    perform public.recover_expired_material_processing_batch_internal(b);
    raise exception 'valid prepared lease stolen';
  exception when others then
    if sqlerrm not like '%lease_still_valid%' then raise; end if;
  end;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  recovered := public.recover_expired_material_processing_batch_internal(b);
  perform pg_temp.assert_recovery(recovered='prepared','prepared recovery');
  begin
    perform public.mark_material_processing_batch_submitted_internal(b,token);
    raise exception 'stale prepared token accepted';
  exception when others then
    if sqlerrm not like '%batch_submit_conflict%' then raise; end if;
  end;

  -- Submitted without a response ID becomes user-retry-required. The paid
  -- attempt and consumed budget remain persisted.
  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444402','2');
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  attempt := public.mark_material_processing_batch_submitted_internal(b,token);
  begin
    perform public.recover_expired_material_processing_batch_internal(b);
    raise exception 'valid submitted lease stolen';
  exception when others then
    if sqlerrm not like '%lease_still_valid%' then raise; end if;
  end;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  recovered := public.recover_expired_material_processing_batch_internal(b);
  perform pg_temp.assert_recovery(recovered='user_retry_required','submitted ambiguity recovery');
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='user_retry_required',
    'parked user retry remains parked');
  begin
    perform public.claim_material_processing_batch_internal(j,'page_text');
    raise exception 'user retry unexpectedly claimable';
  exception when others then
    if sqlerrm not like '%job_not_claimable%' then raise; end if;
  end;
  perform pg_temp.assert_recovery(
    (select attempt_count=1 and budget_state='consumed' from public.material_processing_batches where id=b)
    and (select status='dispatch_unknown' and budget_effect='retained' from public.material_processing_attempts where id=attempt),
    'ambiguous attempt remains consumed and auditable');

  -- Explicit authenticated authorization is consumed once. The predecessor is
  -- unchanged and a new unique attempt links back to it.
  perform pg_catalog.set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444444',true);
  v_authorization := public.authorize_material_analysis_retry(
    '44444444-4444-4444-4444-444444444402');
  perform public.request_material_processing_retry_internal(
    '44444444-4444-4444-4444-444444444402',v_authorization);
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  perform public.mark_material_processing_batch_submitted_internal(b,token);
  perform pg_temp.assert_recovery(
    (select count(*)=2 and count(distinct idempotency_key)=2 from public.material_processing_attempts where batch_id=b)
    and (select count(*)=1 from public.material_processing_attempts where batch_id=b and predecessor_attempt_id=attempt)
    and (select status='dispatch_unknown' from public.material_processing_attempts where id=attempt),
    'explicit retry preserves immutable predecessor and unique idempotency');

  -- Submitted with a persisted response ID can only move to reconciliation.
  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444403','3');
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  perform public.mark_material_processing_batch_submitted_internal(b,token);
  update public.material_processing_batches set upstream_response_id='response_crash_403' where id=b;
  update public.material_processing_attempts set upstream_response_id='response_crash_403' where batch_id=b;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='reconciliation_required',
    'submitted response recovery');

  -- response_known retains a valid lease, then becomes reconciliation-only on
  -- expiry; the old token cannot complete or mutate it afterward.
  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444404','4');
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  perform public.mark_material_processing_batch_submitted_internal(b,token);
  perform public.mark_material_processing_response_known_internal(b,token,'response_known_404');
  begin
    perform public.recover_expired_material_processing_batch_internal(b);
    raise exception 'valid response_known lease stolen';
  exception when others then
    if sqlerrm not like '%lease_still_valid%' then raise; end if;
  end;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='reconciliation_required',
    'response_known expiry');
  begin
    perform public.complete_material_processing_batch_internal(
      b,token,'{"schema_version":1,"operation":"page_text","content":{}}',
      'phase-c-validator-v2',repeat('4',64));
    raise exception 'stale response token accepted';
  exception when others then
    if sqlerrm not like '%batch_completion_conflict%' then raise; end if;
  end;

  -- dispatch_unknown without/with a subsequently persisted response follows
  -- user-retry/reconciliation respectively and never automatic submission.
  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444405','5');
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  perform public.mark_material_processing_batch_submitted_internal(b,token);
  perform public.mark_material_processing_dispatch_unknown_internal(b,token);
  begin
    perform public.recover_expired_material_processing_batch_internal(b);
    raise exception 'valid dispatch_unknown lease stolen';
  exception when others then
    if sqlerrm not like '%lease_still_valid%' then raise; end if;
  end;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='user_retry_required',
    'dispatch_unknown without response');

  select p_job,p_batch into j,b from pg_temp.make_recovery_case(
    '44444444-4444-4444-4444-444444444406','6');
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  perform public.mark_material_processing_batch_submitted_internal(b,token);
  perform public.mark_material_processing_dispatch_unknown_internal(b,token);
  update public.material_processing_batches set upstream_response_id='response_late_406' where id=b;
  update public.material_processing_attempts set upstream_response_id='response_late_406' where batch_id=b;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='reconciliation_required',
    'dispatch_unknown with response');

  -- A reconciliation lease is claimable only through reconciliation and
  -- returns to reconciliation after expiry. user_retry_required stays parked.
  select batch_id,lease_token into claimed,token from public.claim_material_processing_batch_internal(j,'page_text');
  begin
    perform public.recover_expired_material_processing_batch_internal(b);
    raise exception 'valid reconciliation lease stolen';
  exception when others then
    if sqlerrm not like '%lease_still_valid%' then raise; end if;
  end;
  update public.material_processing_jobs set active_lease_expires_at=now()-interval '1 second' where id=j;
  update public.material_processing_batches set lease_expires_at=now()-interval '1 second' where id=b;
  perform pg_temp.assert_recovery(
    public.recover_expired_material_processing_batch_internal(b)='reconciliation_required',
    'reconciliation expiry remains reconciliation');
end
$$;

select 'PHASE_C1_RECOVERY_OK' as result;
