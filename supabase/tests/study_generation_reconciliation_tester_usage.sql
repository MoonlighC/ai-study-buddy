\set ON_ERROR_STOP on

create or replace function pg_temp.assert_generation_030(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'generation_030_assertion_failed: %', message;
  end if;
end
$$;

do $$
declare
  v_signature text;
  v_proc record;
begin
  foreach v_signature in array array[
    'public.reserve_study_generation_internal(uuid,uuid,uuid,text,text,integer,numeric,text)',
    'public.claim_study_generation_provider_internal(uuid,uuid)',
    'public.record_study_generation_response_internal(uuid,uuid,text,text)',
    'public.claim_study_generation_reconciliation_internal(uuid,uuid,uuid)',
    'public.update_study_generation_provider_status_internal(uuid,uuid,uuid,text)',
    'public.fail_study_generation_reconciliation_internal(uuid,uuid,text,text,uuid)',
    'public.complete_flashcard_generation_internal(uuid,uuid,uuid,jsonb,text,integer,integer,numeric,uuid)',
    'public.complete_quiz_generation_internal(uuid,uuid,uuid,text,jsonb,text,integer,integer,numeric,uuid)',
    'public.get_study_generation_operation_internal(uuid,uuid)',
    'public.set_unlimited_tester(uuid,boolean)'
  ] loop
    select p.proowner, p.prosecdef, p.proconfig
    into strict v_proc
    from pg_proc p
    where p.oid = v_signature::regprocedure;
    perform pg_temp.assert_generation_030(
      v_proc.proowner = 'postgres'::regrole and v_proc.prosecdef and
      v_proc.proconfig = array['search_path=pg_catalog, public']::text[],
      v_signature || ' is postgres-owned and fixed-search-path'
    );
    perform pg_temp.assert_generation_030(
      has_function_privilege('service_role', v_signature, 'execute') and
      not has_function_privilege('authenticated', v_signature, 'execute') and
      not has_function_privilege('anon', v_signature, 'execute'),
      v_signature || ' is service-role-only'
    );
  end loop;

  select p.proowner, p.prosecdef, p.provolatile, p.proconfig
  into strict v_proc
  from pg_proc p
  where p.oid = 'public.get_my_usage_status()'::regprocedure;
  perform pg_temp.assert_generation_030(
    v_proc.proowner = 'postgres'::regrole and v_proc.prosecdef and
    v_proc.provolatile = 's' and
    v_proc.proconfig = array['search_path=pg_catalog, public']::text[],
    'usage status is stable, owned, and fixed-search-path'
  );
  perform pg_temp.assert_generation_030(
    has_function_privilege(
      'authenticated', 'public.get_my_usage_status()', 'execute'
    ) and
    not has_function_privilege('anon', 'public.get_my_usage_status()', 'execute') and
    not has_function_privilege(
      'service_role', 'public.get_my_usage_status()', 'execute'
    ),
    'usage status is authenticated-only'
  );
  perform pg_temp.assert_generation_030(
    not has_table_privilege(
      'authenticated', 'public.study_generation_operations', 'select'
    ) and
    not has_column_privilege(
      'authenticated', 'public.profiles', 'is_unlimited_tester', 'update'
    ),
    'provider identity and tester mutation are not client surfaces'
  );
end
$$;

insert into auth.users(id, email) values
  ('30303030-3030-4030-8030-303030303001', 'standard-030@example.test'),
  ('30303030-3030-4030-8030-303030303002', 'tester-030@example.test');

insert into public.profiles(id, email) values
  ('30303030-3030-4030-8030-303030303001', 'standard-030@example.test'),
  ('30303030-3030-4030-8030-303030303002', 'tester-030@example.test');

insert into public.subjects(id, user_id, name, color_value) values
  (
    '30303030-3030-4030-8030-303030303011',
    '30303030-3030-4030-8030-303030303001',
    'Standard subject',
    1
  ),
  (
    '30303030-3030-4030-8030-303030303012',
    '30303030-3030-4030-8030-303030303002',
    'Tester subject',
    2
  );

insert into public.materials(
  id, user_id, subject_id, title, kind, source_kind, content_text,
  processing_status
) values
  (
    '30303030-3030-4030-8030-303030303021',
    '30303030-3030-4030-8030-303030303001',
    '30303030-3030-4030-8030-303030303011',
    'Standard material',
    'pasted_text',
    'manual',
    'Sufficient owned source text for standard quota tests.',
    'ready'
  ),
  (
    '30303030-3030-4030-8030-303030303022',
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303012',
    'Tester material',
    'pasted_text',
    'manual',
    'Sufficient owned source text for tester and reconciliation tests.',
    'ready'
  );

insert into public.daily_usage_limits(
  user_id, usage_date, flashcards_generated, quiz_questions_generated,
  estimated_openai_cost_usd
) values (
  '30303030-3030-4030-8030-303030303001',
  current_date,
  120,
  80,
  0.25
);

do $$
begin
  begin
    perform * from public.reserve_study_generation_internal(
      '30303030-3030-4030-8030-303030303001',
      '30303030-3030-4030-8030-303030303031',
      '30303030-3030-4030-8030-303030303021',
      'generate_flashcards',
      repeat('a', 64),
      1,
      0.03,
      'gpt-4.1-mini'
    );
    raise exception 'standard flashcard cap was bypassed';
  exception when others then
    if sqlerrm not like '%flashcard_daily_limit_exceeded%' then raise; end if;
  end;
  begin
    perform * from public.reserve_study_generation_internal(
      '30303030-3030-4030-8030-303030303001',
      '30303030-3030-4030-8030-303030303032',
      '30303030-3030-4030-8030-303030303021',
      'generate_quiz_questions',
      repeat('b', 64),
      1,
      0.03,
      'gpt-4.1-mini'
    );
    raise exception 'standard quiz cap was bypassed';
  exception when others then
    if sqlerrm not like '%quiz_daily_limit_exceeded%' then raise; end if;
  end;
end
$$;

select pg_temp.assert_generation_030(
  public.set_unlimited_tester(
    '30303030-3030-4030-8030-303030303002', true
  ),
  'service policy enables tester idempotently'
);
select pg_temp.assert_generation_030(
  public.set_unlimited_tester(
    '30303030-3030-4030-8030-303030303002', true
  ),
  'repeated tester enablement is harmless'
);

update public.daily_usage_limits
set flashcards_generated = 120,
    quiz_questions_generated = 80,
    estimated_openai_cost_usd = 0.25
where user_id = '30303030-3030-4030-8030-303030303002'
  and usage_date = current_date;

insert into public.daily_usage_limits(
  user_id, usage_date, flashcards_generated, quiz_questions_generated,
  estimated_openai_cost_usd
)
select
  '30303030-3030-4030-8030-303030303002',
  current_date,
  120,
  80,
  0.25
where not exists (
  select 1 from public.daily_usage_limits
  where user_id = '30303030-3030-4030-8030-303030303002'
    and usage_date = current_date
);

do $$
declare
  v_new boolean;
  v_status text;
  v_ids uuid[];
begin
  select * into v_new, v_status, v_ids
  from public.reserve_study_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    '30303030-3030-4030-8030-303030303022',
    'generate_flashcards',
    repeat('c', 64),
    1,
    0.03,
    'gpt-4.1-mini'
  );
  perform pg_temp.assert_generation_030(
    v_new and v_status = 'reserved',
    'tester bypasses quantity and cost caps'
  );
  perform pg_temp.assert_generation_030(
    (
      select count(*) = 1
      from public.usage_logs
      where user_id = '30303030-3030-4030-8030-303030303002'
        and status = 'reserved'
        and metadata->>'account_policy' = 'unlimited_tester'
    ),
    'tester reservation remains logged'
  );

  begin
    perform * from public.reserve_study_generation_internal(
      '30303030-3030-4030-8030-303030303002',
      '30303030-3030-4030-8030-303030303042',
      '30303030-3030-4030-8030-303030303022',
      'generate_flashcards',
      repeat('d', 64),
      31,
      0.03,
      'gpt-4.1-mini'
    );
    raise exception 'tester per-action maximum was bypassed';
  exception when others then
    if sqlerrm not like '%invalid_generation_reservation%' then raise; end if;
  end;
