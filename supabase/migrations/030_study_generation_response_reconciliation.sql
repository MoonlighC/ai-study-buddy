-- Study generation crash reconciliation, trusted tester policy, and usage status.

alter table public.profiles
  add column is_unlimited_tester boolean not null default false;

comment on column public.profiles.is_unlimited_tester is
  'Trusted server-managed policy. Authenticated clients cannot update this column.';

alter table public.study_generation_operations
  drop constraint study_generation_operations_status_check;

alter table public.study_generation_operations
  drop constraint study_generation_operations_safe_failure_code_check;

alter table public.study_generation_operations
  add constraint study_generation_operations_status_check check (
    status in (
      'reserved',
      'provider_claimed',
      'reconciliation_required',
      'persisting',
      'succeeded',
      'failed',
      'failed_before_provider',
      'failed_after_provider'
    )
  ),
  add constraint study_generation_operations_safe_failure_code_check check (
    safe_failure_code is null or safe_failure_code in (
      'generation_failed', 'provider_failed', 'response_parse_failed',
      'material_unavailable', 'database_write_failed', 'generation_stale',
      'provider_terminal_failed'
    )
  ),
  add column provider_response_identity text,
  add column provider_request_submitted_at timestamptz,
  add column provider_terminal_status text,
  add column reconciliation_token uuid,
  add column reconciliation_lease_expires_at timestamptz,
  add constraint study_generation_provider_response_identity_check check (
    provider_response_identity is null or (
      pg_catalog.length(provider_response_identity) between 6 and 255 and
      provider_response_identity ~ '^[A-Za-z0-9_-]+$'
    )
  ),
  add constraint study_generation_provider_terminal_status_check check (
    provider_terminal_status is null or provider_terminal_status in (
      'queued', 'in_progress', 'completed', 'failed', 'cancelled', 'incomplete'
    )
  ),
  add constraint study_generation_reconciliation_lease_check check (
    (reconciliation_token is null and reconciliation_lease_expires_at is null)
    or
    (reconciliation_token is not null and reconciliation_lease_expires_at is not null)
  );

comment on column public.study_generation_operations.provider_response_identity is
  'Service-only provider response identity used for GET-only crash reconciliation.';
comment on column public.study_generation_operations.provider_request_submitted_at is
  'First timestamp at which an accepted provider response identity was durably recorded.';
comment on column public.study_generation_operations.reconciliation_token is
  'Short-lived service-only lease token. Never exposed through authenticated RPCs.';

create index study_generation_operations_reconciliation_idx
on public.study_generation_operations (status, updated_at)
where status in (
  'reserved', 'provider_claimed', 'reconciliation_required', 'persisting'
);

create unique index study_generation_operations_provider_response_identity_idx
on public.study_generation_operations (provider_response_identity)
where provider_response_identity is not null;

drop function public.fail_study_generation_internal(uuid, uuid, text, boolean);

create or replace function public.reserve_study_generation_internal(
  p_user_id uuid, p_operation_id uuid, p_material_id uuid, p_feature text,
  p_request_hash text, p_quantity integer, p_reserved_cost_usd numeric,
  p_model text
) returns table(is_new boolean, operation_status text, result_ids uuid[])
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_existing public.study_generation_operations%rowtype;
  v_limits public.daily_usage_limits%rowtype;
  v_usage_id uuid;
  v_unlimited boolean;
