# Supabase Schema Plan

This document describes the planned Phase 5A schema. The companion SQL draft is `supabase/migrations/001_initial_schema.sql`.

## Schema Principles

- Use `uuid` primary keys for all app tables.
- Store `user_id` on all user-owned rows.
- Use `created_at`, `updated_at`, and optional `deleted_at` for sync and soft delete.
- Use `jsonb` for flexible AI metadata, answers, and provider usage details.
- Keep current mock data shapes recognizable while leaving room for synced and generated records.
- Keep usage accounting server-controlled.

## Tables

### `profiles`

App-specific user profile data. One row per Supabase Auth user.

Key fields:

- `id`: references `auth.users(id)`.
- `email`
- `display_name`
- `avatar_url`
- `preferred_study_mode`
- `onboarding_completed`

### `subjects`

User-owned study subjects.

Maps current `Subject`:

- `id`
- `name`
- `description`
- `color_value`

Adds:

- `user_id`
- `icon_name`
- `sort_order`
- sync timestamps

### `materials`

User-owned study materials from pasted text, PDFs, images, or later processed uploads.

Maps current `StudyMaterial`:

- `subject_id`
- `title`
- `kind`
- `content_text`

Adds:

- `source_kind`
- `summary`
- `storage_bucket`
- `storage_path`
- `mime_type`
- `file_size_bytes`
- `processing_status`
- `metadata`

### `flashcards`

Generated or manually created flashcards.

Maps current `Flashcard`:

- `subject_id`
- `front`
- `back`
- `topic`

Adds:

- `material_id`
- `difficulty`
- review counters
- spaced repetition timestamps

Favorites are normalized into the generic `favorites` table instead of a boolean column.

### `quizzes`

Quiz containers.

Fields:

- `subject_id`
- `material_id`
- `title`
- `quiz_type`
- `question_count`
- `metadata`

### `quiz_questions`

Individual quiz questions belonging to a quiz.

Maps current `QuizQuestion`:

- `question`
- `options`
- `correct_answer`
- `explanation`
- `difficulty`

Adds:

- `quiz_id`
- `material_id`
- `topic`
- `sort_order`

### `quiz_attempts`

User quiz results.

Fields:

- `quiz_id`
- `score`
- `total_questions`
- `correct_questions`
- `started_at`
- `completed_at`
- `answers`
- `weak_topics_snapshot`

### `study_sessions`

Study activity and generated session output.

Maps current `StudySession`:

- `subject_id`
- `material_id`
- `confidence`
- `summary`
- `selected_answer`
- `quiz_score_percent`
- `feedback`

Adds:

- session timing
- duration
- activity type
- generated item counters
- `study_time_blocks`
- `metadata`

### `favorites`

Generic favorite rows for flashcards first and other entity types later.

Fields:

- `entity_type`
- `entity_id`
- unique `(user_id, entity_type, entity_id)`

The database cannot enforce a polymorphic foreign key for `entity_id`, so app code and future RPCs must validate allowed entity types.

### `weak_topics`

Aggregated learning gaps.

Maps current `WeakTopic`:

- `subject_id`
- `topic`
- `reason`

Adds:

- `material_id`
- `score`
- `miss_count`
- `last_seen_at`
- `source`

### `usage_logs`

Append-only log for AI and upload usage. This table is designed for server-side writes by Edge Functions or security-definer RPCs.

Fields:

- `event_type`
- `feature`
- `model`
- `quantity`
- `input_tokens`
- `output_tokens`
- `estimated_cost_usd`
- `status`
- `metadata`

Flutter should be able to read its own rows for usage display, but direct client inserts/updates/deletes are intentionally not enabled.

### `daily_usage_limits`

Per-user, per-day usage counters and limits.

Default limits:

- `flashcards_limit = 120`
- `quiz_questions_limit = 80`
- `uploads_limit = 3`
- `estimated_openai_cost_limit_usd = 0.25`

Current counters:

- `flashcards_generated`
- `quiz_questions_generated`
- `uploads_count`
- `estimated_openai_cost_usd`

This table should be mutated only by server-side quota logic.

## Index Strategy

Common indexes:

- `user_id` on all user-owned tables.
- Foreign keys such as `subject_id`, `material_id`, and `quiz_id`.
- `updated_at` for sync queries.
- `deleted_at` where soft deletes are used.
- `usage_date` and `(user_id, usage_date)` for daily usage.

Search indexes can be added later after product behavior is clearer. Phase 5A does not add full-text search indexes.

## Sync Strategy

Initial sync should be simple:

- Pull user rows by `updated_at`.
- Treat `deleted_at` as a tombstone.
- For conflicts on basic user-edited data, start with latest `updated_at` wins.
- For append-only data such as `usage_logs`, never overwrite existing rows.
- For server-controlled counters, do not merge from Flutter.

## Planned Storage Metadata

Storage bucket creation is not part of this migration. The `materials` table still includes storage metadata fields so future upload rows can point to private objects.

Planned buckets:

- `study-materials`
- `study-images`

Planned path prefix:

```text
{user_id}/...
```

The storage RLS policy should require the first path segment to equal `auth.uid()`.
