\set ON_ERROR_STOP on

create or replace function pg_temp.assert_analyze_again(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'analyze_again_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_analyze_again(
  pg_get_function_result(
    'public.get_material_analysis_status(uuid)'::regprocedure
  ) =
  'TABLE(material_id uuid, processing_mode text, state text, public_stage text, page_count integer, completed_pages integer, confirmation_required boolean, can_retry boolean, retry_after_seconds integer, warnings jsonb, summary_schema_version integer, summary_payload jsonb, safe_error_code text, active_operation text)',
  'v1 result contract remains byte-for-byte compatible');

select pg_temp.assert_analyze_again(
  to_regprocedure(
    'public.material_analysis_analyze_again_eligible(uuid,uuid)'
  ) is not null
    and not helper.prosecdef
    and helper.provolatile='s'
    and helper.proconfig=array['search_path=pg_catalog, public']
    and helper.proowner='postgres'::regrole,
  'durable-source helper is stable and trusted')
from pg_proc helper
where helper.oid=
  'public.material_analysis_analyze_again_eligible(uuid,uuid)'::regprocedure;

select pg_temp.assert_analyze_again(
  status_v2.prosecdef
    and status_v2.provolatile='s'
    and status_v2.proconfig=array['search_path=pg_catalog, public']
    and status_v2.proowner='postgres'::regrole
    and pg_get_function_result(status_v2.oid)=
      'TABLE(material_id uuid, processing_mode text, state text, public_stage text, page_count integer, completed_pages integer, confirmation_required boolean, can_retry boolean, can_analyze_again boolean, retry_after_seconds integer, warnings jsonb, summary_schema_version integer, summary_payload jsonb, safe_error_code text, active_operation text)',
  'v2 return and trusted execution contracts are exact')
from pg_proc status_v2
where status_v2.oid=
  'public.get_material_analysis_status_v2(uuid)'::regprocedure;

select pg_temp.assert_analyze_again(
  has_function_privilege(
    'authenticated','public.get_material_analysis_status_v2(uuid)','execute')
    and not has_function_privilege(
      'anon','public.get_material_analysis_status_v2(uuid)','execute')
    and not has_function_privilege(
      'service_role','public.get_material_analysis_status_v2(uuid)','execute')
    and has_function_privilege(
      'service_role',
      'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)',
      'execute')
    and not has_function_privilege(
      'authenticated',
      'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)',
      'execute')
    and not has_function_privilege(
      'authenticated',
      'public.material_analysis_analyze_again_eligible(uuid,uuid)',
      'execute')
    and not has_function_privilege(
      'service_role',
      'public.material_analysis_analyze_again_eligible(uuid,uuid)',
      'execute'),
  'status, preparation, and helper grants remain least privilege');

select pg_temp.assert_analyze_again(
  (
    select format_type(attribute.atttypid,attribute.atttypmod)='text'
    from pg_attribute attribute
    where attribute.attrelid='storage.objects'::regclass
      and attribute.attname='owner_id'
      and attribute.attnum>0
      and not attribute.attisdropped
  ),
  'storage owner fixture matches hosted text type');

insert into auth.users(id,email) values
  ('32323232-3232-4232-8232-323232323231','owner@example.test'),
  ('32323232-3232-4232-8232-323232323239','other@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata,cleanup_status,deleted_at
) values
  (
    '32323232-3232-4232-8232-323232323232',
    '32323232-3232-4232-8232-323232323231',
    'Cleanup pending','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323232/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323233',
    '32323232-3232-4232-8232-323232323231',
    'Uploaded','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323233/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323234',
    '32323232-3232-4232-8232-323232323231',
    'Cleaned','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323234/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323235',
    '32323232-3232-4232-8232-323232323231',
    'Missing source','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323235/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323236',
    '32323232-3232-4232-8232-323232323231',
    'Active generation','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323236/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323237',
    '32323232-3232-4232-8232-323232323231',
    'Active batch','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323237/source.pdf',
    'application/pdf',128,'failed','{}',null,null
  ),
  (
    '32323232-3232-4232-8232-323232323238',
    '32323232-3232-4232-8232-323232323231',
    'Source cleanup','pdf','upload','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323238/source.pdf',
    'application/pdf',128,'failed','{}','pending_storage',null
  );

