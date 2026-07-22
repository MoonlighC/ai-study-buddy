\set ON_ERROR_STOP on

create or replace function pg_temp.assert_study_generation(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'study_generation_assertion_failed: %',message; end if;
end
$$;

do $$
declare v_proc record; v_signature text;
begin
  select p.proowner,p.prosecdef,p.provolatile,p.proconfig into v_proc from pg_proc p
    where p.oid='public.load_study_generation_source_internal(uuid,uuid)'::regprocedure;
  perform pg_temp.assert_study_generation(v_proc.proowner='postgres'::regrole and
    v_proc.prosecdef and v_proc.provolatile='s' and
    v_proc.proconfig=array['search_path=pg_catalog, public']::text[],
    'canonical selector is stable, owned, and fixed-search-path');
  perform pg_temp.assert_study_generation(
    has_function_privilege('service_role','public.load_study_generation_source_internal(uuid,uuid)','execute') and
    not has_function_privilege('anon','public.load_study_generation_source_internal(uuid,uuid)','execute') and
    not has_function_privilege('authenticated','public.load_study_generation_source_internal(uuid,uuid)','execute'),
    'canonical selector is service-only');
  perform pg_temp.assert_study_generation(
    not has_table_privilege('anon','public.study_generation_operations','select') and
    not has_table_privilege('authenticated','public.study_generation_operations','select'),
    'operation ledger is not client-readable');

  foreach v_signature in array array[
    'public.reserve_study_generation_internal(uuid,uuid,uuid,text,text,integer,numeric,text)',
    'public.claim_study_generation_provider_internal(uuid,uuid)',
    'public.get_study_generation_operation_internal(uuid,uuid)',
    'public.complete_flashcard_generation_internal(uuid,uuid,uuid,jsonb,text,integer,integer,numeric)',
    'public.fail_study_generation_internal(uuid,uuid,text,boolean)'
  ] loop
    select p.proowner,p.prosecdef,p.proconfig into v_proc from pg_proc p
      where p.oid=v_signature::regprocedure;
    perform pg_temp.assert_study_generation(v_proc.proowner='postgres'::regrole and
      v_proc.prosecdef and
      v_proc.proconfig=array['search_path=pg_catalog, public']::text[],
      v_signature || ' is owned and fixed-search-path');
    perform pg_temp.assert_study_generation(
      has_function_privilege('service_role',v_signature,'execute') and
      not has_function_privilege('anon',v_signature,'execute') and
      not has_function_privilege('authenticated',v_signature,'execute'),
      v_signature || ' is service-only');
  end loop;
end
$$;

insert into auth.users(id,email) values
('25252525-2525-4525-8525-252525252525','study-generation@example.test');
insert into public.subjects(id,user_id,name,color_value)
values('25252525-2525-4525-8525-252525252501','25252525-2525-4525-8525-252525252525','Study source',1);
insert into public.materials(id,user_id,subject_id,title,kind,source_kind,content_text,processing_status)
values('25252525-2525-4525-8525-252525252502','25252525-2525-4525-8525-252525252525',
  '25252525-2525-4525-8525-252525252501','Text source','pasted_text','manual',
  'Authoritative source text with enough detail for a deterministic generation test.','ready'),
('25252525-2525-4525-8525-252525252506','25252525-2525-4525-8525-252525252525',
  '25252525-2525-4525-8525-252525252501','Other text source','pasted_text','manual',
  'A second authoritative source used only to prove operation conflicts.','ready');

do $$
declare v_new boolean; v_status text; v_ids uuid[]; v_claim boolean; v_count integer;
begin
  select * into v_new,v_status,v_ids from public.reserve_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
    '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('a',64),5,0.03,'gpt-4.1-mini');
  perform pg_temp.assert_study_generation(v_new and v_status='reserved','first reservation wins');
  select * into v_new,v_status,v_ids from public.reserve_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
    '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('a',64),5,0.03,'gpt-4.1-mini');
  perform pg_temp.assert_study_generation(not v_new and v_status='reserved','same operation joins');
  begin
    perform * from public.reserve_study_generation_internal(
      '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
      '25252525-2525-4525-8525-252525252506','generate_flashcards',repeat('a',64),5,0.03,'gpt-4.1-mini');
    raise exception 'different material did not conflict';
  exception when others then
    if sqlerrm not like '%generation_operation_conflict%' then raise; end if;
  end;
  begin
    perform * from public.reserve_study_generation_internal(
      '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
      '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('b',64),5,0.03,'gpt-4.1-mini');
    raise exception 'different fingerprint did not conflict';
  exception when others then
    if sqlerrm not like '%generation_operation_conflict%' then raise; end if;
  end;
  begin
    perform * from public.reserve_study_generation_internal(
      '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
      '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('a',64),6,0.03,'gpt-4.1-mini');
    raise exception 'different count did not conflict';
  exception when others then
    if sqlerrm not like '%generation_operation_conflict%' then raise; end if;
  end;
  select public.claim_study_generation_provider_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503') into v_claim;
  perform pg_temp.assert_study_generation(v_claim,'provider is claimed once');
  select public.claim_study_generation_provider_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503') into v_claim;
  perform pg_temp.assert_study_generation(not v_claim,'duplicate provider claim is rejected');

  perform * from public.complete_flashcard_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
    '25252525-2525-4525-8525-252525252502',
    '[{"front":"Question","back":"Answer","topic":"Topic","difficulty":"medium"}]',
    'gpt-4.1-mini',100,50,0.00012);
  perform * from public.complete_flashcard_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252503',
    '25252525-2525-4525-8525-252525252502',
    '[{"front":"Ignored replay","back":"Ignored","topic":"Topic","difficulty":"medium"}]',
    'gpt-4.1-mini',100,50,0.00012);
  select count(*) into v_count from public.flashcards where material_id='25252525-2525-4525-8525-252525252502';
  perform pg_temp.assert_study_generation(v_count=1,'completion persists exactly once');
  perform pg_temp.assert_study_generation((select count(*)=1 from public.flashcards
    where material_id='25252525-2525-4525-8525-252525252502'
      and subject_id='25252525-2525-4525-8525-252525252501'
      and user_id='25252525-2525-4525-8525-252525252525'),
    'result is owned by the exact user, subject, and material');
  perform pg_temp.assert_study_generation((select flashcards_generated=1 and
    estimated_openai_cost_usd=0.00012 from public.daily_usage_limits
    where user_id='25252525-2525-4525-8525-252525252525'),
    'unused quantity and cost reservations are released');
  perform pg_temp.assert_study_generation((select count(*)=1 from public.usage_logs
    where user_id='25252525-2525-4525-8525-252525252525' and status='succeeded'),
    'one append-only usage entry represents the operation');
end
$$;

do $$
declare v_new boolean; v_status text; v_ids uuid[];
begin
  select * into v_new,v_status,v_ids from public.reserve_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252504',
    '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('b',64),2,0.03,'gpt-4.1-mini');
  perform public.fail_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252504','provider_failed',false);
  perform public.fail_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252504','provider_failed',false);
  perform pg_temp.assert_study_generation((select flashcards_generated=1 and
    estimated_openai_cost_usd=0.00012 from public.daily_usage_limits
    where user_id='25252525-2525-4525-8525-252525252525'),
    'terminal failure releases budget exactly once');
end
$$;

do $$
declare v_new boolean; v_status text; v_ids uuid[];
begin
  select * into v_new,v_status,v_ids from public.reserve_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252505',
    '25252525-2525-4525-8525-252525252502','generate_flashcards',repeat('c',64),2,0.03,'gpt-4.1-mini');
  perform public.fail_study_generation_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252505',
    'response_parse_failed',true);
  perform pg_temp.assert_study_generation((select flashcards_generated=1 and
    estimated_openai_cost_usd=0.03012 from public.daily_usage_limits
    where user_id='25252525-2525-4525-8525-252525252525'),
    'provider-submitted failure releases quantity but conservatively retains cost');
end
$$;

select pg_temp.assert_study_generation(
  (select count(*)=1 from public.load_study_generation_source_internal(
    '25252525-2525-4525-8525-252525252525','25252525-2525-4525-8525-252525252502')),
  'owned extracted text is selectable');
