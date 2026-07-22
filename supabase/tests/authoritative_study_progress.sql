\set ON_ERROR_STOP on

create or replace function pg_temp.assert_progress(value boolean,message text)
returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'progress_assertion_failed: %',message; end if; end $$;

do $$ declare p record; begin
  select proowner,prosecdef,provolatile,proconfig into strict p from pg_proc
  where oid='public.get_study_progress(uuid,uuid)'::regprocedure;
  perform pg_temp.assert_progress(
    p.proowner='postgres'::regrole and p.prosecdef and p.provolatile='s'
      and p.proconfig=array['search_path=pg_catalog, public']::text[],
    'owner security definer stable fixed search path');
  perform pg_temp.assert_progress(
    has_function_privilege('authenticated','public.get_study_progress(uuid,uuid)','execute')
      and not has_function_privilege('anon','public.get_study_progress(uuid,uuid)','execute')
      and not has_function_privilege('public','public.get_study_progress(uuid,uuid)','execute'),
    'authenticated-only exact grant');
end $$;

insert into auth.users(id,email) values
('27000000-0000-4000-8000-000000000001','progress-owner@example.test'),
('27000000-0000-4000-8000-000000000002','progress-foreign@example.test');
insert into public.subjects(id,user_id,name) values
('27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000001','Physics'),
('27000000-0000-4000-8000-000000000012','27000000-0000-4000-8000-000000000001','History'),
('27000000-0000-4000-8000-000000000013','27000000-0000-4000-8000-000000000002','Foreign');
insert into public.materials(id,user_id,subject_id,title,kind) values
('27000000-0000-4000-8000-000000000021','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','Mechanics','pasted_text'),
('27000000-0000-4000-8000-000000000022','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000012','Archive source','pasted_text'),
('27000000-0000-4000-8000-000000000023','27000000-0000-4000-8000-000000000002','27000000-0000-4000-8000-000000000013','Foreign material','pasted_text');

insert into public.flashcards(id,user_id,subject_id,material_id,front,back,correct_count,incorrect_count,next_review_at) values
('27000000-0000-4000-8000-000000000031','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','F1','B1',100,0,now()-interval '1 day'),
('27000000-0000-4000-8000-000000000032','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','F2','B2',0,1,now()+interval '1 day'),
('27000000-0000-4000-8000-000000000033','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','F3','B3',2,1,null),
('27000000-0000-4000-8000-000000000034','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','Never','Reviewed',0,0,null),
('27000000-0000-4000-8000-000000000035','27000000-0000-4000-8000-000000000002','27000000-0000-4000-8000-000000000013','27000000-0000-4000-8000-000000000023','Foreign','Card',99,0,now());

insert into public.quizzes(id,user_id,subject_id,material_id,title,question_count) values
('27000000-0000-4000-8000-000000000041','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','Current quiz',5),
('27000000-0000-4000-8000-000000000042','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000012','27000000-0000-4000-8000-000000000022','Historical quiz',2),
('27000000-0000-4000-8000-000000000043','27000000-0000-4000-8000-000000000002','27000000-0000-4000-8000-000000000013','27000000-0000-4000-8000-000000000023','Foreign quiz',10);
insert into public.quiz_attempts(id,user_id,quiz_id,subject_id,score,total_questions,correct_questions,completed_at) values
('27000000-0000-4000-8000-000000000051','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000041','27000000-0000-4000-8000-000000000011',60,5,3,now()-interval '2 hours'),
('27000000-0000-4000-8000-000000000052','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000041','27000000-0000-4000-8000-000000000011',40,5,2,now()-interval '1 hour'),
('27000000-0000-4000-8000-000000000053','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000041','27000000-0000-4000-8000-000000000011',null,5,0,null),
('27000000-0000-4000-8000-000000000054','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000042','27000000-0000-4000-8000-000000000012',50,2,1,now()-interval '3 hours'),
('27000000-0000-4000-8000-000000000055','27000000-0000-4000-8000-000000000002','27000000-0000-4000-8000-000000000043','27000000-0000-4000-8000-000000000013',100,10,10,now());

insert into public.study_sessions(id,user_id,subject_id,material_id,session_type,items_completed,ended_at,metadata) values
('27000000-0000-4000-8000-000000000061','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','flashcards',1,null,'{"version":1,"mode":"all","card_ids":["27000000-0000-4000-8000-000000000031"],"current_index":1}'),
('27000000-0000-4000-8000-000000000062','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','flashcards',1,now()-interval '30 minutes','{"version":1,"mode":"all","card_ids":["27000000-0000-4000-8000-000000000031"],"current_index":1}'),
('27000000-0000-4000-8000-000000000063','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','quiz_mistake_review',0,null,'{"version":1,"attempt_id":"27000000-0000-4000-8000-000000000051","question_ids":[],"current_index":0}'),
('27000000-0000-4000-8000-000000000064','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000012','27000000-0000-4000-8000-000000000022','manual',2,now()-interval '2 hours','{}');

