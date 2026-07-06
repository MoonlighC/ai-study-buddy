-- Phase 5A planned initial schema for AI Study Buddy.
-- This migration is intentionally not wired into Flutter yet.
-- It contains table, index, trigger, and RLS policy design for later Supabase setup.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  preferred_study_mode text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  color_value integer,
  icon_name text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  kind text not null check (kind in ('pasted_text', 'image', 'pdf')),
  source_kind text not null default 'manual' check (source_kind in ('manual', 'upload', 'generated')),
  content_text text,
  summary text,
  storage_bucket text,
  storage_path text,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  processing_status text not null default 'ready' check (
    processing_status in ('ready', 'pending', 'processing', 'failed')
  ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint materials_storage_pair check (
    (storage_bucket is null and storage_path is null)
    or (storage_bucket is not null and storage_path is not null)
  )
);

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  material_id uuid references public.materials(id) on delete set null,
  front text not null,
  back text not null,
  topic text not null default '',
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'exam')),
  next_review_at timestamptz,
  last_reviewed_at timestamptz,
  correct_count integer not null default 0 check (correct_count >= 0),
  incorrect_count integer not null default 0 check (incorrect_count >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  material_id uuid references public.materials(id) on delete set null,
  title text not null,
  quiz_type text not null default 'practice' check (quiz_type in ('practice', 'exam_prep', 'after_lecture')),
  question_count integer not null default 0 check (question_count >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  quiz_id uuid references public.quizzes(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  material_id uuid references public.materials(id) on delete set null,
  question text not null,
  options jsonb not null default '[]'::jsonb,
  correct_answer text not null,
  explanation text not null default '',
  topic text not null default '',
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'exam')),
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  quiz_id uuid references public.quizzes(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  score numeric(5, 2) check (score is null or (score >= 0 and score <= 100)),
  total_questions integer not null default 0 check (total_questions >= 0),
  correct_questions integer not null default 0 check (correct_questions >= 0),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  answers jsonb not null default '[]'::jsonb,
  weak_topics_snapshot jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint quiz_attempts_correct_lte_total check (correct_questions <= total_questions)
);

create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  material_id uuid references public.materials(id) on delete set null,
  quiz_attempt_id uuid references public.quiz_attempts(id) on delete set null,
  session_type text not null default 'after_lecture' check (
    session_type in ('after_lecture', 'exam_prep', 'flashcards', 'ai_teacher', 'manual')
  ),
  confidence text check (
    confidence is null
    or confidence in ('understood_everything', 'mostly', 'about_half', 'completely_lost')
  ),
  summary text,
  selected_answer text,
  quiz_score_percent integer check (
    quiz_score_percent is null or (quiz_score_percent >= 0 and quiz_score_percent <= 100)
  ),
  feedback text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  items_completed integer not null default 0 check (items_completed >= 0),
  flashcards_generated integer not null default 0 check (flashcards_generated >= 0),
  quiz_questions_generated integer not null default 0 check (quiz_questions_generated >= 0),
  study_time_blocks jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (
    entity_type in ('flashcard', 'material', 'subject', 'quiz')
  ),
  entity_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);

comment on column public.favorites.entity_id is
  'Polymorphic reference. Future app/RPC validation must ensure entity_id belongs to the same user and entity_type.';