begin
  if p_user_id is null or p_operation_id is null or p_material_id is null or
    p_feature not in ('generate_flashcards','generate_quiz_questions') or
    p_request_hash !~ '^[0-9a-f]{64}$' or p_quantity < 1 or p_quantity > 30 or
    p_reserved_cost_usd < 0 or p_reserved_cost_usd > 0.25 or
    nullif(pg_catalog.btrim(p_model),'') is null then
    raise exception 'invalid_generation_reservation';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_operation_id::text, 0)
  );

  select * into v_existing
  from public.study_generation_operations
  where operation_id = p_operation_id
  for update;

  if found then
    if v_existing.user_id <> p_user_id or
      v_existing.material_id <> p_material_id or
      v_existing.feature <> p_feature or
      v_existing.request_hash <> p_request_hash or
      v_existing.requested_quantity <> p_quantity then
      raise exception 'generation_operation_conflict';
    end if;
    return query
      select false, v_existing.status, v_existing.result_ids;
    return;
  end if;

  if not exists (
    select 1
    from public.materials m
    where m.id = p_material_id and m.user_id = p_user_id
      and m.deleted_at is null
  ) then
    raise exception 'material_unavailable';
  end if;

  select coalesce(p.is_unlimited_tester, false)
  into v_unlimited
  from public.profiles p
  where p.id = p_user_id;
  v_unlimited := coalesce(v_unlimited, false);

  insert into public.daily_usage_limits(user_id, usage_date)
  values (p_user_id, current_date)
  on conflict(user_id, usage_date) do nothing;

  select * into strict v_limits
  from public.daily_usage_limits
  where user_id = p_user_id and usage_date = current_date
  for update;

  if not v_unlimited and p_feature = 'generate_flashcards' and
    v_limits.flashcards_generated + p_quantity > v_limits.flashcards_limit then
    raise exception 'flashcard_daily_limit_exceeded';
  end if;
  if not v_unlimited and p_feature = 'generate_quiz_questions' and
    v_limits.quiz_questions_generated + p_quantity >
      v_limits.quiz_questions_limit then
    raise exception 'quiz_daily_limit_exceeded';
  end if;
  if not v_unlimited and
    v_limits.estimated_openai_cost_usd + p_reserved_cost_usd >
      v_limits.estimated_openai_cost_limit_usd then
    raise exception 'openai_cost_limit_exceeded';
  end if;

  insert into public.usage_logs(
    user_id, event_type, feature, model, quantity,
    estimated_cost_usd, status, metadata
  ) values (
    p_user_id, p_feature, p_feature, p_model, p_quantity,
    p_reserved_cost_usd, 'reserved',
    jsonb_build_object(
      'operation_id', p_operation_id,
      'account_policy',
      case when v_unlimited then 'unlimited_tester' else 'standard' end
    )
  ) returning id into v_usage_id;

  insert into public.study_generation_operations(
    operation_id, user_id, material_id, feature, request_hash,
    requested_quantity, reserved_cost_usd, usage_log_id
  ) values (
    p_operation_id, p_user_id, p_material_id, p_feature, p_request_hash,
    p_quantity, p_reserved_cost_usd, v_usage_id
  );

  update public.daily_usage_limits
  set flashcards_generated = flashcards_generated +
        case when p_feature = 'generate_flashcards' then p_quantity else 0 end,
      quiz_questions_generated = quiz_questions_generated +
        case when p_feature = 'generate_quiz_questions' then p_quantity else 0 end,
      estimated_openai_cost_usd =
        estimated_openai_cost_usd + p_reserved_cost_usd,
      updated_at = now()
  where id = v_limits.id;

  return query select true, 'reserved'::text, '{}'::uuid[];
end
$$;

create or replace function public.claim_study_generation_provider_internal(
  p_user_id uuid, p_operation_id uuid
) returns boolean
language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  update public.study_generation_operations
  set status = 'provider_claimed',
      provider_started_at = coalesce(provider_started_at, now()),
      updated_at = now()
  where operation_id = p_operation_id and user_id = p_user_id
    and status = 'reserved' and provider_started_at is null;
  return found;
end
$$;

create or replace function public.record_study_generation_response_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_provider_response_identity text,
  p_provider_status text
) returns void
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_op public.study_generation_operations%rowtype;
begin
  if p_provider_response_identity is null or
    pg_catalog.length(p_provider_response_identity) not between 6 and 255 or
    p_provider_response_identity !~ '^[A-Za-z0-9_-]+$' or
    p_provider_status not in (
      'queued', 'in_progress', 'completed', 'failed', 'cancelled', 'incomplete'
    ) then
    raise exception 'invalid_generation_provider_response';
  end if;

  select * into v_op
  from public.study_generation_operations
  where operation_id = p_operation_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'generation_operation_unavailable';
  end if;
  if v_op.status = 'succeeded' then
    if v_op.provider_response_identity is distinct from
      p_provider_response_identity then
      raise exception 'generation_response_identity_conflict';
    end if;
    return;
  end if;
  if v_op.status in ('failed', 'failed_before_provider', 'failed_after_provider') then
    raise exception 'generation_operation_terminal';
  end if;
  if v_op.status not in (
    'provider_claimed', 'reconciliation_required', 'persisting'
  ) or v_op.provider_started_at is null then
    raise exception 'invalid_generation_provider_state';
  end if;
  if v_op.provider_response_identity is not null and
    v_op.provider_response_identity <> p_provider_response_identity then
    raise exception 'generation_response_identity_conflict';
  end if;

  update public.study_generation_operations
  set status = 'reconciliation_required',
      provider_response_identity = p_provider_response_identity,
      provider_request_submitted_at =
        coalesce(provider_request_submitted_at, now()),
      provider_terminal_status = p_provider_status,
      reconciliation_token = null,
      reconciliation_lease_expires_at = null,
      updated_at = now()
  where operation_id = p_operation_id;
