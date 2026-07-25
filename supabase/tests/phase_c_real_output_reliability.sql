\set ON_ERROR_STOP on

create or replace function pg_temp.assert_reliability(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'reliability_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_reliability(
  to_regprocedure(
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)'
  ) is not null,
  'Analyze-again trusted overload exists');

select pg_temp.assert_reliability(
  pg_get_function_result(
    'public.get_material_analysis_status(uuid)'::regprocedure
  ) =
  'TABLE(material_id uuid, processing_mode text, state text, public_stage text, page_count integer, completed_pages integer, confirmation_required boolean, can_retry boolean, retry_after_seconds integer, warnings jsonb, summary_schema_version integer, summary_payload jsonb, safe_error_code text, active_operation text)',
  'v1 result contract remains byte-for-byte compatible');

select pg_temp.assert_reliability(
  to_regprocedure('public.get_material_analysis_status_v2(uuid)') is not null
    and prosecdef
    and proconfig = array['search_path=pg_catalog, public']
    and proowner = 'postgres'::regrole,
  'v2 exists with fixed trusted execution properties')
from pg_proc
where oid='public.get_material_analysis_status_v2(uuid)'::regprocedure;

select pg_temp.assert_reliability(
  has_function_privilege(
    'authenticated','public.get_material_analysis_status(uuid)','execute')
    and has_function_privilege(
      'authenticated','public.get_material_analysis_status_v2(uuid)','execute')
    and not has_function_privilege(
      'anon','public.get_material_analysis_status_v2(uuid)','execute')
    and not has_function_privilege(
      'authenticated',
      'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)',
      'execute'),
  'public status grants and trusted Analyze-again boundary are exact');

insert into auth.users(id,email) values
  ('31313131-3131-4131-8131-313131313131','reliability@example.test'),
  ('31313131-3131-4131-8131-313131313139','other@example.test');
insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values
  (
    '31313131-3131-4131-8131-313131313132',
    '31313131-3131-4131-8131-313131313131',
    'Analyze again source','pdf','upload','study-materials',
    '31313131-3131-4131-8131-313131313131/31313131-3131-4131-8131-313131313132/source.pdf',
    'application/pdf',128,'failed','{}'
  ),
  (
    '31313131-3131-4131-8131-313131313133',
    '31313131-3131-4131-8131-313131313131',
    'Legacy summary','pdf','upload','study-materials',
    '31313131-3131-4131-8131-313131313131/31313131-3131-4131-8131-313131313133/source.pdf',
    'application/pdf',128,'failed','{}'
  ),
  (
    '31313131-3131-4131-8131-313131313134',
    '31313131-3131-4131-8131-313131313131',
    'Current summary','pdf','upload','study-materials',
    '31313131-3131-4131-8131-313131313131/31313131-3131-4131-8131-313131313134/source.pdf',
    'application/pdf',128,'failed','{}'
  ),
  (
    '31313131-3131-4131-8131-313131313135',
    '31313131-3131-4131-8131-313131313131',
    'Wrong validator','pdf','upload','study-materials',
    '31313131-3131-4131-8131-313131313131/31313131-3131-4131-8131-313131313135/source.pdf',
    'application/pdf',128,'failed','{}'
  );

do $$
declare
  v_contract_v2 jsonb;
  v_contract_v3 jsonb;
  v_fingerprint_v2 text;
  v_fingerprint_v3 text;
  v_old uuid;
  v_new uuid;
  v_duplicate uuid;
  v_work jsonb;
  v_old_snapshot jsonb;
  v_plan_50 jsonb;
  v_plan_1 jsonb;
  v_summary jsonb;
  v_legacy_job uuid;
  v_current_job uuid;
  v_wrong_job uuid;
  v_cross_user_count integer;
