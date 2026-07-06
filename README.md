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
  --dart-define=SUPABASE_URL=https://msaaqhqnnhpmclgdzowo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Only the exact value `APP_BACKEND_MODE=supabase` enables Supabase mode. If the
URL or publishable/anon key is missing, the app continues in mock mode and logs
a sanitized debug message.

Do not commit real Supabase keys, service role keys, OpenAI keys, or local
`.env` files. Phase 5C only initializes the Supabase Flutter client; it does
not add auth UI, data sync, Edge Functions, or AI calls.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