end
$$;

do $$
declare
  v_claim boolean;
  v_reconcile boolean;
  v_status text;
  v_identity text;
  v_ids uuid[];
  v_code text;
  v_token uuid := '30303030-3030-4030-8030-303030303051';
  v_card_count integer;
begin
  select public.claim_study_generation_provider_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041'
  ) into v_claim;
  perform pg_temp.assert_generation_030(v_claim, 'provider claim succeeds once');
  perform pg_temp.assert_generation_030(
    not public.claim_study_generation_provider_internal(
      '30303030-3030-4030-8030-303030303002',
      '30303030-3030-4030-8030-303030303041'
    ),
    'provider claim remains one-time'
  );

  perform public.record_study_generation_response_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    'resp_generation_030_flashcards',
    'completed'
  );
  select * into v_reconcile, v_status, v_identity, v_ids, v_code
  from public.claim_study_generation_reconciliation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    v_token
  );
  perform pg_temp.assert_generation_030(
    v_reconcile and v_status = 'persisting' and
    v_identity = 'resp_generation_030_flashcards',
    'one reconciler receives the response identity lease'
  );
  perform pg_temp.assert_generation_030(
    not (
      select claimed
      from public.claim_study_generation_reconciliation_internal(
        '30303030-3030-4030-8030-303030303002',
        '30303030-3030-4030-8030-303030303041',
        '30303030-3030-4030-8030-303030303052'
      )
    ),
    'concurrent reconciler cannot acquire an active lease'
  );
  perform public.update_study_generation_provider_status_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    v_token,
    'completed'
  );
  perform * from public.complete_flashcard_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    '30303030-3030-4030-8030-303030303022',
    '[{"front":"Recovered","back":"Once","topic":"Crash","difficulty":"medium"}]',
    'gpt-4.1-mini',
    10,
    20,
    0.00004,
    v_token
  );
  perform * from public.complete_flashcard_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303041',
    '30303030-3030-4030-8030-303030303022',
    '[{"front":"Duplicate","back":"Must not persist","topic":"Crash","difficulty":"medium"}]',
    'gpt-4.1-mini',
    10,
    20,
    0.00004,
    '30303030-3030-4030-8030-303030303052'
  );
  select count(*) into v_card_count
  from public.flashcards
  where material_id = '30303030-3030-4030-8030-303030303022';
  perform pg_temp.assert_generation_030(
    v_card_count = 1,
    'reconciliation and replay persist cards exactly once'
  );