end
$$;

create or replace function public.fail_study_generation_reconciliation_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_safe_failure_code text,
  p_failure_phase text,
  p_reconciliation_token uuid default null
) returns void
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_op public.study_generation_operations%rowtype;
  v_code text;
  v_retain_cost boolean;
begin
  if p_failure_phase not in ('before_provider', 'after_provider') then
    raise exception 'invalid_generation_failure_phase';
  end if;
  v_code := case
    when p_safe_failure_code in (
      'provider_failed', 'response_parse_failed', 'material_unavailable',
      'database_write_failed', 'generation_stale', 'provider_terminal_failed'
    ) then p_safe_failure_code
    else 'generation_failed'
  end;
  v_retain_cost := p_failure_phase = 'after_provider';

  select * into v_op
  from public.study_generation_operations
  where operation_id = p_operation_id and user_id = p_user_id
  for update;

  if not found or v_op.status in (
    'succeeded', 'failed', 'failed_before_provider', 'failed_after_provider'
  ) then
    return;
  end if;
  if p_failure_phase = 'before_provider' and (
    v_op.provider_response_identity is not null or
    v_op.provider_request_submitted_at is not null
  ) then
    raise exception 'generation_provider_work_already_recorded';
  end if;
  if p_reconciliation_token is not null and (
    v_op.reconciliation_token is distinct from p_reconciliation_token or
    v_op.reconciliation_lease_expires_at <= now()
  ) then
    raise exception 'generation_reconciliation_lease_lost';
  end if;

  insert into public.usage_logs(
    user_id, event_type, feature, model, quantity,
    estimated_cost_usd, status, metadata
  )
  select p_user_id, v_op.feature, v_op.feature, reservation.model, 0,
    case when v_retain_cost then v_op.reserved_cost_usd else 0 end,
    'failed',
    jsonb_build_object(
      'operation_id', p_operation_id,
      'reservation_log_id', v_op.usage_log_id,
      'safe_failure_code', v_code,
      'failure_phase', p_failure_phase
    )
  from public.usage_logs reservation
  where reservation.id = v_op.usage_log_id;

  update public.daily_usage_limits
  set flashcards_generated = greatest(
        0,
        flashcards_generated -
          case when v_op.feature = 'generate_flashcards'
            then v_op.requested_quantity else 0 end
      ),
      quiz_questions_generated = greatest(
        0,
        quiz_questions_generated -
          case when v_op.feature = 'generate_quiz_questions'
            then v_op.requested_quantity else 0 end
      ),
      estimated_openai_cost_usd = greatest(
        0,
        estimated_openai_cost_usd -
          case when v_retain_cost then 0 else v_op.reserved_cost_usd end
      ),
      updated_at = now()
  where user_id = p_user_id and usage_date = v_op.usage_date;

  update public.study_generation_operations
  set status = case when v_retain_cost
        then 'failed_after_provider' else 'failed_before_provider' end,
      safe_failure_code = v_code,
      provider_terminal_status = case
        when v_retain_cost then coalesce(provider_terminal_status, 'failed')
        else provider_terminal_status end,
      reconciliation_token = null,
      reconciliation_lease_expires_at = null,
      completed_at = now(),
      updated_at = now()
  where operation_id = p_operation_id;
end
$$;

create or replace function public.claim_study_generation_reconciliation_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_reconciliation_token uuid
) returns table(
  claimed boolean,
  operation_status text,
  provider_response_identity text,
  result_ids uuid[],
  safe_failure_code text
)
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_op public.study_generation_operations%rowtype;
  v_stale_after interval := interval '10 minutes';
