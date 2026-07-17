\set ON_ERROR_STOP on

create or replace function pg_temp.assert_true(value boolean, message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'assertion_failed: %', message; end if;
end
$$;

create or replace function pg_temp.expect_invalid_batch_payload(p_batch uuid,p_lease uuid)
returns void language plpgsql as $$
begin
  begin
    perform public.complete_material_processing_batch_internal(
      p_batch,p_lease,'{}'::jsonb,'phase-c-validator-v2',repeat('2',64));
    raise exception 'malformed batch unexpectedly accepted';
  exception when others then
    if sqlerrm not like '%invalid_result%' then raise; end if;
  end;
end
$$;

create or replace function pg_temp.expect_incomplete_manifest(p_job uuid,p_lease uuid)
returns void language plpgsql as $$
begin
  begin
    perform public.finalize_material_processing_job_internal(
      p_job,p_lease,
      '{"language":"en","sections":[{}],"key_concepts":[],"equations":[],"warnings":[],"partial_extraction":{}}'::jsonb,
      'Safe summary.','phase-c-validator-v2',repeat('7',64));
    raise exception 'incomplete manifest unexpectedly finalized';
  exception when others then
    if sqlerrm not like '%page_manifest_incomplete%' then raise; end if;
  end;
end
$$;

create or replace function pg_temp.statement_is_denied(statement text)
returns boolean language plpgsql as $$
begin
  execute statement;
  return false;
exception when others then
  return true;
end
$$;

select pg_temp.assert_true(
  (select count(*) = 5 from pg_catalog.pg_class
    where relnamespace='public'::regnamespace and relname in (
      'material_processing_jobs','material_processing_pages','material_processing_batches',
      'material_processing_attempts','material_processing_retry_authorizations'
    )),
  'processing table inventory'
);
select pg_temp.assert_true(
  (select count(*) >= 75 from information_schema.columns
    where table_schema='public' and table_name like 'material_processing_%') and
  (select count(*) >= 25 from information_schema.table_constraints
    where table_schema='public' and table_name like 'material_processing_%') and
  (select count(*) >= 5 from pg_catalog.pg_trigger trigger
    join pg_catalog.pg_class relation on relation.oid=trigger.tgrelid
    where relation.relnamespace='public'::regnamespace
      and relation.relname like 'material_processing_%' and not trigger.tgisinternal) and
  (select count(*) >= 8 from pg_catalog.pg_indexes
    where schemaname='public' and tablename like 'material_processing_%'),
  'columns constraints triggers and indexes exist'
);
select pg_temp.assert_true(
  pg_catalog.pg_get_function_result(
    'public.get_material_analysis_status(uuid)'::regprocedure
  ) like 'TABLE(material_id uuid, processing_mode text, state text,%',
  'public status return type'
);
select pg_temp.assert_true(
  not exists (
    select 1 from pg_catalog.pg_class where relnamespace='public'::regnamespace
      and relname like 'material_processing_%' and relkind='r'
      and (not relrowsecurity or not relforcerowsecurity)
  ),
  'RLS and FORCE RLS enabled'
);
select pg_temp.assert_true(
  not exists (
    select 1 from pg_catalog.pg_roles
    where rolname='material_analysis_executor'
  ),
  'no custom Phase C executor role exists'
);
select pg_temp.assert_true(
  not exists (
    select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef and (
      p.proname like '%material_processing%' or p.proname in (
        'confirm_material_analysis','authorize_material_analysis_retry','get_material_analysis_status'
      )
    ) and pg_catalog.pg_get_userbyid(p.proowner) <> 'postgres'
  ),
  'all Phase C definers have the explicit managed postgres owner'
);
select pg_temp.assert_true(
  not pg_catalog.has_table_privilege('anon','public.material_processing_jobs','select') and
  not pg_catalog.has_table_privilege('authenticated','public.material_processing_jobs','select') and
  not pg_catalog.has_table_privilege('service_role','public.material_processing_jobs','select') and
  not pg_catalog.has_table_privilege('service_role','public.material_processing_jobs','insert,update,delete'),
  'no direct processing-table authority'
);
select pg_temp.assert_true(
  pg_catalog.has_function_privilege('service_role',
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text)','execute') and
  not pg_catalog.has_function_privilege('authenticated',
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text)','execute') and
  pg_catalog.has_function_privilege('authenticated',
    'public.get_material_analysis_status(uuid)','execute'),
  'exact RPC grants'
);

insert into auth.users(id,email) values
  ('11111111-1111-1111-1111-111111111111','owner1@example.test'),
  ('22222222-2222-2222-2222-222222222222','owner2@example.test'),
  ('33333333-3333-3333-3333-333333333333','cascade@example.test');
insert into public.subjects(id,user_id,name) values
  ('31111111-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111','Deletion fixture');
insert into public.materials(id,user_id,subject_id,title,kind) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','11111111-1111-1111-1111-111111111111',null,'Concurrent one','pdf'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2','11111111-1111-1111-1111-111111111111',null,'Concurrent two','pdf'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3','11111111-1111-1111-1111-111111111111',null,'Concurrent three','pdf'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','22222222-2222-2222-2222-222222222222',null,'Other owner','pdf'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','22222222-2222-2222-2222-222222222222',null,'Other owner two','pdf'),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1','11111111-1111-1111-1111-111111111111','31111111-1111-1111-1111-111111111111','Subject cascade','pdf'),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1','33333333-3333-3333-3333-333333333333',null,'Account cascade','pdf'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1','11111111-1111-1111-1111-111111111111',null,'Exact finalization','pdf'),
  ('99999999-9999-9999-9999-999999999991','11111111-1111-1111-1111-111111111111',null,'Incomplete manifest','pdf'),
  ('abababab-abab-4bab-8bab-ababababab01','11111111-1111-1111-1111-111111111111',null,'Confirmation fixture','pdf'),
  ('ffffffff-ffff-ffff-ffff-fffffffffff1','11111111-1111-1111-1111-111111111111',null,'Material cascade','pdf');

