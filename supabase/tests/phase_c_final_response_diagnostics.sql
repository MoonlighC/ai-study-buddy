\set ON_ERROR_STOP on

create or replace function pg_temp.assert_final_diagnostic(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'final_diagnostic_assertion_failed: %',message;
  end if;
end
$$;

create or replace function pg_temp.expect_final_diagnostic_failure(statement text,expected text)
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

select pg_temp.assert_final_diagnostic(
  has_function_privilege('service_role','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and has_function_privilege('service_role','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not has_function_privilege('anon','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and not has_function_privilege('authenticated','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and not has_function_privilege('anon','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not has_function_privilege('authenticated','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not exists (
    select 1 from information_schema.role_routine_grants
    where routine_schema='public'
      and routine_name in (
        'load_material_analysis_diagnostic_target_internal',
        'record_material_analysis_diagnostic_internal'
      )
      and grantee='PUBLIC'
  ),
  'diagnostic RPC execution is service-only'
);

select pg_temp.assert_final_diagnostic(
  not has_table_privilege('service_role','public.material_processing_batches','select,insert,update,delete')
  and not has_table_privilege('authenticated','public.material_processing_batches','select,insert,update,delete')
  and not has_table_privilege('anon','public.material_processing_batches','select,insert,update,delete'),
  'migration adds no direct processing-table DML'
);

select pg_temp.assert_final_diagnostic(
  public.material_analysis_valid_diagnostic_metadata(
    '{"response_status":"failed","error_present":true,"incomplete_details_present":false,"refusal_count":0,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":2048,"top_level_key_count":6,"warning_count":1,"equation_count":2,"source_page_count":1,"section_count":1,"concept_count":1,"validator_stage":"validateFinalSummarySchema"}'
  )
  and not public.material_analysis_valid_diagnostic_metadata('{"summary":"content"}')
  and not public.material_analysis_valid_diagnostic_metadata('{"response_id":"provider-id"}')
  and not public.material_analysis_valid_diagnostic_metadata('{"section_count":25}')
  and not public.material_analysis_valid_diagnostic_metadata('{"concept_count":51}')
  and not public.material_analysis_valid_diagnostic_metadata(
    jsonb_build_object('validator_stage','validateFinalSummarySchema','extra',repeat('x',8192))
  ),
  'final metadata is bounded, closed, and content-free'
);

insert into auth.users(id,email) values
  ('72222222-2222-4222-8222-222222222222','final-diagnostic-owner@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '72222222-2222-4222-8222-222222222201',
  '72222222-2222-4222-8222-222222222222',
  'Final diagnostic source','pdf','upload','study-materials',
  '72222222-2222-4222-8222-222222222222/72222222-2222-4222-8222-222222222201/source.pdf',
  'application/pdf',128,'ready','{}'
);

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid; v_target jsonb;
  v_attempt uuid; v_attempt_snapshot jsonb; v_batch_snapshot jsonb;
  v_job_snapshot jsonb; v_page_snapshot jsonb; v_material_snapshot jsonb;
  v_public_snapshot jsonb; v_public_after jsonb;
begin
  v_job:=public.prepare_material_analysis_internal(
    '72222222-2222-4222-8222-222222222201',
    'recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Reliable selectable synthetic study text.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '72222222-2222-4222-8222-222222222201'
  );
  perform pg_temp.assert_final_diagnostic(v_work->>'kind'='page_text','page work claimed');
  v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_page_12345678',null);
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe page summary.","key_concepts":["Concept"],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}',
    'phase-c-validator-v2',repeat('c',64),null,true
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '72222222-2222-4222-8222-222222222201'
  );
  perform pg_temp.assert_final_diagnostic(v_work->>'kind'='reduction','reduction claimed');
  v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_reduction_12345678',null);
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"source_pages":[1],"summary_markdown":"Safe reduction.","key_concepts":["Concept"],"equation_ids":[],"warnings":[],"confidence":0.9}',
    'phase-c-validator-v2',repeat('d',64),null,true
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '72222222-2222-4222-8222-222222222201'
  );
  perform pg_temp.assert_final_diagnostic(v_work->>'kind'='final_summary','final summary claimed');
  v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_final_12345678',null);
  perform public.fail_material_analysis_operation_internal(v_batch,v_lease,'non_retryable',null,null,true);

  select current_attempt_id into v_attempt
  from public.material_processing_batches where id=v_batch;
  select to_jsonb(a) into v_attempt_snapshot
  from public.material_processing_attempts a where a.id=v_attempt;
  select to_jsonb(b)-array[
    'diagnostic_code','diagnostic_metadata','diagnostic_version','diagnostic_recorded_at'
  ] into v_batch_snapshot
  from public.material_processing_batches b where b.id=v_batch;
  select to_jsonb(j) into v_job_snapshot
  from public.material_processing_jobs j where j.id=v_job;
  select to_jsonb(p) into v_page_snapshot
  from public.material_processing_pages p where p.job_id=v_job and p.page_number=1;
  select to_jsonb(m) into v_material_snapshot
  from public.materials m where m.id='72222222-2222-4222-8222-222222222201';
  perform set_config('request.jwt.claim.sub','72222222-2222-4222-8222-222222222222',false);
  select to_jsonb(s) into v_public_snapshot
  from public.get_material_analysis_status('72222222-2222-4222-8222-222222222201') s;

  v_target:=public.load_material_analysis_diagnostic_target_internal(v_batch);
  perform pg_temp.assert_final_diagnostic(
    v_target->>'batch_id'=v_batch::text
    and v_target->>'operation'='final_summary'
    and v_target->>'status'='failed'
    and v_target->>'response_id'='resp_final_12345678'
    and v_target->'page_numbers'='[1]'::jsonb
    and v_target->>'page_count'='1',
    'failed final-summary target loads persisted response identity internally'
  );

  perform public.record_material_analysis_diagnostic_internal(
    v_batch,'final_summary_schema_failed',
    '{"response_status":"completed","error_present":false,"incomplete_details_present":false,"refusal_count":0,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":2048,"top_level_key_count":6,"warning_count":1,"equation_count":2,"source_page_count":1,"section_count":1,"concept_count":1,"validator_stage":"validateFinalSummarySchema"}',
    1
  );
  perform public.record_material_analysis_diagnostic_internal(
    v_batch,'final_summary_schema_failed',
    '{"response_status":"completed","error_present":false,"incomplete_details_present":false,"refusal_count":0,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":2048,"top_level_key_count":6,"warning_count":1,"equation_count":2,"source_page_count":1,"section_count":1,"concept_count":1,"validator_stage":"validateFinalSummarySchema"}',
    1
  );

  select to_jsonb(s) into v_public_after
  from public.get_material_analysis_status('72222222-2222-4222-8222-222222222201') s;
  perform pg_temp.assert_final_diagnostic(
    (select diagnostic_code='final_summary_schema_failed'
      and diagnostic_version=1 and diagnostic_recorded_at is not null
      from public.material_processing_batches where id=v_batch)
    and (select to_jsonb(b)-array[
        'diagnostic_code','diagnostic_metadata','diagnostic_version','diagnostic_recorded_at'
      ]=v_batch_snapshot from public.material_processing_batches b where b.id=v_batch)
    and (select to_jsonb(a)=v_attempt_snapshot from public.material_processing_attempts a where a.id=v_attempt)
    and (select to_jsonb(j)=v_job_snapshot from public.material_processing_jobs j where j.id=v_job)
    and (select to_jsonb(p)=v_page_snapshot from public.material_processing_pages p where p.job_id=v_job and p.page_number=1)
    and (select to_jsonb(m)=v_material_snapshot from public.materials m where m.id='72222222-2222-4222-8222-222222222201')
    and v_public_after=v_public_snapshot,
    'diagnostic write changes only diagnostic columns; all authoritative state and public status are byte-identical'
  );

  perform pg_temp.expect_final_diagnostic_failure(format(
    'select public.record_material_analysis_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,'page_latex_failed','{"validator_stage":"validatePageLatex"}'
  ),'diagnostic_target_unavailable');
  perform pg_temp.expect_final_diagnostic_failure(format(
    'select public.record_material_analysis_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,'final_summary_markdown_failed','{"validator_stage":"validateFinalSummaryMarkdown"}'
  ),'diagnostic_conflict');

  delete from public.materials where id='72222222-2222-4222-8222-222222222201';
  perform pg_temp.assert_final_diagnostic(
    not exists(select 1 from public.material_processing_batches where id=v_batch),
    'material deletion cascades final diagnostic data'
  );
end
$$;

select 'phase_c_final_response_diagnostics_passed' as result;
