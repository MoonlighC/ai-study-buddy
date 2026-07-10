-- Phase 8D.2: authoritative quiz attempts and cumulative weak topics.

alter table public.weak_topics
add column topic_key text generated always as (lower(btrim(topic))) stored;

with grouped as (
  select
    user_id,
    subject_id,
    topic_key,
    (array_agg(id order by created_at, id))[1] as keeper_id,
    least(sum(miss_count::bigint), 2147483647)::integer as total_miss_count,
    max(last_seen_at) as latest_seen_at,
    (array_agg(source order by last_seen_at desc, created_at desc, id desc))[1]
      as latest_source
  from public.weak_topics
  where deleted_at is null
    and topic_key <> ''
  group by user_id, subject_id, topic_key
  having count(*) > 1
)
update public.weak_topics as weak_topic
set
  miss_count = grouped.total_miss_count,
  last_seen_at = grouped.latest_seen_at,
  source = grouped.latest_source
from grouped
where weak_topic.id = grouped.keeper_id;

with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, subject_id, topic_key
      order by created_at, id
    ) as duplicate_number
  from public.weak_topics
  where deleted_at is null
    and topic_key <> ''
)
update public.weak_topics as weak_topic
set deleted_at = now()
from ranked
where weak_topic.id = ranked.id
  and ranked.duplicate_number > 1;

create unique index weak_topics_active_identity_idx
on public.weak_topics (user_id, subject_id, topic_key) nulls not distinct
where deleted_at is null and topic_key <> '';

create or replace function public.save_quiz_attempt_with_weak_topics(
  p_attempt_id uuid,
  p_quiz_id uuid,
  p_started_at timestamptz,
  p_selected_answers jsonb
)
returns setof public.quiz_attempts
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  authoritative_completed_at timestamptz := now();
  quiz_subject_id uuid;
  stored_question_count integer;
  submitted_answer_count integer;
  correct_answer_count integer;
  authoritative_answers jsonb;
  authoritative_weak_topics jsonb;
  inserted_attempt public.quiz_attempts%rowtype;
  existing_attempt public.quiz_attempts%rowtype;