insert into public.weak_topics(id,user_id,subject_id,material_id,topic,miss_count) values
('27000000-0000-4000-8000-000000000071','27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000011','27000000-0000-4000-8000-000000000021','Momentum',2);

select set_config('request.jwt.claim.sub','27000000-0000-4000-8000-000000000001',false);

do $$ declare result jsonb; repeated jsonb; begin
  result:=public.get_study_progress(); repeated:=public.get_study_progress();
  perform pg_temp.assert_progress(result->>'schema_version'='1','closed schema version');
  perform pg_temp.assert_progress((result->'global'->>'quiz_correct_answers')::int=6 and (result->'global'->>'quiz_total_answers')::int=12 and (result->'global'->>'completed_quiz_attempt_count')::int=3,'global completed quiz aggregation and unfinished exclusion');
  perform pg_temp.assert_progress((result->'global'->>'quiz_accuracy')::numeric=50 and (result->'global'->>'latest_quiz_score')::numeric=40,'accuracy and latest score');
  perform pg_temp.assert_progress((result->'global'->>'flashcard_known_review_count')::int=2 and (result->'global'->>'flashcard_not_known_review_count')::int=1 and (result->'global'->>'flashcard_evidence_count')::int=3,'latest-state-per-card prevents repeat inflation');
  perform pg_temp.assert_progress((result->'global'->>'knowledge_score')::numeric=52.86,'combined Bayesian score');
  perform pg_temp.assert_progress((result->'global'->>'weak_card_count')::int=1 and (result->'global'->>'due_card_count')::int=1,'weak and due counts separate');
  perform pg_temp.assert_progress((result->'global'->>'active_session_count')::int=2 and (result->'global'->>'completed_session_count')::int=2,'current sessions include review but do not alter evidence');
  perform pg_temp.assert_progress(jsonb_array_length(result->'subjects')=2 and jsonb_array_length(result->'materials')=2,'per subject and material rows');
  perform pg_temp.assert_progress((result->'subjects'->0->>'subject_name')='History' or (result->'subjects'->1->>'subject_name')='Physics','subject names present');
  perform pg_temp.assert_progress(jsonb_array_length(result->'global'->'cumulative_weak_topics')=1 and result->'global'->'cumulative_weak_topics'->0->>'material_id'='27000000-0000-4000-8000-000000000021','weak topic provenance');
  perform pg_temp.assert_progress((repeated->'global'->>'quiz_evidence_count')=(result->'global'->>'quiz_evidence_count'),'read replay is idempotent');
  perform pg_temp.assert_progress(result::text !~ '"(correct_answer|selected_answer|operation_id|provider|cost|prompt)"[[:space:]]*:','no sensitive/internal payload');
end $$;

do $$ begin
  perform public.get_study_progress('27000000-0000-4000-8000-000000000013',null);
  raise exception 'foreign subject filter accepted';
exception when no_data_found then null; end $$;
do $$ begin
  perform public.get_study_progress(null,'27000000-0000-4000-8000-000000000023');
  raise exception 'foreign material filter accepted';
exception when no_data_found then null; end $$;

delete from public.materials where id='27000000-0000-4000-8000-000000000022';
do $$ declare result jsonb; begin
  result:=public.get_study_progress();
  perform pg_temp.assert_progress((result->'global'->>'quiz_total_answers')::int=10 and (result->'global'->>'knowledge_score')::numeric=52.86,'deleted material excluded from current score');
  perform pg_temp.assert_progress((result->'historical'->>'quiz_total_answers')::int=2 and (result->'historical'->>'completed_quiz_attempt_count')::int=1 and (result->'historical'->>'completed_session_count')::int=1,'deleted material explicitly historical');
end $$;
do $$ declare result jsonb; begin
  result:=public.get_study_progress('27000000-0000-4000-8000-000000000012',null);
  perform pg_temp.assert_progress((result->'global'->>'knowledge_score') is null and jsonb_array_length(result->'materials')=0,'zero evidence returns null for scoped current data');
end $$;

select set_config('request.jwt.claim.sub','27000000-0000-4000-8000-000000000002',false);
do $$ declare result jsonb; begin
  result:=public.get_study_progress();
  perform pg_temp.assert_progress((result->'global'->>'quiz_total_answers')::int=10 and (result->'global'->>'flashcard_evidence_count')::int=1 and jsonb_array_length(result->'subjects')=1,'cross-user ownership filtering');
end $$;

select set_config('request.jwt.claim.sub','',false);
do $$ begin perform public.get_study_progress(); raise exception 'anonymous call accepted'; exception when insufficient_privilege then null; end $$;

delete from auth.users where id in ('27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000002');
select pg_temp.assert_progress(not exists(select 1 from public.quiz_attempts where user_id in ('27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000002')) and not exists(select 1 from public.study_sessions where user_id in ('27000000-0000-4000-8000-000000000001','27000000-0000-4000-8000-000000000002')),'account deletion cascades progress sources');
