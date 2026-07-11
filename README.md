# AI Study Buddy

AI Study Buddy is a Flutter study workspace for Android, iOS, web, and Windows.
The Dart package name and internal executable slug remain `ai_study_buddy`.

## Local development

Local development defaults to the in-memory backend:

```powershell
flutter run
flutter test
```

To use a Supabase client explicitly, provide public client configuration at
compile time:

```powershell
flutter run `
  --dart-define=APP_ENV=local `
  --dart-define=APP_BACKEND_MODE=supabase `
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=PUBLIC_CLIENT_KEY
```

`SUPABASE_ANON_KEY` may contain a Supabase legacy anon key or current
publishable client key. It is public client configuration, not a server secret.
Service-role, database, and OpenAI credentials must remain server-side.

See [Phase 11.1 release foundation](docs/release-foundation-phase-11-1.md) for
the environment matrix, platform identifiers, build commands, deployment
checklists, and distribution limitations.

See [Phase 11.2 release readiness](docs/release-readiness-phase-11-2.md) for
structural signing validation, packaging, CI, store checklists, and release
runbooks.
