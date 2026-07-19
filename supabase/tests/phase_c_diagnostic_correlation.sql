\set ON_ERROR_STOP on

create or replace function pg_temp.assert_diagnostic_correlation(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'diagnostic_correlation_assertion_failed: %', message;
  end if;
end
$$;

create or replace function pg_temp.expect_diagnostic_target_unavailable()
returns void language plpgsql as $$
begin
  begin
    perform public.select_material_analysis_diagnostic_target_internal();
    raise exception 'expected diagnostic_target_unavailable';
  exception when others then
    if sqlerrm not like '%diagnostic_target_unavailable%' then raise; end if;
  end;
end
$$;

select pg_temp.assert_diagnostic_correlation(
  has_function_privilege(
    'service_role',
    'public.select_material_analysis_diagnostic_target_internal()',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.select_material_analysis_diagnostic_target_internal()',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.select_material_analysis_diagnostic_target_internal()',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.record_correlated_material_analysis_diagnostic_internal(text,jsonb,integer)',
    'execute'
  ),
  'only service_role may execute diagnostic correlation RPCs'
);

select pg_temp.assert_diagnostic_correlation(
  not has_table_privilege(
    'service_role',
    'public.material_analysis_diagnostic_correlations',
    'select,insert,update,delete'
  )
  and not has_table_privilege(
    'authenticated',
    'public.material_analysis_diagnostic_correlations',
    'select,insert,update,delete'
  )
  and not has_table_privilege(
    'anon',
    'public.material_analysis_diagnostic_correlations',
    'select,insert,update,delete'
  ),
  'diagnostic correlation table has no API-role privileges'
);

select pg_temp.assert_diagnostic_correlation(
  (select pg_catalog.count(*) = 1
    from public.material_analysis_diagnostic_correlations
    where status = 'awaiting_fixture' and consumed_at is null),
  'migration creates exactly one random active correlation'
);

do $$
declare
  v_user uuid := gen_random_uuid();
  v_other_material uuid := gen_random_uuid();
  v_target_material uuid := gen_random_uuid();
  v_other_job uuid;
  v_target_job uuid;
  v_work jsonb;
  v_batch uuid;
  v_lease uuid;
  v_visual uuid;
  v_reduction uuid;
  v_final uuid;
  v_correlation uuid;
  v_target jsonb;
  v_metadata jsonb := '{
    "response_status":"failed",
    "error_present":true,
    "incomplete_details_present":false,
    "refusal_count":0,
    "output_item_count":0,
    "structured_candidate_count":0,
    "parsed_json_byte_length":0,
    "top_level_key_count":0,
    "warning_count":0,
    "equation_count":0,
    "source_page_count":1,
    "section_count":0,
    "concept_count":0,
    "validator_stage":"validateResponseEnvelope"
  }'::jsonb;