set role service_role;
select public.create_material_processing_job_internal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','recommended',false,1,'general') as job_a1 \gset
select public.create_material_processing_job_internal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2','recommended',false,1,'general') as job_a2 \gset
select public.create_material_processing_job_internal('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3','recommended',false,1,'general') as job_a3 \gset
select public.create_material_processing_job_internal('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','recommended',false,1,'general') as job_b1 \gset
select public.create_material_processing_job_internal('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','recommended',false,1,'general') as job_b2 \gset
select public.create_material_processing_job_internal('cccccccc-cccc-cccc-cccc-ccccccccccc1','recommended',false,1,'general') as job_c1 \gset
select public.create_material_processing_job_internal('dddddddd-dddd-dddd-dddd-ddddddddddd1','recommended',false,1,'general') as job_d1 \gset
select public.create_material_processing_job_internal('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1','recommended',false,1,'general') as job_e1 \gset
select public.create_material_processing_job_internal('99999999-9999-9999-9999-999999999991','recommended',false,3,'general') as job_g1 \gset
select public.create_material_processing_job_internal('abababab-abab-4bab-8bab-ababababab01','recommended',false,21,'general') as job_confirm \gset
select public.create_material_processing_job_internal('ffffffff-ffff-ffff-ffff-fffffffffff1','recommended',false,1,'general') as job_f1 \gset
select public.create_material_processing_batch_internal(
  :'job_a1',
  'page_text',array[1],repeat('a',64));
select public.create_material_processing_batch_internal(
  :'job_a2',
  'page_text',array[1],repeat('b',64));
select public.create_material_processing_batch_internal(
  :'job_a3',
  'page_text',array[1],repeat('c',64));
select public.create_material_processing_batch_internal(
  :'job_b1',
  'page_text',array[1],repeat('d',64));
select public.create_material_processing_batch_internal(
  :'job_b2',
  'page_text',array[1],repeat('8',64));
reset role;

set role service_role;
select 1 / case when pg_temp.statement_is_denied(
  $sql$update public.material_processing_jobs set updated_at=now()
    where id='00000000-0000-0000-0000-000000000000'$sql$
) then 1 else 0 end;
reset role;

select pg_temp.assert_true(
  not exists (
    select 1 from public.material_processing_jobs job
    where (select count(*) from public.material_processing_pages page where page.job_id=job.id) <> job.page_count
      or (select min(page_number) from public.material_processing_pages page where page.job_id=job.id) <> 1
      or (select max(page_number) from public.material_processing_pages page where page.job_id=job.id) <> job.page_count
  ),
  'trusted manifest is exactly 1..page_count'
);

