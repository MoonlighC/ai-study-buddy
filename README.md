# AI Study Buddy 📚🤖

AI-powered study assistant built with Flutter.

Upload your lectures, notes and PDFs. 
AI Study Buddy helps students understand, organize and practice learning materials.

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

## Project Status

🚧 Active development

Current implemented:
- PDF upload
- AI material analysis
- Summaries
- Flashcards
- Quizzes
- Study sessions

## Roadmap

- [ ] App Store release
- [ ] Google Play release
- [ ] More AI learning modes
- [ ] Offline learning support
- [ ] Collaborative studying

## License

MIT License