begin
  if p_reconciliation_token is null then
    raise exception 'invalid_generation_reconciliation_token';
  end if;

  select * into v_op
  from public.study_generation_operations
  where operation_id = p_operation_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'generation_operation_unavailable';
  end if;

  if v_op.status = 'reserved' and v_op.updated_at <= now() - v_stale_after then
    perform public.fail_study_generation_reconciliation_internal(
      p_user_id, p_operation_id, 'generation_stale', 'before_provider', null
    );
    select * into v_op from public.study_generation_operations
    where operation_id = p_operation_id;
  elsif v_op.status = 'provider_claimed' and
    v_op.provider_response_identity is null and
    v_op.updated_at <= now() - v_stale_after then
    perform public.fail_study_generation_reconciliation_internal(
      p_user_id, p_operation_id, 'generation_stale', 'after_provider', null
    );
    select * into v_op from public.study_generation_operations
    where operation_id = p_operation_id;
  end if;

  if v_op.status = 'succeeded' then
    return query select false, v_op.status, null::text,
      v_op.result_ids, v_op.safe_failure_code;
    return;
  end if;
  if v_op.status in (
    'failed', 'failed_before_provider', 'failed_after_provider'
  ) then
    return query select false, v_op.status, null::text,
      v_op.result_ids, v_op.safe_failure_code;
    return;
  end if;
  if v_op.provider_response_identity is null then
    return query select false, v_op.status, null::text,
      v_op.result_ids, v_op.safe_failure_code;
    return;
  end if;

  if v_op.status in ('reconciliation_required', 'persisting') and (
    v_op.reconciliation_token is null or
    v_op.reconciliation_lease_expires_at <= now() or
    v_op.reconciliation_token = p_reconciliation_token
  ) then
    update public.study_generation_operations
    set status = 'persisting',
        reconciliation_token = p_reconciliation_token,
        reconciliation_lease_expires_at = now() + interval '45 seconds',
        updated_at = now()
    where operation_id = p_operation_id
    returning * into v_op;
    return query select true, v_op.status,
      v_op.provider_response_identity, v_op.result_ids, v_op.safe_failure_code;
    return;
  end if;

  return query select false, v_op.status, null::text,
    v_op.result_ids, v_op.safe_failure_code;
end
$$;

create or replace function public.update_study_generation_provider_status_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_reconciliation_token uuid,
  p_provider_status text
) returns void
language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if p_provider_status not in (
    'queued', 'in_progress', 'completed', 'failed', 'cancelled', 'incomplete'
  ) then
    raise exception 'invalid_generation_provider_status';
  end if;
  update public.study_generation_operations
  set provider_terminal_status = p_provider_status,
      status = case when p_provider_status in ('queued', 'in_progress')
        then 'reconciliation_required' else status end,
      reconciliation_token = case when p_provider_status in ('queued', 'in_progress')
        then null else reconciliation_token end,
      reconciliation_lease_expires_at =
        case when p_provider_status in ('queued', 'in_progress')
          then null else reconciliation_lease_expires_at end,
      updated_at = now()
  where operation_id = p_operation_id and user_id = p_user_id
    and status = 'persisting'
    and reconciliation_token = p_reconciliation_token
    and reconciliation_lease_expires_at > now();
  if not found then
    raise exception 'generation_reconciliation_lease_lost';
  end if;
end
$$;

drop function public.complete_flashcard_generation_internal(
  uuid, uuid, uuid, jsonb, text, integer, integer, numeric
);

create function public.complete_flashcard_generation_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_material_id uuid,
  p_cards jsonb,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_actual_cost_usd numeric,
  p_reconciliation_token uuid
) returns table(
  id uuid,
  subject_id uuid,
  material_id uuid,
  front text,
  back text,
  topic text,
  difficulty text
)
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_op public.study_generation_operations%rowtype;
  v_material public.materials%rowtype;
  v_card jsonb;
  v_ids uuid[] := '{}'::uuid[];
  v_id uuid;
  v_created integer := 0;
