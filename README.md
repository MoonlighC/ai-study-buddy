# AI Study Buddy 📚🤖

[![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Supported platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-blue)

AI Study Buddy is an AI-powered learning assistant built with Flutter.

Upload lectures, notes and PDFs. Generate summaries, flashcards and quizzes.
Organize subjects and track learning progress.

## Features

✨ Upload learning materials
- PDF documents
- Images
- Multiple files per subject

🧠 AI-powered learning
- Automatic summaries
- Flashcards generation
- Quiz generation
- Study sessions

📈 Learning progress
- Track completed sessions
- Identify weak topics
- Review favorites

🔐 Secure architecture
- Flutter frontend
- Supabase backend
- Row Level Security
- Server-side AI processing

## Backend setup

This repository contains the client and backend source code.

To run your own instance you need:

- your own Supabase project
- your own OpenAI API key
- your own Supabase secrets

No production credentials are included.

## Architecture

```
Flutter App
     |
     |
Supabase
     |
     |
Edge Functions
     |
     |
AI Providers
```

## Tech Stack

Frontend:
- Flutter
- Dart

Backend:
- Supabase
- PostgreSQL
- Edge Functions

AI:
- OpenAI API integration

Testing:
- Flutter tests
- Deno tests
- SQL migration tests


## Local Development

Clone repository:

```bash
git clone https://github.com/MoonlighC/ai-study-buddy.git
```

Install dependencies:

```bash
flutter pub get
```

Run:

```bash
flutter run
```

## Environment Configuration

Create your local configuration:

```
config/local.example.dart-defines.json
```

Required values:

```
SUPABASE_URL
SUPABASE_ANON_KEY
```

Never use service_role keys inside the mobile application.

## Status

**Beta / Active Development**

Current implemented:
- PDF upload
- AI material analysis
- Summaries
- Flashcards
- Quizzes
- Study sessions

## Security

Production credentials are never stored in this repository. The Flutter client
uses public Supabase configuration, while privileged credentials and OpenAI
access remain server-side in Supabase Edge Functions.

Please review [SECURITY.md](SECURITY.md) before reporting a vulnerability or
working with credentials.

## Roadmap

- [ ] App Store release
- [ ] Google Play release
- [ ] More AI learning modes
- [ ] Offline learning support
- [ ] Collaborative studying

## License

This project is available under the [MIT License](LICENSE).
