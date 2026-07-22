-- Phase A: service-only canonical study source and idempotent generation usage.

create table public.study_generation_operations (
  operation_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete cascade,
  feature text not null check (feature in ('generate_flashcards', 'generate_quiz_questions')),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  requested_quantity integer not null check (requested_quantity between 1 and 30),
  reserved_cost_usd numeric(10, 6) not null check (reserved_cost_usd >= 0),
  status text not null default 'reserved' check (status in ('reserved', 'succeeded', 'failed')),
  provider_started_at timestamptz,
  result_ids uuid[] not null default '{}'::uuid[],
  usage_log_id uuid not null unique references public.usage_logs(id) on delete cascade,
  usage_date date not null default current_date,
  safe_failure_code text check (
    safe_failure_code is null or safe_failure_code in (
      'generation_failed', 'provider_failed', 'response_parse_failed',
      'material_unavailable', 'database_write_failed'
    )
  ),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.study_generation_operations is
  'Service-only idempotency and quota ledger for user-triggered study generation.';

create index study_generation_operations_user_created_idx
on public.study_generation_operations (user_id, created_at desc);

alter table public.study_generation_operations enable row level security;
revoke all on table public.study_generation_operations from public, anon, authenticated;
grant select, insert, update on table public.study_generation_operations to service_role;

create or replace function public.load_study_generation_source_internal(
  p_user_id uuid, p_material_id uuid
) returns table(
  id uuid, user_id uuid, subject_id uuid, kind text, source_kind text,
  processing_status text, content_text text, summary_payload jsonb,
  summary_schema_version integer, summary_validation_version text,
  summary_validation_hash text, analysis_status text, analysis_page_count integer
) language sql stable security definer
set search_path = pg_catalog, public
as $$
  select m.id,m.user_id,m.subject_id,m.kind,m.source_kind,m.processing_status,
    m.content_text,m.summary_payload,m.summary_schema_version,
    m.summary_validation_version,m.summary_validation_hash,j.status,j.page_count
  from public.materials m
  left join lateral (
    select latest.status,latest.page_count
    from public.material_processing_jobs latest
    where latest.material_id=m.id and latest.user_id=m.user_id
    order by latest.generation desc limit 1
  ) j on true
  where m.id=p_material_id and m.user_id=p_user_id and m.deleted_at is null
    and (
      (nullif(pg_catalog.btrim(m.content_text),'') is not null and (
        (m.kind='pasted_text' and m.source_kind='manual') or
        (m.kind in ('pdf','image') and m.source_kind='upload' and m.processing_status='ready')
      )) or (
        j.status in ('completed','completed_with_warnings') and
        m.summary_schema_version=1 and
        m.summary_validation_version='phase-c-validator-v2' and
        m.summary_validation_hash ~ '^[0-9a-f]{64}$' and
        public.material_analysis_valid_summary_payload(m.summary_payload)
      )
    );
$$;

create or replace function public.reserve_study_generation_internal(
  p_user_id uuid, p_operation_id uuid, p_material_id uuid, p_feature text,
  p_request_hash text, p_quantity integer, p_reserved_cost_usd numeric,
  p_model text
) returns table(is_new boolean, operation_status text, result_ids uuid[])
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_existing public.study_generation_operations%rowtype;
  v_limits public.daily_usage_limits%rowtype; v_usage_id uuid;
begin
  if p_user_id is null or p_operation_id is null or p_material_id is null or
    p_feature not in ('generate_flashcards','generate_quiz_questions') or
    p_request_hash !~ '^[0-9a-f]{64}$' or p_quantity<1 or p_quantity>30 or
    p_reserved_cost_usd<0 or p_reserved_cost_usd>0.25 or
    nullif(pg_catalog.btrim(p_model),'') is null then
    raise exception 'invalid_generation_reservation';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_operation_id::text,0)
  );

  select * into v_existing from public.study_generation_operations
  where operation_id=p_operation_id for update;
  if found then
    if v_existing.user_id<>p_user_id or v_existing.material_id<>p_material_id or
      v_existing.feature<>p_feature or v_existing.request_hash<>p_request_hash or
      v_existing.requested_quantity<>p_quantity then
      raise exception 'generation_operation_conflict';
    end if;
    return query select false,v_existing.status,v_existing.result_ids;
    return;
  end if;

  if not exists(select 1 from public.materials m where m.id=p_material_id
    and m.user_id=p_user_id and m.deleted_at is null) then
    raise exception 'material_unavailable';
  end if;

  insert into public.daily_usage_limits(user_id,usage_date)
  values(p_user_id,current_date) on conflict(user_id,usage_date) do nothing;
  select * into strict v_limits from public.daily_usage_limits
    where user_id=p_user_id and usage_date=current_date for update;
  if p_feature='generate_flashcards' and
    v_limits.flashcards_generated+p_quantity>v_limits.flashcards_limit then
    raise exception 'flashcard_daily_limit_exceeded';
  end if;
  if p_feature='generate_quiz_questions' and
    v_limits.quiz_questions_generated+p_quantity>v_limits.quiz_questions_limit then
    raise exception 'quiz_daily_limit_exceeded';
  end if;
  if v_limits.estimated_openai_cost_usd+p_reserved_cost_usd>
    v_limits.estimated_openai_cost_limit_usd then
    raise exception 'openai_cost_limit_exceeded';
  end if;

  insert into public.usage_logs(user_id,event_type,feature,model,quantity,
    estimated_cost_usd,status,metadata)
  values(p_user_id,p_feature,p_feature,p_model,p_quantity,p_reserved_cost_usd,
    'reserved',jsonb_build_object('operation_id',p_operation_id)) returning id into v_usage_id;
  insert into public.study_generation_operations(operation_id,user_id,material_id,
    feature,request_hash,requested_quantity,reserved_cost_usd,usage_log_id)
  values(p_operation_id,p_user_id,p_material_id,p_feature,p_request_hash,p_quantity,
    p_reserved_cost_usd,v_usage_id);
  update public.daily_usage_limits set
    flashcards_generated=flashcards_generated+
      case when p_feature='generate_flashcards' then p_quantity else 0 end,
    quiz_questions_generated=quiz_questions_generated+
      case when p_feature='generate_quiz_questions' then p_quantity else 0 end,
    estimated_openai_cost_usd=estimated_openai_cost_usd+p_reserved_cost_usd,
    updated_at=now()
  where id=v_limits.id;
  return query select true,'reserved'::text,'{}'::uuid[];
