\set ON_ERROR_STOP on

create or replace function pg_temp.assert_role_portability(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'role_portability_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_role_portability(
  (select not rolsuper and rolcreaterole and not rolcreatedb and rolcanlogin and
      rolinherit and not rolreplication and not rolbypassrls
    from pg_catalog.pg_roles where rolname=current_user),
  'migration runs as a Supabase-like non-superuser CREATEROLE login'
);

select pg_temp.assert_role_portability(
  (select not rolcanlogin and not rolsuper and not rolcreatedb and
      not rolcreaterole and not rolinherit and not rolreplication and
      not rolbypassrls
    from pg_catalog.pg_roles where rolname='material_analysis_executor'),
  'executor has the exact safe attributes'
);

select pg_temp.assert_role_portability(
  not exists (
    select 1
    from pg_catalog.pg_auth_members membership
    join pg_catalog.pg_roles executor on executor.oid=membership.roleid
    where executor.rolname='material_analysis_executor'
  ),
  'executor has no members after migration success'
);

select pg_temp.assert_role_portability(
  not pg_catalog.has_schema_privilege(
    'material_analysis_executor','public','create'
  ),
  'executor retains no CREATE privilege on public after migration success'
);

with expected(signature) as (
  select unnest(array[
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text,integer,jsonb,text)'::regprocedure,
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text)'::regprocedure,
    'public.create_material_processing_batch_internal(uuid,text,integer[],text)'::regprocedure,
    'public.claim_material_processing_batch_internal(uuid,text)'::regprocedure,
    'public.mark_material_processing_batch_submitted_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_dispatch_unknown_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_response_known_internal(uuid,uuid,text)'::regprocedure,
    'public.complete_material_processing_page_internal(uuid,integer,uuid,text,jsonb,jsonb,text,text)'::regprocedure,
    'public.complete_material_processing_batch_internal(uuid,uuid,jsonb,text,text)'::regprocedure,
    'public.fail_material_processing_batch_internal(uuid,uuid,text)'::regprocedure,
    'public.recover_expired_material_processing_batch_internal(uuid)'::regprocedure,
    'public.request_material_processing_retry_internal(uuid,uuid)'::regprocedure,
    'public.finalize_material_processing_job_internal(uuid,uuid,jsonb,text,text,text)'::regprocedure,
    'public.load_material_analysis_source_internal(uuid,uuid)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb,text,jsonb)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb)'::regprocedure,
    'public.material_analysis_work_payload(uuid,uuid)'::regprocedure,
    'public.claim_next_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.submit_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.create_material_analysis_file_intent_internal(uuid,uuid)'::regprocedure,
    'public.record_material_analysis_file_uploaded_internal(uuid,uuid,text)'::regprocedure,
    'public.record_material_analysis_file_recovery_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.record_material_analysis_response_internal(uuid,uuid,text,text)'::regprocedure,
    'public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure,
    'public.fail_material_analysis_operation_internal(uuid,uuid,text,integer,text,boolean)'::regprocedure,
    'public.complete_material_analysis_cleanup_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.confirm_material_analysis(uuid)'::regprocedure,
    'public.authorize_material_analysis_retry(uuid)'::regprocedure,
    'public.get_material_analysis_status(uuid)'::regprocedure
  ])
), actual(signature) as (
  select procedure.oid::regprocedure
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_roles owner on owner.oid=procedure.proowner
  where owner.rolname='material_analysis_executor'
)
select pg_temp.assert_role_portability(
  (select count(*)=29 from expected) and
  not exists(select signature from expected except select signature from actual) and
  not exists(select signature from actual except select signature from expected),
  'executor owns exactly the 26 internal and three public Phase C functions'
);

with internal(signature) as (
  select unnest(array[
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text,integer,jsonb,text)'::regprocedure,
    'public.create_material_processing_job_internal(uuid,text,boolean,integer,text)'::regprocedure,
    'public.create_material_processing_batch_internal(uuid,text,integer[],text)'::regprocedure,
    'public.claim_material_processing_batch_internal(uuid,text)'::regprocedure,
    'public.mark_material_processing_batch_submitted_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_dispatch_unknown_internal(uuid,uuid)'::regprocedure,
    'public.mark_material_processing_response_known_internal(uuid,uuid,text)'::regprocedure,
    'public.complete_material_processing_page_internal(uuid,integer,uuid,text,jsonb,jsonb,text,text)'::regprocedure,
    'public.complete_material_processing_batch_internal(uuid,uuid,jsonb,text,text)'::regprocedure,
    'public.fail_material_processing_batch_internal(uuid,uuid,text)'::regprocedure,
    'public.recover_expired_material_processing_batch_internal(uuid)'::regprocedure,
    'public.request_material_processing_retry_internal(uuid,uuid)'::regprocedure,
    'public.finalize_material_processing_job_internal(uuid,uuid,jsonb,text,text,text)'::regprocedure,
    'public.load_material_analysis_source_internal(uuid,uuid)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb,text,jsonb)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,uuid,text,boolean,integer,text,jsonb)'::regprocedure,
    'public.material_analysis_work_payload(uuid,uuid)'::regprocedure,
    'public.claim_next_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.submit_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.create_material_analysis_file_intent_internal(uuid,uuid)'::regprocedure,
    'public.record_material_analysis_file_uploaded_internal(uuid,uuid,text)'::regprocedure,
    'public.record_material_analysis_file_recovery_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.record_material_analysis_response_internal(uuid,uuid,text,text)'::regprocedure,
    'public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure,
    'public.fail_material_analysis_operation_internal(uuid,uuid,text,integer,text,boolean)'::regprocedure,
    'public.complete_material_analysis_cleanup_internal(uuid,uuid,text,boolean)'::regprocedure
  ])
)
select pg_temp.assert_role_portability(
  not exists (
    select 1 from internal
    where not pg_catalog.has_function_privilege('service_role',signature,'execute')
      or pg_catalog.has_function_privilege('authenticated',signature,'execute')
      or pg_catalog.has_function_privilege('anon',signature,'execute')
  ),
  'only service_role can execute every internal Phase C function'
);

with public_rpc(signature) as (
  select unnest(array[
    'public.confirm_material_analysis(uuid)'::regprocedure,
    'public.authorize_material_analysis_retry(uuid)'::regprocedure,
    'public.get_material_analysis_status(uuid)'::regprocedure
  ])
)
select pg_temp.assert_role_portability(
  not exists (
    select 1 from public_rpc
    where not pg_catalog.has_function_privilege('authenticated',signature,'execute')
      or pg_catalog.has_function_privilege('service_role',signature,'execute')
      or pg_catalog.has_function_privilege('anon',signature,'execute')
  ) and not exists (
    select 1
    from public_rpc
    join pg_catalog.pg_proc procedure on procedure.oid=public_rpc.signature
    cross join lateral pg_catalog.aclexplode(
      coalesce(procedure.proacl,pg_catalog.acldefault('f',procedure.proowner))
    ) privilege
    where privilege.grantee=0 and privilege.privilege_type='EXECUTE'
  ),
  'authenticated alone receives the three public RPC grants and PUBLIC receives none'
);

select 'PHASE_C_ROLE_PORTABILITY_OK' as result;
