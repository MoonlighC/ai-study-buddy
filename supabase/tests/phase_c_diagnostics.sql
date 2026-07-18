\set ON_ERROR_STOP on

create or replace function pg_temp.assert_diagnostic(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'diagnostic_assertion_failed: %',message;
  end if;
end
$$;

create or replace function pg_temp.expect_diagnostic_failure(statement text,expected text)
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

select pg_temp.assert_diagnostic(
  to_regprocedure('public.material_analysis_valid_diagnostic_metadata(jsonb)') is not null
  and to_regprocedure('public.load_material_analysis_diagnostic_target_internal(uuid)') is not null
  and to_regprocedure('public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)') is not null,
  'diagnostic function inventory'
);

select pg_temp.assert_diagnostic(
  has_function_privilege('service_role','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and has_function_privilege('service_role','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not has_function_privilege('authenticated','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and not has_function_privilege('authenticated','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not has_function_privilege('anon','public.load_material_analysis_diagnostic_target_internal(uuid)','execute')
  and not has_function_privilege('anon','public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)','execute')
  and not exists(
    select 1 from information_schema.role_routine_grants
    where routine_schema='public'
      and routine_name in (
        'load_material_analysis_diagnostic_target_internal',
        'record_material_analysis_diagnostic_internal'
      ) and grantee='PUBLIC'
  ),
  'only service_role can execute diagnostic RPCs'
);

select pg_temp.assert_diagnostic(
  not has_table_privilege('service_role','public.material_processing_batches','select,insert,update,delete')
  and not has_table_privilege('authenticated','public.material_processing_batches','select,insert,update,delete')
  and not has_table_privilege('anon','public.material_processing_batches','select,insert,update,delete'),
  'diagnostics add no direct processing-table access'
);

select pg_temp.assert_diagnostic(
  public.material_analysis_valid_diagnostic_metadata(
    '{"response_status":"completed","error_present":false,"incomplete_details_present":false,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":512,"top_level_key_count":1,"requested_page_number":1,"returned_page_number":1,"warning_count":0,"equation_count":2,"source_page_count":1,"validator_stage":"validatePageLatex"}'
  ),
  'closed bounded metadata accepts non-content facts'
);

select pg_temp.assert_diagnostic(
  not public.material_analysis_valid_diagnostic_metadata('{"response_text":"private"}')
  and not public.material_analysis_valid_diagnostic_metadata('{"latex":"\\frac{a}{b}"}')
  and not public.material_analysis_valid_diagnostic_metadata('{"url":"https://example.test"}')
  and not public.material_analysis_valid_diagnostic_metadata('{"output_item_count":-1}')
  and not public.material_analysis_valid_diagnostic_metadata('{"output_item_count":101}')
  and not public.material_analysis_valid_diagnostic_metadata('{"requested_page_number":0}')
  and not public.material_analysis_valid_diagnostic_metadata(
    jsonb_build_object('validator_stage','validatePageSchema','unknown',repeat('x',9000))
  ),
  'content, unknown keys, and invalid bounds are rejected'
);

insert into auth.users(id,email) values
  ('71111111-1111-4111-8111-111111111111','diagnostic-owner@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '71111111-1111-4111-8111-111111111101',
  '71111111-1111-4111-8111-111111111111',
  'Diagnostic source','pdf','upload','study-materials',
  '71111111-1111-4111-8111-111111111111/71111111-1111-4111-8111-111111111101/source.pdf',
  'application/pdf',128,'ready','{}'
);

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '71111111-1111-4111-8111-111111111102',
  '71111111-1111-4111-8111-111111111111',
  'Completed diagnostic source','pdf','upload','study-materials',
  '71111111-1111-4111-8111-111111111111/71111111-1111-4111-8111-111111111102/source.pdf',
  'application/pdf',128,'ready','{}'
);

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid; v_target jsonb;
  v_completed_work jsonb; v_completed_batch uuid; v_completed_lease uuid;
  v_attempt_count integer; v_budget text; v_cleanup text; v_status text;
  v_attempt_snapshot jsonb; v_batch_snapshot jsonb; v_page_snapshot jsonb;
  v_public_keys text[];
begin
  v_job:=public.prepare_material_analysis_internal(
    '71111111-1111-4111-8111-111111111101',
    'recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  v_work:=public.claim_next_material_analysis_operation_internal(
    '71111111-1111-4111-8111-111111111101'
  );
  perform pg_temp.assert_diagnostic(v_work->>'kind'='page_visual','visual work claimed');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_diagnostic_12345678',null
  );
  perform public.fail_material_analysis_operation_internal(
    v_batch,v_lease,'non_retryable',null,null,true
  );

  select attempt_count,budget_state,cleanup_state,status
    into v_attempt_count,v_budget,v_cleanup,v_status
  from public.material_processing_batches where id=v_batch;
  select to_jsonb(a) into v_attempt_snapshot
  from public.material_processing_attempts a
  where a.id=(select current_attempt_id from public.material_processing_batches where id=v_batch);
  select to_jsonb(b)-array[
    'diagnostic_code','diagnostic_metadata','diagnostic_version',
    'diagnostic_recorded_at'
  ] into v_batch_snapshot
  from public.material_processing_batches b where b.id=v_batch;
  select to_jsonb(p) into v_page_snapshot
  from public.material_processing_pages p
  where p.job_id=v_job and p.page_number=1;

  v_target:=public.load_material_analysis_diagnostic_target_internal(v_batch);
  perform pg_temp.assert_diagnostic(
    v_target->>'batch_id'=v_batch::text
    and v_target->>'operation'='page_visual'
    and v_target->>'status'='failed'
    and v_target->>'response_id'='resp_diagnostic_12345678'
    and v_target->'page_numbers'='[1]'::jsonb
    and v_target->>'page_count'='1'
    and v_target->>'cleanup_state'=v_cleanup,
    'failed visual target loads minimum trusted metadata'
  );

  begin
    update public.material_processing_batches
    set operation='page_text'
    where id=v_batch;
    perform public.load_material_analysis_diagnostic_target_internal(v_batch);
    raise exception 'expected wrong-operation diagnostic target rejection';
  exception when others then
    if sqlerrm not like '%diagnostic_target_unavailable%' then raise; end if;
  end;

  begin
    update public.material_processing_batches
    set upstream_response_id=null
    where id=v_batch;
    perform public.load_material_analysis_diagnostic_target_internal(v_batch);
    raise exception 'expected missing-response diagnostic target rejection';
  exception when others then
    if sqlerrm not like '%diagnostic_target_unavailable%' then raise; end if;
  end;

  perform public.prepare_material_analysis_internal(
    '71111111-1111-4111-8111-111111111102',
    'recommended',false,1,repeat('d',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]'
  );
  v_completed_work:=public.claim_next_material_analysis_operation_internal(
    '71111111-1111-4111-8111-111111111102'
  );
  v_completed_batch:=(v_completed_work->>'batch_id')::uuid;
  v_completed_lease:=(v_completed_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(
    v_completed_batch,v_completed_lease
  );
  perform public.record_material_analysis_response_internal(
    v_completed_batch,v_completed_lease,'resp_completed_12345678',null
  );
  perform public.complete_material_analysis_operation_internal(
    v_completed_batch,v_completed_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}'::jsonb,
    'phase-c-validator-v2',repeat('f',64),null,true
  );
  perform pg_temp.expect_diagnostic_failure(format(
    'select public.load_material_analysis_diagnostic_target_internal(%L)',
    v_completed_batch
  ),'diagnostic_target_unavailable');

  perform public.record_material_analysis_diagnostic_internal(
    v_batch,'page_latex_failed',
    '{"response_status":"completed","error_present":false,"incomplete_details_present":false,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":512,"top_level_key_count":1,"requested_page_number":1,"returned_page_number":1,"warning_count":0,"equation_count":2,"source_page_count":1,"validator_stage":"validatePageLatex"}',
    1
  );
  perform public.record_material_analysis_diagnostic_internal(
    v_batch,'page_latex_failed',
    '{"response_status":"completed","error_present":false,"incomplete_details_present":false,"output_item_count":1,"structured_candidate_count":1,"parsed_json_byte_length":512,"top_level_key_count":1,"requested_page_number":1,"returned_page_number":1,"warning_count":0,"equation_count":2,"source_page_count":1,"validator_stage":"validatePageLatex"}',
    1
  );
  perform pg_temp.assert_diagnostic(
    (select diagnostic_code='page_latex_failed' and diagnostic_version=1
      and diagnostic_recorded_at is not null
      and diagnostic_metadata->>'validator_stage'='validatePageLatex'
      from public.material_processing_batches where id=v_batch),
    'same diagnostic is idempotent'
  );
  perform pg_temp.assert_diagnostic(
    (select attempt_count=v_attempt_count and budget_state=v_budget
      and cleanup_state=v_cleanup and status=v_status
      and upstream_response_id='resp_diagnostic_12345678'
      and lease_token is null
      from public.material_processing_batches where id=v_batch)
    and (select to_jsonb(a)=v_attempt_snapshot from public.material_processing_attempts a
      where a.id=(select current_attempt_id from public.material_processing_batches where id=v_batch))
    and (select to_jsonb(b)-array[
        'diagnostic_code','diagnostic_metadata','diagnostic_version',
        'diagnostic_recorded_at'
      ]=v_batch_snapshot
      from public.material_processing_batches b where b.id=v_batch)
    and (select to_jsonb(p)=v_page_snapshot
      from public.material_processing_pages p
      where p.job_id=v_job and p.page_number=1),
    'only diagnostic fields change; batch, attempt, page, budget, status, response, lease, and cleanup remain byte-identical'
  );

  perform pg_temp.expect_diagnostic_failure(format(
    'select public.record_material_analysis_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,'unknown_diagnostic','{}'
  ),'invalid_material_analysis_diagnostic');
  perform pg_temp.expect_diagnostic_failure(format(
    'select public.record_material_analysis_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,'page_markdown_failed','{"extra":1}'
  ),'invalid_material_analysis_diagnostic');
  perform pg_temp.expect_diagnostic_failure(format(
    'select public.record_material_analysis_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,'page_markdown_failed','{"validator_stage":"validatePageMarkdown"}'
  ),'diagnostic_conflict');
  perform pg_temp.expect_diagnostic_failure(
    'select public.load_material_analysis_diagnostic_target_internal(''71111111-1111-4111-8111-111111119999'')',
    'diagnostic_target_unavailable'
  );

  perform set_config('request.jwt.claim.sub','71111111-1111-4111-8111-111111111111',false);
  select array_agg(key order by key) into v_public_keys
  from public.get_material_analysis_status('71111111-1111-4111-8111-111111111101') s,
    lateral jsonb_object_keys(to_jsonb(s)) key;
  perform pg_temp.assert_diagnostic(
    v_public_keys=array[
      'can_retry','completed_pages','confirmation_required','material_id',
      'page_count','processing_mode','public_stage','retry_after_seconds',
      'state','summary_payload','summary_schema_version','warnings'
    ]::text[],
    'public status contract contains no diagnostic fields'
  );

  delete from public.materials where id='71111111-1111-4111-8111-111111111101';
  delete from public.materials where id='71111111-1111-4111-8111-111111111102';
  perform pg_temp.assert_diagnostic(
    not exists(select 1 from public.material_processing_batches where id=v_batch),
    'material deletion cascades diagnostic batch'
  );
end
$$;

select 'phase_c_diagnostics_passed' as result;
