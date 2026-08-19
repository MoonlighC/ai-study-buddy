# Security Policy

## Reporting a vulnerability

If you discover a security issue, please do not open a public issue.

Contact:
your-email@example.com

## Security architecture

AI Study Buddy uses:

- Flutter client
- Supabase authentication
- PostgreSQL Row Level Security
- Supabase Edge Functions
- Server-side OpenAI API access

Production secrets are never stored in the client application or repository.

## Secrets

Never commit:

- OpenAI API keys
- Supabase service_role keys
- signing keys
- environment files