begin
  select * into v_op
  from public.study_generation_operations o
  where o.operation_id = p_operation_id and o.user_id = p_user_id
    and o.material_id = p_material_id
  for update;
  if not found then raise exception 'generation_operation_unavailable'; end if;
  if v_op.status = 'succeeded' then
    return query
      select f.id, f.subject_id, f.material_id, f.front, f.back, f.topic,
        f.difficulty
      from public.flashcards f
      where f.id = any(v_op.result_ids)
      order by f.created_at, f.id;
    return;
  end if;
  if v_op.status <> 'persisting' or
    v_op.reconciliation_token is distinct from p_reconciliation_token or
    v_op.reconciliation_lease_expires_at <= now() or
    v_op.provider_response_identity is null or
    v_op.provider_terminal_status <> 'completed' or
    v_op.feature <> 'generate_flashcards' or
    jsonb_typeof(p_cards) <> 'array' or
    jsonb_array_length(p_cards) > v_op.requested_quantity or
    p_input_tokens < 0 or p_output_tokens < 0 or p_actual_cost_usd < 0 or
    p_actual_cost_usd > v_op.reserved_cost_usd then
    raise exception 'invalid_generation_completion';
  end if;

  select * into strict v_material
  from public.materials m
  where m.id = p_material_id and m.user_id = p_user_id
    and m.deleted_at is null
  for update;

  for v_card in select value from jsonb_array_elements(p_cards) loop
    if jsonb_typeof(v_card) <> 'object' or
      (select array_agg(key order by key) from jsonb_object_keys(v_card) key) <>
        array['back','difficulty','front','topic']::text[] or
      nullif(btrim(v_card->>'front'),'') is null or
      length(v_card->>'front') > 1000 or
      nullif(btrim(v_card->>'back'),'') is null or
      length(v_card->>'back') > 4000 or
      nullif(btrim(v_card->>'topic'),'') is null or
      length(v_card->>'topic') > 300 or
      v_card->>'difficulty' not in ('easy','medium','exam') then
      raise exception 'invalid_flashcard_payload';
    end if;
    insert into public.flashcards(
      user_id, subject_id, material_id, front, back, topic, difficulty, metadata
    ) values (
      p_user_id, v_material.subject_id, p_material_id,
      btrim(v_card->>'front'), btrim(v_card->>'back'),
      btrim(v_card->>'topic'), v_card->>'difficulty',
      jsonb_build_object(
        'source', 'generate-flashcards',
        'model', p_model,
        'operation_id', p_operation_id
      )
    ) returning public.flashcards.id into v_id;
    v_ids := array_append(v_ids, v_id);
    v_created := v_created + 1;
  end loop;

  insert into public.usage_logs(
    user_id, event_type, feature, model, quantity, input_tokens,
    output_tokens, estimated_cost_usd, status, metadata
  ) values (
    p_user_id, 'generate_flashcards', 'generate_flashcards', p_model,
    v_created, p_input_tokens, p_output_tokens, p_actual_cost_usd, 'succeeded',
    jsonb_build_object(
      'operation_id', p_operation_id,
      'reservation_log_id', v_op.usage_log_id,
      'created_count', v_created
    )
  );

  update public.daily_usage_limits
  set flashcards_generated = greatest(
        0, flashcards_generated - (v_op.requested_quantity - v_created)
      ),
      estimated_openai_cost_usd = greatest(
        0,
        estimated_openai_cost_usd -
          (v_op.reserved_cost_usd - p_actual_cost_usd)
      ),
      updated_at = now()
  where user_id = p_user_id and usage_date = v_op.usage_date;

  update public.study_generation_operations
  set status = 'succeeded',
      result_ids = v_ids,
      provider_terminal_status = 'completed',
      reconciliation_token = null,
      reconciliation_lease_expires_at = null,
      completed_at = now(),
      updated_at = now()
  where operation_id = p_operation_id;

  return query
    select f.id, f.subject_id, f.material_id, f.front, f.back, f.topic,
      f.difficulty
    from public.flashcards f
    where f.id = any(v_ids)
    order by f.created_at, f.id;
end
$$;

drop function public.complete_quiz_generation_internal(
  uuid, uuid, uuid, text, jsonb, text, integer, integer, numeric
);

