\set ON_ERROR_STOP on

create or replace function pg_temp.assert_reconciliation_operation(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'reconciliation_operation_assertion_failed: %',message;
  end if;
end
$$;

do $$
declare
  v_proc record;
begin
  select p.proowner,p.prosecdef,p.provolatile,p.proconfig
  into v_proc
  from pg_proc p
  where p.oid='public.material_analysis_work_payload(uuid,uuid)'::regprocedure;
  perform pg_temp.assert_reconciliation_operation(
    v_proc.proowner='postgres'::regrole,
    'work payload owner remains postgres');
  perform pg_temp.assert_reconciliation_operation(
    v_proc.prosecdef and v_proc.provolatile='s',
    'work payload remains stable security definer');
  perform pg_temp.assert_reconciliation_operation(
    v_proc.proconfig=array['search_path=pg_catalog, public']::text[],
    'work payload keeps its fixed search path');
  perform pg_temp.assert_reconciliation_operation(
    has_function_privilege('service_role',
      'public.material_analysis_work_payload(uuid,uuid)','execute')
    and not has_function_privilege('anon',
      'public.material_analysis_work_payload(uuid,uuid)','execute')
    and not has_function_privilege('authenticated',
      'public.material_analysis_work_payload(uuid,uuid)','execute'),
    'work payload remains service-role-only');
end
$$;

insert into auth.users(id,email) values
  ('24242424-2424-4424-8424-242424242424','reconciliation-operation@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '24242424-2424-4424-8424-242424242401',
  '24242424-2424-4424-8424-242424242424',
  'Reconciliation operation fixture','pdf','upload','study-materials',
  '24242424-2424-4424-8424-242424242424/24242424-2424-4424-8424-242424242401/source.pdf',
  'application/pdf',128,'pending','{}'
);

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid;
begin
  v_job:=public.prepare_material_analysis_internal(
    '24242424-2424-4424-8424-242424242401','recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Selectable page.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '24242424-2424-4424-8424-242424242401');
  perform pg_temp.assert_reconciliation_operation(
    v_work->>'kind'='page_text' and v_work->>'operation'='page_text'
      and array(select jsonb_object_keys(v_work->'input_payload') order by 1)=array['pages'],
    'page-text normal payload has a separate trusted operation');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_page_text_24242424',null);
  perform public.fail_material_analysis_operation_internal(
    v_batch,v_lease,'reconcile_only',null,null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '24242424-2424-4424-8424-242424242401');
  perform pg_temp.assert_reconciliation_operation(
    v_work->>'kind'='reconciliation'
      and v_work->>'operation'='page_text'
      and (v_work->>'batch_id')::uuid=v_batch
      and (v_work->>'job_id')::uuid=v_job
      and v_work->>'response_id'='resp_page_text_24242424'
      and array(select jsonb_object_keys(v_work->'input_payload') order by 1)=array['pages']
      and (select lease_token=(v_work->>'lease_token')::uuid
        and upstream_response_id=v_work->>'response_id'
        from public.material_processing_batches where id=v_batch),
    'page-text reconciliation preserves trusted operation and batch linkage');
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe page.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}'::jsonb,
    'phase-c-validator-v2',repeat('c',64),null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '24242424-2424-4424-8424-242424242401');
  perform pg_temp.assert_reconciliation_operation(
    v_work->>'kind'='reduction' and v_work->>'operation'='reduction'
      and array(select jsonb_object_keys(v_work->'input_payload') order by 1)=array['equation_ids','inputs']
      and not (v_work->'input_payload' ? 'operation'),
    'reduction provider input remains exactly equation_ids and inputs');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_reduction_24242424',null);
  perform public.fail_material_analysis_operation_internal(
    v_batch,v_lease,'reconcile_only',null,null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '24242424-2424-4424-8424-242424242401');
  perform pg_temp.assert_reconciliation_operation(
    v_work->>'kind'='reconciliation'
      and v_work->>'operation'='reduction'
      and (v_work->>'batch_id')::uuid=v_batch
      and (v_work->>'job_id')::uuid=v_job
      and v_work->>'response_id'='resp_reduction_24242424'
      and array(select jsonb_object_keys(v_work->'input_payload') order by 1)=array['equation_ids','inputs']
      and not (v_work->'input_payload' ? 'operation')
      and (select lease_token=(v_work->>'lease_token')::uuid
        and upstream_response_id=v_work->>'response_id'
        and attempt_count=1
        from public.material_processing_batches where id=v_batch),
    'stranded reduction is claimable without changing payload or attempt identity');
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"source_pages":[1],"summary_markdown":"Safe reduction.","key_concepts":[],"equation_ids":[],"warnings":[],"confidence":0.9}'::jsonb,
    'phase-c-validator-v2',repeat('d',64),null,true);
  perform pg_temp.assert_reconciliation_operation(
    (select status='completed' and attempt_count=1
      from public.material_processing_batches where id=v_batch),
    'completed reconciliation persists the original single attempt once');
end
$$;

delete from public.materials
where id='24242424-2424-4424-8424-242424242401';
delete from auth.users where id='24242424-2424-4424-8424-242424242424';