begin
  if current_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  if p_attempt_id is null or p_quiz_id is null then
    raise exception 'Invalid quiz attempt.' using errcode = '22023';
  end if;

  select subject_id
  into quiz_subject_id
  from public.quizzes
  where id = p_quiz_id
    and user_id = current_user_id
    and deleted_at is null;

  if not found then
    raise exception 'Quiz not found.' using errcode = 'P0002';
  end if;

  select *
  into existing_attempt
  from public.quiz_attempts
  where id = p_attempt_id
    and user_id = current_user_id;

  if found then
    if existing_attempt.quiz_id is distinct from p_quiz_id then
      raise exception 'Quiz attempt id collision.' using errcode = '23505';
    end if;
    return next existing_attempt;
    return;
  end if;

  if p_started_at is null
    or p_started_at > authoritative_completed_at + interval '5 minutes'
    or p_started_at < authoritative_completed_at - interval '24 hours' then
    raise exception 'Invalid quiz attempt.' using errcode = '22023';
  end if;

  if jsonb_typeof(p_selected_answers) is distinct from 'array' then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  select count(*)
  into stored_question_count
  from public.quiz_questions
  where quiz_id = p_quiz_id
    and user_id = current_user_id
    and deleted_at is null;

  if stored_question_count = 0 then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  select count(*)
  into submitted_answer_count
  from jsonb_array_elements(p_selected_answers);

  if submitted_answer_count <> stored_question_count then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_selected_answers) as submitted(value)
    where jsonb_typeof(submitted.value) is distinct from 'object'
      or jsonb_typeof(submitted.value -> 'question_id') is distinct from 'string'
      or jsonb_typeof(submitted.value -> 'selected_answer') is distinct from 'string'
      or submitted.value - 'question_id' - 'selected_answer' <> '{}'::jsonb
      or (submitted.value ->> 'question_id') !~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  ) then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_selected_answers) as submitted(value)
    join public.quiz_questions as question
      on question.id = (submitted.value ->> 'question_id')::uuid
      and question.quiz_id = p_quiz_id
      and question.user_id = current_user_id
      and question.deleted_at is null
    where submitted.value ->> 'selected_answer' <> ''
      and (
        jsonb_typeof(question.options) is distinct from 'array'
        or not (question.options ? (submitted.value ->> 'selected_answer'))
      )
  ) then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  if (
    select count(distinct (submitted.value ->> 'question_id')::uuid)
    from jsonb_array_elements(p_selected_answers) as submitted(value)
  ) <> submitted_answer_count then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_selected_answers) as submitted(value)
    left join public.quiz_questions as question
      on question.id = (submitted.value ->> 'question_id')::uuid
      and question.quiz_id = p_quiz_id
      and question.user_id = current_user_id
      and question.deleted_at is null
    where question.id is null
  ) then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.quiz_questions as question
    where question.quiz_id = p_quiz_id
      and question.user_id = current_user_id
      and question.deleted_at is null
      and not exists (
        select 1
        from jsonb_array_elements(p_selected_answers) as submitted(value)
        where (submitted.value ->> 'question_id')::uuid = question.id
      )
  ) then
    raise exception 'Invalid selected answers.' using errcode = '22023';
  end if;

  with submitted as (
    select
      (value ->> 'question_id')::uuid as question_id,
      value ->> 'selected_answer' as selected_answer,
      ordinality
    from jsonb_array_elements(p_selected_answers) with ordinality
  ), evaluated as (
    select
      submitted.ordinality,
      question.id,
      question.question,
      submitted.selected_answer,
      question.correct_answer,
      submitted.selected_answer <> ''
        and submitted.selected_answer = question.correct_answer as is_correct,
      btrim(question.topic) as topic,
      question.difficulty
    from submitted
    join public.quiz_questions as question
      on question.id = submitted.question_id
      and question.quiz_id = p_quiz_id
      and question.user_id = current_user_id
      and question.deleted_at is null
  )
  select
    count(*) filter (where is_correct),
    jsonb_agg(
      jsonb_build_object(
        'question_id', id,
        'question', question,
        'selected_answer', selected_answer,
        'correct_answer', correct_answer,
        'is_correct', is_correct,
        'topic', topic,
        'difficulty', difficulty
      ) order by ordinality
    )
  into correct_answer_count, authoritative_answers
  from evaluated;

  with submitted as (
    select
      (value ->> 'question_id')::uuid as question_id,
      value ->> 'selected_answer' as selected_answer,
      ordinality
    from jsonb_array_elements(p_selected_answers) with ordinality
  ), missed as (
    select
      lower(btrim(question.topic)) as topic_key,
      btrim(question.topic) as display_topic,
      submitted.ordinality
    from submitted
    join public.quiz_questions as question
      on question.id = submitted.question_id
      and question.quiz_id = p_quiz_id
      and question.user_id = current_user_id
      and question.deleted_at is null
    where (
        submitted.selected_answer = ''
        or submitted.selected_answer <> question.correct_answer
      )
      and btrim(question.topic) <> ''
  ), grouped as (
    select
      topic_key,
      (array_agg(display_topic order by ordinality))[1] as display_topic,
      count(*)::integer as miss_count,
      min(ordinality) as first_ordinality
    from missed
    group by topic_key
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object('topic', display_topic, 'miss_count', miss_count)
      order by first_ordinality
    ),
    '[]'::jsonb
  )
  into authoritative_weak_topics
  from grouped;

  insert into public.quiz_attempts (
    id,
    user_id,
    quiz_id,
    subject_id,
    score,
    total_questions,
    correct_questions,
    started_at,
    completed_at,
    answers,
    weak_topics_snapshot
  ) values (
    p_attempt_id,
    current_user_id,
    p_quiz_id,
    quiz_subject_id,
    round(correct_answer_count * 100.0 / stored_question_count, 2),
    stored_question_count,
    correct_answer_count,
    p_started_at,
    authoritative_completed_at,
    authoritative_answers,
    authoritative_weak_topics
  )
  on conflict (id) do nothing
  returning * into inserted_attempt;

  if inserted_attempt.id is not null then
    insert into public.weak_topics (
      user_id,
      subject_id,
      topic,
      miss_count,
      last_seen_at,
      source
    )
    select
      current_user_id,
      quiz_subject_id,
      item.value ->> 'topic',
      (item.value ->> 'miss_count')::integer,
      authoritative_completed_at,
      jsonb_build_object(
        'quiz_attempt_id', p_attempt_id,
        'quiz_id', p_quiz_id
      )
    from jsonb_array_elements(authoritative_weak_topics) as item(value)
    on conflict (user_id, subject_id, topic_key)
      where deleted_at is null and topic_key <> ''
    do update set
      miss_count = public.weak_topics.miss_count + excluded.miss_count,
      last_seen_at = greatest(
        public.weak_topics.last_seen_at,
        excluded.last_seen_at
      ),
      source = case
        when excluded.last_seen_at >= public.weak_topics.last_seen_at
          then excluded.source
        else public.weak_topics.source
      end;

    return next inserted_attempt;
    return;
  end if;

  select *
  into existing_attempt
  from public.quiz_attempts
  where id = p_attempt_id
    and user_id = current_user_id;

  if not found then
    raise exception 'Quiz attempt id collision.' using errcode = '23505';
  end if;

  if existing_attempt.quiz_id is distinct from p_quiz_id then
    raise exception 'Quiz attempt id collision.' using errcode = '23505';
  end if;

  return next existing_attempt;
end;
$$;

alter function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) owner to postgres;

grant select on table public.quizzes to authenticated;
grant select on table public.quiz_questions to authenticated;
revoke insert, update, delete on table public.quizzes
  from public, authenticated, anon;
revoke insert, update, delete on table public.quiz_questions
  from public, authenticated, anon;
revoke insert, update, delete on table public.quiz_attempts
  from public, authenticated, anon;
revoke insert, update, delete on table public.weak_topics
  from public, authenticated, anon;
grant select on table public.quiz_attempts to authenticated;
grant select on table public.weak_topics to authenticated;

revoke all on function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) from public;
revoke all on function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) from anon;
grant execute on function public.save_quiz_attempt_with_weak_topics(
  uuid, uuid, timestamptz, jsonb
) to authenticated;

notify pgrst, 'reload schema';
