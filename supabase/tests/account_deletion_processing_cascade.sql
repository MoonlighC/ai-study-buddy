\set ON_ERROR_STOP on

create or replace function pg_temp.assert_account_cascade(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'account_deletion_cascade_assertion_failed: %', message;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_roles where rolname = 'account_deletion_cascade_test'
  ) then
    create role account_deletion_cascade_test nologin;
  end if;
end
$$;

grant account_deletion_cascade_test to postgres;
grant usage on schema auth to account_deletion_cascade_test;
grant delete on table auth.users to account_deletion_cascade_test;
grant select(id) on table auth.users to account_deletion_cascade_test;

insert into auth.users(id,email) values
  ('19191919-1919-4919-8919-191919191919','account-cascade@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '19191919-1919-4919-8919-191919191901',
  '19191919-1919-4919-8919-191919191919',
  'Account cascade fixture','pdf','upload','study-materials',
  '19191919-1919-4919-8919-191919191919/19191919-1919-4919-8919-191919191901/source.pdf',
  'application/pdf',128,'pending','{}'
);

select public.prepare_material_analysis_internal(
  '19191919-1919-4919-8919-191919191901',
  'recommended',false,1,repeat('a',64),
  '[{"page_number":1,"route":"text","normalized_text":"Readable page.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
) as account_cascade_job \gset

set role account_deletion_cascade_test;
delete from auth.users
where id = '19191919-1919-4919-8919-191919191919';
reset role;

select pg_temp.assert_account_cascade(
  not exists (
    select 1 from auth.users
    where id = '19191919-1919-4919-8919-191919191919'
  ),
  'Auth user deletion succeeds under a role with no processing-table access'
);
select pg_temp.assert_account_cascade(
  not exists (
    select 1 from public.materials
    where id = '19191919-1919-4919-8919-191919191901'
  ),
  'material cascades with the Auth user'
);
select pg_temp.assert_account_cascade(
  not exists (
    select 1 from public.material_processing_jobs
    where id = :'account_cascade_job'
  ),
  'processing job and dependent pages cascade without direct table grants'
);
select pg_temp.assert_account_cascade(
  not has_table_privilege(
    'account_deletion_cascade_test',
    'public.material_processing_jobs',
    'select,insert,update,delete'
  ),
  'regression does not grant processing-table authority to the Auth role'
);

revoke delete on table auth.users from account_deletion_cascade_test;
revoke select(id) on table auth.users from account_deletion_cascade_test;
revoke usage on schema auth from account_deletion_cascade_test;
revoke account_deletion_cascade_test from postgres;
drop role account_deletion_cascade_test;