begin
  v_contract_v2:=jsonb_build_object(
    'fingerprint_version','phase-c-fingerprint-v2',
    'source_content_hash',repeat('a',64),
    'source_metadata_hash',repeat('b',64),
    'processing_mode','recommended','page_count',50,
    'router_version','phase-c-router-v1',
    'prompt_version','phase-c-prompts-v2',
    'page_schema_version','phase-c-page-schema-v2',
    'reduction_schema_version','phase-c-reduction-schema-v2',
    'final_summary_schema_version','phase-c-final-schema-v2',
    'validator_version','phase-c-validator-v2',
    'openai_configuration_version','phase-c-server-v1',
    'mini_pdf_version','phase-c-mini-pdf-v1');
  v_contract_v3:=v_contract_v2 || jsonb_build_object(
    'prompt_version','phase-c-prompts-v3',
    'page_schema_version','phase-c-page-schema-v3',
    'final_summary_schema_version','phase-c-final-schema-v3',
    'validator_version','phase-c-validator-v3',
    'openai_configuration_version','phase-c-server-v2');
  select jsonb_agg(jsonb_build_object(
    'page_number',page_number,
    'route','text',
    'normalized_text','Sanitized grounded page.',
    'routing_signals',jsonb_build_object(
      'router_version','phase-c-router-v1'),
    'routing_confidence',0.9,
    'input_hash',repeat('c',64)
  ) order by page_number)
  into v_plan_50 from generate_series(1,50) page_number;
  v_fingerprint_v2:=public.material_analysis_version_fingerprint(v_contract_v2);
  v_fingerprint_v3:=public.material_analysis_version_fingerprint(v_contract_v3);
  perform pg_temp.assert_reliability(
    v_fingerprint_v2<>v_fingerprint_v3,
    'v3 contract produces a different fingerprint');

  v_old:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313132','recommended',true,50,
    repeat('a',64),v_contract_v2,v_fingerprint_v2,v_plan_50,false);
  update public.material_processing_jobs
  set status='failed',safe_error_code='structured_output_invalid',
    completed_at=now(),updated_at=now()
  where id=v_old;
  select to_jsonb(j) into v_old_snapshot
  from public.material_processing_jobs j where id=v_old;

  perform set_config(
    'request.jwt.claim.sub','31313131-3131-4131-8131-313131313131',false);
  perform pg_temp.assert_reliability(
    (select not (to_jsonb(s)?'can_analyze_again')
      from public.get_material_analysis_status(
        '31313131-3131-4131-8131-313131313132') s),
    'old client sees the exact v1 shape after migration 031');
  perform pg_temp.assert_reliability(
    (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '31313131-3131-4131-8131-313131313132')),
    'new client sees Analyze again through v2');

  v_new:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313132','recommended',false,50,
    repeat('a',64),v_contract_v3,v_fingerprint_v3,v_plan_50,true);
  v_duplicate:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313132','recommended',false,50,
    repeat('a',64),v_contract_v3,v_fingerprint_v3,v_plan_50,true);
  perform pg_temp.assert_reliability(
    v_new=v_duplicate and v_new<>v_old
      and (select count(*)=2 and max(generation)=2
        from public.material_processing_jobs
        where material_id='31313131-3131-4131-8131-313131313132'),
    'double Analyze Again joins one new generation');
  perform pg_temp.assert_reliability(
    (select status='awaiting_confirmation' and confirmation_required
      from public.material_processing_jobs where id=v_new)
      and not exists(
        select 1 from public.material_processing_batches where job_id=v_new),
    '50-page Analyze Again creates no operation before confirmation');
  perform pg_temp.assert_reliability(
    (select to_jsonb(j)=v_old_snapshot
      from public.material_processing_jobs j where id=v_old),
    'old failed generation remains immutable');

  perform set_config(
    'request.jwt.claim.sub','31313131-3131-4131-8131-313131313139',false);
  select count(*) into v_cross_user_count
  from public.get_material_analysis_status_v2(
    '31313131-3131-4131-8131-313131313132');
  perform pg_temp.assert_reliability(
    v_cross_user_count=0,
    'authenticated users cannot read another owner analysis');
  perform set_config(
    'request.jwt.claim.sub','31313131-3131-4131-8131-313131313131',false);

  v_plan_1:=jsonb_build_array(jsonb_build_object(
    'page_number',1,'route','text',
    'normalized_text','Sanitized grounded page.',
    'routing_signals',jsonb_build_object(
      'router_version','phase-c-router-v1'),
    'routing_confidence',0.9,'input_hash',repeat('d',64)));
  v_summary:='{"language":"en","sections":[{"id":"overview","title":"Overview","blocks":[{"kind":"prose","markdown":"Safe final summary.","display":"block"}],"source_pages":[1],"confidence":0.9}],"key_concepts":[],"equations":[],"warnings":[],"partial_extraction":{"is_partial":false,"analyzed_pages":[1],"partial_pages":[],"missing_pages":[],"page_modes":[{"page":1,"mode":"text"}]}}'::jsonb;

  v_contract_v2:=jsonb_set(v_contract_v2,'{page_count}','1'::jsonb);
  v_contract_v3:=jsonb_set(v_contract_v3,'{page_count}','1'::jsonb);
  v_fingerprint_v2:=public.material_analysis_version_fingerprint(v_contract_v2);
  v_fingerprint_v3:=public.material_analysis_version_fingerprint(v_contract_v3);
  v_legacy_job:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313133','recommended',true,1,
    repeat('a',64),v_contract_v2,v_fingerprint_v2,v_plan_1,false);
  update public.material_processing_jobs set status='processing',
    budget_state='reserved',active_lease_token=gen_random_uuid(),
    active_lease_expires_at=now()+interval '5 minutes',updated_at=now()
  where id=v_legacy_job;
  update public.material_processing_jobs set status='completed',
    budget_state='consumed',completed_at=now(),active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_legacy_job;
  update public.materials set processing_status='ready',
    summary_payload=v_summary,summary_schema_version=1,
    summary_processing_mode='recommended',
    summary_validation_version='phase-c-validator-v2',
    summary_validation_hash=repeat('e',64)
  where id='31313131-3131-4131-8131-313131313133';
  perform pg_temp.assert_reliability(
    (select summary_payload is not null
      from public.get_material_analysis_status_v2(
        '31313131-3131-4131-8131-313131313133'))
      and exists(select 1 from public.load_study_generation_source_internal(
        '31313131-3131-4131-8131-313131313131',
        '31313131-3131-4131-8131-313131313133')),
    'trusted legacy v2 summary remains readable and study eligible');

  v_current_job:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313134','recommended',true,1,
    repeat('a',64),v_contract_v3,v_fingerprint_v3,v_plan_1,false);
  update public.material_processing_jobs set status='processing',
    budget_state='reserved',active_lease_token=gen_random_uuid(),
    active_lease_expires_at=now()+interval '5 minutes',updated_at=now()
  where id=v_current_job;
  update public.material_processing_jobs set status='completed',
    budget_state='consumed',completed_at=now(),active_lease_token=null,
    active_lease_expires_at=null,updated_at=now() where id=v_current_job;
  update public.materials set processing_status='ready',
    summary_payload=v_summary,summary_schema_version=1,
    summary_processing_mode='recommended',
    summary_validation_version='phase-c-validator-v3',
    summary_validation_hash=repeat('f',64)
  where id='31313131-3131-4131-8131-313131313134';
  perform pg_temp.assert_reliability(
    (select summary_payload is not null
      from public.get_material_analysis_status_v2(
        '31313131-3131-4131-8131-313131313134'))
      and exists(select 1 from public.load_study_generation_source_internal(
        '31313131-3131-4131-8131-313131313131',
        '31313131-3131-4131-8131-313131313134')),
    'trusted current v3 summary persists and remains study eligible');

  v_wrong_job:=public.prepare_material_analysis_internal(
    '31313131-3131-4131-8131-313131313135','recommended',true,1,
    repeat('a',64),v_contract_v3,v_fingerprint_v3,v_plan_1,false);
  v_work:=public.claim_next_material_analysis_operation_internal(
    '31313131-3131-4131-8131-313131313135');
  begin
    perform public.complete_material_processing_page_internal(
      v_wrong_job,1,(v_work->>'lease_token')::uuid,'completed',
      '{"page_number":1,"content_status":"completed","summary_markdown":"Safe page.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}'::jsonb,
      '[]'::jsonb,'phase-c-validator-v2',repeat('1',64));
    raise exception 'wrong validator was accepted';
  exception when others then
    if sqlerrm='wrong validator was accepted' then raise; end if;
  end;
  perform pg_temp.assert_reliability(
    (select status<>'completed' from public.material_processing_pages
      where job_id=v_wrong_job and page_number=1),
    'v3 work cannot complete under the v2 validator');
end
$$;

delete from public.materials
where user_id='31313131-3131-4131-8131-313131313131';
delete from auth.users
where id in (
  '31313131-3131-4131-8131-313131313131',
  '31313131-3131-4131-8131-313131313139');
