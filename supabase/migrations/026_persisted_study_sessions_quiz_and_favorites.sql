-- Phase BC: trusted favorites, durable study sessions, and quiz completion.

alter table public.study_sessions drop constraint study_sessions_session_type_check;
alter table public.study_sessions add constraint study_sessions_session_type_check check (
  session_type in (
    'after_lecture', 'exam_prep', 'flashcards', 'quiz_draft',
    'quiz_mistake_review', 'ai_teacher', 'manual'
  )
);

create unique index study_sessions_one_active_flashcard_mode_idx
on public.study_sessions (
  user_id, material_id, session_type, (metadata->>'mode')
)
where deleted_at is null and ended_at is null and session_type = 'flashcards';

create unique index study_sessions_one_active_quiz_idx
on public.study_sessions (user_id, (metadata->>'attempt_id'), session_type)
where deleted_at is null and ended_at is null
  and session_type in ('quiz_draft', 'quiz_mistake_review');

create or replace function public.favorite_flashcard(p_flashcard_id uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not exists (
    select 1 from public.flashcards f
    join public.materials m on m.id=f.material_id and m.user_id=v_user and m.deleted_at is null
    join public.subjects s on s.id=f.subject_id and s.user_id=v_user and s.deleted_at is null
    where f.id=p_flashcard_id and f.user_id=v_user and f.deleted_at is null
      and m.subject_id=s.id
  ) then raise exception 'flashcard_unavailable' using errcode='P0002'; end if;
  insert into public.favorites(user_id,entity_type,entity_id)
  values(v_user,'flashcard',p_flashcard_id) on conflict do nothing;
end $$;

create or replace function public.unfavorite_flashcard(p_flashcard_id uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not exists (
    select 1 from public.flashcards f
    join public.materials m on m.id=f.material_id and m.user_id=v_user and m.deleted_at is null
    join public.subjects s on s.id=f.subject_id and s.user_id=v_user and s.deleted_at is null
    where f.id=p_flashcard_id and f.user_id=v_user and f.deleted_at is null
      and m.subject_id=s.id
  ) then raise exception 'flashcard_unavailable' using errcode='P0002'; end if;
  delete from public.favorites where user_id=v_user and entity_type='flashcard'
    and entity_id=p_flashcard_id;
end $$;

create or replace function public.list_favorite_flashcards()
returns setof public.flashcards language sql stable security definer
set search_path = pg_catalog, public as $$
  select f.* from public.favorites x
  join public.flashcards f on f.id=x.entity_id and f.user_id=auth.uid() and f.deleted_at is null
  join public.materials m on m.id=f.material_id and m.user_id=auth.uid() and m.deleted_at is null
  join public.subjects s on s.id=f.subject_id and s.user_id=auth.uid() and s.deleted_at is null
  where auth.uid() is not null and x.user_id=auth.uid() and x.entity_type='flashcard'
    and m.subject_id=s.id order by x.created_at desc;
$$;

create or replace function public.favorite_material(p_material_id uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not exists(select 1 from public.materials m where m.id=p_material_id
    and m.user_id=v_user and m.deleted_at is null) then
    raise exception 'material_unavailable' using errcode='P0002';
  end if;
  insert into public.favorites(user_id,entity_type,entity_id)
  values(v_user,'material',p_material_id) on conflict do nothing;
end $$;

create or replace function public.unfavorite_material(p_material_id uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  delete from public.favorites where user_id=v_user and entity_type='material'
    and entity_id=p_material_id;
end $$;

create or replace function public.start_flashcard_training(
  p_session_id uuid, p_material_id uuid, p_mode text, p_card_ids uuid[]
) returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_material public.materials%rowtype;
  v_existing public.study_sessions%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_session_id is null or p_mode not in ('all','first_pass_missed','weak','due','favorites')
    or cardinality(p_card_ids)<1 or cardinality(p_card_ids)<>cardinality(array(select distinct unnest(p_card_ids))) then
    raise exception 'invalid_flashcard_session' using errcode='22023';
  end if;
  select * into v_material from public.materials where id=p_material_id and user_id=v_user
    and deleted_at is null;
  if not found or v_material.subject_id is null then raise exception 'material_unavailable' using errcode='P0002'; end if;
  if exists(select 1 from unnest(p_card_ids) as input(card_id) left join public.flashcards f
      on f.id=input.card_id and f.user_id=v_user and f.material_id=p_material_id
      and f.subject_id=v_material.subject_id and f.deleted_at is null where f.id is null) then
    raise exception 'invalid_flashcard_session' using errcode='22023';
  end if;
  select * into v_existing from public.study_sessions where id=p_session_id and user_id=v_user;
  if found then
    if v_existing.session_type<>'flashcards' or v_existing.material_id<>p_material_id
      or v_existing.metadata->>'mode'<>p_mode
      or v_existing.metadata->'card_ids'<>to_jsonb(p_card_ids) then
      raise exception 'study_session_collision' using errcode='23505';
    end if;
    return next v_existing; return;
  end if;
  select * into v_existing from public.study_sessions where user_id=v_user
    and material_id=p_material_id and session_type='flashcards' and ended_at is null
    and deleted_at is null and metadata->>'mode'=p_mode for update;
  if found then return next v_existing; return; end if;
  insert into public.study_sessions(id,user_id,subject_id,material_id,session_type,metadata)
  values(p_session_id,v_user,v_material.subject_id,p_material_id,'flashcards',jsonb_build_object(
    'version',1,'mode',p_mode,'card_ids',to_jsonb(p_card_ids),'current_index',0,
    'answer_visible',false,'first_pass_missed_ids',case when p_mode='first_pass_missed' then to_jsonb(p_card_ids) else '[]'::jsonb end,
    'graded_card_ids','[]'::jsonb,'known_count',0,'not_known_count',0,
    'status','active','updated_at',now()
  )) returning * into v_existing;
  return next v_existing;
end $$;

create or replace function public.update_flashcard_training(
  p_session_id uuid, p_expected_version integer, p_current_index integer,
  p_answer_visible boolean, p_card_id uuid default null, p_result text default null,
  p_reviewed_at timestamptz default null
) returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_session public.study_sessions%rowtype;
  v_card_ids uuid[]; v_graded uuid[]; v_missed uuid[]; v_pos integer; v_next integer;
  v_known integer; v_not_known integer;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_session from public.study_sessions where id=p_session_id and user_id=v_user
    and session_type='flashcards' and deleted_at is null for update;
  if not found then raise exception 'study_session_unavailable' using errcode='P0002'; end if;
  if v_session.ended_at is not null then return next v_session; return; end if;
  if (v_session.metadata->>'version')::integer=p_expected_version+1 and p_card_id is null
    and p_current_index=(v_session.metadata->>'current_index')::integer
    and p_answer_visible=(v_session.metadata->>'answer_visible')::boolean then
    return next v_session; return;
  end if;
  if (v_session.metadata->>'version')::integer=p_expected_version+1 and p_card_id is not null
    and p_current_index=(v_session.metadata->>'current_index')::integer
    and (v_session.metadata->'graded_card_ids') ? p_card_id::text then
    return next v_session; return;
  end if;
  if (v_session.metadata->>'version')::integer<>p_expected_version then
    raise exception 'study_session_version_conflict' using errcode='40001';
  end if;
  select array_agg(value::uuid order by ordinality) into v_card_ids
    from jsonb_array_elements_text(v_session.metadata->'card_ids') with ordinality;
  select coalesce(array_agg(value::uuid order by ordinality),'{}') into v_graded
    from jsonb_array_elements_text(v_session.metadata->'graded_card_ids') with ordinality;
  select coalesce(array_agg(value::uuid order by ordinality),'{}') into v_missed
    from jsonb_array_elements_text(v_session.metadata->'first_pass_missed_ids') with ordinality;
  v_pos:=(v_session.metadata->>'current_index')::integer;
  if p_current_index<v_pos or p_current_index>cardinality(v_card_ids) then
    raise exception 'invalid_flashcard_progress' using errcode='22023';
  end if;
  v_known:=(v_session.metadata->>'known_count')::integer;
  v_not_known:=(v_session.metadata->>'not_known_count')::integer;
  if p_card_id is not null or p_result is not null then
    if p_card_id is null or p_result not in ('known','not_known') or p_reviewed_at is null
      or p_card_id<>v_card_ids[v_pos+1] or p_current_index<>least(v_pos+1,cardinality(v_card_ids)) then
      raise exception 'invalid_flashcard_grade' using errcode='22023';
    end if;
    if p_card_id=any(v_graded) then
      if p_current_index=v_pos then return next v_session; return; end if;
      raise exception 'duplicate_flashcard_grade' using errcode='22023';
    end if;
    update public.flashcards set
      correct_count=correct_count+case when p_result='known' then 1 else 0 end,
      incorrect_count=incorrect_count+case when p_result='not_known' then 1 else 0 end,
      last_reviewed_at=p_reviewed_at,
      next_review_at=p_reviewed_at+case when p_result='known' then interval '3 days' else interval '1 day' end
    where id=p_card_id and user_id=v_user and material_id=v_session.material_id
      and subject_id=v_session.subject_id and deleted_at is null;
    if not found then raise exception 'flashcard_unavailable' using errcode='P0002'; end if;
    v_graded:=array_append(v_graded,p_card_id);
    if p_result='known' then v_known:=v_known+1; else
      v_not_known:=v_not_known+1;
      if v_session.metadata->>'mode'<>'first_pass_missed' then v_missed:=array_append(v_missed,p_card_id); end if;
    end if;
  elsif p_current_index<>v_pos then
    raise exception 'grade_required_for_progress' using errcode='22023';
  end if;
  update public.study_sessions set items_completed=p_current_index, metadata=jsonb_build_object(
    'version',p_expected_version+1,'mode',v_session.metadata->>'mode',
    'card_ids',to_jsonb(v_card_ids),'current_index',p_current_index,
    'answer_visible',p_answer_visible,'first_pass_missed_ids',to_jsonb(v_missed),
    'graded_card_ids',to_jsonb(v_graded),'known_count',v_known,
    'not_known_count',v_not_known,'status','active','updated_at',now()
  ) where id=p_session_id returning * into v_session;
  return next v_session;
end $$;

create or replace function public.load_active_flashcard_training(p_material_id uuid default null)
returns setof public.study_sessions language sql stable security definer
set search_path = pg_catalog, public as $$
  select s.* from public.study_sessions s where auth.uid() is not null
    and s.user_id=auth.uid() and s.session_type='flashcards' and s.ended_at is null
    and s.deleted_at is null and (p_material_id is null or s.material_id=p_material_id)
  order by s.updated_at desc;
$$;

create or replace function public.finalize_flashcard_training(p_session_id uuid)
returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_session public.study_sessions%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_session from public.study_sessions where id=p_session_id and user_id=v_user
    and session_type='flashcards' and deleted_at is null for update;
  if not found then raise exception 'study_session_unavailable' using errcode='P0002'; end if;
  if v_session.ended_at is null then
    if (v_session.metadata->>'current_index')::integer<>
      jsonb_array_length(v_session.metadata->'card_ids') then
      raise exception 'study_session_incomplete' using errcode='22023';
    end if;
    update public.study_sessions set ended_at=now(),duration_seconds=greatest(0,extract(epoch from now()-started_at)::integer),
      metadata=jsonb_set(jsonb_set(metadata,'{status}','"completed"'::jsonb),'{updated_at}',to_jsonb(now()))
      where id=p_session_id returning * into v_session;
  end if;
  return next v_session;
end $$;

create or replace function public.start_quiz_draft(
  p_attempt_id uuid,p_quiz_id uuid,p_question_ids uuid[],p_option_orders jsonb
) returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_quiz public.quizzes%rowtype; v_session public.study_sessions%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_quiz from public.quizzes where id=p_quiz_id and user_id=v_user and deleted_at is null;
  if not found or p_attempt_id is null or cardinality(p_question_ids)<1
    or cardinality(p_question_ids)<>cardinality(array(select distinct unnest(p_question_ids)))
    or jsonb_typeof(p_option_orders)<>'object' then raise exception 'invalid_quiz_draft' using errcode='22023'; end if;
  if exists(select 1 from unnest(p_question_ids) as input(question_id) left join public.quiz_questions q
    on q.id=input.question_id and q.quiz_id=p_quiz_id and q.user_id=v_user and q.material_id=v_quiz.material_id
    and q.subject_id=v_quiz.subject_id and q.deleted_at is null where q.id is null) or
    (select count(*) from public.quiz_questions q where q.quiz_id=p_quiz_id and q.user_id=v_user and q.deleted_at is null)<>cardinality(p_question_ids) then
    raise exception 'invalid_quiz_draft' using errcode='22023';
  end if;
  if exists(select 1 from public.quiz_questions q where q.id=any(p_question_ids) and
    (not p_option_orders ? q.id::text or jsonb_typeof(p_option_orders->q.id::text)<>'array'
     or (select array_agg(v order by v) from jsonb_array_elements_text(p_option_orders->q.id::text) v)
        is distinct from (select array_agg(v order by v) from jsonb_array_elements_text(q.options) v))) then
    raise exception 'invalid_quiz_option_order' using errcode='22023';
  end if;
  select * into v_session from public.study_sessions where metadata->>'attempt_id'=p_attempt_id::text and user_id=v_user;
  if found then
    if v_session.session_type<>'quiz_draft' or v_session.metadata->>'quiz_id'<>p_quiz_id::text
      or v_session.material_id<>v_quiz.material_id then raise exception 'quiz_attempt_collision' using errcode='23505'; end if;
    return next v_session; return;
  end if;
  insert into public.study_sessions(user_id,subject_id,material_id,session_type,metadata)
  values(v_user,v_quiz.subject_id,v_quiz.material_id,'quiz_draft',jsonb_build_object(
    'version',1,'attempt_id',p_attempt_id,'quiz_id',p_quiz_id,'question_ids',to_jsonb(p_question_ids),
    'option_orders',p_option_orders,'current_index',0,'selected_answers','{}'::jsonb,
    'status','active','started_at',now(),'updated_at',now()
  )) returning * into v_session;
  return next v_session;
end $$;

create or replace function public.update_quiz_draft(
  p_attempt_id uuid,p_expected_version integer,p_current_index integer,
  p_question_id uuid,p_selected_answer text
) returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_session public.study_sessions%rowtype; v_question public.quiz_questions%rowtype;
  v_ids uuid[]; v_answers jsonb; v_old text;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_session from public.study_sessions where metadata->>'attempt_id'=p_attempt_id::text
    and user_id=v_user and session_type='quiz_draft' and deleted_at is null for update;
  if not found then raise exception 'quiz_draft_unavailable' using errcode='P0002'; end if;
  if v_session.ended_at is not null then raise exception 'quiz_draft_completed' using errcode='55000'; end if;
  if (v_session.metadata->>'version')::integer=p_expected_version+1 and
    p_current_index=(v_session.metadata->>'current_index')::integer and
    (p_question_id is null or v_session.metadata->'selected_answers'->>p_question_id::text=p_selected_answer) then
    return next v_session; return;
  end if;
  if (v_session.metadata->>'version')::integer<>p_expected_version then raise exception 'study_session_version_conflict' using errcode='40001'; end if;
  select array_agg(value::uuid order by ordinality) into v_ids from jsonb_array_elements_text(v_session.metadata->'question_ids') with ordinality;
  if p_question_id is null then
    if p_selected_answer is not null or p_current_index<>(v_session.metadata->>'current_index')::integer+1
      or p_current_index>=cardinality(v_ids) then raise exception 'invalid_quiz_progress' using errcode='22023'; end if;
    update public.study_sessions set metadata=jsonb_set(jsonb_set(jsonb_set(metadata,'{version}',to_jsonb(p_expected_version+1)),'{current_index}',to_jsonb(p_current_index)),'{updated_at}',to_jsonb(now()))
      where id=v_session.id returning * into v_session;
    return next v_session; return;
  end if;
  if p_current_index<>(v_session.metadata->>'current_index')::integer or p_current_index>=cardinality(v_ids)
    or p_question_id<>v_ids[p_current_index+1] then raise exception 'invalid_quiz_progress' using errcode='22023'; end if;
  select * into v_question from public.quiz_questions where id=p_question_id and user_id=v_user
    and quiz_id=(v_session.metadata->>'quiz_id')::uuid and deleted_at is null;
  if not found or not(v_question.options ? p_selected_answer) then raise exception 'invalid_quiz_answer' using errcode='22023'; end if;
  v_answers:=v_session.metadata->'selected_answers'; v_old:=v_answers->>p_question_id::text;
  if v_old is not null and v_old<>p_selected_answer then raise exception 'quiz_answer_finalized' using errcode='55000'; end if;
  v_answers:=jsonb_set(v_answers,array[p_question_id::text],to_jsonb(p_selected_answer),true);
  update public.study_sessions set items_completed=(select count(*) from jsonb_object_keys(v_answers)),
    metadata=jsonb_build_object('version',p_expected_version+1,'attempt_id',v_session.metadata->'attempt_id','quiz_id',v_session.metadata->'quiz_id',
      'question_ids',v_session.metadata->'question_ids','option_orders',v_session.metadata->'option_orders',
      'current_index',p_current_index,'selected_answers',v_answers,'status','active',
      'started_at',v_session.metadata->'started_at','updated_at',now())
    where id=v_session.id returning * into v_session;
  return next v_session;
end $$;

create or replace function public.load_active_quiz_draft(p_material_id uuid default null)
returns setof public.study_sessions language sql stable security definer
set search_path = pg_catalog, public as $$
  select s.* from public.study_sessions s where auth.uid() is not null and s.user_id=auth.uid()
    and s.session_type='quiz_draft' and s.ended_at is null and s.deleted_at is null
    and (p_material_id is null or s.material_id=p_material_id) order by s.updated_at desc;
$$;

create or replace function public.finalize_quiz_draft(p_attempt_id uuid)
returns setof public.quiz_attempts language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_session public.study_sessions%rowtype; v_answers jsonb; v_selected jsonb;
  v_attempt public.quiz_attempts%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_session from public.study_sessions where metadata->>'attempt_id'=p_attempt_id::text
    and user_id=v_user and session_type='quiz_draft' and deleted_at is null for update;
  if not found then raise exception 'quiz_draft_unavailable' using errcode='P0002'; end if;
  if v_session.ended_at is not null then
    select * into strict v_attempt from public.quiz_attempts where id=p_attempt_id and user_id=v_user;
    return next v_attempt; return;
  end if;
  v_answers:=v_session.metadata->'selected_answers';
  select jsonb_agg(jsonb_build_object('question_id',value::uuid,'selected_answer',coalesce(v_answers->>value,'')) order by ordinality)
    into v_selected from jsonb_array_elements_text(v_session.metadata->'question_ids') with ordinality;
  select * into strict v_attempt from public.save_quiz_attempt_with_weak_topics(
    p_attempt_id,(v_session.metadata->>'quiz_id')::uuid,
    (v_session.metadata->>'started_at')::timestamptz,v_selected
  );
  update public.study_sessions set quiz_attempt_id=p_attempt_id,ended_at=v_attempt.completed_at,
    duration_seconds=greatest(0,extract(epoch from v_attempt.completed_at-started_at)::integer),
    quiz_score_percent=round(v_attempt.score)::integer,
    metadata=jsonb_set(jsonb_set(metadata,'{status}','"completed"'::jsonb),'{updated_at}',to_jsonb(now()))
    where id=v_session.id;
  return next v_attempt;
end $$;

create or replace function public.start_quiz_mistake_review(p_attempt_id uuid)
returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_attempt public.quiz_attempts%rowtype; v_quiz public.quizzes%rowtype;
  v_ids uuid[]; v_session public.study_sessions%rowtype;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_attempt from public.quiz_attempts where id=p_attempt_id and user_id=v_user
    and completed_at is not null and deleted_at is null;
  if not found then raise exception 'quiz_attempt_unavailable' using errcode='P0002'; end if;
  select * into strict v_quiz from public.quizzes where id=v_attempt.quiz_id and user_id=v_user;
  select coalesce(array_agg((value->>'question_id')::uuid order by ordinality),'{}') into v_ids
    from jsonb_array_elements(v_attempt.answers) with ordinality where not (value->>'is_correct')::boolean;
  if cardinality(v_ids)=0 then raise exception 'no_quiz_mistakes' using errcode='22023'; end if;
  select * into v_session from public.study_sessions where quiz_attempt_id=p_attempt_id and user_id=v_user
    and session_type='quiz_mistake_review' and ended_at is null and deleted_at is null;
  if found then return next v_session; return; end if;
  insert into public.study_sessions(user_id,subject_id,material_id,quiz_attempt_id,session_type,metadata)
  values(v_user,v_attempt.subject_id,v_quiz.material_id,p_attempt_id,'quiz_mistake_review',jsonb_build_object(
    'version',1,'attempt_id',p_attempt_id,'question_ids',to_jsonb(v_ids),'current_index',0,'reviewed_question_ids','[]'::jsonb,
    'status','active','updated_at',now())) returning * into v_session;
  return next v_session;
end $$;

create or replace function public.update_quiz_mistake_review(
  p_attempt_id uuid,p_expected_version integer,p_current_index integer
) returns setof public.study_sessions language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_user uuid:=auth.uid(); v_session public.study_sessions%rowtype; v_count integer;
begin
  if v_user is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_session from public.study_sessions where quiz_attempt_id=p_attempt_id and user_id=v_user
    and session_type='quiz_mistake_review' and deleted_at is null for update;
  if not found then raise exception 'mistake_review_unavailable' using errcode='P0002'; end if;
  if v_session.ended_at is not null then return next v_session; return; end if;
  v_count:=jsonb_array_length(v_session.metadata->'question_ids');
  if (v_session.metadata->>'version')::integer=p_expected_version+1 and
    p_current_index=(v_session.metadata->>'current_index')::integer then
    return next v_session; return;
  end if;
  if (v_session.metadata->>'version')::integer<>p_expected_version or
    p_current_index<(v_session.metadata->>'current_index')::integer or p_current_index>v_count then
    raise exception 'invalid_mistake_review_progress' using errcode='22023';
  end if;
  update public.study_sessions set items_completed=p_current_index,
    ended_at=case when p_current_index=v_count then now() else null end,
    metadata=jsonb_build_object('version',p_expected_version+1,'attempt_id',metadata->'attempt_id','question_ids',metadata->'question_ids',
      'current_index',p_current_index,'reviewed_question_ids',
      (select coalesce(jsonb_agg(value order by ordinality),'[]') from jsonb_array_elements(metadata->'question_ids') with ordinality where ordinality<=p_current_index),
      'status',case when p_current_index=v_count then 'completed' else 'active' end,'updated_at',now())
    where id=v_session.id returning * into v_session;
  return next v_session;
end $$;

create or replace function public.load_active_quiz_mistake_review(p_material_id uuid default null)
returns setof public.study_sessions language sql stable security definer
set search_path = pg_catalog, public as $$
  select s.* from public.study_sessions s where auth.uid() is not null and s.user_id=auth.uid()
    and s.session_type='quiz_mistake_review' and s.ended_at is null and s.deleted_at is null
    and (p_material_id is null or s.material_id=p_material_id) order by s.updated_at desc;
$$;

create or replace function public.read_recent_completed_study_sessions(p_limit integer default 20)
returns setof public.study_sessions language sql stable security definer
set search_path = pg_catalog, public as $$
  select s.* from public.study_sessions s where auth.uid() is not null and s.user_id=auth.uid()
    and s.ended_at is not null and s.deleted_at is null order by s.ended_at desc
    limit least(greatest(coalesce(p_limit,20),1),50);
$$;

create or replace function public.complete_quiz_generation_internal(
  p_user_id uuid,p_operation_id uuid,p_material_id uuid,p_title text,p_questions jsonb,
  p_model text,p_input_tokens integer,p_output_tokens integer,p_actual_cost_usd numeric
) returns table(id uuid,quiz_id uuid,subject_id uuid,material_id uuid,question text,
  options jsonb,correct_answer text,explanation text,topic text,difficulty text,sort_order integer)
language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_op public.study_generation_operations%rowtype; v_material public.materials%rowtype;
  v_quiz uuid; v_q jsonb; v_id uuid; v_ids uuid[]='{}'; v_index integer:=0;
begin
  select * into v_op from public.study_generation_operations where operation_id=p_operation_id
    and user_id=p_user_id and material_id=p_material_id for update;
  if not found then raise exception 'generation_operation_unavailable'; end if;
  if v_op.status='succeeded' then
    return query select q.id,q.quiz_id,q.subject_id,q.material_id,q.question,q.options,q.correct_answer,q.explanation,q.topic,q.difficulty,q.sort_order
      from public.quiz_questions q where q.id=any(v_op.result_ids) order by q.sort_order; return;
  end if;
  if v_op.status<>'reserved' or v_op.provider_started_at is null or v_op.feature<>'generate_quiz_questions'
    or jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)<>v_op.requested_quantity
    or nullif(btrim(p_title),'') is null or length(p_title)>500
    or p_input_tokens<0 or p_output_tokens<0 or p_actual_cost_usd<0 or p_actual_cost_usd>v_op.reserved_cost_usd then
    raise exception 'invalid_generation_completion'; end if;
  select * into strict v_material from public.materials where id=p_material_id and user_id=p_user_id and deleted_at is null;
  for v_q in select value from jsonb_array_elements(p_questions) loop
    if jsonb_typeof(v_q)<>'object' or
      (select array_agg(key order by key) from jsonb_object_keys(v_q) key)<>array['correct_answer','difficulty','explanation','options','question','topic']::text[]
      or nullif(btrim(v_q->>'question'),'') is null or length(v_q->>'question')>2000
      or jsonb_typeof(v_q->'options')<>'array' or jsonb_array_length(v_q->'options')<2
      or jsonb_array_length(v_q->'options')>8 or
      (select count(*) from jsonb_array_elements_text(v_q->'options'))<>(select count(distinct value) from jsonb_array_elements_text(v_q->'options'))
      or not(v_q->'options' ? (v_q->>'correct_answer')) or nullif(btrim(v_q->>'explanation'),'') is null
      or nullif(btrim(v_q->>'topic'),'') is null or v_q->>'difficulty' not in ('easy','medium','exam') then
      raise exception 'invalid_quiz_payload'; end if;
  end loop;
  insert into public.quizzes(user_id,subject_id,material_id,title,quiz_type,question_count,metadata)
  values(p_user_id,v_material.subject_id,p_material_id,btrim(p_title),'practice',jsonb_array_length(p_questions),
    jsonb_build_object('source','generate-quiz','model',p_model,'operation_id',p_operation_id)) returning public.quizzes.id into v_quiz;
  for v_q in select value from jsonb_array_elements(p_questions) loop
    insert into public.quiz_questions(user_id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order,metadata)
    values(p_user_id,v_quiz,v_material.subject_id,p_material_id,btrim(v_q->>'question'),v_q->'options',v_q->>'correct_answer',
      btrim(v_q->>'explanation'),btrim(v_q->>'topic'),v_q->>'difficulty',v_index,
      jsonb_build_object('source','generate-quiz','model',p_model,'operation_id',p_operation_id)) returning public.quiz_questions.id into v_id;
    v_ids:=array_append(v_ids,v_id); v_index:=v_index+1;
  end loop;
  insert into public.usage_logs(user_id,event_type,feature,model,quantity,input_tokens,output_tokens,estimated_cost_usd,status,metadata)
  values(p_user_id,'generate_quiz_questions','generate_quiz_questions',p_model,v_index,p_input_tokens,p_output_tokens,p_actual_cost_usd,'succeeded',
    jsonb_build_object('operation_id',p_operation_id,'reservation_log_id',v_op.usage_log_id,'quiz_id',v_quiz));
  update public.daily_usage_limits set estimated_openai_cost_usd=greatest(0,estimated_openai_cost_usd-(v_op.reserved_cost_usd-p_actual_cost_usd)),updated_at=now()
    where user_id=p_user_id and usage_date=v_op.usage_date;
  update public.study_generation_operations set status='succeeded',result_ids=v_ids,completed_at=now(),updated_at=now() where operation_id=p_operation_id;
  return query select q.id,q.quiz_id,q.subject_id,q.material_id,q.question,q.options,q.correct_answer,q.explanation,q.topic,q.difficulty,q.sort_order
    from public.quiz_questions q where q.id=any(v_ids) order by q.sort_order;
end $$;

revoke insert,delete on table public.favorites from authenticated;
revoke update(correct_count,incorrect_count,last_reviewed_at,next_review_at) on public.flashcards from authenticated;
revoke all on table public.study_sessions from public,anon,authenticated;

do $$ declare f record; begin
  for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'favorite_flashcard','unfavorite_flashcard','list_favorite_flashcards','favorite_material','unfavorite_material',
      'start_flashcard_training','update_flashcard_training','load_active_flashcard_training','finalize_flashcard_training',
      'start_quiz_draft','update_quiz_draft','load_active_quiz_draft','finalize_quiz_draft',
      'start_quiz_mistake_review','update_quiz_mistake_review','load_active_quiz_mistake_review',
      'read_recent_completed_study_sessions','complete_quiz_generation_internal'
    ) loop execute format('alter function %s owner to postgres',f.sig); execute format('revoke all on function %s from public,anon,authenticated',f.sig); end loop;
end $$;

grant execute on function public.favorite_flashcard(uuid),public.unfavorite_flashcard(uuid),
  public.list_favorite_flashcards(),public.favorite_material(uuid),public.unfavorite_material(uuid),
  public.start_flashcard_training(uuid,uuid,text,uuid[]),
  public.update_flashcard_training(uuid,integer,integer,boolean,uuid,text,timestamptz),
  public.load_active_flashcard_training(uuid),public.finalize_flashcard_training(uuid),
  public.start_quiz_draft(uuid,uuid,uuid[],jsonb),public.update_quiz_draft(uuid,integer,integer,uuid,text),
  public.load_active_quiz_draft(uuid),public.finalize_quiz_draft(uuid),
  public.start_quiz_mistake_review(uuid),public.update_quiz_mistake_review(uuid,integer,integer),
  public.load_active_quiz_mistake_review(uuid),public.read_recent_completed_study_sessions(integer)
to authenticated;

grant execute on function public.complete_quiz_generation_internal(uuid,uuid,uuid,text,jsonb,text,integer,integer,numeric)
to service_role;

notify pgrst,'reload schema';
