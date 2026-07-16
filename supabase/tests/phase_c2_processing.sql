\set ON_ERROR_STOP on

create or replace function pg_temp.assert_c2(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'c2_assertion_failed: %',message; end if;
end
$$;

create or replace function pg_temp.expect_c2_failure(statement text,expected text)
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

create or replace function pg_temp.force_c2_finalize_rollback()
returns trigger language plpgsql as $$
begin
  if current_setting('c2.force_finalize_failure',true)='on'
    and new.status in ('completed','completed_with_warnings') then
    raise exception 'forced_finalize_rollback';
  end if;
  return new;
end
$$;
create trigger force_c2_finalize_rollback_trigger
before update on public.material_processing_jobs for each row
execute function pg_temp.force_c2_finalize_rollback();

select pg_temp.assert_c2(
  to_regprocedure('public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb)') is not null
  and to_regprocedure('public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb,text,jsonb)') is not null
  and to_regprocedure('public.claim_next_material_analysis_operation_internal(uuid,uuid)') is not null
  and to_regprocedure('public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)') is not null
  and to_regprocedure('public.create_material_analysis_file_intent_internal(uuid,uuid)') is not null
  and to_regprocedure('public.record_material_analysis_file_uploaded_internal(uuid,uuid,text)') is not null
  and to_regprocedure('public.record_material_analysis_file_recovery_internal(uuid,uuid,text,boolean)') is not null,
  'C2 trusted RPC inventory'
);

select pg_temp.assert_c2(not exists(
  select 1 from information_schema.role_routine_grants
  where routine_schema='public' and routine_name in (
    'prepare_material_analysis_internal','claim_next_material_analysis_operation_internal',
    'complete_material_analysis_operation_internal','fail_material_analysis_operation_internal',
    'create_material_analysis_file_intent_internal','record_material_analysis_file_uploaded_internal',
    'record_material_analysis_file_recovery_internal'
  ) and grantee in ('anon','authenticated','PUBLIC')
),'C2 internal RPCs are not public');

select pg_temp.assert_c2(public.material_analysis_version_fingerprint($json$
{"fingerprint_version":"phase-c-fingerprint-v2","source_content_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","source_metadata_hash":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","processing_mode":"recommended","page_count":1,"router_version":"phase-c-router-v1","prompt_version":"phase-c-prompts-v1","page_schema_version":"phase-c-page-schema-v1","reduction_schema_version":"phase-c-reduction-schema-v1","final_summary_schema_version":"phase-c-final-schema-v1","validator_version":"phase-c-validator-v2","openai_configuration_version":"phase-c-server-v1","mini_pdf_version":"phase-c-mini-pdf-v1"}
$json$::jsonb)='5e21cbc0a7a74807a99551a00233404f7716c0221f26258d9f9c62c1cd30da33',
  'TypeScript and SQL use the same canonical version fingerprint');

insert into auth.users(id,email) values
  ('88888888-8888-4888-8888-888888888888','c2-owner@example.test'),
  ('99999999-9999-4999-8999-999999999999','c2-other@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888',
  'C2 source','pdf','upload','study-materials',
  '88888888-8888-4888-8888-888888888888/88888888-8888-4888-8888-888888888801/source.pdf',
  'application/pdf',128,'ready','{}'
);

select pg_temp.assert_c2(
  (select count(*)=1 from public.load_material_analysis_source_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888'))
  and (select count(*)=0 from public.load_material_analysis_source_internal(
    '88888888-8888-4888-8888-888888888801','99999999-9999-4999-8999-999999999999')),
  'source owner succeeds and cross-user is denied'
);

do $$
declare v_job uuid; v_same uuid; v_work jsonb; v_batch uuid; v_lease uuid;
  v_key1 text; v_key2 text; v_auth uuid; v_attempt1 uuid; v_attempt2 uuid;
  v_summary jsonb; v_contract jsonb; v_new uuid;
begin
  v_job:=public.prepare_material_analysis_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888',
    'recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Reliable selectable study text for the bounded page operation.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  v_same:=public.prepare_material_analysis_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888',
    'recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Reliable selectable study text for the bounded page operation.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  perform pg_temp.assert_c2(v_job=v_same,'duplicate preparation is idempotent');
  perform pg_temp.assert_c2((select array_agg(page_number order by page_number)=array[1]
    from public.material_processing_pages where job_id=v_job),'exact manifest 1..P');

  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888');
  perform pg_temp.assert_c2(v_work->>'kind'='page_text','bounded text work claimed');
  v_batch:=(v_work->>'batch_id')::uuid;v_lease:=(v_work->>'lease_token')::uuid;
  select idempotency_key into v_key1 from public.submit_material_analysis_operation_internal(v_batch,v_lease);
  select current_attempt_id into v_attempt1 from public.material_processing_batches where id=v_batch;
  perform public.mark_material_processing_dispatch_unknown_internal(v_batch,v_lease);
  perform public.fail_material_analysis_operation_internal(v_batch,v_lease,'user_retry_required',null,null,true);
  perform pg_temp.assert_c2((select status='user_retry_required' and budget_state='consumed'
    from public.material_processing_batches where id=v_batch),'ambiguous work retains budget');

  perform set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',false);
  v_auth:=public.authorize_material_analysis_retry('88888888-8888-4888-8888-888888888801');
  perform public.request_material_processing_retry_internal('88888888-8888-4888-8888-888888888801',v_auth);
  perform pg_temp.assert_c2((select consumed_at is not null from public.material_processing_retry_authorizations
    where id=v_auth),'retry authorization consumed');
  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888');
  v_lease:=(v_work->>'lease_token')::uuid;
  select idempotency_key into v_key2 from public.submit_material_analysis_operation_internal(v_batch,v_lease);
  select current_attempt_id into v_attempt2 from public.material_processing_batches where id=v_batch;
  perform pg_temp.assert_c2(v_key1<>v_key2 and v_attempt1<>v_attempt2,'retry attempt and idempotency are immutable and unique');
  perform pg_temp.assert_c2((select status='dispatch_unknown' and completed_at is null
    from public.material_processing_attempts where id=v_attempt1),'predecessor attempt remains unchanged');
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_12345678',null);
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe page summary.","key_concepts":["Concept"],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}'::jsonb,
    'phase-c-validator-v2',repeat('c',64),null,true
  );
  perform pg_temp.assert_c2((select status='completed' and total_upstream_attempts=2
    from public.material_processing_pages where job_id=v_job and page_number=1),'page completion and attempt ceiling accounting');

  -- One leaf reduction, then one final summary; each claim owns one bounded unit.
  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888');
  perform pg_temp.assert_c2(v_work->>'kind'='reduction' and jsonb_array_length(v_work->'page_numbers')<=10,
    'bounded leaf reduction claimed');
  v_batch:=(v_work->>'batch_id')::uuid;v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_22345678',null);
  perform public.complete_material_analysis_operation_internal(v_batch,v_lease,
    '{"source_pages":[1],"summary_markdown":"Safe reduction.","key_concepts":["Concept"],"equation_ids":[],"warnings":[],"confidence":0.9}'::jsonb,
    'phase-c-validator-v2',repeat('d',64),null,true);

  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888');
  perform pg_temp.assert_c2(v_work->>'kind'='final_summary','final summary claimed after persisted reduction');
  v_batch:=(v_work->>'batch_id')::uuid;v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_32345678',null);
  v_summary:='{"language":"en","sections":[{"id":"overview","title":"Overview","blocks":[{"kind":"prose","markdown":"Safe final summary.","display":"block"}],"source_pages":[1],"confidence":0.9}],"key_concepts":[{"title":"Concept","explanation_markdown":"Safe explanation.","source_pages":[1],"confidence":0.9}],"equations":[],"warnings":[],"partial_extraction":{"is_partial":false,"analyzed_pages":[1],"partial_pages":[],"missing_pages":[],"page_modes":[{"page":1,"mode":"text"}]}}'::jsonb;
  perform set_config('c2.force_finalize_failure','on',true);
  begin
    perform public.complete_material_analysis_operation_internal(v_batch,v_lease,v_summary,
      'phase-c-validator-v2',repeat('e',64),'## Overview\n\nSafe final summary.\n\nPages: 1',true);
    raise exception 'expected forced finalization failure';
  exception when others then
    if sqlerrm not like '%forced_finalize_rollback%' then raise; end if;
  end;
  perform pg_temp.assert_c2((select summary_payload is null from public.materials
    where id='88888888-8888-4888-8888-888888888801')
    and (select status='response_known' from public.material_processing_batches where id=v_batch),
    'finalization failure rolls back material and batch atomically');
  perform set_config('c2.force_finalize_failure','off',true);
  perform public.complete_material_analysis_operation_internal(v_batch,v_lease,v_summary,
    'phase-c-validator-v2',repeat('e',64),'## Overview\n\nSafe final summary.\n\nPages: 1',true);
  perform pg_temp.assert_c2((select summary_payload=v_summary and summary_schema_version=1
    and summary_processing_mode='recommended' and summary like '## Overview%'
    from public.materials where id='88888888-8888-4888-8888-888888888801'),
    'structured summary and safe compatibility projection persisted');
  perform pg_temp.assert_c2((select state='completed' and completed_pages=1 and summary_payload=v_summary
    from public.get_material_analysis_status('88888888-8888-4888-8888-888888888801')),
    'safe public status projection');

  v_contract:=jsonb_build_object(
    'fingerprint_version','phase-c-fingerprint-v2','source_content_hash',repeat('a',64),
    'source_metadata_hash',repeat('f',64),'processing_mode','recommended','page_count',1,
    'router_version','phase-c-router-v1','prompt_version','phase-c-prompts-v2',
    'page_schema_version','phase-c-page-schema-v1','reduction_schema_version','phase-c-reduction-schema-v1',
    'final_summary_schema_version','phase-c-final-schema-v1','validator_version','phase-c-validator-v2',
    'openai_configuration_version','phase-c-server-v1','mini_pdf_version','phase-c-mini-pdf-v1');
  v_new:=public.prepare_material_analysis_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888',
    'recommended',false,1,repeat('a',64),v_contract,
    public.material_analysis_version_fingerprint(v_contract),
    '[{"page_number":1,"route":"text","normalized_text":"Reliable selectable study text for the new generation.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}]');
  perform pg_temp.assert_c2(v_new<>v_job
    and (select count(*)=2 and max(generation)=2 from public.material_processing_jobs
      where material_id='88888888-8888-4888-8888-888888888801')
    and (select status in ('completed','completed_with_warnings') from public.material_processing_jobs where id=v_job),
    'incompatible completed contract starts a new generation and preserves history');
end
$$;

select pg_temp.expect_c2_failure($sql$
  select public.prepare_material_analysis_internal(
    '88888888-8888-4888-8888-888888888801','88888888-8888-4888-8888-888888888888',
    'recommended',false,2,repeat('a',64),'[]'::jsonb)
$sql$,'invalid_preparation');

delete from public.materials where id='88888888-8888-4888-8888-888888888801';
select pg_temp.assert_c2(
  not exists(select 1 from public.material_processing_jobs where material_id='88888888-8888-4888-8888-888888888801')
  and not exists(select 1 from public.material_processing_attempts where material_id='88888888-8888-4888-8888-888888888801'),
  'material deletion cascades through C2 state'
);

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '88888888-8888-4888-8888-888888888802','88888888-8888-4888-8888-888888888888',
  'C2 visual lifecycle','image','upload','study-images',
  '88888888-8888-4888-8888-888888888888/88888888-8888-4888-8888-888888888802/source.png',
  'image/png',128,'ready','{}'
);