end
$$;

create or replace function public.claim_study_generation_provider_internal(
  p_user_id uuid, p_operation_id uuid
) returns boolean language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  update public.study_generation_operations set provider_started_at=now(),updated_at=now()
  where operation_id=p_operation_id and user_id=p_user_id and status='reserved'
    and provider_started_at is null;
  return found;
end
$$;

create or replace function public.get_study_generation_operation_internal(
  p_user_id uuid, p_operation_id uuid
) returns table(operation_status text,result_ids uuid[],safe_failure_code text)
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select o.status,o.result_ids,o.safe_failure_code
  from public.study_generation_operations o
  where o.operation_id=p_operation_id and o.user_id=p_user_id;
$$;

create or replace function public.complete_flashcard_generation_internal(
  p_user_id uuid,p_operation_id uuid,p_material_id uuid,p_cards jsonb,
  p_model text,p_input_tokens integer,p_output_tokens integer,p_actual_cost_usd numeric
) returns table(
  id uuid,subject_id uuid,material_id uuid,front text,back text,topic text,difficulty text
) language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_op public.study_generation_operations%rowtype; v_material public.materials%rowtype;
  v_card jsonb; v_ids uuid[]='{}'::uuid[]; v_id uuid; v_created integer=0;
begin
  select o.* into v_op from public.study_generation_operations o
    where o.operation_id=p_operation_id and o.user_id=p_user_id
      and o.material_id=p_material_id for update;
  if not found then raise exception 'generation_operation_unavailable'; end if;
  if v_op.status='succeeded' then
    return query select f.id,f.subject_id,f.material_id,f.front,f.back,f.topic,f.difficulty
      from public.flashcards f where f.id=any(v_op.result_ids)
      order by f.created_at,f.id;
    return;
  end if;
  if v_op.status<>'reserved' or v_op.provider_started_at is null or
    v_op.feature<>'generate_flashcards' or jsonb_typeof(p_cards)<>'array' or
    jsonb_array_length(p_cards)>v_op.requested_quantity or
    p_input_tokens<0 or p_output_tokens<0 or p_actual_cost_usd<0 or
    p_actual_cost_usd>v_op.reserved_cost_usd then
    raise exception 'invalid_generation_completion';
  end if;
  select m.* into strict v_material from public.materials m where m.id=p_material_id
    and m.user_id=p_user_id and m.deleted_at is null for update;
  for v_card in select value from jsonb_array_elements(p_cards) loop
    if jsonb_typeof(v_card)<>'object' or
      (select array_agg(key order by key) from jsonb_object_keys(v_card) key)<>
        array['back','difficulty','front','topic']::text[] or
      nullif(btrim(v_card->>'front'),'') is null or length(v_card->>'front')>1000 or
      nullif(btrim(v_card->>'back'),'') is null or length(v_card->>'back')>4000 or
      nullif(btrim(v_card->>'topic'),'') is null or length(v_card->>'topic')>300 or
      v_card->>'difficulty' not in ('easy','medium','exam') then
      raise exception 'invalid_flashcard_payload';
    end if;
    insert into public.flashcards(user_id,subject_id,material_id,front,back,topic,
      difficulty,metadata) values(p_user_id,v_material.subject_id,p_material_id,
      btrim(v_card->>'front'),btrim(v_card->>'back'),btrim(v_card->>'topic'),
      v_card->>'difficulty',jsonb_build_object('source','generate-flashcards','model',p_model,
        'operation_id',p_operation_id)) returning public.flashcards.id into v_id;
    v_ids:=array_append(v_ids,v_id); v_created:=v_created+1;
  end loop;
  insert into public.usage_logs(user_id,event_type,feature,model,quantity,input_tokens,
    output_tokens,estimated_cost_usd,status,metadata)
  values(p_user_id,'generate_flashcards','generate_flashcards',p_model,v_created,
    p_input_tokens,p_output_tokens,p_actual_cost_usd,'succeeded',
    jsonb_build_object('operation_id',p_operation_id,'reservation_log_id',v_op.usage_log_id,
      'created_count',v_created));
  update public.daily_usage_limits set
    flashcards_generated=greatest(0,flashcards_generated-(v_op.requested_quantity-v_created)),
    estimated_openai_cost_usd=greatest(0,estimated_openai_cost_usd-
      (v_op.reserved_cost_usd-p_actual_cost_usd)),updated_at=now()
  where user_id=p_user_id and usage_date=v_op.usage_date;
  update public.study_generation_operations set status='succeeded',result_ids=v_ids,
    completed_at=now(),updated_at=now() where operation_id=p_operation_id;
  return query select f.id,f.subject_id,f.material_id,f.front,f.back,f.topic,f.difficulty
    from public.flashcards f where f.id=any(v_ids)
    order by f.created_at,f.id;