create table public.weak_topics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  material_id uuid references public.materials(id) on delete set null,
  topic text not null,
  reason text not null default '',
  score numeric(5, 2) check (score is null or (score >= 0 and score <= 100)),
  miss_count integer not null default 0 check (miss_count >= 0),
  last_seen_at timestamptz not null default now(),
  source jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.usage_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (
    event_type in ('generate_flashcards', 'generate_quiz_questions', 'upload', 'summarize_material', 'other')
  ),
  feature text not null,
  model text,
  quantity integer not null default 1 check (quantity >= 0),
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  estimated_cost_usd numeric(10, 6) not null default 0 check (estimated_cost_usd >= 0),
  status text not null default 'succeeded' check (
    status in ('reserved', 'succeeded', 'failed')
  ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.usage_logs is
  'Append-only server-side usage log. Users may read their own rows, but Flutter should not write directly.';

create table public.daily_usage_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date,
  flashcards_generated integer not null default 0 check (flashcards_generated >= 0),
  flashcards_limit integer not null default 120 check (flashcards_limit >= 0),
  quiz_questions_generated integer not null default 0 check (quiz_questions_generated >= 0),
  quiz_questions_limit integer not null default 80 check (quiz_questions_limit >= 0),
  uploads_count integer not null default 0 check (uploads_count >= 0),
  uploads_limit integer not null default 3 check (uploads_limit >= 0),
  estimated_openai_cost_usd numeric(10, 6) not null default 0 check (estimated_openai_cost_usd >= 0),
  estimated_openai_cost_limit_usd numeric(10, 6) not null default 0.25 check (
    estimated_openai_cost_limit_usd >= 0
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, usage_date)
);

comment on table public.daily_usage_limits is
  'Server-enforced per-user daily counters. Future Edge Functions or RPCs should reserve and update usage.';

-- Storage buckets are intentionally not created in Phase 5A.
-- Planned private buckets: study-materials, study-images, and possibly generated-assets.
-- Planned object paths should start with {user_id}/ so storage RLS can enforce ownership.

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_subjects_updated_at
before update on public.subjects
for each row execute function public.set_updated_at();

create trigger set_materials_updated_at
before update on public.materials
for each row execute function public.set_updated_at();

create trigger set_flashcards_updated_at
before update on public.flashcards
for each row execute function public.set_updated_at();

create trigger set_quizzes_updated_at
before update on public.quizzes
for each row execute function public.set_updated_at();

create trigger set_quiz_questions_updated_at
before update on public.quiz_questions
for each row execute function public.set_updated_at();

create trigger set_quiz_attempts_updated_at
before update on public.quiz_attempts
for each row execute function public.set_updated_at();

create trigger set_study_sessions_updated_at
before update on public.study_sessions
for each row execute function public.set_updated_at();

create trigger set_weak_topics_updated_at
before update on public.weak_topics
for each row execute function public.set_updated_at();

create trigger set_daily_usage_limits_updated_at
before update on public.daily_usage_limits
for each row execute function public.set_updated_at();

create index profiles_email_idx on public.profiles (email);

create index subjects_user_id_idx on public.subjects (user_id);
create index subjects_user_updated_at_idx on public.subjects (user_id, updated_at desc);
create index subjects_user_deleted_at_idx on public.subjects (user_id, deleted_at);

create index materials_user_id_idx on public.materials (user_id);
create index materials_subject_id_idx on public.materials (subject_id);
create index materials_user_updated_at_idx on public.materials (user_id, updated_at desc);
create index materials_user_deleted_at_idx on public.materials (user_id, deleted_at);

create index flashcards_user_id_idx on public.flashcards (user_id);
create index flashcards_subject_id_idx on public.flashcards (subject_id);
create index flashcards_material_id_idx on public.flashcards (material_id);
create index flashcards_user_next_review_at_idx on public.flashcards (user_id, next_review_at);
create index flashcards_user_updated_at_idx on public.flashcards (user_id, updated_at desc);
create index flashcards_user_deleted_at_idx on public.flashcards (user_id, deleted_at);

create index quizzes_user_id_idx on public.quizzes (user_id);
create index quizzes_subject_id_idx on public.quizzes (subject_id);
create index quizzes_material_id_idx on public.quizzes (material_id);
create index quizzes_user_updated_at_idx on public.quizzes (user_id, updated_at desc);

create index quiz_questions_user_id_idx on public.quiz_questions (user_id);
create index quiz_questions_quiz_id_idx on public.quiz_questions (quiz_id);
create index quiz_questions_subject_id_idx on public.quiz_questions (subject_id);
create index quiz_questions_user_updated_at_idx on public.quiz_questions (user_id, updated_at desc);