create function public.complete_quiz_generation_internal(
  p_user_id uuid,
  p_operation_id uuid,
  p_material_id uuid,
  p_title text,
  p_questions jsonb,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_actual_cost_usd numeric,
  p_reconciliation_token uuid
) returns table(
  id uuid,
  quiz_id uuid,
  subject_id uuid,
  material_id uuid,
  question text,
  options jsonb,
  correct_answer text,
  explanation text,
  topic text,
  difficulty text,
  sort_order integer
)
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_op public.study_generation_operations%rowtype;
  v_material public.materials%rowtype;
  v_quiz uuid;
  v_q jsonb;
  v_id uuid;
  v_ids uuid[] := '{}';
  v_index integer := 0;
begin
  select * into v_op
  from public.study_generation_operations o
  where o.operation_id = p_operation_id and o.user_id = p_user_id
    and o.material_id = p_material_id
  for update;
  if not found then raise exception 'generation_operation_unavailable'; end if;
  if v_op.status = 'succeeded' then
    return query
      select q.id, q.quiz_id, q.subject_id, q.material_id, q.question,
        q.options, q.correct_answer, q.explanation, q.topic, q.difficulty,
        q.sort_order
      from public.quiz_questions q
      where q.id = any(v_op.result_ids)
      order by q.sort_order;
    return;
  end if;
  if v_op.status <> 'persisting' or
    v_op.reconciliation_token is distinct from p_reconciliation_token or
    v_op.reconciliation_lease_expires_at <= now() or
    v_op.provider_response_identity is null or
    v_op.provider_terminal_status <> 'completed' or
    v_op.feature <> 'generate_quiz_questions' or
    jsonb_typeof(p_questions) <> 'array' or
    jsonb_array_length(p_questions) <> v_op.requested_quantity or
    nullif(btrim(p_title),'') is null or length(p_title) > 500 or
    p_input_tokens < 0 or p_output_tokens < 0 or p_actual_cost_usd < 0 or
    p_actual_cost_usd > v_op.reserved_cost_usd then
    raise exception 'invalid_generation_completion';
  end if;

  select * into strict v_material
  from public.materials m
  where m.id = p_material_id and m.user_id = p_user_id
    and m.deleted_at is null;

  for v_q in select value from jsonb_array_elements(p_questions) loop
    if jsonb_typeof(v_q) <> 'object' or
      (select array_agg(key order by key) from jsonb_object_keys(v_q) key) <>
        array[
          'correct_answer','difficulty','explanation','options','question','topic'
        ]::text[] or
      nullif(btrim(v_q->>'question'),'') is null or
      length(v_q->>'question') > 2000 or
      jsonb_typeof(v_q->'options') <> 'array' or
      jsonb_array_length(v_q->'options') < 2 or
      jsonb_array_length(v_q->'options') > 8 or
      (select count(*) from jsonb_array_elements_text(v_q->'options')) <>
        (select count(distinct value)
          from jsonb_array_elements_text(v_q->'options')) or
      not (v_q->'options' ? (v_q->>'correct_answer')) or
      nullif(btrim(v_q->>'explanation'),'') is null or
      nullif(btrim(v_q->>'topic'),'') is null or
      v_q->>'difficulty' not in ('easy','medium','exam') then
      raise exception 'invalid_quiz_payload';
    end if;
  end loop;

  insert into public.quizzes(
    user_id, subject_id, material_id, title, quiz_type, question_count, metadata
  ) values (
    p_user_id, v_material.subject_id, p_material_id, btrim(p_title), 'practice',
    jsonb_array_length(p_questions),
    jsonb_build_object(
      'source', 'generate-quiz',
      'model', p_model,
      'operation_id', p_operation_id
    )
  ) returning public.quizzes.id into v_quiz;

  for v_q in select value from jsonb_array_elements(p_questions) loop
    insert into public.quiz_questions(
      user_id, quiz_id, subject_id, material_id, question, options,
      correct_answer, explanation, topic, difficulty, sort_order, metadata
    ) values (
      p_user_id, v_quiz, v_material.subject_id, p_material_id,
      btrim(v_q->>'question'), v_q->'options', v_q->>'correct_answer',
      btrim(v_q->>'explanation'), btrim(v_q->>'topic'), v_q->>'difficulty',
      v_index,
      jsonb_build_object(
        'source', 'generate-quiz',
        'model', p_model,
        'operation_id', p_operation_id
      )
    ) returning public.quiz_questions.id into v_id;
    v_ids := array_append(v_ids, v_id);
    v_index := v_index + 1;
  end loop;

  insert into public.usage_logs(
    user_id, event_type, feature, model, quantity, input_tokens,
    output_tokens, estimated_cost_usd, status, metadata
  ) values (
    p_user_id, 'generate_quiz_questions', 'generate_quiz_questions', p_model,
    v_index, p_input_tokens, p_output_tokens, p_actual_cost_usd, 'succeeded',
    jsonb_build_object(
      'operation_id', p_operation_id,
      'reservation_log_id', v_op.usage_log_id,
      'quiz_id', v_quiz
    )
  );

  update public.daily_usage_limits
  set estimated_openai_cost_usd = greatest(
        0,
        estimated_openai_cost_usd -
          (v_op.reserved_cost_usd - p_actual_cost_usd)
      ),
      updated_at = now()
  where user_id = p_user_id and usage_date = v_op.usage_date;

  update public.study_generation_operations
  set status = 'succeeded',
      result_ids = v_ids,
      provider_terminal_status = 'completed',
      reconciliation_token = null,
      reconciliation_lease_expires_at = null,
      completed_at = now(),
      updated_at = now()
  where operation_id = p_operation_id;

  return query
    select q.id, q.quiz_id, q.subject_id, q.material_id, q.question,
      q.options, q.correct_answer, q.explanation, q.topic, q.difficulty,
      q.sort_order
    from public.quiz_questions q
    where q.id = any(v_ids)
    order by q.sort_order;
