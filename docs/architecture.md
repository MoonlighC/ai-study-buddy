# AI Study Buddy Architecture

## Phase 1 Shape

AI Study Buddy starts as a Flutter app with mock local data. The first app shell is clickable and demo-ready, but it does not connect to Supabase or OpenAI yet.

## Client

- Flutter owns the mobile, web, and Windows debug UI.
- Feature folders keep screens grouped by user workflow.
- `lib/core/models` contains simple data models that can later map to Supabase rows.
- `lib/mock` contains in-memory demo data and the mock AI service.

## Backend Boundary

Supabase will later provide:

- Auth for email, Google, and Apple sign-in.
- Postgres tables for subjects, materials, generated outputs, flashcards, quiz questions, favorites, and usage logs.
- Storage for photos and PDFs.
- Edge Functions for all OpenAI calls.

The Flutter app must never include `OPENAI_API_KEY`. OpenAI requests must go through Supabase Edge Functions so usage can be logged and limited per account.

## Planned AI Logging

Every real AI call should log:

- `user_id`
- feature name
- model
- input tokens
- output tokens
- estimated cost
- timestamp

## Planned Daily Limits

- 120 generated flashcards per user
- 80 quiz questions per user
- 3 uploads per user
- $0.25 estimated OpenAI cost per user by default
