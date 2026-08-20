# Contributing to AI Study Buddy

Thank you for helping improve AI Study Buddy.

## Requirements

- Flutter SDK
- Dart SDK
- Supabase CLI for backend and database work

Use the Flutter version configured by the repository's validation workflow when
possible.

## Local development

Install dependencies:

```bash
flutter pub get
```

Run the test suite:

```bash
flutter test
```

Run the application:

```bash
flutter run
```

Copy `config/local.example.dart-defines.json` to an ignored local configuration
file when a Supabase-backed build is required. Never commit real credentials.

## Pull requests

Before opening a pull request:

- ensure all relevant tests pass;
- format changed Dart code with `dart format`;
- provide a clear description of the change and its motivation;
- include reproduction and verification steps when fixing a bug;
- keep pull requests focused on one logical change.

Do not include secrets, generated build artifacts, signing material, or unrelated
formatting changes.
