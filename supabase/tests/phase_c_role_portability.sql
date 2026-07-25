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
  current_user='postgres' and (select not rolsuper and rolcreaterole and
      rolcreatedb and rolcanlogin and rolinherit and rolreplication and rolbypassrls
    from pg_catalog.pg_roles where rolname=current_user),
  'migration runs as the expected Supabase-like managed postgres role'
);

select pg_temp.assert_role_portability(
  not exists(select 1 from pg_catalog.pg_roles where rolname='material_analysis_executor'),
  'migration creates no custom Phase C role'
);

with phase_c_table(relation) as (
  select unnest(array[
    'public.material_processing_jobs'::regclass,
    'public.material_processing_batches'::regclass,
    'public.material_processing_artifacts'::regclass,
    'public.material_processing_attempts'::regclass,
    'public.material_processing_pages'::regclass,
    'public.material_processing_retry_authorizations'::regclass
  ])
)
select pg_temp.assert_role_portability(
  not exists (
    select 1 from phase_c_table
    join pg_catalog.pg_class relation on relation.oid=phase_c_table.relation
    where not relation.relrowsecurity or not relation.relforcerowsecurity
      or pg_catalog.has_table_privilege('anon',phase_c_table.relation,'select,insert,update,delete')
      or pg_catalog.has_table_privilege('authenticated',phase_c_table.relation,'select,insert,update,delete')
      or pg_catalog.has_table_privilege('service_role',phase_c_table.relation,'select,insert,update,delete')
      or exists (
        select 1
        from pg_catalog.aclexplode(
          coalesce(relation.relacl,pg_catalog.acldefault('r',relation.relowner))
        ) privilege
        where privilege.grantee=0
          and privilege.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
      )
  ),
  'all six current tables keep RLS and FORCE RLS with no direct API-role or PUBLIC DML'
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
    'public.load_material_analysis_source_internal(uuid)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb)'::regprocedure,
    'public.material_analysis_work_payload(uuid,uuid)'::regprocedure,
    'public.claim_next_material_analysis_operation_internal(uuid)'::regprocedure,
    'public.submit_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.create_material_analysis_file_intent_internal(uuid,uuid)'::regprocedure,
    'public.record_material_analysis_file_uploaded_internal(uuid,uuid,text)'::regprocedure,
    'public.record_material_analysis_file_recovery_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.record_material_analysis_response_internal(uuid,uuid,text,text)'::regprocedure,
    'public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure,
    'public.fail_material_analysis_operation_internal(uuid,uuid,text,integer,text,boolean)'::regprocedure,
    'public.complete_material_analysis_cleanup_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.load_material_analysis_diagnostic_target_internal(uuid)'::regprocedure,
    'public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)'::regprocedure,
    'public.terminalize_material_analysis_operation_internal(uuid,uuid,text)'::regprocedure,
    'public.confirm_material_analysis(uuid)'::regprocedure,
    'public.authorize_material_analysis_retry(uuid)'::regprocedure,
    'public.get_material_analysis_status(uuid)'::regprocedure,
    'public.get_material_analysis_status_v2(uuid)'::regprocedure
  ])
), actual(signature) as (
  select procedure.oid::regprocedure
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_roles owner on owner.oid=procedure.proowner
  where owner.rolname='postgres' and procedure.prosecdef
    and procedure.oid::regprocedure in (select signature from expected)
)
select pg_temp.assert_role_portability(
  (select count(*)=34 from expected) and
  not exists(select signature from expected except select signature from actual) and
  not exists(select signature from actual except select signature from expected),
  'postgres owns exactly the 30 internal and four public Phase C definers'
);