end
$$;

create or replace function public.fail_study_generation_internal(
  p_user_id uuid,p_operation_id uuid,p_safe_failure_code text,
  p_retain_reserved_cost boolean
) returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_op public.study_generation_operations%rowtype; v_code text;
begin
  v_code:=case when p_safe_failure_code in ('provider_failed','response_parse_failed',
    'material_unavailable','database_write_failed') then p_safe_failure_code
    else 'generation_failed' end;
  select * into v_op from public.study_generation_operations where operation_id=p_operation_id
    and user_id=p_user_id for update;
  if not found or v_op.status in ('succeeded','failed') then return; end if;
  insert into public.usage_logs(user_id,event_type,feature,model,quantity,
    estimated_cost_usd,status,metadata)
  select p_user_id,v_op.feature,v_op.feature,reservation.model,0,
    case when p_retain_reserved_cost then v_op.reserved_cost_usd else 0 end,'failed',
    jsonb_build_object('operation_id',p_operation_id,'reservation_log_id',v_op.usage_log_id,
      'safe_failure_code',v_code)
  from public.usage_logs reservation where reservation.id=v_op.usage_log_id;
  update public.daily_usage_limits set
    flashcards_generated=greatest(0,flashcards_generated-
      case when v_op.feature='generate_flashcards' then v_op.requested_quantity else 0 end),
    quiz_questions_generated=greatest(0,quiz_questions_generated-
      case when v_op.feature='generate_quiz_questions' then v_op.requested_quantity else 0 end),
    estimated_openai_cost_usd=greatest(0,estimated_openai_cost_usd-
      case when p_retain_reserved_cost then 0 else v_op.reserved_cost_usd end),
    updated_at=now()
  where user_id=p_user_id and usage_date=v_op.usage_date;
  update public.study_generation_operations set status='failed',safe_failure_code=v_code,
    completed_at=now(),updated_at=now() where operation_id=p_operation_id;
end
$$;

alter function public.load_study_generation_source_internal(uuid,uuid) owner to postgres;
alter function public.reserve_study_generation_internal(uuid,uuid,uuid,text,text,integer,numeric,text) owner to postgres;
alter function public.claim_study_generation_provider_internal(uuid,uuid) owner to postgres;
alter function public.get_study_generation_operation_internal(uuid,uuid) owner to postgres;
alter function public.complete_flashcard_generation_internal(uuid,uuid,uuid,jsonb,text,integer,integer,numeric) owner to postgres;
alter function public.fail_study_generation_internal(uuid,uuid,text,boolean) owner to postgres;

revoke all on function public.load_study_generation_source_internal(uuid,uuid) from public,anon,authenticated;
revoke all on function public.reserve_study_generation_internal(uuid,uuid,uuid,text,text,integer,numeric,text) from public,anon,authenticated;
revoke all on function public.claim_study_generation_provider_internal(uuid,uuid) from public,anon,authenticated;
revoke all on function public.get_study_generation_operation_internal(uuid,uuid) from public,anon,authenticated;
revoke all on function public.complete_flashcard_generation_internal(uuid,uuid,uuid,jsonb,text,integer,integer,numeric) from public,anon,authenticated;
revoke all on function public.fail_study_generation_internal(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.load_study_generation_source_internal(uuid,uuid) to service_role;
grant execute on function public.reserve_study_generation_internal(uuid,uuid,uuid,text,text,integer,numeric,text) to service_role;
grant execute on function public.claim_study_generation_provider_internal(uuid,uuid) to service_role;
grant execute on function public.get_study_generation_operation_internal(uuid,uuid) to service_role;
grant execute on function public.complete_flashcard_generation_internal(uuid,uuid,uuid,jsonb,text,integer,integer,numeric) to service_role;
grant execute on function public.fail_study_generation_internal(uuid,uuid,text,boolean) to service_role;

notify pgrst, 'reload schema';