end
$$;

drop function public.get_study_generation_operation_internal(uuid, uuid);

create function public.get_study_generation_operation_internal(
  p_user_id uuid,
  p_operation_id uuid
) returns table(
  operation_status text,
  client_status text,
  result_ids uuid[],
  safe_failure_code text,
  can_retry boolean,
  provider_response_identity text
)
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select o.status,
    case
      when o.status in ('reserved', 'provider_claimed') then 'generating'
      when o.status in ('reconciliation_required', 'persisting') then 'reconciling'
      when o.status = 'succeeded' then 'completed'
      else 'failed'
    end,
    o.result_ids,
    o.safe_failure_code,
    o.status in ('failed', 'failed_before_provider', 'failed_after_provider'),
    o.provider_response_identity
  from public.study_generation_operations o
  where o.operation_id = p_operation_id and o.user_id = p_user_id;
$$;

create or replace function public.set_unlimited_tester(
  p_user_id uuid,
  p_enabled boolean
) returns boolean
language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if p_user_id is null or p_enabled is null then
    raise exception 'invalid_tester_policy';
  end if;
  update public.profiles
  set is_unlimited_tester = p_enabled,
      updated_at = now()
  where id = p_user_id;
  if not found then
    raise exception 'profile_unavailable';
  end if;
  return p_enabled;
end
$$;

create or replace function public.get_my_usage_status()
returns table(
  account_policy text,
  flashcards_used_today integer,
  flashcards_daily_limit integer,
  quiz_questions_used_today integer,
  quiz_questions_daily_limit integer,
  estimated_cost_used_today numeric,
  estimated_cost_daily_limit numeric,
  active_reservations integer,
  reset_at timestamptz
)
language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_unlimited boolean;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select coalesce(p.is_unlimited_tester, false)
  into v_unlimited
  from public.profiles p
  where p.id = v_user;
  v_unlimited := coalesce(v_unlimited, false);

  return query
    select
      case when v_unlimited then 'unlimited_tester' else 'standard' end,
      coalesce(d.flashcards_generated, 0),
      case when v_unlimited then null else coalesce(d.flashcards_limit, 120) end,
      coalesce(d.quiz_questions_generated, 0),
      case when v_unlimited then null else coalesce(d.quiz_questions_limit, 80) end,
      coalesce(d.estimated_openai_cost_usd, 0),
      case when v_unlimited then null
        else coalesce(d.estimated_openai_cost_limit_usd, 0.25) end,
      (
        select count(*)::integer
        from public.study_generation_operations o
        where o.user_id = v_user and o.status in (
          'reserved', 'provider_claimed', 'reconciliation_required', 'persisting'
        )
      ),
      ((current_date + 1)::timestamp at time zone 'UTC')
    from (select 1) seed
    left join public.daily_usage_limits d
      on d.user_id = v_user and d.usage_date = current_date;
