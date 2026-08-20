# Security Policy

## Reporting a vulnerability

Please do not disclose security vulnerabilities in a public issue, discussion,
or pull request.

Use GitHub's private vulnerability reporting feature on the **Security** tab of
this repository. If private reporting is unavailable, contact the maintainer
through their GitHub profile and request a private communication channel. Share
only the minimum information needed until a private channel is established.

Include the affected component, reproduction steps, expected impact, and any
suggested mitigation. Reports will be acknowledged and assessed as promptly as
possible.

## Secrets and credentials

Never commit:

- OpenAI API keys;
- Supabase `service_role` keys;
- signing keys, keystores, or provisioning credentials;
- environment files containing real configuration values.

Use placeholder values in tracked example files. Production secrets must be
configured in the appropriate Supabase or GitHub environment.

## Security architecture

```text
Flutter client
    |
    v
Supabase Auth + RLS
    |
    v
Supabase Edge Functions
    |
    v
OpenAI API
```

The Flutter client receives only public client configuration. Privileged
credentials and OpenAI access remain on the server side behind authentication,
Row Level Security, and Edge Functions.