delete from public.material_processing_pages where job_id=:'job_g1' and page_number=1;
select gen_random_uuid() as incomplete_lease_token \gset
update public.material_processing_jobs set status='processing',budget_state='reserved',
  active_lease_token=:'incomplete_lease_token',
  active_lease_expires_at=now()+interval '2 minutes' where id=:'job_g1';
select pg_temp.expect_incomplete_manifest(
  :'job_g1',:'incomplete_lease_token');
update public.material_processing_jobs set status='prepared',active_lease_token=null,
  active_lease_expires_at=null where id=:'job_g1';

-- Exercise the full one-page canonical completion path, including lease proof,
-- malformed batch rejection, derived progress, and exact finalization.
set role service_role;
select public.create_material_processing_batch_internal(
  :'job_e1','page_text',array[1],repeat('e',64)) as page_batch_e1 \gset
select * from public.claim_material_processing_batch_internal(:'job_e1','page_text') \gset page_claim_
select public.mark_material_processing_batch_submitted_internal(
  :'page_claim_batch_id',:'page_claim_lease_token');
select public.mark_material_processing_response_known_internal(
  :'page_claim_batch_id',:'page_claim_lease_token','response_page_e1');
select public.complete_material_processing_page_internal(
  :'job_e1',1,:'page_claim_lease_token','completed',
  '{"page_number":1,"summary_markdown":"Safe page.","key_concepts":[],"equations":[],"confidence":0.9,"warnings":[],"trustworthy":true}'::jsonb,
  '[]'::jsonb,'phase-c-validator-v2',repeat('1',64));
select pg_temp.expect_invalid_batch_payload(:'page_claim_batch_id',:'page_claim_lease_token');
select public.complete_material_processing_batch_internal(
  :'page_claim_batch_id',:'page_claim_lease_token',
  '{"schema_version":1,"operation":"page_text","content":{"pages":[1]}}'::jsonb,
  'phase-c-validator-v2',repeat('2',64));
select public.create_material_processing_batch_internal(
  :'job_e1','final_summary',array[1],repeat('9',64)) as summary_batch_e1 \gset
select * from public.claim_material_processing_batch_internal(:'job_e1','final_summary') \gset summary_claim_
select public.mark_material_processing_batch_submitted_internal(
  :'summary_claim_batch_id',:'summary_claim_lease_token');
select public.mark_material_processing_response_known_internal(
  :'summary_claim_batch_id',:'summary_claim_lease_token','response_summary_e1');
select public.finalize_material_processing_job_internal(
  :'job_e1',:'summary_claim_lease_token',
  '{"language":"en","sections":[{"id":"overview","title":"Overview","blocks":[{"kind":"prose","markdown":"Safe summary.","display":"block"}],"source_pages":[1],"confidence":0.9}],"key_concepts":[],"equations":[],"warnings":[],"partial_extraction":{"is_partial":false,"analyzed_pages":[1],"partial_pages":[],"missing_pages":[],"page_modes":[{"page":1,"mode":"text"}]}}'::jsonb,
  'Safe summary.','phase-c-validator-v2',repeat('3',64));
reset role;
select pg_temp.assert_true(
  (select status='completed' and completed_page_count=1 from public.material_processing_jobs where id=:'job_e1') and
  (select summary_schema_version=1 and summary_validation_version='phase-c-validator-v2'
    from public.materials where id='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1') and
  (select status='completed' from public.material_processing_batches where id=:'summary_claim_batch_id'),
  'exact manifest finalizes canonical result'
);

