\set ON_ERROR_STOP on

create or replace function pg_temp.assert_reduction_repair(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'reduction_repair_assertion_failed: %',message;
  end if;
end
$$;

create or replace function pg_temp.expect_reduction_repair_failure(
  statement text,
  expected text
) returns void language plpgsql as $$
begin
  begin
    execute statement;
    raise exception 'expected failure did not occur: %',expected;
  exception when others then
    if sqlerrm not like '%'||expected||'%' then raise; end if;
  end;
end
$$;

select pg_temp.assert_reduction_repair(
  has_function_privilege(
    'service_role',
    'public.record_material_analysis_reduction_diagnostic_internal(uuid,uuid,jsonb,integer)',
    'execute')
  and has_function_privilege(
    'service_role',
    'public.load_material_analysis_reduction_diagnostic_internal(uuid)',
    'execute')
  and not has_function_privilege(
    'authenticated',
    'public.record_material_analysis_reduction_diagnostic_internal(uuid,uuid,jsonb,integer)',
    'execute')
  and not has_function_privilege(
    'authenticated',
    'public.load_material_analysis_reduction_diagnostic_internal(uuid)',
    'execute')
  and not has_function_privilege(
    'anon',
    'public.record_material_analysis_reduction_diagnostic_internal(uuid,uuid,jsonb,integer)',
    'execute')
  and not has_function_privilege(
    'anon',
    'public.load_material_analysis_reduction_diagnostic_internal(uuid)',
    'execute')
  and not exists(
    select 1
    from information_schema.role_routine_grants
    where routine_schema='public'
      and routine_name in (
        'record_material_analysis_reduction_diagnostic_internal',
        'load_material_analysis_reduction_diagnostic_internal'
      )
      and grantee='PUBLIC'
  ),
  'reduction diagnostics are service-role-only');

select pg_temp.assert_reduction_repair(
  not has_table_privilege(
    'service_role','public.material_processing_batches',
    'select,insert,update,delete')
  and not has_table_privilege(
    'authenticated','public.material_processing_batches',
    'select,insert,update,delete')
  and not has_table_privilege(
    'anon','public.material_processing_batches',
    'select,insert,update,delete'),
  'migration introduces no direct processing-table access');

select pg_temp.assert_reduction_repair(
  pg_get_functiondef(
    'public.material_analysis_analyze_again_eligible(uuid,uuid)'::regprocedure
  ) like '%file_size_bytes between 1 and 41943040%'
  and pg_get_functiondef(
    'public.material_analysis_analyze_again_eligible(uuid,uuid)'::regprocedure
  ) not like '%file_size_bytes between 1 and 10485760%',
  'Analyze Again uses the exact authoritative 40 MiB byte ceiling');

select pg_temp.assert_reduction_repair(
  validator.proowner='postgres'::regrole
    and not validator.prosecdef
    and validator.provolatile='i'
    and validator.proconfig=array['search_path=pg_catalog, public'],
  'diagnostic validator has immutable trusted ownership')
from pg_proc validator
where validator.oid=
  'public.material_analysis_valid_reduction_diagnostic_metadata(jsonb)'::regprocedure;

select pg_temp.assert_reduction_repair(
  public.material_analysis_valid_reduction_diagnostic_metadata(
    '{"operation_kind":"reduction","reduction_level":"global","validator_stage":"validateReductionSourcePages","safe_validator_code":"reduction_source_pages_mismatch","input_concept_count":100,"accepted_concept_count":24,"duplicate_concept_count":1,"oversized_concept_count":1,"serialized_list_concept_count":1,"dropped_concept_count":76,"source_page_count":55,"equation_id_count":53,"warning_count":8}'
  )
  and not public.material_analysis_valid_reduction_diagnostic_metadata(
    '{"operation_kind":"reduction","reduction_level":"global","validator_stage":"validateReductionSourcePages","safe_validator_code":"reduction_source_pages_mismatch","summary_markdown":"forbidden","source_page_count":55,"equation_id_count":53,"warning_count":8}'
  )
  and not public.material_analysis_valid_reduction_diagnostic_metadata(
    '{"operation_kind":"reduction","reduction_level":"global","validator_stage":"validateReductionSourcePages","safe_validator_code":"reduction_equation_references_invalid","source_page_count":55,"equation_id_count":53,"warning_count":8}'
  ),
  'diagnostic metadata is closed, counts-only, and stage-code coherent');

insert into auth.users(id,email) values
  ('35353535-3535-4535-8535-353535353531','repair-owner@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '35353535-3535-4535-8535-353535353532',
  '35353535-3535-4535-8535-353535353531',
  'Sanitized repair fixture','pdf','upload','study-materials',
  '35353535-3535-4535-8535-353535353531/35353535-3535-4535-8535-353535353532/source.pdf',
  'application/pdf',10485760,'ready','{}'
);

insert into storage.objects(id,bucket_id,name,owner_id) values (
  '35353535-3535-4535-8535-353535353533','study-materials',
  '35353535-3535-4535-8535-353535353531/35353535-3535-4535-8535-353535353532/source.pdf',
  '35353535-3535-4535-8535-353535353531'
);

do $$
declare
  v_job uuid;
  v_work jsonb;
  v_batch uuid;
  v_lease uuid;
  v_diagnostic jsonb;
  v_failed_job uuid;
  v_contract jsonb;
  v_fingerprint text;
  v_sizes bigint[]:=array[
    10485760,
    10485761,
    11702108,
    41943040
  ];
  v_size bigint;
begin
  v_contract:=jsonb_build_object(
    'fingerprint_version','phase-c-fingerprint-v2',
    'source_content_hash',repeat('a',64),
    'source_metadata_hash',repeat('b',64),
    'processing_mode','recommended',
    'page_count',1,
    'router_version','phase-c-router-v1',
    'prompt_version','phase-c-prompts-v3',
    'page_schema_version','phase-c-page-schema-v3',
    'reduction_schema_version','phase-c-reduction-schema-v2',
    'final_summary_schema_version','phase-c-final-schema-v3',
    'validator_version','phase-c-validator-v3',
    'openai_configuration_version','phase-c-server-v2',
    'mini_pdf_version','phase-c-mini-pdf-v1');
  v_fingerprint:=
    public.material_analysis_version_fingerprint(v_contract);
  v_job:=public.prepare_material_analysis_internal(
    '35353535-3535-4535-8535-353535353532',
    'recommended',false,1,repeat('a',64),
    v_contract,v_fingerprint,
    '[{"page_number":1,"route":"text","normalized_text":"Reliable selectable synthetic study text.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]',
    false
  );
  v_work:=public.claim_next_material_analysis_operation_internal(
    '35353535-3535-4535-8535-353535353532');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_page_repair_12345678',null);
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"pages":[{"page_number":1,"content_status":"completed","summary_markdown":"Safe page summary.","key_concepts":["Concept"],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}',
    'phase-c-validator-v3',repeat('c',64),null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '35353535-3535-4535-8535-353535353532');
  perform pg_temp.assert_reduction_repair(
    v_work->>'kind'='reduction'
      and v_work->>'reduction_level'='1',
    'claimed reduction exposes its authoritative level');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_reduction_repair_12345678',null);
  v_diagnostic:=
    '{"operation_kind":"reduction","reduction_level":"first_level","validator_stage":"validateReductionEquationReferences","safe_validator_code":"reduction_equation_references_invalid","input_concept_count":3,"accepted_concept_count":2,"duplicate_concept_count":0,"oversized_concept_count":1,"serialized_list_concept_count":1,"dropped_concept_count":1,"source_page_count":1,"equation_id_count":1,"warning_count":0}';
  perform public.record_material_analysis_reduction_diagnostic_internal(
    v_batch,v_lease,v_diagnostic,1);
  perform public.record_material_analysis_reduction_diagnostic_internal(
    v_batch,v_lease,v_diagnostic,1);
  perform public.terminalize_material_analysis_operation_internal(
    v_batch,v_lease,'terminal_structured_output_invalid');
  perform pg_temp.assert_reduction_repair(
    public.load_material_analysis_reduction_diagnostic_internal(v_batch)
      =v_diagnostic,
    'counts-only diagnostic survives terminal failure');

  perform pg_temp.expect_reduction_repair_failure(format(
    'select public.record_material_analysis_reduction_diagnostic_internal(%L,%L,%L::jsonb,1)',
    v_batch,v_lease,v_diagnostic||'{"summary_markdown":"forbidden"}'::jsonb
  ),'invalid_material_analysis_reduction_diagnostic');

  select * into v_failed_job
  from (
    select id
    from public.material_processing_jobs
    where material_id='35353535-3535-4535-8535-353535353532'
    order by generation desc
    limit 1
  ) latest;

  foreach v_size in array v_sizes loop
    update public.materials
    set file_size_bytes=v_size
    where id='35353535-3535-4535-8535-353535353532';
    perform pg_temp.assert_reduction_repair(
      public.material_analysis_analyze_again_eligible(
        '35353535-3535-4535-8535-353535353532',v_failed_job),
      format('PDF size %s remains eligible',v_size));
  end loop;

  perform pg_temp.expect_reduction_repair_failure(
    'update public.materials set file_size_bytes=41943041 where id=''35353535-3535-4535-8535-353535353532''',
    'materials_upload_shape');
end
$$;

delete from public.materials
where id='35353535-3535-4535-8535-353535353532';
delete from storage.objects
where id='35353535-3535-4535-8535-353535353533';
delete from auth.users
where id='35353535-3535-4535-8535-353535353531';

select 'phase_c_reduction_failure_repair_passed' as result;
