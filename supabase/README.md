# Supabase Placeholder

This folder is reserved for future Supabase schema notes, Edge Functions, and storage configuration.

Phase 1 intentionally does not include:

- Real Supabase URL or anon key.
- Service role key.
- OpenAI API key.
- Edge Function implementation.
- Database migrations.

Future Edge Functions will be the only place that can call OpenAI. Flutter should call Supabase, Supabase should enforce account limits, and each AI request should be logged before returning generated study content.
