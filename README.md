# ai_study_buddy

A new Flutter project.

## Backend Modes

The app defaults to the local in-memory mock backend. No Supabase values are
required for normal local development:

```powershell
flutter run
flutter test
```

To verify the optional Supabase client connection path, pass public runtime
configuration with `--dart-define`:

```powershell
flutter run `
  --dart-define=APP_BACKEND_MODE=supabase `
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR-PUBLISHABLE-OR-ANON-KEY
```

Only the exact value `APP_BACKEND_MODE=supabase` enables Supabase mode. If the
URL or publishable/anon key is missing, the app continues in mock mode and logs
a sanitized debug message.

Supabase mode supports email/password login, signup, password reset email, and
logout. On login or signup with an active session, the app upserts the signed-in
user's `public.profiles` row using the authenticated client.

Do not commit real Supabase keys, server-only keys, OpenAI keys, or local
`.env` files. The app still does not add data sync, file uploads, Edge
Functions, or AI calls.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
