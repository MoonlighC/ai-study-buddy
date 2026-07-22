-- Authoritative, read-only study progress for the signed-in user.
--
-- Knowledge score (all terms are current, owned, non-deleted material data):
--   flashcards = 100 * (known cards + 2) / (reviewed cards + 4)
--   quizzes    = 100 * (correct answers + 2) / (total answers + 4)
--   both       = 60% quizzes + 40% flashcards
-- A reviewed card contributes exactly one item of evidence. Its latest state is
-- not-known when incorrect_count > correct_count and known otherwise.

create or replace function public.get_study_progress(
  p_subject_id uuid default null,
  p_material_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := statement_timestamp();
  v_global jsonb;
  v_subjects jsonb;
  v_materials jsonb;
  v_historical jsonb;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if p_subject_id is not null and not exists (
    select 1 from public.subjects s
    where s.id = p_subject_id and s.user_id = v_user and s.deleted_at is null
  ) then
    raise exception 'subject_unavailable' using errcode = 'P0002';
  end if;

  if p_material_id is not null and not exists (
    select 1 from public.materials m
    join public.subjects s on s.id = m.subject_id and s.user_id = v_user and s.deleted_at is null
    where m.id = p_material_id and m.user_id = v_user and m.deleted_at is null
      and (p_subject_id is null or m.subject_id = p_subject_id)
  ) then
    raise exception 'material_unavailable' using errcode = 'P0002';
  end if;

  with
  scoped_materials as (
    select m.id, m.subject_id, m.title
    from public.materials m
    join public.subjects s on s.id = m.subject_id and s.user_id = v_user and s.deleted_at is null
    where m.user_id = v_user and m.deleted_at is null
      and (p_subject_id is null or m.subject_id = p_subject_id)
      and (p_material_id is null or m.id = p_material_id)
  ),
  quiz_evidence as (
    select a.id, a.subject_id, q.material_id, a.correct_questions, a.total_questions,
      a.score, a.completed_at
    from public.quiz_attempts a
    join public.quizzes q on q.id = a.quiz_id and q.user_id = v_user and q.deleted_at is null
    join scoped_materials m on m.id = q.material_id and m.subject_id = a.subject_id
    where a.user_id = v_user and a.completed_at is not null and a.deleted_at is null
  ),
  card_states as (
    select f.id, f.subject_id, f.material_id,
      case when f.incorrect_count > f.correct_count then false else true end as known
    from public.flashcards f
    join scoped_materials m on m.id = f.material_id and m.subject_id = f.subject_id
    where f.user_id = v_user and f.deleted_at is null
      and f.correct_count + f.incorrect_count > 0
  ),
  counts as (
    select
      coalesce((select sum(correct_questions) from quiz_evidence), 0)::integer as quiz_correct,
      coalesce((select sum(total_questions) from quiz_evidence), 0)::integer as quiz_total,
      (select count(*) from quiz_evidence)::integer as attempt_count,
      (select score from quiz_evidence order by completed_at desc, id desc limit 1) as latest_score,
      (select count(*) from card_states where known)::integer as known_cards,
      (select count(*) from card_states where not known)::integer as not_known_cards
  ),
  scores as (
    select c.*,
      case when c.quiz_total > 0 then round(100.0 * (c.quiz_correct + 2) / (c.quiz_total + 4), 2) end as quiz_score,
      case when c.known_cards + c.not_known_cards > 0
        then round(100.0 * (c.known_cards + 2) / (c.known_cards + c.not_known_cards + 4), 2)
      end as flashcard_score
    from counts c
  ),
  weak_topic_rows as (
    select w.id, w.subject_id, coalesce(w.material_id, source_quiz.material_id) as material_id,
      w.topic, w.miss_count, w.last_seen_at
    from public.weak_topics w
    left join public.quizzes source_quiz
      on source_quiz.id = case when w.source->>'quiz_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then (w.source->>'quiz_id')::uuid end and source_quiz.user_id = v_user
    where w.user_id = v_user and w.deleted_at is null and w.topic_key <> ''
  ),
  current_weak_topics as (
    select w.*, m.title as material_title, s.name as subject_name
    from weak_topic_rows w
    join scoped_materials m on m.id = w.material_id and m.subject_id = w.subject_id
    join public.subjects s on s.id = w.subject_id and s.user_id = v_user and s.deleted_at is null
  ),
  current_sessions as (
    select ss.*, sm.title as material_title, s.name as subject_name
    from public.study_sessions ss
    join scoped_materials sm on sm.id = ss.material_id and sm.subject_id = ss.subject_id
    join public.subjects s on s.id = ss.subject_id and s.user_id = v_user and s.deleted_at is null
    where ss.user_id = v_user and ss.deleted_at is null
  ),
  score_row as (
    select s.*,
      case
        when s.quiz_total > 0 and s.known_cards + s.not_known_cards > 0
          then round(s.quiz_score * 0.60 + s.flashcard_score * 0.40, 2)
        when s.quiz_total > 0 then s.quiz_score
        when s.known_cards + s.not_known_cards > 0 then s.flashcard_score
      end as knowledge_score
    from scores s
  )
  select jsonb_build_object(
    'quiz_correct_answers', score_row.quiz_correct,
    'quiz_total_answers', score_row.quiz_total,
    'quiz_accuracy', case when score_row.quiz_total > 0
      then round(100.0 * score_row.quiz_correct / score_row.quiz_total, 2) end,
    'completed_quiz_attempt_count', score_row.attempt_count,
    'latest_quiz_score', score_row.latest_score,
    'flashcard_known_review_count', score_row.known_cards,
    'flashcard_not_known_review_count', score_row.not_known_cards,
    'weak_card_count', (select count(*) from public.flashcards f join scoped_materials m on m.id=f.material_id
      where f.user_id=v_user and f.deleted_at is null and f.incorrect_count > f.correct_count),
    'due_card_count', (select count(*) from public.flashcards f join scoped_materials m on m.id=f.material_id
      where f.user_id=v_user and f.deleted_at is null and f.next_review_at is not null and f.next_review_at <= v_now),
    'active_session_count', (select count(*) from current_sessions where ended_at is null),
    'completed_session_count', (select count(*) from current_sessions where ended_at is not null),
    'active_sessions', coalesce((select jsonb_agg(jsonb_build_object(
      'session_id', id, 'session_type', session_type, 'subject_id', subject_id,
      'subject_name', subject_name, 'material_id', material_id, 'material_title', material_title,
      'current_progress', items_completed,
      'total_items', case when session_type='flashcards' then jsonb_array_length(metadata->'card_ids')
        when session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(metadata->'question_ids') else items_completed end,
      'updated_at', updated_at, 'quiz_attempt_id', quiz_attempt_id
    ) order by updated_at desc) from current_sessions where ended_at is null), '[]'::jsonb),
    'recent_completed_sessions', coalesce((select jsonb_agg(item) from (select jsonb_build_object(
      'session_id', id, 'session_type', session_type, 'subject_id', subject_id,
      'subject_name', subject_name, 'material_id', material_id, 'material_title', material_title,
      'current_progress', items_completed,
      'total_items', case when session_type='flashcards' then jsonb_array_length(metadata->'card_ids')
        when session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(metadata->'question_ids') else items_completed end,
      'completed_at', ended_at, 'quiz_attempt_id', quiz_attempt_id
    ) as item from current_sessions where ended_at is not null order by ended_at desc limit 10) recent), '[]'::jsonb),
    'cumulative_weak_topics', coalesce((select jsonb_agg(jsonb_build_object(
      'weak_topic_id', id, 'topic', topic, 'miss_count', miss_count, 'last_seen_at', last_seen_at,
      'subject_id', subject_id, 'subject_name', subject_name,
      'material_id', material_id, 'material_title', material_title
    ) order by miss_count desc, last_seen_at desc) from current_weak_topics), '[]'::jsonb),
    'knowledge_score', score_row.knowledge_score,
    'quiz_evidence_count', score_row.quiz_total,
    'flashcard_evidence_count', score_row.known_cards + score_row.not_known_cards
  ) into v_global from score_row;

  with scoped_subjects as (
    select s.id, s.name from public.subjects s
    where s.user_id=v_user and s.deleted_at is null
      and (p_subject_id is null or s.id=p_subject_id)
      and (p_material_id is null or exists(select 1 from public.materials m where m.id=p_material_id and m.subject_id=s.id and m.user_id=v_user and m.deleted_at is null))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'subject_id', s.id, 'subject_name', s.name,
    'quiz_accuracy', x.quiz_accuracy, 'attempt_count', x.attempt_count,
    'flashcard_known_review_count', x.known_cards, 'flashcard_not_known_review_count', x.not_known_cards,
    'weak_card_count', x.weak_cards, 'due_card_count', x.due_cards,
    'weak_topics', x.weak_topics, 'active_sessions', x.active_sessions,
    'recent_completed_sessions', x.recent_sessions, 'knowledge_score', x.knowledge_score,
    'quiz_evidence_count', x.quiz_total, 'flashcard_evidence_count', x.known_cards+x.not_known_cards
  ) order by s.name, s.id), '[]'::jsonb) into v_subjects
  from scoped_subjects s
  cross join lateral (
    with mats as (select m.id,m.title from public.materials m where m.user_id=v_user and m.subject_id=s.id and m.deleted_at is null and (p_material_id is null or m.id=p_material_id)),
    qe as (select a.* from public.quiz_attempts a join public.quizzes q on q.id=a.quiz_id and q.user_id=v_user and q.deleted_at is null join mats m on m.id=q.material_id where a.user_id=v_user and a.completed_at is not null and a.deleted_at is null),
    cs as (select f.*, (f.incorrect_count<=f.correct_count) known from public.flashcards f join mats m on m.id=f.material_id where f.user_id=v_user and f.deleted_at is null and f.correct_count+f.incorrect_count>0),
    c as (select coalesce((select sum(correct_questions) from qe),0)::int qc,coalesce((select sum(total_questions) from qe),0)::int qt,(select count(*) from qe)::int ac,(select count(*) from cs where known)::int kc,(select count(*) from cs where not known)::int nc),
    sc as (select *,case when qt>0 then 100.0*(qc+2)/(qt+4) end qs,case when kc+nc>0 then 100.0*(kc+2)/(kc+nc+4) end fs from c)
    select case when qt>0 then round(100.0*qc/qt,2) end quiz_accuracy, ac attempt_count, kc known_cards,nc not_known_cards,
      (select count(*) from public.flashcards f join mats m on m.id=f.material_id where f.user_id=v_user and f.deleted_at is null and f.incorrect_count>f.correct_count) weak_cards,
      (select count(*) from public.flashcards f join mats m on m.id=f.material_id where f.user_id=v_user and f.deleted_at is null and f.next_review_at is not null and f.next_review_at<=v_now) due_cards,
      coalesce((select jsonb_agg(jsonb_build_object('weak_topic_id',w.id,'topic',w.topic,'miss_count',w.miss_count,'material_id',coalesce(w.material_id,q.material_id),'material_title',m.title,'subject_id',s.id,'subject_name',s.name,'last_seen_at',w.last_seen_at) order by w.miss_count desc,w.last_seen_at desc) from public.weak_topics w left join public.quizzes q on q.id=case when w.source->>'quiz_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then (w.source->>'quiz_id')::uuid end and q.user_id=v_user join mats m on m.id=coalesce(w.material_id,q.material_id) where w.user_id=v_user and w.subject_id=s.id and w.deleted_at is null and w.topic_key<>''),'[]') weak_topics,
      coalesce((select jsonb_agg(jsonb_build_object('session_id',ss.id,'session_type',ss.session_type,'subject_id',s.id,'subject_name',s.name,'material_id',ss.material_id,'material_title',m.title,'current_progress',ss.items_completed,'total_items',case when ss.session_type='flashcards' then jsonb_array_length(ss.metadata->'card_ids') when ss.session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(ss.metadata->'question_ids') else ss.items_completed end,'updated_at',ss.updated_at,'quiz_attempt_id',ss.quiz_attempt_id) order by ss.updated_at desc) from public.study_sessions ss join mats m on m.id=ss.material_id where ss.user_id=v_user and ss.subject_id=s.id and ss.deleted_at is null and ss.ended_at is null),'[]') active_sessions,
      coalesce((select jsonb_agg(item) from (select jsonb_build_object('session_id',ss.id,'session_type',ss.session_type,'subject_id',s.id,'subject_name',s.name,'material_id',ss.material_id,'material_title',m.title,'current_progress',ss.items_completed,'total_items',case when ss.session_type='flashcards' then jsonb_array_length(ss.metadata->'card_ids') when ss.session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(ss.metadata->'question_ids') else ss.items_completed end,'completed_at',ss.ended_at,'quiz_attempt_id',ss.quiz_attempt_id) item from public.study_sessions ss join mats m on m.id=ss.material_id where ss.user_id=v_user and ss.subject_id=s.id and ss.deleted_at is null and ss.ended_at is not null order by ss.ended_at desc limit 5) r),'[]') recent_sessions,
      case when qt>0 and kc+nc>0 then round(qs*.60+fs*.40,2) when qt>0 then round(qs,2) when kc+nc>0 then round(fs,2) end knowledge_score,
      qt quiz_total
    from sc
  ) x;

  with scoped_materials as (
    select m.id,m.title,m.subject_id,s.name subject_name from public.materials m join public.subjects s on s.id=m.subject_id and s.user_id=v_user and s.deleted_at is null
    where m.user_id=v_user and m.deleted_at is null and (p_subject_id is null or m.subject_id=p_subject_id) and (p_material_id is null or m.id=p_material_id)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'material_id',m.id,'material_title',m.title,'subject_id',m.subject_id,'subject_name',m.subject_name,
    'quiz_accuracy',x.quiz_accuracy,'attempt_count',x.attempt_count,
    'flashcard_known_review_count',x.known_cards,'flashcard_not_known_review_count',x.not_known_cards,
    'weak_card_count',x.weak_cards,'due_card_count',x.due_cards,'weak_topics',x.weak_topics,
    'active_sessions',x.active_sessions,'recent_completed_sessions',x.recent_sessions,
    'knowledge_score',x.knowledge_score,'quiz_evidence_count',x.quiz_total,
    'flashcard_evidence_count',x.known_cards+x.not_known_cards
  ) order by m.title,m.id),'[]'::jsonb) into v_materials
  from scoped_materials m cross join lateral (
    with qe as (select a.* from public.quiz_attempts a join public.quizzes q on q.id=a.quiz_id and q.user_id=v_user and q.material_id=m.id and q.deleted_at is null where a.user_id=v_user and a.completed_at is not null and a.deleted_at is null),
    cs as (select f.*,(f.incorrect_count<=f.correct_count) known from public.flashcards f where f.user_id=v_user and f.material_id=m.id and f.deleted_at is null and f.correct_count+f.incorrect_count>0),
    c as (select coalesce((select sum(correct_questions) from qe),0)::int qc,coalesce((select sum(total_questions) from qe),0)::int qt,(select count(*) from qe)::int ac,(select count(*) from cs where known)::int kc,(select count(*) from cs where not known)::int nc),
    sc as (select *,case when qt>0 then 100.0*(qc+2)/(qt+4) end qs,case when kc+nc>0 then 100.0*(kc+2)/(kc+nc+4) end fs from c)
    select case when qt>0 then round(100.0*qc/qt,2) end quiz_accuracy,ac attempt_count,kc known_cards,nc not_known_cards,
      (select count(*) from public.flashcards f where f.user_id=v_user and f.material_id=m.id and f.deleted_at is null and f.incorrect_count>f.correct_count) weak_cards,
      (select count(*) from public.flashcards f where f.user_id=v_user and f.material_id=m.id and f.deleted_at is null and f.next_review_at is not null and f.next_review_at<=v_now) due_cards,
      coalesce((select jsonb_agg(jsonb_build_object('weak_topic_id',w.id,'topic',w.topic,'miss_count',w.miss_count,'subject_id',m.subject_id,'subject_name',m.subject_name,'material_id',m.id,'material_title',m.title,'last_seen_at',w.last_seen_at) order by w.miss_count desc,w.last_seen_at desc) from public.weak_topics w left join public.quizzes q on q.id=case when w.source->>'quiz_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then (w.source->>'quiz_id')::uuid end and q.user_id=v_user where w.user_id=v_user and coalesce(w.material_id,q.material_id)=m.id and w.deleted_at is null and w.topic_key<>''),'[]') weak_topics,
      coalesce((select jsonb_agg(jsonb_build_object('session_id',ss.id,'session_type',ss.session_type,'subject_id',m.subject_id,'subject_name',m.subject_name,'material_id',m.id,'material_title',m.title,'current_progress',ss.items_completed,'total_items',case when ss.session_type='flashcards' then jsonb_array_length(ss.metadata->'card_ids') when ss.session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(ss.metadata->'question_ids') else ss.items_completed end,'updated_at',ss.updated_at,'quiz_attempt_id',ss.quiz_attempt_id) order by ss.updated_at desc) from public.study_sessions ss where ss.user_id=v_user and ss.material_id=m.id and ss.deleted_at is null and ss.ended_at is null),'[]') active_sessions,
      coalesce((select jsonb_agg(item) from (select jsonb_build_object('session_id',ss.id,'session_type',ss.session_type,'subject_id',m.subject_id,'subject_name',m.subject_name,'material_id',m.id,'material_title',m.title,'current_progress',ss.items_completed,'total_items',case when ss.session_type='flashcards' then jsonb_array_length(ss.metadata->'card_ids') when ss.session_type in ('quiz_draft','quiz_mistake_review') then jsonb_array_length(ss.metadata->'question_ids') else ss.items_completed end,'completed_at',ss.ended_at,'quiz_attempt_id',ss.quiz_attempt_id) item from public.study_sessions ss where ss.user_id=v_user and ss.material_id=m.id and ss.deleted_at is null and ss.ended_at is not null order by ss.ended_at desc limit 5) r),'[]') recent_sessions,
      case when qt>0 and kc+nc>0 then round(qs*.60+fs*.40,2) when qt>0 then round(qs,2) when kc+nc>0 then round(fs,2) end knowledge_score,qt quiz_total
    from sc
  ) x;

  with historical_attempts as (
    select a.* from public.quiz_attempts a
    left join public.quizzes q on q.id=a.quiz_id and q.user_id=v_user and q.deleted_at is null
    left join public.materials m on m.id=q.material_id and m.user_id=v_user and m.deleted_at is null
    left join public.subjects s on s.id=m.subject_id and s.user_id=v_user and s.deleted_at is null
    where a.user_id=v_user and a.completed_at is not null and a.deleted_at is null
      and (q.id is null or m.id is null or s.id is null)
      and (p_subject_id is null or a.subject_id=p_subject_id)
      and (p_material_id is null or q.material_id=p_material_id)
  ), historical_sessions as (
    select ss.* from public.study_sessions ss
    left join public.materials m on m.id=ss.material_id and m.user_id=v_user and m.deleted_at is null
    left join public.subjects s on s.id=ss.subject_id and s.user_id=v_user and s.deleted_at is null
    where ss.user_id=v_user and ss.deleted_at is null and ss.ended_at is not null
      and (m.id is null or s.id is null)
      and (p_subject_id is null or ss.subject_id=p_subject_id)
      and (p_material_id is null or ss.material_id=p_material_id)
  )
  select jsonb_build_object(
    'label','Deleted or detached material activity',
    'quiz_correct_answers',coalesce((select sum(correct_questions) from historical_attempts),0),
    'quiz_total_answers',coalesce((select sum(total_questions) from historical_attempts),0),
    'completed_quiz_attempt_count',(select count(*) from historical_attempts),
    'completed_session_count',(select count(*) from historical_sessions),
    'recent_completed_sessions',coalesce((select jsonb_agg(item) from (select jsonb_build_object(
      'session_id',id,'session_type',session_type,'subject_id',subject_id,'material_id',material_id,
      'current_progress',items_completed,'completed_at',ended_at,'quiz_attempt_id',quiz_attempt_id
    ) item from historical_sessions order by ended_at desc limit 10) r),'[]'::jsonb)
  ) into v_historical;

  return jsonb_build_object(
    'schema_version',1,
    'generated_at',v_now,
    'scope',jsonb_build_object('subject_id',p_subject_id,'material_id',p_material_id),
    'global',v_global,
    'subjects',v_subjects,
    'materials',v_materials,
    'historical',v_historical
  );
end;
$$;

comment on function public.get_study_progress(uuid,uuid) is
  'Version 1 authoritative progress. Current scores exclude deleted/detached material activity and count each reviewed flashcard once by latest state.';

alter function public.get_study_progress(uuid,uuid) owner to postgres;
revoke all on function public.get_study_progress(uuid,uuid) from public, anon, authenticated;
grant execute on function public.get_study_progress(uuid,uuid) to authenticated;
