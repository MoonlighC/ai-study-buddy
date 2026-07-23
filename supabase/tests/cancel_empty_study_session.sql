\set ON_ERROR_STOP on

create or replace function pg_temp.assert_cancel(value boolean,message text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'cancel_empty_session_assertion_failed: %',message;
  end if;
end
$$;

select pg_temp.assert_cancel(
  has_function_privilege('authenticated','public.cancel_empty_study_session(uuid)','execute')
    and not has_function_privilege('anon','public.cancel_empty_study_session(uuid)','execute')
    and not has_function_privilege('service_role','public.cancel_empty_study_session(uuid)','execute'),
  'authenticated-only execute grant'
);
select pg_temp.assert_cancel(
  (select p.prosecdef and pg_get_userbyid(p.proowner)='postgres'
     and p.proconfig=array['search_path=pg_catalog, public']
   from pg_proc p where p.oid='public.cancel_empty_study_session(uuid)'::regprocedure),
  'owner security definer and fixed search path'
);

insert into auth.users(id,email) values
('28282828-2828-4828-8828-282828282828','cancel-owner@example.test'),
('29292929-2929-4929-8929-292929292929','cancel-foreign@example.test');
insert into public.subjects(id,user_id,name) values
('28282828-2828-4828-8828-282828282801','28282828-2828-4828-8828-282828282828','Owner'),
('29292929-2929-4929-8929-292929292901','29292929-2929-4929-8929-292929292929','Foreign');
insert into public.materials(id,user_id,subject_id,title,kind,source_kind,content_text) values
('28282828-2828-4828-8828-282828282802','28282828-2828-4828-8828-282828282828','28282828-2828-4828-8828-282828282801','Owner material','pasted_text','manual',repeat('a',100)),
('29292929-2929-4929-8929-292929292902','29292929-2929-4929-8929-292929292929','29292929-2929-4929-8929-292929292901','Foreign material','pasted_text','manual',repeat('b',100));
insert into public.flashcards(id,user_id,subject_id,material_id,front,back) values
('28282828-2828-4828-8828-282828282803','28282828-2828-4828-8828-282828282828','28282828-2828-4828-8828-282828282801','28282828-2828-4828-8828-282828282802','Q','A'),
('29292929-2929-4929-8929-292929292903','29292929-2929-4929-8929-292929292929','29292929-2929-4929-8929-292929292901','29292929-2929-4929-8929-292929292902','FQ','FA');

create temporary table cancel_quiz_counts_before as
select
  (select count(*) from public.quizzes) quizzes,
  (select count(*) from public.quiz_questions) quiz_questions,
  (select count(*) from public.quiz_attempts) quiz_attempts,
  (select count(*) from public.weak_topics) weak_topics;

select set_config('request.jwt.claim.sub','28282828-2828-4828-8828-282828282828',false);
select * from public.start_flashcard_training('28282828-2828-4828-8828-282828282804','28282828-2828-4828-8828-282828282802','all',array['28282828-2828-4828-8828-282828282803'::uuid]);
select pg_temp.assert_cancel(public.cancel_empty_study_session('28282828-2828-4828-8828-282828282804'),'empty active cancellation');
select pg_temp.assert_cancel(public.cancel_empty_study_session('28282828-2828-4828-8828-282828282804'),'idempotent replay');
select pg_temp.assert_cancel(not exists(select 1 from public.study_sessions where id='28282828-2828-4828-8828-282828282804'),'empty row deleted');
select pg_temp.assert_cancel((select count(*)=0 from public.study_sessions where user_id='28282828-2828-4828-8828-282828282828' and ended_at is not null),'no completed history created');
select pg_temp.assert_cancel((select correct_count=0 and incorrect_count=0 from public.flashcards where id='28282828-2828-4828-8828-282828282803'),'grading unchanged');
select pg_temp.assert_cancel(
  (select row(q.quizzes,q.quiz_questions,q.quiz_attempts,q.weak_topics)
     = row(b.quizzes,b.quiz_questions,b.quiz_attempts,b.weak_topics)
   from (select
      (select count(*) from public.quizzes) quizzes,
      (select count(*) from public.quiz_questions) quiz_questions,
      (select count(*) from public.quiz_attempts) quiz_attempts,
      (select count(*) from public.weak_topics) weak_topics) q,
     cancel_quiz_counts_before b),
  'empty cancellation mutates no quiz data'
);

select * from public.start_flashcard_training('28282828-2828-4828-8828-282828282806','28282828-2828-4828-8828-282828282802','all',array['28282828-2828-4828-8828-282828282803'::uuid]);
update public.study_sessions
set metadata=jsonb_set(metadata,'{graded_card_ids}','["28282828-2828-4828-8828-282828282803"]'::jsonb)
where id='28282828-2828-4828-8828-282828282806';
do $$ begin
  perform public.cancel_empty_study_session('28282828-2828-4828-8828-282828282806');
  raise exception 'session with graded-card IDs cancelled';
exception when sqlstate '22023' then null;
end $$;
select pg_temp.assert_cancel(exists(select 1 from public.study_sessions where id='28282828-2828-4828-8828-282828282806'),'graded-card guard preserves session');
delete from public.study_sessions where id='28282828-2828-4828-8828-282828282806';

select * from public.start_flashcard_training('28282828-2828-4828-8828-282828282805','28282828-2828-4828-8828-282828282802','all',array['28282828-2828-4828-8828-282828282803'::uuid]);
select * from public.update_flashcard_training('28282828-2828-4828-8828-282828282805',1,1,false,'28282828-2828-4828-8828-282828282803','known',now());
do $$ begin
  perform public.cancel_empty_study_session('28282828-2828-4828-8828-282828282805');
  raise exception 'non-empty session cancelled';
exception when sqlstate '22023' then null;
end $$;
select * from public.finalize_flashcard_training('28282828-2828-4828-8828-282828282805');
do $$ begin
  perform public.cancel_empty_study_session('28282828-2828-4828-8828-282828282805');
  raise exception 'completed session cancelled';
exception when sqlstate '22023' then null;
end $$;
select pg_temp.assert_cancel((select count(*)=1 from public.study_sessions where id='28282828-2828-4828-8828-282828282805' and ended_at is not null),'completed history preserved once');
select pg_temp.assert_cancel((select correct_count=1 and incorrect_count=0 from public.flashcards where id='28282828-2828-4828-8828-282828282803'),'rejected cancellation does not mutate grading');

select set_config('request.jwt.claim.sub','29292929-2929-4929-8929-292929292929',false);
select * from public.start_flashcard_training('29292929-2929-4929-8929-292929292904','29292929-2929-4929-8929-292929292902','all',array['29292929-2929-4929-8929-292929292903'::uuid]);
select set_config('request.jwt.claim.sub','28282828-2828-4828-8828-282828282828',false);
do $$ begin
  perform public.cancel_empty_study_session('29292929-2929-4929-8929-292929292904');
  raise exception 'foreign session cancelled';
exception when sqlstate '42501' then null;
end $$;
