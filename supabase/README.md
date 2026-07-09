# Supabase Placeholder

This folder is reserved for future Supabase schema notes, Edge Functions, and storage configuration.

Phase 1 intentionally does not include:

- Real Supabase URL or anon key.
- Service role key.
- OpenAI API key.
- Edge Function implementation.
- Database migrations.

Future Edge Functions will be the only place that can call OpenAI. Flutter should call Supabase, Supabase should enforce account limits, and each AI request should be logged before returning generated study content.

## Phase 8A: Generate Summary Edge Function

The `generate-summary` Edge Function summarizes synced pasted-text materials. It requires an authenticated Supabase user and reads `OPENAI_API_KEY` only from Supabase function secrets.

Set the function secret with a placeholder value replaced locally:

```powershell
supabase secrets set OPENAI_API_KEY=<your-openai-api-key>
```

Deploy the function:

```powershell
supabase functions deploy generate-summary
```

Run Flutter in Supabase mode with public client configuration:

```powershell
C:\src\flutter\bin\flutter.bat run --dart-define=APP_BACKEND_MODE=supabase --dart-define=SUPABASE_URL=<your-project-url> --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

After signing in, create a pasted-text material, open the material detail screen, and use `Summarize with AI`.