create index quiz_attempts_user_id_idx on public.quiz_attempts (user_id);
create index quiz_attempts_quiz_id_idx on public.quiz_attempts (quiz_id);
create index quiz_attempts_user_started_at_idx on public.quiz_attempts (user_id, started_at desc);

create index study_sessions_user_id_idx on public.study_sessions (user_id);
create index study_sessions_subject_id_idx on public.study_sessions (subject_id);
create index study_sessions_material_id_idx on public.study_sessions (material_id);
create index study_sessions_user_started_at_idx on public.study_sessions (user_id, started_at desc);
create index study_sessions_user_updated_at_idx on public.study_sessions (user_id, updated_at desc);

create index favorites_user_id_idx on public.favorites (user_id);
create index favorites_user_entity_idx on public.favorites (user_id, entity_type, entity_id);

create index weak_topics_user_id_idx on public.weak_topics (user_id);
create index weak_topics_subject_id_idx on public.weak_topics (subject_id);
create index weak_topics_user_last_seen_at_idx on public.weak_topics (user_id, last_seen_at desc);

create index usage_logs_user_id_idx on public.usage_logs (user_id);
create index usage_logs_user_created_at_idx on public.usage_logs (user_id, created_at desc);
create index usage_logs_user_event_created_at_idx on public.usage_logs (user_id, event_type, created_at desc);

create index daily_usage_limits_user_id_idx on public.daily_usage_limits (user_id);
create index daily_usage_limits_usage_date_idx on public.daily_usage_limits (usage_date);

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.materials enable row level security;
alter table public.flashcards enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.study_sessions enable row level security;
alter table public.favorites enable row level security;
alter table public.weak_topics enable row level security;
alter table public.usage_logs enable row level security;
alter table public.daily_usage_limits enable row level security;

create policy "Users can read own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) is not null and id = (select auth.uid()));

create policy "Users can insert own profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) is not null and id = (select auth.uid()));

create policy "Users can update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) is not null and id = (select auth.uid()))
with check ((select auth.uid()) is not null and id = (select auth.uid()));

create policy "Users can delete own profile"
on public.profiles for delete
to authenticated
using ((select auth.uid()) is not null and id = (select auth.uid()));

create policy "Users can read own subjects"
on public.subjects for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own subjects"
on public.subjects for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own subjects"
on public.subjects for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own subjects"
on public.subjects for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own materials"
on public.materials for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own materials"
on public.materials for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own materials"
on public.materials for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own materials"
on public.materials for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own flashcards"
on public.flashcards for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own flashcards"
on public.flashcards for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own flashcards"
on public.flashcards for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own flashcards"
on public.flashcards for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own quizzes"
on public.quizzes for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own quizzes"
on public.quizzes for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own quizzes"
on public.quizzes for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own quizzes"
on public.quizzes for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own quiz questions"
on public.quiz_questions for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own quiz questions"
on public.quiz_questions for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own quiz questions"
on public.quiz_questions for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own quiz questions"
on public.quiz_questions for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own quiz attempts"
on public.quiz_attempts for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own quiz attempts"
on public.quiz_attempts for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own quiz attempts"
on public.quiz_attempts for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own quiz attempts"
on public.quiz_attempts for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own study sessions"
on public.study_sessions for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own study sessions"
on public.study_sessions for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own study sessions"
on public.study_sessions for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own study sessions"
on public.study_sessions for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own favorites"
on public.favorites for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own favorites"
on public.favorites for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own favorites"
on public.favorites for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own weak topics"
on public.weak_topics for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can insert own weak topics"
on public.weak_topics for insert
to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can update own weak topics"
on public.weak_topics for update
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can delete own weak topics"
on public.weak_topics for delete
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "Users can read own usage logs"
on public.usage_logs for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

-- No authenticated insert, update, or delete policies for usage_logs.
-- Future Edge Functions or security-definer RPCs should write append-only usage events.

create policy "Users can read own daily usage limits"
on public.daily_usage_limits for select
to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

-- No authenticated insert, update, or delete policies for daily_usage_limits.
-- Future server-side quota logic should create, reserve, and update daily counters.
