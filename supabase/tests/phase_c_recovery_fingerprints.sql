\set ON_ERROR_STOP on

create or replace function pg_temp.assert_recovery_fingerprint(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'recovery_fingerprint_assertion_failed: %',message;
  end if;
end
$$;

create or replace function pg_temp.expect_recovery_fingerprint_failure(statement text,expected text)
returns void language plpgsql as $$
begin
  begin
    execute statement;
    raise exception 'expected failure did not occur: %',expected;
  exception when others then
    if sqlerrm not like '%'||expected||'%' then raise; end if;
  end;
end
$$;

insert into auth.users(id,email)
values('15151515-1515-4515-8515-151515151515','recovery-fingerprint@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '15151515-1515-4515-8515-151515151501','15151515-1515-4515-8515-151515151515',
  'Recovery fingerprint regression','pdf','upload','study-materials',
  '15151515-1515-4515-8515-151515151515/15151515-1515-4515-8515-151515151501/source.pdf',
  'application/pdf',128,'ready','{}'
);

do $$
declare
  v_job uuid; v_work jsonb; v_first uuid; v_first_lease uuid; v_first_fp text;
  v_recovery uuid; v_recovery_lease uuid; v_recovery_fp text;
  v_same uuid; v_later uuid; v_later_lease uuid; v_later_fp text;
begin
  v_job:=public.prepare_material_analysis_internal(
    '15151515-1515-4515-8515-151515151501','recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '15151515-1515-4515-8515-151515151501');
  perform pg_temp.assert_recovery_fingerprint(v_work->>'kind'='page_visual',
    'first visual operation claimed');
  v_first:=(v_work->>'batch_id')::uuid;
  v_first_lease:=(v_work->>'lease_token')::uuid;
  select fingerprint into v_first_fp from public.material_processing_batches where id=v_first;
  perform public.submit_material_analysis_operation_internal(v_first,v_first_lease);
  perform public.fail_material_analysis_operation_internal(
    v_first,v_first_lease,'non_retryable',null,null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '15151515-1515-4515-8515-151515151501');
  perform pg_temp.assert_recovery_fingerprint(v_work->>'kind'='page_visual',
    'first grouped recovery remains visual');
  v_recovery:=(v_work->>'batch_id')::uuid;
  v_recovery_lease:=(v_work->>'lease_token')::uuid;
  select fingerprint into v_recovery_fp from public.material_processing_batches where id=v_recovery;
  perform pg_temp.assert_recovery_fingerprint(
    v_recovery<>v_first and v_recovery_fp<>v_first_fp,
    'first attempt and first recovery fingerprints differ');

  -- A retry before dispatch reuses the already-created recovery batch. The
  -- logical generation is unchanged, so no new fingerprint or batch appears.
  perform public.fail_material_analysis_operation_internal(
    v_recovery,v_recovery_lease,'pre_dispatch_retryable',0,null,true);
  v_work:=public.claim_next_material_analysis_operation_internal(
    '15151515-1515-4515-8515-151515151501');
  v_same:=(v_work->>'batch_id')::uuid;
  v_recovery_lease:=(v_work->>'lease_token')::uuid;
  perform pg_temp.assert_recovery_fingerprint(
    v_same=v_recovery and (select count(*)=2 from public.material_processing_batches where job_id=v_job),
    'same recovery generation resolves to the existing batch');

  perform public.submit_material_analysis_operation_internal(v_recovery,v_recovery_lease);
  perform public.fail_material_analysis_operation_internal(
    v_recovery,v_recovery_lease,'non_retryable',null,null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '15151515-1515-4515-8515-151515151501');
  perform pg_temp.assert_recovery_fingerprint(v_work->>'kind'='page_recovery',
    'later permitted recovery uses the recovery operation');
  v_later:=(v_work->>'batch_id')::uuid;
  v_later_lease:=(v_work->>'lease_token')::uuid;
  select fingerprint into v_later_fp from public.material_processing_batches where id=v_later;
  perform pg_temp.assert_recovery_fingerprint(
    v_later_fp<>v_first_fp and v_later_fp<>v_recovery_fp,
    'later logical recovery generation has a distinct fingerprint');

  -- The active job lease serializes concurrent/repeated claims before any
  -- provider dispatch and therefore cannot create another batch or attempt.
  v_work:=public.claim_next_material_analysis_operation_internal(
    '15151515-1515-4515-8515-151515151501');
  perform pg_temp.assert_recovery_fingerprint(
    v_work->>'kind'='none'
      and (select count(*)=3 from public.material_processing_batches where job_id=v_job)
      and (select count(*)=2 from public.material_processing_attempts where job_id=v_job),
    'repeated claim creates neither a batch nor an attempt');

  perform pg_temp.expect_recovery_fingerprint_failure(format(
    'insert into public.material_processing_batches(job_id,material_id,user_id,operation,page_numbers,fingerprint,max_attempts) '
    'select job_id,material_id,user_id,operation,page_numbers,fingerprint,max_attempts from public.material_processing_batches where id=%L',
    v_later),'duplicate key');

  perform public.submit_material_analysis_operation_internal(v_later,v_later_lease);
  perform pg_temp.assert_recovery_fingerprint(
    (select count(*)=3 and count(distinct batch_id)=3
       from public.material_processing_attempts where job_id=v_job)
      and (select total_upstream_attempts=3 and grouped_attempts=2 and recovery_attempts=1
        from public.material_processing_pages where job_id=v_job and page_number=1)
      and (select budget_state='consumed' from public.material_processing_jobs where id=v_job),
    'attempt and budget accounting remains bounded and consistent');
end
$$;

delete from public.materials where id='15151515-1515-4515-8515-151515151501';
delete from auth.users where id='15151515-1515-4515-8515-151515151515';