insert into storage.objects(id,bucket_id,name,owner_id) values
  (
    '72727272-7272-4272-8272-727272727232','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323232/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  ),
  (
    '72727272-7272-4272-8272-727272727233','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323233/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  ),
  (
    '72727272-7272-4272-8272-727272727234','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323234/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  ),
  (
    '72727272-7272-4272-8272-727272727236','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323236/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  ),
  (
    '72727272-7272-4272-8272-727272727237','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323237/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  ),
  (
    '72727272-7272-4272-8272-727272727238','study-materials',
    '32323232-3232-4232-8232-323232323231/32323232-3232-4232-8232-323232323238/source.pdf',
    '32323232-3232-4232-8232-323232323231'
  );

do $$
declare
  v_contract jsonb;
  v_fingerprint text;
  v_plan_50 jsonb;
  v_new uuid;
  v_duplicate uuid;
  v_old_snapshot jsonb;
  v_artifact_snapshot jsonb;
  v_wrong_owner_count integer;
begin
  v_contract:=jsonb_build_object(
    'fingerprint_version','phase-c-fingerprint-v2',
    'source_content_hash',repeat('a',64),
    'source_metadata_hash',repeat('b',64),
    'processing_mode','recommended','page_count',50,
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
  select jsonb_agg(jsonb_build_object(
    'page_number',page_number,
    'route','text',
    'normalized_text','Sanitized grounded page.',
    'routing_signals',jsonb_build_object(
      'router_version','phase-c-router-v1'),
    'routing_confidence',0.9,
    'input_hash',repeat('c',64)
  ) order by page_number)
  into v_plan_50
  from generate_series(1,50) page_number;

  insert into public.material_processing_jobs(
    id,material_id,user_id,generation,page_count,status,public_stage,
    processing_mode,confirmation_required,domain_profile,router_version,
    schema_version,source_hash,version_contract,version_fingerprint,
    safe_error_code,completed_at
  ) values
    (
      '42424242-4242-4242-8242-424242424232',
      '32323232-3232-4232-8232-323232323232',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424233',
      '32323232-3232-4232-8232-323232323233',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424234',
      '32323232-3232-4232-8232-323232323234',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424235',
      '32323232-3232-4232-8232-323232323235',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424236',
      '32323232-3232-4232-8232-323232323236',
      '32323232-3232-4232-8232-323232323231',
      1,50,'prepared','preparing_document','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      null,null
    ),
    (
      '42424242-4242-4242-8242-424242424246',
      '32323232-3232-4232-8232-323232323236',
      '32323232-3232-4232-8232-323232323231',
      2,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424237',
      '32323232-3232-4232-8232-323232323237',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    ),
    (
      '42424242-4242-4242-8242-424242424238',
      '32323232-3232-4232-8232-323232323238',
      '32323232-3232-4232-8232-323232323231',
      1,50,'failed','recognizing_formulas_and_diagrams','recommended',true,
      'general','phase-c-router-v1',1,repeat('a',64),v_contract,v_fingerprint,
      'structured_output_invalid',now()
    );

  insert into public.material_processing_batches(
    id,job_id,material_id,user_id,operation,page_numbers,status,fingerprint,
    max_attempts,completed_at
  ) values
    (
      '52525252-5252-4252-8252-525252525232',
      '42424242-4242-4242-8242-424242424232',
      '32323232-3232-4232-8232-323232323232',
      '32323232-3232-4232-8232-323232323231',
      'page_visual',array[1],'failed',repeat('2',64),2,now()
    ),
    (
      '52525252-5252-4252-8252-525252525233',
      '42424242-4242-4242-8242-424242424233',
      '32323232-3232-4232-8232-323232323233',
      '32323232-3232-4232-8232-323232323231',
      'page_visual',array[1],'failed',repeat('3',64),2,now()
    ),
    (
      '52525252-5252-4252-8252-525252525234',
      '42424242-4242-4242-8242-424242424234',
      '32323232-3232-4232-8232-323232323234',
      '32323232-3232-4232-8232-323232323231',
      'page_visual',array[1],'failed',repeat('4',64),2,now()
    ),
    (
      '52525252-5252-4252-8252-525252525237',
      '42424242-4242-4242-8242-424242424237',
      '32323232-3232-4232-8232-323232323237',
      '32323232-3232-4232-8232-323232323231',
      'page_visual',array[1],'prepared',repeat('7',64),2,null
    );

  insert into public.material_processing_artifacts(
    id,batch_id,job_id,material_id,user_id,provider_filename,
    provider_file_id,state,uploaded_at,cleaned_at
  ) values
    (
      '62626262-6262-4262-8262-626262626232',
      '52525252-5252-4252-8252-525252525232',
      '42424242-4242-4242-8242-424242424232',
      '32323232-3232-4232-8232-323232323232',
      '32323232-3232-4232-8232-323232323231',
      'analysis-62626262-6262-4262-8262-626262626232.pdf',
      'file-cleanup-pending-0001','cleanup_pending',now(),null
    ),
    (
      '62626262-6262-4262-8262-626262626233',
      '52525252-5252-4252-8252-525252525233',
      '42424242-4242-4242-8242-424242424233',
      '32323232-3232-4232-8232-323232323233',
      '32323232-3232-4232-8232-323232323231',
      'analysis-62626262-6262-4262-8262-626262626233.pdf',
      'file-uploaded-0002','uploaded',now(),null
    ),
    (
      '62626262-6262-4262-8262-626262626234',
      '52525252-5252-4252-8252-525252525234',
      '42424242-4242-4242-8242-424242424234',
      '32323232-3232-4232-8232-323232323234',
      '32323232-3232-4232-8232-323232323231',
      'analysis-62626262-6262-4262-8262-626262626234.pdf',
      'file-cleaned-0003','cleaned',now(),now()
    );

  perform set_config(
    'request.jwt.claim.sub','32323232-3232-4232-8232-323232323231',false);
  perform pg_temp.assert_analyze_again(
    (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323232')),
    'matching text owner permits cleanup_pending provider artifact');
  perform pg_temp.assert_analyze_again(
    (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323233')),
    'uploaded provider artifact does not block');
  perform pg_temp.assert_analyze_again(
    (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323234')),
    'cleaned provider artifact does not block');
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323235')),
    'missing durable source blocks Analyze Again');
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323236')),
    'another active generation blocks Analyze Again');
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323237')),
    'a non-terminal batch blocks Analyze Again');
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323238')),
    'durable-source cleanup blocks Analyze Again');

  update storage.objects
  set owner_id='32323232-3232-4232-8232-323232323239'
  where id='72727272-7272-4272-8272-727272727232';
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323232')),
    'different text storage owner blocks Analyze Again');

  update storage.objects
  set owner_id='malformed-non-uuid-owner'
  where id='72727272-7272-4272-8272-727272727232';
  perform pg_temp.assert_analyze_again(
    not (select can_analyze_again
      from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323232')),
    'malformed text storage owner is rejected without a cast exception');

  update storage.objects
  set owner_id='32323232-3232-4232-8232-323232323231'
  where id='72727272-7272-4272-8272-727272727232';

  perform set_config(
    'request.jwt.claim.sub','32323232-3232-4232-8232-323232323239',false);
  select count(*) into v_wrong_owner_count
  from public.get_material_analysis_status_v2(
    '32323232-3232-4232-8232-323232323232');
  perform pg_temp.assert_analyze_again(
    v_wrong_owner_count=0,
    'wrong owner receives no status row');
  perform set_config(
    'request.jwt.claim.sub','32323232-3232-4232-8232-323232323231',false);

  select to_jsonb(j) into v_old_snapshot
  from public.material_processing_jobs j
  where j.id='42424242-4242-4242-8242-424242424232';
  select to_jsonb(a) into v_artifact_snapshot
  from public.material_processing_artifacts a
  where a.id='62626262-6262-4262-8262-626262626232';

  v_new:=public.prepare_material_analysis_internal(
    '32323232-3232-4232-8232-323232323232','recommended',false,50,
    repeat('a',64),v_contract,v_fingerprint,v_plan_50,true);
  v_duplicate:=public.prepare_material_analysis_internal(
    '32323232-3232-4232-8232-323232323232','recommended',false,50,
    repeat('a',64),v_contract,v_fingerprint,v_plan_50,true);

  perform pg_temp.assert_analyze_again(
    v_new=v_duplicate
      and v_new<>'42424242-4242-4242-8242-424242424232'
      and (select generation=2
        from public.material_processing_jobs where id=v_new)
      and (select count(*)=2
        from public.material_processing_jobs
        where material_id='32323232-3232-4232-8232-323232323232'),
    'double Analyze Again joins generation 2');
  perform pg_temp.assert_analyze_again(
    (select status='awaiting_confirmation'
        and confirmation_required
        and confirmation_authorized_at is null
        and source_hash=repeat('a',64)
      from public.material_processing_jobs where id=v_new)
      and not exists(
        select 1 from public.material_processing_batches where job_id=v_new)
      and not exists(
        select 1 from public.material_processing_attempts where job_id=v_new)
      and not exists(
        select 1 from public.material_processing_artifacts where job_id=v_new),
    '50-page generation 2 awaits confirmation with zero provider work');
  perform pg_temp.assert_analyze_again(
    (select to_jsonb(j)=v_old_snapshot
      from public.material_processing_jobs j
      where j.id='42424242-4242-4242-8242-424242424232')
      and (select to_jsonb(a)=v_artifact_snapshot
        from public.material_processing_artifacts a
        where a.id='62626262-6262-4262-8262-626262626232'),
    'generation 1 and its provider artifact remain immutable');

  update public.materials
  set deleted_at=now(),cleanup_status='pending_storage'
  where id='32323232-3232-4232-8232-323232323235';
  perform pg_temp.assert_analyze_again(
    not exists(
      select 1 from public.get_material_analysis_status_v2(
        '32323232-3232-4232-8232-323232323235')),
    'deleted durable source returns no status row');
end
$$;

delete from public.materials
where user_id='32323232-3232-4232-8232-323232323231';
delete from storage.objects
where owner_id='32323232-3232-4232-8232-323232323231';
delete from auth.users
where id in (
  '32323232-3232-4232-8232-323232323231',
  '32323232-3232-4232-8232-323232323239');
