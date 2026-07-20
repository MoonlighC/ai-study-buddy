\set ON_ERROR_STOP on

create or replace function pg_temp.assert_no_work(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'no_work_terminalization_assertion_failed: %',message;
  end if;
end
$$;

insert into auth.users(id,email) values
  ('16161616-1616-4616-8616-161616161616','no-work@example.test'),
  ('17171717-1717-4717-8717-171717171717','partial-work@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values
  ('16161616-1616-4616-8616-161616161601','16161616-1616-4616-8616-161616161616',
   'No usable pages','pdf','upload','study-materials',
   '16161616-1616-4616-8616-161616161616/16161616-1616-4616-8616-161616161601/source.pdf',
   'application/pdf',128,'pending','{}'),
  ('17171717-1717-4717-8717-171717171701','17171717-1717-4717-8717-171717171717',
   'One usable page','pdf','upload','study-materials',
   '17171717-1717-4717-8717-171717171717/17171717-1717-4717-8717-171717171701/source.pdf',
   'application/pdf',128,'pending','{}');

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid; i integer;
  v_completed_at timestamptz; v_updated_at timestamptz;
begin
  v_job:=public.prepare_material_analysis_internal(
    '16161616-1616-4616-8616-161616161601','recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );

  for i in 1..3 loop
    v_work:=public.claim_next_material_analysis_operation_internal(
      '16161616-1616-4616-8616-161616161601');
    perform pg_temp.assert_no_work(
      v_work->>'kind'=case when i<3 then 'page_visual' else 'page_recovery' end,
      'bounded page recovery generation claimed');
    v_batch:=(v_work->>'batch_id')::uuid;
    v_lease:=(v_work->>'lease_token')::uuid;
    perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
    perform public.fail_material_analysis_operation_internal(
      v_batch,v_lease,'non_retryable',null,null,true);
  end loop;

  perform pg_temp.assert_no_work(
    (select status='prepared' and budget_state='consumed'
       from public.material_processing_jobs where id=v_job)
      and (select status='missing' from public.material_processing_pages
        where job_id=v_job and page_number=1),
    'fixture reaches prepared no-work state before terminal claim');

  v_work:=public.claim_next_material_analysis_operation_internal(
    '16161616-1616-4616-8616-161616161601');
  perform pg_temp.assert_no_work(v_work->>'kind'='none',
    'terminalization creates no work payload');
  perform pg_temp.assert_no_work(
    (select status='failed' and safe_error_code='unable_to_extract_content'
       and budget_state='released' and completed_at is not null
       and active_lease_token is null and active_lease_expires_at is null
       from public.material_processing_jobs where id=v_job),
    'job terminalizes with bounded safe failure and released budget');
  perform pg_temp.assert_no_work(
    (select processing_status='failed' from public.materials
      where id='16161616-1616-4616-8616-161616161601'),
    'material public state leaves pending');
  perform pg_temp.assert_no_work(
    (select count(*)=3 and count(*) filter(where operation='reduction')=0
       and count(*) filter(where operation='final_summary')=0
       from public.material_processing_batches where job_id=v_job)
      and (select count(*)=3 from public.material_processing_attempts where job_id=v_job)
      and (select summary is null and summary_payload is null from public.materials
        where id='16161616-1616-4616-8616-161616161601'),
    'terminalization creates no batches attempts or summary');

  select completed_at,updated_at into v_completed_at,v_updated_at
    from public.material_processing_jobs where id=v_job;
  v_work:=public.claim_next_material_analysis_operation_internal(
    '16161616-1616-4616-8616-161616161601');
  perform pg_temp.assert_no_work(
    v_work->>'kind'='none'
      and (select completed_at=v_completed_at and updated_at=v_updated_at
        and budget_state='released' from public.material_processing_jobs where id=v_job)
      and (select count(*)=3 from public.material_processing_batches where job_id=v_job)
      and (select count(*)=3 from public.material_processing_attempts where job_id=v_job),
    'repeated terminal claim is mutation-free and idempotent');

  perform set_config('request.jwt.claim.sub','16161616-1616-4616-8616-161616161616',true);
  perform pg_temp.assert_no_work(
    (select state='failed' from public.get_material_analysis_status(
      '16161616-1616-4616-8616-161616161601')),
    'public analysis projection is terminal failed');
end
$$;

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid; i integer;
begin
  v_job:=public.prepare_material_analysis_internal(
    '17171717-1717-4717-8717-171717171701','recommended',false,2,repeat('c',64),
    '[{"page_number":1,"route":"text","normalized_text":"Usable page.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"},{"page_number":2,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]'
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '17171717-1717-4717-8717-171717171701');
  perform pg_temp.assert_no_work(v_work->>'kind'='page_text','usable text page claimed');
  v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_partial_12345678',null);
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Usable.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}',
    'phase-c-validator-v2',repeat('f',64),null,true);

  for i in 1..3 loop
    v_work:=public.claim_next_material_analysis_operation_internal(
      '17171717-1717-4717-8717-171717171701');
    perform pg_temp.assert_no_work(
      v_work->>'kind'=case when i<3 then 'page_visual' else 'page_recovery' end,
      'missing page recovery remains bounded');
    v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
    perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
    perform public.fail_material_analysis_operation_internal(
      v_batch,v_lease,'non_retryable',null,null,true);
  end loop;

  v_work:=public.claim_next_material_analysis_operation_internal(
    '17171717-1717-4717-8717-171717171701');
  perform pg_temp.assert_no_work(
    v_work->>'kind'='reduction'
      and v_work->'page_numbers'='[1]'::jsonb
      and (select status='processing' and safe_error_code is null
        from public.material_processing_jobs where id=v_job)
      and (select count(*)=1 from public.material_processing_batches
        where job_id=v_job and operation='reduction')
      and (select count(*)=0 from public.material_processing_batches
        where job_id=v_job and operation='final_summary'),
    'one usable page continues into reduction without terminalization');
end
$$;

delete from public.materials where id in (
  '16161616-1616-4616-8616-161616161601',
  '17171717-1717-4717-8717-171717171701'
);
delete from auth.users where id in (
  '16161616-1616-4616-8616-161616161616',
  '17171717-1717-4717-8717-171717171717'
);