end
$$;

do $$
declare
  v_new boolean;
  v_status text;
  v_ids uuid[];
  v_token uuid := '30303030-3030-4030-8030-303030303061';
  v_quiz_count integer;
  v_question_count integer;
begin
  select * into v_new, v_status, v_ids
  from public.reserve_study_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    '30303030-3030-4030-8030-303030303022',
    'generate_quiz_questions',
    repeat('e', 64),
    1,
    0.03,
    'gpt-4.1-mini'
  );
  perform public.claim_study_generation_provider_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062'
  );
  perform public.record_study_generation_response_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    'resp_generation_030_quiz',
    'completed'
  );
  perform * from public.claim_study_generation_reconciliation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    v_token
  );
  perform public.update_study_generation_provider_status_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    v_token,
    'completed'
  );
  perform * from public.complete_quiz_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    '30303030-3030-4030-8030-303030303022',
    'Recovered quiz',
    '[{"question":"Q?","options":["A","B"],"correct_answer":"A","explanation":"Grounded.","topic":"Crash","difficulty":"medium"}]',
    'gpt-4.1-mini',
    10,
    20,
    0.00004,
    v_token
  );
  perform * from public.complete_quiz_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303062',
    '30303030-3030-4030-8030-303030303022',
    'Ignored replay',
    '[{"question":"Other?","options":["A","B"],"correct_answer":"A","explanation":"Grounded.","topic":"Crash","difficulty":"medium"}]',
    'gpt-4.1-mini',
    10,
    20,
    0.00004,
    '30303030-3030-4030-8030-303030303063'
  );
  select count(*) into v_quiz_count from public.quizzes
  where material_id = '30303030-3030-4030-8030-303030303022';
  select count(*) into v_question_count from public.quiz_questions
  where material_id = '30303030-3030-4030-8030-303030303022';
  perform pg_temp.assert_generation_030(
    v_quiz_count = 1 and v_question_count = 1,
    'quiz result and questions persist exactly once'
  );