select pg_catalog.set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
set role authenticated;
select 1 / case when count(*)=1 then 1 else 0 end
from public.get_material_analysis_status('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
select 1 / case when count(*)=0 then 1 else 0 end
from public.get_material_analysis_status('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');
select 1 / case when pg_temp.statement_is_denied(
  $sql$select public.confirm_material_analysis('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1')$sql$
) then 1 else 0 end;
select public.confirm_material_analysis('abababab-abab-4bab-8bab-ababababab01');
reset role;

select pg_catalog.set_config('request.jwt.claim.sub','',false);
set role authenticated;
select 1 / case when count(*)=0 then 1 else 0 end
from public.get_material_analysis_status('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
select 1 / case when pg_temp.statement_is_denied(
  $sql$select public.confirm_material_analysis('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1')$sql$
) then 1 else 0 end;
select 1 / case when pg_temp.statement_is_denied(
  $sql$select public.authorize_material_analysis_retry('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1')$sql$
) then 1 else 0 end;
reset role;
select pg_catalog.set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);

select pg_temp.assert_true(
  (select status='prepared' and confirmation_authorized_at is not null
    from public.material_processing_jobs where id=:'job_confirm'),
  'owner confirmation succeeds while cross-user and null-user calls are non-revealing'
);

-- Malformed canonical payloads fail before any persistence.
do $$
begin
  if public.material_analysis_valid_page_payload('{}'::jsonb) then raise exception 'malformed page accepted'; end if;
  if public.material_analysis_valid_summary_payload('{}'::jsonb) then raise exception 'malformed summary accepted'; end if;
  if public.material_analysis_safe_warnings('[{"code":"x","detail":"","source_pages":[]}]'::jsonb)
    then raise exception 'malformed warning accepted'; end if;
end
$$;

-- Direct out-of-range manifest rows and completed-count drift are rejected by
-- executable triggers even for the migration owner.
do $$
declare target public.material_processing_jobs%rowtype;
begin
  select * into target from public.material_processing_jobs
    where material_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  begin
    insert into public.material_processing_pages(job_id,material_id,user_id,page_number)
    values(target.id,target.material_id,target.user_id,2);
    raise exception 'extra page unexpectedly accepted';
  exception when others then
    if sqlerrm not like '%page_outside_manifest%' then raise; end if;
  end;
  begin
    update public.material_processing_jobs set completed_page_count=1 where id=target.id;
    raise exception 'progress drift unexpectedly accepted';
  exception when others then
    if sqlerrm not like '%completed_page_count_drift%' then raise; end if;
  end;
end
$$;

-- Material cascade includes jobs, pages, batches, attempts and retry records.
set role service_role;
select public.create_material_processing_batch_internal(
  :'job_f1',
  'page_text',array[1],repeat('f',64));
reset role;
delete from public.materials where id='ffffffff-ffff-ffff-ffff-fffffffffff1';
select pg_temp.assert_true(
  not exists(select 1 from public.material_processing_jobs where material_id='ffffffff-ffff-ffff-ffff-fffffffffff1') and
  not exists(select 1 from public.material_processing_pages where material_id='ffffffff-ffff-ffff-ffff-fffffffffff1') and
  not exists(select 1 from public.material_processing_batches where material_id='ffffffff-ffff-ffff-ffff-fffffffffff1'),
  'material processing cascade'
);

-- Existing trusted subject deletion still cascades the Phase C rows.
set role service_role;
select * from public.begin_subject_deletion_internal(
  '11111111-1111-1111-1111-111111111111','31111111-1111-1111-1111-111111111111');
select public.mark_subject_deletion_internal(
  '11111111-1111-1111-1111-111111111111','31111111-1111-1111-1111-111111111111',
  'storage_verified',null,0,0);
select public.finalize_subject_deletion_internal(
  '11111111-1111-1111-1111-111111111111','31111111-1111-1111-1111-111111111111');
reset role;
select pg_temp.assert_true(
  not exists(select 1 from public.materials where id='cccccccc-cccc-cccc-cccc-ccccccccccc1') and
  not exists(select 1 from public.material_processing_jobs where material_id='cccccccc-cccc-cccc-cccc-ccccccccccc1'),
  'subject deletion cascade remains trusted'
);

-- Auth deletion continues through materials into every Phase C table.
delete from auth.users where id='33333333-3333-3333-3333-333333333333';
select pg_temp.assert_true(
  not exists(select 1 from public.materials where id='dddddddd-dddd-dddd-dddd-ddddddddddd1') and
  not exists(select 1 from public.material_processing_jobs where material_id='dddddddd-dddd-dddd-dddd-ddddddddddd1'),
  'account deletion cascade'
);

select 'PHASE_C1_SQL_ASSERTIONS_OK' as result;
