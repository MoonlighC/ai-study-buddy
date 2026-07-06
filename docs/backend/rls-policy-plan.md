# RLS Policy Plan

Supabase exposes the `public` schema through APIs, so every app table in `public` must have Row Level Security enabled before the Flutter app connects.

## Baseline Policy

For regular user-owned tables:

- Users can select rows where `user_id = auth.uid()`.
- Users can insert rows only when `user_id = auth.uid()`.
- Users can update rows they own and cannot change ownership.
- Users can delete rows they own.

The planned SQL uses explicit authenticated checks:

```sql
(select auth.uid()) is not null and user_id = (select auth.uid())
```

This avoids accidental access for unauthenticated requests where `auth.uid()` is null.

## Profile Policy

`profiles` is keyed by the Auth user ID:

- `profiles.id = auth.uid()`

Users can read and update their own profile. Inserts are allowed only for the user's own ID so either a future trigger or first-login upsert can create the row.

## Usage Tables

`usage_logs` and `daily_usage_limits` are intentionally stricter than normal user-owned tables.

Users can:

- Read their own usage logs.
- Read their own daily usage counters.

Users cannot directly:

- Insert usage logs.
- Update usage logs.
- Delete usage logs.
- Insert daily usage rows.
- Update daily counters.
- Delete daily usage rows.

Future Edge Functions should write these rows using server-side privileges or carefully reviewed security-definer RPCs. This prevents a modified Flutter client from increasing quota or hiding usage.

## Storage RLS

Storage buckets are planned but not created in Phase 5A.

Future storage policies should:

- Keep buckets private.
- Require authenticated users.
- Require `storage.foldername(name)[1] = auth.uid()::text`.
- Allow users to read/write only files under their own user ID prefix.
- Keep processed files private unless a short-lived signed URL is created.

## Service Role Key Rule

The service role key must never be used in Flutter. It bypasses RLS and belongs only in trusted server-side environments such as Supabase Edge Functions or deployment secrets.

## Edge Function Rule

OpenAI calls should happen only in Edge Functions. The function should validate the user, check quota, perform the AI call, write generated data, write usage logs, and then return a minimal result to Flutter.

## Review Checklist Before Phase 5B

- Confirm all public tables have RLS enabled.
- Confirm no user-owned table has a broad `using (true)` policy.
- Confirm usage tables have no client write policies.
- Confirm indexes match expected sync queries.
- Confirm storage buckets are private.
- Confirm Flutter receives only the publishable/anon key.