end
$$;

revoke all on function public.reserve_study_generation_internal(
  uuid, uuid, uuid, text, text, integer, numeric, text
) from public, anon, authenticated;
revoke all on function public.claim_study_generation_provider_internal(
  uuid, uuid
) from public, anon, authenticated;
revoke all on function public.record_study_generation_response_internal(
  uuid, uuid, text, text
) from public, anon, authenticated;
revoke all on function public.claim_study_generation_reconciliation_internal(
  uuid, uuid, uuid
) from public, anon, authenticated;
revoke all on function public.update_study_generation_provider_status_internal(
  uuid, uuid, uuid, text
) from public, anon, authenticated;
revoke all on function public.fail_study_generation_reconciliation_internal(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function public.complete_flashcard_generation_internal(
  uuid, uuid, uuid, jsonb, text, integer, integer, numeric, uuid
) from public, anon, authenticated;
revoke all on function public.complete_quiz_generation_internal(
  uuid, uuid, uuid, text, jsonb, text, integer, integer, numeric, uuid
) from public, anon, authenticated;
revoke all on function public.get_study_generation_operation_internal(
  uuid, uuid
) from public, anon, authenticated;
revoke all on function public.set_unlimited_tester(uuid, boolean)
from public, anon, authenticated;
revoke all on function public.get_my_usage_status()
from public, anon, service_role;

grant execute on function public.reserve_study_generation_internal(
  uuid, uuid, uuid, text, text, integer, numeric, text
) to service_role;
grant execute on function public.claim_study_generation_provider_internal(
  uuid, uuid
) to service_role;
grant execute on function public.record_study_generation_response_internal(
  uuid, uuid, text, text
) to service_role;
grant execute on function public.claim_study_generation_reconciliation_internal(
  uuid, uuid, uuid
) to service_role;
grant execute on function public.update_study_generation_provider_status_internal(
  uuid, uuid, uuid, text
) to service_role;
grant execute on function public.fail_study_generation_reconciliation_internal(
  uuid, uuid, text, text, uuid
) to service_role;
grant execute on function public.complete_flashcard_generation_internal(
  uuid, uuid, uuid, jsonb, text, integer, integer, numeric, uuid
) to service_role;
grant execute on function public.complete_quiz_generation_internal(
  uuid, uuid, uuid, text, jsonb, text, integer, integer, numeric, uuid
) to service_role;
grant execute on function public.get_study_generation_operation_internal(
  uuid, uuid
) to service_role;
grant execute on function public.set_unlimited_tester(uuid, boolean)
to service_role;
grant execute on function public.get_my_usage_status()
to authenticated;

alter function public.reserve_study_generation_internal(
  uuid, uuid, uuid, text, text, integer, numeric, text
) owner to postgres;
alter function public.claim_study_generation_provider_internal(
  uuid, uuid
) owner to postgres;
alter function public.record_study_generation_response_internal(
  uuid, uuid, text, text
) owner to postgres;
alter function public.claim_study_generation_reconciliation_internal(
  uuid, uuid, uuid
) owner to postgres;
alter function public.update_study_generation_provider_status_internal(
  uuid, uuid, uuid, text
) owner to postgres;
alter function public.fail_study_generation_reconciliation_internal(
  uuid, uuid, text, text, uuid
) owner to postgres;
alter function public.complete_flashcard_generation_internal(
  uuid, uuid, uuid, jsonb, text, integer, integer, numeric, uuid
) owner to postgres;
alter function public.complete_quiz_generation_internal(
  uuid, uuid, uuid, text, jsonb, text, integer, integer, numeric, uuid
) owner to postgres;
alter function public.get_study_generation_operation_internal(
  uuid, uuid
) owner to postgres;
alter function public.set_unlimited_tester(uuid, boolean)
owner to postgres;
alter function public.get_my_usage_status()
owner to postgres;

revoke update(is_unlimited_tester) on table public.profiles
from public, anon, authenticated;
alter table public.profiles enable row level security;
alter table public.study_generation_operations enable row level security;
revoke all on table public.study_generation_operations
from public, anon, authenticated;
grant select, insert, update on table public.study_generation_operations
to service_role;

notify pgrst, 'reload schema';