do $$
declare v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid; v_artifact uuid; i integer;
  v_second uuid:='77777777-7777-4777-8777-777777777779';
begin
  v_job:=public.prepare_material_analysis_internal(
    '88888888-8888-4888-8888-888888888802','88888888-8888-4888-8888-888888888888',
    'recommended',false,1,repeat('1',64),
    '[{"page_number":1,"route":"visual","normalized_text":"","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":1,"input_hash":"2222222222222222222222222222222222222222222222222222222222222222"}]');
  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888802','88888888-8888-4888-8888-888888888888');
  v_batch:=(v_work->>'batch_id')::uuid; v_lease:=(v_work->>'lease_token')::uuid;
  select artifact_id into v_artifact from public.create_material_analysis_file_intent_internal(v_batch,v_lease);
  perform pg_temp.assert_c2((select state='upload_intent' and provider_file_id is null
    from public.material_processing_artifacts where id=v_artifact)
    and (select attempt_count=0 and status='prepared' from public.material_processing_batches where id=v_batch),
    'file intent is durable before upload and before paid dispatch');
  perform public.record_material_analysis_file_uploaded_internal(v_artifact,v_lease,'file_lifecycle_12345678');
  perform pg_temp.assert_c2((select state='uploaded' and provider_filename='analysis-'||v_artifact::text||'.pdf'
    from public.material_processing_artifacts where id=v_artifact),
    'uploaded file identity is immediately durable with stable recovery filename');
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(v_batch,v_lease,'resp_lifecycle_12345678',null);
  perform public.complete_material_analysis_operation_internal(v_batch,v_lease,
    '{"pages":[{"page_number":1,"summary_markdown":"Safe visual page.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}]}',
    'phase-c-validator-v2',repeat('3',64),null,false);
  perform pg_temp.assert_c2((select state='cleanup_pending' from public.material_processing_artifacts where id=v_artifact),
    'operation completion durably schedules later cleanup');

  for i in 1..10 loop
    update public.material_processing_artifacts set cleanup_retry_after=now()-interval '1 second'
      where id=v_artifact;
    v_work:=public.claim_next_material_analysis_operation_internal(
      '88888888-8888-4888-8888-888888888802','88888888-8888-4888-8888-888888888888');
    perform pg_temp.assert_c2(v_work->>'kind'='cleanup','cleanup remains a bounded independent work unit');
    perform public.complete_material_analysis_cleanup_internal(
      v_artifact,(v_work->>'lease_token')::uuid,'file_lifecycle_12345678',false);
  end loop;
  perform pg_temp.assert_c2((select state='manual_cleanup_required' and cleanup_attempt_count=10
    from public.material_processing_artifacts where id=v_artifact),
    'cleanup exhaustion is explicit and cannot overflow its counter');

  insert into public.material_processing_artifacts(
    id,batch_id,job_id,material_id,user_id,provider_filename,provider_file_id,state
  ) select v_second,b.id,b.job_id,b.material_id,b.user_id,
    'analysis-'||v_second::text||'.pdf','file_idempotent_12345678','cleanup_pending'
    from public.material_processing_batches b where b.id=v_batch;
  v_work:=public.claim_next_material_analysis_operation_internal(
    '88888888-8888-4888-8888-888888888802','88888888-8888-4888-8888-888888888888');
  perform public.complete_material_analysis_cleanup_internal(
    v_second,(v_work->>'lease_token')::uuid,'file_idempotent_12345678',true);
  perform public.complete_material_analysis_cleanup_internal(
    v_second,(v_work->>'lease_token')::uuid,'file_idempotent_12345678',true);
  perform pg_temp.assert_c2((select state='cleaned' and cleaned_at is not null
    from public.material_processing_artifacts where id=v_second),'cleanup completion is idempotent');
end
$$;

delete from public.materials where id='88888888-8888-4888-8888-888888888802';

select 'PHASE_C2_SQL_ASSERTIONS_OK' as result;
