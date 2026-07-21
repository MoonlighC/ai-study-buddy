\set ON_ERROR_STOP on

create or replace function pg_temp.assert_reproduction_diagnostic(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'reproduction_diagnostic_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_reproduction_diagnostic(
  not has_table_privilege('anon','public.material_analysis_reproduction_diagnostics','select')
  and not has_table_privilege('authenticated','public.material_analysis_reproduction_diagnostics','select')
  and has_table_privilege('service_role','public.material_analysis_reproduction_diagnostics','select')
  and not has_table_privilege('service_role','public.material_analysis_reproduction_diagnostics','insert,update,delete'),
  'diagnostic table is service-readable but not caller-writable'
);
select pg_temp.assert_reproduction_diagnostic(
  has_function_privilege(
    'service_role',
    'public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.record_material_analysis_reproduction_diagnostic_internal(uuid,uuid,jsonb)',
    'execute'
  ),
  'recording function is service-role-only'
);

select pg_temp.assert_reproduction_diagnostic(
  public.material_analysis_reproduction_metadata_valid($json${
    "operation":"final_summary",
    "provider_status":"completed",
    "validator_stage":"validateFinalSummarySchema",
    "json_parse_success":true,
    "top_level_keys":["partial_extraction","sections"],
    "observed_types":{"$":"object","$.partial_extraction.page_modes":"object"},
    "missing_required":["$.warnings"],
    "unexpected_fields":[],
    "mismatches":[{
      "path":"$.partial_extraction.page_modes",
      "code":"type_mismatch",
      "expected_type":"array",
      "observed_type":"object"
    }],
    "array_object_counts":{"$":6},
    "parsed_json_byte_length":1024,
    "schema_version":"phase-c-final-schema-v1",
    "safe_failure_code":"final_summary_schema_failed"
  }$json$::jsonb),
  'bounded structural metadata is accepted'
);
select pg_temp.assert_reproduction_diagnostic(
  not public.material_analysis_reproduction_metadata_valid(
    $json${"summary":"private content"}$json$::jsonb
  )
  and not public.material_analysis_reproduction_metadata_valid(
    $json${
      "operation":null,
      "provider_status":"completed",
      "validator_stage":"validateFinalSummarySchema",
      "json_parse_success":true,
      "top_level_keys":[],"observed_types":{},"missing_required":[],
      "unexpected_fields":[],"mismatches":[],"array_object_counts":{},
      "parsed_json_byte_length":0,
      "schema_version":"phase-c-final-schema-v1",
      "safe_failure_code":"final_summary_schema_failed"
    }$json$::jsonb
  ),
  'content fields and null scalar metadata are rejected'
);

insert into auth.users(id,email) values
  ('20202020-2020-4020-8020-202020202020','reproduction-diagnostic@example.test');
insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '20202020-2020-4020-8020-202020202001',
  '20202020-2020-4020-8020-202020202020',
  'Reproduction diagnostic fixture','pdf','upload','study-materials',
  '20202020-2020-4020-8020-202020202020/20202020-2020-4020-8020-202020202001/source.pdf',
  'application/pdf',128,'pending','{}'
);

do $$
declare
  v_job uuid;
  v_work jsonb;
  v_batch uuid;
begin
  v_job:=public.prepare_material_analysis_internal(
    '20202020-2020-4020-8020-202020202001','recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Readable page.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  perform pg_temp.assert_reproduction_diagnostic(
    (select job_id=v_job and metadata is null
      from public.material_analysis_reproduction_diagnostics where singleton),
    'the next job is correlated automatically without a caller-selected ID'
  );
  v_work:=public.claim_next_material_analysis_operation_internal(
    '20202020-2020-4020-8020-202020202001'
  );
  v_batch:=(v_work->>'batch_id')::uuid;
  perform public.record_material_analysis_reproduction_diagnostic_internal(
    v_job,v_batch,$json${
      "operation":"page_text","provider_status":"completed",
      "validator_stage":"validatePageSchema","json_parse_success":true,
      "top_level_keys":["pages"],"observed_types":{"$":"object"},
      "missing_required":["$.pages[].warnings"],"unexpected_fields":[],
      "mismatches":[],"array_object_counts":{"$":1},
      "parsed_json_byte_length":256,
      "schema_version":"phase-c-page-schema-v1",
      "safe_failure_code":"page_schema_failed"
    }$json$::jsonb
  );
  perform public.record_material_analysis_reproduction_diagnostic_internal(
    v_job,v_batch,$json${
      "operation":"page_text","provider_status":"completed",
      "validator_stage":"validatePageSchema","json_parse_success":true,
      "top_level_keys":[],"observed_types":{},"missing_required":[],
      "unexpected_fields":[],"mismatches":[],"array_object_counts":{},
      "parsed_json_byte_length":1,
      "schema_version":"phase-c-page-schema-v1",
      "safe_failure_code":"replacement_must_not_persist"
    }$json$::jsonb
  );
  perform pg_temp.assert_reproduction_diagnostic(
    (select metadata->>'safe_failure_code'='page_schema_failed'
      and batch_id=v_batch and captured_at is not null
      from public.material_analysis_reproduction_diagnostics where singleton),
    'repeated reconciliation captures exactly once'
  );
end
$$;