begin
  insert into auth.users(id,email)
  values (v_user, v_user::text || '@diagnostic.invalid');

  insert into public.materials(
    id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
    file_size_bytes,processing_status,metadata
  ) values (
    v_other_material,v_user,repeat('x',8),'pdf','upload','study-materials',
    v_user::text || '/' || v_other_material::text || '/source.pdf',
    'application/pdf',1946,'ready','{}'
  );
  v_other_job := public.prepare_material_analysis_internal(
    v_other_material,'recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"reasons":["text_unusable"],"router_version":"phase-c-router-v1"},"routing_confidence":0.7,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  perform pg_temp.assert_diagnostic_correlation(
    not exists (
      select 1 from public.material_analysis_diagnostic_correlations
      where material_id = v_other_material or job_id = v_other_job
    ),
    'ordinary user material cannot attach the correlation'
  );
  perform pg_temp.expect_diagnostic_target_unavailable();

  insert into public.materials(
    id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
    file_size_bytes,processing_status,metadata
  ) values (
    v_target_material,v_user,repeat('y',8),'pdf','upload','study-materials',
    v_user::text || '/' || v_target_material::text || '/source.pdf',
    'application/pdf',1946,'ready','{}'
  );
  v_target_job := public.prepare_material_analysis_internal(
    v_target_material,'recommended',false,1,
    '9c4df300f7bff18e8522322f3973b36bdc3186122af01ffdbc5852669b40f46a',
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"reasons":["text_unusable"],"router_version":"phase-c-router-v1"},"routing_confidence":0.7,"input_hash":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}]'
  );
  select correlation_id into v_correlation
  from public.material_analysis_diagnostic_correlations
  where material_id = v_target_material and job_id = v_target_job;
  perform pg_temp.assert_diagnostic_correlation(
    v_correlation is not null
      and (select domain_profile = 'general'
        from public.material_processing_jobs where id = v_target_job),
    'exact fixture hash attaches one general-profile visual job'
  );

  v_work := public.claim_next_material_analysis_operation_internal(v_target_material);
  perform pg_temp.assert_diagnostic_correlation(
    v_work->>'kind' = 'page_visual',
    'controlled fixture creates one visual operation'
  );
  v_visual := (v_work->>'batch_id')::uuid;
  v_lease := (v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_visual,v_lease);
  perform public.record_material_analysis_response_internal(
    v_visual,v_lease,'resp_visual_test_12345678',null
  );
  perform public.complete_material_analysis_operation_internal(
    v_visual,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}',
    'phase-c-validator-v2',repeat('d',64),null,true
  );

  v_work := public.claim_next_material_analysis_operation_internal(v_target_material);
  perform pg_temp.assert_diagnostic_correlation(
    v_work->>'kind' = 'reduction',
    'controlled fixture creates one reduction operation'
  );
  v_reduction := (v_work->>'batch_id')::uuid;
  v_lease := (v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_reduction,v_lease);
  perform public.record_material_analysis_response_internal(
    v_reduction,v_lease,'resp_reduction_test_12345678',null
  );
  perform public.complete_material_analysis_operation_internal(
    v_reduction,v_lease,
    '{"source_pages":[1],"summary_markdown":"Safe.","key_concepts":[],"equation_ids":[],"warnings":[],"confidence":0.9}',
    'phase-c-validator-v2',repeat('e',64),null,true
  );

  v_work := public.claim_next_material_analysis_operation_internal(v_target_material);
  perform pg_temp.assert_diagnostic_correlation(
    v_work->>'kind' = 'final_summary',
    'controlled fixture creates one final-summary operation'
  );
  v_final := (v_work->>'batch_id')::uuid;
  v_lease := (v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_final,v_lease);
  perform public.record_material_analysis_response_internal(
    v_final,v_lease,'resp_final_test_12345678',null
  );
  perform public.fail_material_analysis_operation_internal(
    v_final,v_lease,'non_retryable',null,null,true
  );

  update public.material_analysis_diagnostic_correlations
  set job_id = v_other_job
  where correlation_id = v_correlation;
  perform pg_temp.expect_diagnostic_target_unavailable();
  update public.material_analysis_diagnostic_correlations
  set job_id = v_target_job
  where correlation_id = v_correlation;

  v_target := public.select_material_analysis_diagnostic_target_internal();
  perform pg_temp.assert_diagnostic_correlation(
    v_target->>'operation' = 'final_summary'
      and v_target->>'status' = 'failed'
      and v_target->>'response_id' = 'resp_final_test_12345678'
      and v_target->'page_numbers' = '[1]'::jsonb
      and v_target->>'page_count' = '1'
      and v_target->>'cleanup_state' = 'not_required'
      and not (v_target ? 'batch_id')
      and not (v_target ? 'correlation_id'),
    'one exact graph selects without exposing correlation or batch IDs'
  );

  drop index public.material_analysis_diagnostic_one_active_correlation;
  insert into public.material_analysis_diagnostic_correlations(
    material_id,job_id,final_batch_id,status
  ) values (v_target_material,v_target_job,v_final,'ready');
  perform pg_temp.expect_diagnostic_target_unavailable();
  delete from public.material_analysis_diagnostic_correlations
  where correlation_id <> v_correlation;
  create unique index material_analysis_diagnostic_one_active_correlation
    on public.material_analysis_diagnostic_correlations ((consumed_at is null))
    where consumed_at is null;

  perform public.record_correlated_material_analysis_diagnostic_internal(
    'response_status_not_completed',v_metadata,1
  );
  perform public.record_correlated_material_analysis_diagnostic_internal(
    'response_status_not_completed',v_metadata,1
  );
  perform pg_temp.assert_diagnostic_correlation(
    (select status = 'consumed' and consumed_at is not null
      from public.material_analysis_diagnostic_correlations
      where correlation_id = v_correlation)
      and (select diagnostic_code = 'response_status_not_completed'
        and diagnostic_metadata = v_metadata
        from public.material_processing_batches where id = v_final)
      and (select pg_catalog.count(*) = 3
        from public.material_processing_attempts where job_id = v_target_job)
      and (select pg_catalog.count(*) = 3
        from public.material_processing_batches where job_id = v_target_job),
    'recording is idempotent and preserves the exact three-operation graph'
  );
end
$$;

select 'phase_c_diagnostic_correlation_passed' as result;