with phase_c_helper(signature) as (
  select unnest(array[
    'public.material_analysis_safe_warnings(jsonb)'::regprocedure,
    'public.material_analysis_valid_page_payload(jsonb)'::regprocedure,
    'public.material_analysis_valid_summary_payload(jsonb)'::regprocedure,
    'public.material_analysis_valid_batch_payload(jsonb,text)'::regprocedure,
    'public.material_analysis_valid_page_numbers(integer[])'::regprocedure,
    'public.material_analysis_version_fingerprint(jsonb)'::regprocedure,
    'public.material_analysis_valid_diagnostic_metadata(jsonb)'::regprocedure,
    'public.enforce_material_processing_job_row()'::regprocedure,
    'public.enforce_material_processing_page_row()'::regprocedure,
    'public.enforce_material_processing_batch_row()'::regprocedure,
    'public.enforce_material_processing_attempt_row()'::regprocedure,
    'public.refresh_material_processing_progress()'::regprocedure,
    'public.reject_material_processing_status_self_transition()'::regprocedure
  ])
)
select pg_temp.assert_role_portability(
  not exists (
    select 1 from phase_c_helper
    join pg_catalog.pg_proc procedure on procedure.oid=phase_c_helper.signature
    where pg_catalog.pg_get_userbyid(procedure.proowner)<>'postgres'
      or pg_catalog.has_function_privilege('anon',phase_c_helper.signature,'execute')
      or pg_catalog.has_function_privilege('authenticated',phase_c_helper.signature,'execute')
      or pg_catalog.has_function_privilege('service_role',phase_c_helper.signature,'execute')
      or exists (
        select 1
        from pg_catalog.aclexplode(
          coalesce(procedure.proacl,pg_catalog.acldefault('f',procedure.proowner))
        ) privilege
        where privilege.grantee=0 and privilege.privilege_type='EXECUTE'
      )
  ),
  'postgres owns all thirteen helpers and no API role can execute them directly'
);

with phase_c_definer as (
  select procedure.*
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
  where namespace.nspname='public' and procedure.prosecdef
    and (procedure.proname like '%material_processing%'
      or procedure.proname like '%material_analysis%')
)
select pg_temp.assert_role_portability(
  (select count(*)=34 from phase_c_definer)
  and not exists (
    select 1 from phase_c_definer
    where pg_catalog.pg_get_userbyid(proowner)<>'postgres'
      or not coalesce(proconfig,'{}'::text[]) @> array['search_path=pg_catalog, public']
      or 'p_user_id'=any(coalesce(proargnames,'{}'::text[]))
  ),
  'every Phase C definer has postgres ownership, fixed search_path, and no authoritative user ID parameter'
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
    'public.load_material_analysis_source_internal(uuid)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb,boolean)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb,text,jsonb)'::regprocedure,
    'public.prepare_material_analysis_internal(uuid,text,boolean,integer,text,jsonb)'::regprocedure,
    'public.material_analysis_work_payload(uuid,uuid)'::regprocedure,
    'public.claim_next_material_analysis_operation_internal(uuid)'::regprocedure,
    'public.submit_material_analysis_operation_internal(uuid,uuid)'::regprocedure,
    'public.create_material_analysis_file_intent_internal(uuid,uuid)'::regprocedure,
    'public.record_material_analysis_file_uploaded_internal(uuid,uuid,text)'::regprocedure,
    'public.record_material_analysis_file_recovery_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.record_material_analysis_response_internal(uuid,uuid,text,text)'::regprocedure,
    'public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure,
    'public.fail_material_analysis_operation_internal(uuid,uuid,text,integer,text,boolean)'::regprocedure,
    'public.complete_material_analysis_cleanup_internal(uuid,uuid,text,boolean)'::regprocedure,
    'public.load_material_analysis_diagnostic_target_internal(uuid)'::regprocedure,
    'public.record_material_analysis_diagnostic_internal(uuid,text,jsonb,integer)'::regprocedure,
    'public.terminalize_material_analysis_operation_internal(uuid,uuid,text)'::regprocedure
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
    'public.get_material_analysis_status(uuid)'::regprocedure,
    'public.get_material_analysis_status_v2(uuid)'::regprocedure
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
  'authenticated alone receives the four public RPC grants and PUBLIC receives none'
);

select 'PHASE_C_ROLE_PORTABILITY_OK' as result;
