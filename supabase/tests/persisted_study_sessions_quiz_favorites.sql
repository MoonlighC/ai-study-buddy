\set ON_ERROR_STOP on

create or replace function pg_temp.assert_bc(value boolean,message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'phase_bc_assertion_failed: %',message; end if; end $$;

do $$ declare signature text; begin
  foreach signature in array array[
    'public.favorite_flashcard(uuid)','public.unfavorite_flashcard(uuid)','public.list_favorite_flashcards()',
    'public.start_flashcard_training(uuid,uuid,text,uuid[])','public.update_flashcard_training(uuid,integer,integer,boolean,uuid,text,timestamptz)',
    'public.load_active_flashcard_training(uuid)','public.finalize_flashcard_training(uuid)','public.start_quiz_draft(uuid,uuid,uuid[],jsonb)',
    'public.update_quiz_draft(uuid,integer,integer,uuid,text)','public.finalize_quiz_draft(uuid)',
    'public.load_active_quiz_draft(uuid)','public.start_quiz_mistake_review(uuid)','public.update_quiz_mistake_review(uuid,integer,integer)',
    'public.load_active_quiz_mistake_review(uuid)','public.read_recent_completed_study_sessions(integer)'
  ] loop
    perform pg_temp.assert_bc(has_function_privilege('authenticated',signature,'execute') and not has_function_privilege('anon',signature,'execute'),signature||' exact grant');
  end loop;
  perform pg_temp.assert_bc(not has_table_privilege('authenticated','public.favorites','insert') and not has_table_privilege('authenticated','public.favorites','delete'),'no broad favorite writes');
  perform pg_temp.assert_bc(not has_column_privilege('authenticated','public.flashcards','correct_count','update'),'no direct grading');
  perform pg_temp.assert_bc(has_function_privilege('service_role','public.complete_quiz_generation_internal(uuid,uuid,uuid,text,jsonb,text,integer,integer,numeric)','execute') and not has_function_privilege('authenticated','public.complete_quiz_generation_internal(uuid,uuid,uuid,text,jsonb,text,integer,integer,numeric)','execute'),'quiz completion service only');
end $$;

insert into auth.users(id,email) values
('26262626-2626-4626-8626-262626262626','bc-owner@example.test'),
('27272727-2727-4727-8727-272727272727','bc-foreign@example.test');
insert into public.subjects(id,user_id,name) values
('26262626-2626-4626-8626-262626262601','26262626-2626-4626-8626-262626262626','Owner'),
('27272727-2727-4727-8727-272727272701','27272727-2727-4727-8727-272727272727','Foreign');
insert into public.materials(id,user_id,subject_id,title,kind,source_kind,content_text) values
('26262626-2626-4626-8626-262626262602','26262626-2626-4626-8626-262626262626','26262626-2626-4626-8626-262626262601','Owner material','pasted_text','manual',repeat('a',100)),
('27272727-2727-4727-8727-272727272702','27272727-2727-4727-8727-272727272727','27272727-2727-4727-8727-272727272701','Foreign material','pasted_text','manual',repeat('b',100));
insert into public.flashcards(id,user_id,subject_id,material_id,front,back) values
('26262626-2626-4626-8626-262626262603','26262626-2626-4626-8626-262626262626','26262626-2626-4626-8626-262626262601','26262626-2626-4626-8626-262626262602','Q1','A1'),
('26262626-2626-4626-8626-262626262604','26262626-2626-4626-8626-262626262626','26262626-2626-4626-8626-262626262601','26262626-2626-4626-8626-262626262602','Q2','A2'),
('27272727-2727-4727-8727-272727272703','27272727-2727-4727-8727-272727272727','27272727-2727-4727-8727-272727272701','27272727-2727-4727-8727-272727272702','FQ','FA');

select set_config('request.jwt.claim.sub','26262626-2626-4626-8626-262626262626',false);
select public.favorite_flashcard('26262626-2626-4626-8626-262626262603');
select public.favorite_flashcard('26262626-2626-4626-8626-262626262603');
select pg_temp.assert_bc((select count(*)=1 from public.favorites where entity_type='flashcard'),'favorite idempotent');
do $$ begin perform public.favorite_flashcard('27272727-2727-4727-8727-272727272703');raise exception 'foreign favorite accepted';exception when no_data_found then null;end $$;
select public.unfavorite_flashcard('26262626-2626-4626-8626-262626262603');
select public.unfavorite_flashcard('26262626-2626-4626-8626-262626262603');
do $$ begin perform public.unfavorite_flashcard('27272727-2727-4727-8727-272727272703');raise exception 'foreign unfavorite accepted';exception when no_data_found then null;end $$;

do $$ begin perform public.start_flashcard_training('26262626-2626-4626-8626-262626262609','26262626-2626-4626-8626-262626262602','all',array['27272727-2727-4727-8727-272727272703'::uuid]);raise exception 'foreign flashcard session accepted';exception when sqlstate '22023' then null;end $$;

select * from public.start_flashcard_training('26262626-2626-4626-8626-262626262605','26262626-2626-4626-8626-262626262602','all',array['26262626-2626-4626-8626-262626262603'::uuid,'26262626-2626-4626-8626-262626262604'::uuid]);
select pg_temp.assert_bc((select id='26262626-2626-4626-8626-262626262605'::uuid from public.start_flashcard_training('26262626-2626-4626-8626-262626262610','26262626-2626-4626-8626-262626262602','all',array['26262626-2626-4626-8626-262626262603'::uuid,'26262626-2626-4626-8626-262626262604'::uuid])),'one active flashcard session per material and mode');
select * from public.update_flashcard_training('26262626-2626-4626-8626-262626262605',1,1,false,'26262626-2626-4626-8626-262626262603','not_known',now());
select * from public.update_flashcard_training('26262626-2626-4626-8626-262626262605',1,1,false,'26262626-2626-4626-8626-262626262603','not_known',now());
select pg_temp.assert_bc((select incorrect_count=1 from public.flashcards where id='26262626-2626-4626-8626-262626262603') and (select metadata->'first_pass_missed_ids'='["26262626-2626-4626-8626-262626262603"]'::jsonb from public.study_sessions where id='26262626-2626-4626-8626-262626262605'),'grade and immutable first-pass miss persisted');
do $$ begin perform public.update_flashcard_training('26262626-2626-4626-8626-262626262605',2,0,false,null,null,null);raise exception 'backward progress accepted';exception when sqlstate '22023' then null;end $$;
select * from public.update_flashcard_training('26262626-2626-4626-8626-262626262605',2,2,false,'26262626-2626-4626-8626-262626262604','known',now());
select * from public.finalize_flashcard_training('26262626-2626-4626-8626-262626262605');
select * from public.finalize_flashcard_training('26262626-2626-4626-8626-262626262605');
select pg_temp.assert_bc((select count(*)=1 from public.study_sessions where id='26262626-2626-4626-8626-262626262605' and ended_at is not null),'completed history exactly once');
select * from public.start_flashcard_training('26262626-2626-4626-8626-262626262611','26262626-2626-4626-8626-262626262602','first_pass_missed',array['26262626-2626-4626-8626-262626262603'::uuid]);
select * from public.update_flashcard_training('26262626-2626-4626-8626-262626262611',1,1,false,'26262626-2626-4626-8626-262626262603','known',now());
select pg_temp.assert_bc((select metadata->'first_pass_missed_ids'='["26262626-2626-4626-8626-262626262603"]'::jsonb from public.study_sessions where id='26262626-2626-4626-8626-262626262611'),'repeat answers do not rewrite first-pass misses');

insert into public.quizzes(id,user_id,subject_id,material_id,title,question_count) values('26262626-2626-4626-8626-262626262606','26262626-2626-4626-8626-262626262626','26262626-2626-4626-8626-262626262601','26262626-2626-4626-8626-262626262602','Quiz',1);
insert into public.quiz_questions(id,user_id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic) values('26262626-2626-4626-8626-262626262607','26262626-2626-4626-8626-262626262626','26262626-2626-4626-8626-262626262606','26262626-2626-4626-8626-262626262601','26262626-2626-4626-8626-262626262602','Q','["A","B"]','A','Why','Topic');
do $$ begin perform public.start_quiz_draft('26262626-2626-4626-8626-262626262612','26262626-2626-4626-8626-262626262606',array['26262626-2626-4626-8626-262626262607'::uuid],'{"26262626-2626-4626-8626-262626262607":["A","C"]}');raise exception 'invalid option order accepted';exception when sqlstate '22023' then null;end $$;
select * from public.start_quiz_draft('26262626-2626-4626-8626-262626262608','26262626-2626-4626-8626-262626262606',array['26262626-2626-4626-8626-262626262607'::uuid],'{"26262626-2626-4626-8626-262626262607":["B","A"]}');
select * from public.update_quiz_draft('26262626-2626-4626-8626-262626262608',1,0,'26262626-2626-4626-8626-262626262607','B');
select * from public.finalize_quiz_draft('26262626-2626-4626-8626-262626262608');
select * from public.finalize_quiz_draft('26262626-2626-4626-8626-262626262608');
select pg_temp.assert_bc((select count(*)=1 from public.quiz_attempts where id='26262626-2626-4626-8626-262626262608') and (select miss_count=1 from public.weak_topics where user_id='26262626-2626-4626-8626-262626262626' and topic_key='topic'),'attempt and weak topic exactly once');
select pg_temp.assert_bc((select ended_at is not null from public.start_quiz_draft('26262626-2626-4626-8626-262626262608','26262626-2626-4626-8626-262626262606',array['26262626-2626-4626-8626-262626262607'::uuid],'{"26262626-2626-4626-8626-262626262607":["B","A"]}')),'completed draft cannot reopen');
select * from public.start_quiz_mistake_review('26262626-2626-4626-8626-262626262608');
select pg_temp.assert_bc((select metadata->'question_ids'='["26262626-2626-4626-8626-262626262607"]'::jsonb from public.study_sessions where quiz_attempt_id='26262626-2626-4626-8626-262626262608' and session_type='quiz_mistake_review'),'mistakes derived from authoritative wrong answers');
select * from public.update_quiz_mistake_review('26262626-2626-4626-8626-262626262608',1,1);
select * from public.update_quiz_mistake_review('26262626-2626-4626-8626-262626262608',1,1);
select pg_temp.assert_bc((select score=0 from public.quiz_attempts where id='26262626-2626-4626-8626-262626262608'),'mistake review does not alter score');