end
$$;

do $$
declare
  v_new boolean;
  v_status text;
  v_ids uuid[];
begin
  select * into v_new, v_status, v_ids
  from public.reserve_study_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303071',
    '30303030-3030-4030-8030-303030303022',
    'generate_flashcards',
    repeat('f', 64),
    1,
    0.03,
    'gpt-4.1-mini'
  );
  update public.study_generation_operations
  set updated_at = now() - interval '11 minutes'
  where operation_id = '30303030-3030-4030-8030-303030303071';
  perform * from public.claim_study_generation_reconciliation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303071',
    '30303030-3030-4030-8030-303030303072'
  );
  perform pg_temp.assert_generation_030(
    (
      select status = 'failed_before_provider'
      from public.study_generation_operations
      where operation_id = '30303030-3030-4030-8030-303030303071'
    ),
    'stale reservation without provider claim releases safely'
  );

  select * into v_new, v_status, v_ids
  from public.reserve_study_generation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303073',
    '30303030-3030-4030-8030-303030303022',
    'generate_flashcards',
    repeat('1', 64),
    1,
    0.03,
    'gpt-4.1-mini'
  );
  perform public.claim_study_generation_provider_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303073'
  );
  update public.study_generation_operations
  set updated_at = now() - interval '11 minutes'
  where operation_id = '30303030-3030-4030-8030-303030303073';
  perform * from public.claim_study_generation_reconciliation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303073',
    '30303030-3030-4030-8030-303030303074'
  );
  perform * from public.claim_study_generation_reconciliation_internal(
    '30303030-3030-4030-8030-303030303002',
    '30303030-3030-4030-8030-303030303073',
    '30303030-3030-4030-8030-303030303075'
  );
  perform pg_temp.assert_generation_030(
    (
      select status = 'failed_after_provider'
      from public.study_generation_operations
      where operation_id = '30303030-3030-4030-8030-303030303073'
    ) and (
      select count(*) = 1
      from public.usage_logs
      where metadata->>'operation_id' =
        '30303030-3030-4030-8030-303030303073'
        and status = 'failed'
    ),
    'stale claimed operation terminalizes and accounts exactly once'
  );
end
$$;

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '30303030-3030-4030-8030-303030303002',
  false
);

do $$
begin
  begin
    update public.profiles
    set is_unlimited_tester = false
    where id = '30303030-3030-4030-8030-303030303002';
    raise exception 'authenticated tester spoof succeeded';
  exception when insufficient_privilege then
    null;
  end;
end
$$;

select pg_temp.assert_generation_030(
  (
    select account_policy = 'unlimited_tester' and
      flashcards_daily_limit is null and
      quiz_questions_daily_limit is null and
      estimated_cost_daily_limit is null and
      flashcards_used_today >= 120 and
      quiz_questions_used_today >= 80 and
      active_reservations = 0 and
      reset_at is not null
    from public.get_my_usage_status()
  ),
  'usage RPC returns only the authenticated tester policy and counters'
);

reset role;

select pg_temp.assert_generation_030(
  not public.set_unlimited_tester(
    '30303030-3030-4030-8030-303030303002', false
  ),
  'disabling tester is idempotent and restores standard policy'
);

do $$
begin
  begin
    perform * from public.reserve_study_generation_internal(
      '30303030-3030-4030-8030-303030303002',
      '30303030-3030-4030-8030-303030303081',
      '30303030-3030-4030-8030-303030303022',
      'generate_flashcards',
      repeat('2', 64),
      1,
      0.03,
      'gpt-4.1-mini'
    );
    raise exception 'disabled tester still bypassed limits';
  exception when others then
    if sqlerrm not like '%limit_exceeded%' then raise; end if;
  end;
end
$$;

select pg_temp.assert_generation_030(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.study_generation_operations'::regclass
  ) and (
    select count(*) = 0
    from pg_policies
    where schemaname = 'public' and tablename = 'study_generation_operations'
  ),
  'service operation ledger keeps RLS enabled without client policies'
);
