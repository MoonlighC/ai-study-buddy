\set ON_ERROR_STOP on

create or replace function pg_temp.assert_page_contract(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'page_content_contract_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_page_contract(
  public.material_analysis_safe_warnings_v2('[{"code":"page_content_partial","detail":"Partial grounded content.","source_pages":[1]}]'::jsonb),
  'approved partial warning accepted'
);
select pg_temp.assert_page_contract(
  public.material_analysis_safe_warnings_v2('[{"code":"page_content_missing","detail":"No grounded content.","source_pages":[1]}]'::jsonb),
  'approved missing warning accepted'
);
select pg_temp.assert_page_contract(
  not public.material_analysis_safe_warnings_v2('[{"code":"invented_warning","detail":"Unknown.","source_pages":[1]}]'::jsonb),
  'invented warning rejected'
);
select pg_temp.assert_page_contract(
  not has_function_privilege('authenticated','public.material_analysis_safe_warnings_v2(jsonb)','execute')
    and not has_function_privilege('anon','public.material_analysis_safe_warnings_v2(jsonb)','execute')
    and not has_function_privilege('service_role','public.material_analysis_safe_warnings_v2(jsonb)','execute'),
  'warning validator is not remotely executable'
);
select pg_temp.assert_page_contract(
  has_function_privilege('service_role','public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)','execute')
    and not has_function_privilege('authenticated','public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)','execute'),
  'completion RPC remains service-role only'
);
select pg_temp.assert_page_contract(
  pg_get_functiondef('public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure)
    like '%v_status := v_page->>''content_status''%'
    and pg_get_functiondef('public.complete_material_analysis_operation_internal(uuid,uuid,jsonb,text,text,text,boolean)'::regprocedure)
      not like '%partial_extraction'',''uncertain_extraction%',
  'terminal status is explicit rather than inferred from warning strings'
);
