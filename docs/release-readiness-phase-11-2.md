# Phase 11.2 release readiness

Phase 11.2 provides structural release validation, packaging orchestration, CI
checks, and factual submission runbooks. It does not prove that any build is
signed, accepted by a store, legally compliant, or certified on physical
hardware. No credentials were generated and no store, host, or remote Supabase
project was changed.

## Android signing architecture

The Android release build has no debug-signing fallback. Debug builds are
unchanged. A release task requires one complete source:

- Local: ignored `android/key.properties` containing `storeFile`, `keyAlias`,
  `storePassword`, and `keyPassword`. The upload keystore itself stays outside
  Git.
- CI: `RELEASE_SIGNING_SOURCE=ci` plus `ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEY_ALIAS`, `ANDROID_STORE_PASSWORD`, and `ANDROID_KEY_PASSWORD`.
  CI creates the keystore only in its temporary directory and deletes it in an
  unconditional cleanup step.

Partial sources fail with missing field names. Values, passwords, and resolved
credential paths must never be logged. CI is explicitly selected and is not
merged with partial local properties.

The upload key authenticates bundles uploaded by the developer. With Play App
Signing, Google holds the distinct app-signing key used for user-distributed
APKs. Register and verify the upload certificate fingerprint before uploading:

```text
keytool -list -v -keystore <outside-git-keystore> -alias <alias>
```

Record SHA-256/SHA-1 fingerprints in restricted operational records. Maintain
two encrypted, access-controlled backups of the keystore and recovery data,
with an owner and recovery test. Play can reset an upload key; that does not
rotate the Play-managed app-signing key.

This repository has completed structural validation only. Real verification
requires approved signing material, fingerprint comparison, a production AAB,
Play tooling inspection, and physical-device install/upgrade smoke tests.
Shrinking remains disabled until those tests cover auth, uploads, OCR/AI,
quizzes, persistence, and deletion.

## CI and artifact workflow

`validate.yml` runs on pushes and pull requests with read-only permissions and
no release secrets. It generates localization, analyzes, tests, and runs release
metadata, localization, foundation, secret, template, and Android checks.

`release-validate.yml` is manual only. Web and Windows validation jobs use
repository variables for public Supabase client configuration. The production
Android job uses the protected `production-release` environment and fails
clearly until its secrets exist. Fork pull requests cannot trigger this manual
secret-bearing job. Nothing uploads to a store or deploys to a host. RC/manual
artifacts are retained for 14 days; an explicitly final run uses 30 days.

Artifact names are:

```text
AI-Study-Buddy-<version>+<build>-<environment>-android.aab
AI-Study-Buddy-<version>+<build>-<environment>-android.apk
AI-Study-Buddy-<version>+<build>-<environment>-web.zip
AI-Study-Buddy-<version>+<build>-<environment>-windows-x64.zip
```

The ignored `release-artifacts/` directory is the only controlled local output.
Each package receives a lowercase SHA-256 sidecar and is listed in a sorted
combined checksum file. Its JSON build manifest contains schema version, commit,
semantic version, build number, optional RC label, environment, backend mode,
platform/architecture, UTC timestamp, Flutter/Dart versions, filename, size,
hash, signing status, and sorted migration revisions. It excludes URLs, keys,
aliases, credential paths, passwords, tokens, and environment dumps.

The authoritative version is `MAJOR.MINOR.PATCH+BUILD` in pubspec. Every
externally tested artifact needs a new increasing build number. Final tag
`v1.0.0` and RC tag `v1.0.0-rc.1` both map to pubspec semantic version `1.0.0`;
the RC label remains release metadata. Tags point only to reviewed release
commits, and release notes come from reviewed input rather than blindly from
commit messages.

## Windows portable ZIP

The initial Windows format is an unsigned portable x64 ZIP of the complete
`build/windows/x64/runner/Release` tree. It preserves the executable, Flutter
runtime DLL, plugin libraries, and `data` directory. It creates no installer,
uninstaller, Start Menu entry, updater, or package identity. Removing the
application directory does not intentionally remove preferences/session data
stored in the user's platform data location.

Unsigned ZIP/executable distribution can trigger SmartScreen and has no trusted
publisher reputation. MSIX, installer tooling, publisher identity, Authenticode
certificate acquisition, timestamp signing, and updates require separate owner
approval.

## Web ZIP and hosting guidance

The Web ZIP packages `build/web` after validating its entry point, Flutter
bootstrap/runtime, assets, manifest, and icons. Production and staging are built
separately and cannot exchange labels.

```powershell
flutter build web --release --base-href / <production dart defines>
flutter build web --release --base-href /chosen-path/ <environment dart defines>
```

Use HTTPS and an SPA fallback to `index.html`. Revalidate or avoid caching
`index.html`, bootstrap, service-worker, and version metadata. Content-hashed
assets may be cached long-term and immutable; other generated assets need
bounded caching. Deployment and rollback must invalidate the service worker so
old compiled environment settings do not persist.

Configure Supabase site URL and allowed sign-in/password-reset callback URLs for
the exact origin and base path, then test deep links and refreshes. Staging is
`noindex` and should use host access controls where possible; production becomes
indexable only after launch approval. Evaluate CSP, HSTS, content-type,
referrer, and frame headers for the selected host. No example CSP is assumed to
work unchanged everywhere. Hosting provider, paid plan, domain, and DNS remain
`OWNER DECISION REQUIRED`.

## iOS macOS runbook

1. Confirm Apple Developer membership and register explicit App ID
   `com.moonlightc.aistudybuddy`.
2. Create the App Store Connect record with approved owner metadata.
3. Select the real team for Runner and RunnerTests on macOS. Start with Xcode
   automatic signing; use manual signing only when the team adopts explicit
   certificate/profile custody and renewal procedures.
4. Keep private keys, `.p12`, profiles, archives, and API keys out of Git and in
   approved encrypted storage. Record ownership, expiry, backup, and recovery.
5. Map `1.0.0+1` to short version `1.0.0` and build `1`; increment the build for
   every TestFlight upload.
6. Audit plugins and native code for required privacy manifests and accessed
   reason APIs. Add declarations only from verified behavior.
7. Verify auth/reset redirects, entitlements, encryption/export-compliance
   answers, reviewer test-account needs, icons, and launch screen.
8. Smoke-test simulator and physical device, archive in Xcode, validate the
   archive, and only then optionally upload to TestFlight with approval.

No Apple signing files or invented team values are present. Windows inspection
does not establish iOS build or release readiness.

## Store metadata templates

### Google Play

- App name: AI Study Buddy
- Short/full description: OWNER DECISION REQUIRED
- Category, audience, content rating, ads declaration: OWNER DECISION REQUIRED
- Legal company/developer name and contact: OWNER DECISION REQUIRED
- Privacy policy and account-deletion URL: OWNER DECISION REQUIRED
- Screenshots, feature graphic, icon review: OWNER DECISION REQUIRED
- Data Safety answers and retention disclosures: OWNER DECISION REQUIRED
- Reviewer credentials and release notes: OWNER DECISION REQUIRED

### Apple App Store

- Name: AI Study Buddy
- Subtitle, description, keywords: OWNER DECISION REQUIRED
- Support/privacy URLs and copyright owner: OWNER DECISION REQUIRED
- Screenshots/device sets and age rating: OWNER DECISION REQUIRED
- App Privacy answers: OWNER DECISION REQUIRED
- Review notes/test account: OWNER DECISION REQUIRED
- Encryption/export compliance and account deletion: OWNER DECISION REQUIRED

### Windows and Web

- Product description, publisher/legal identity: OWNER DECISION REQUIRED
- Support contact, privacy URL, website/domain: OWNER DECISION REQUIRED
- Screenshots, requirements, release notes, update channel: OWNER DECISION REQUIRED

## Factual privacy and data inventory

Retention is unknown unless stated. This is a technical inventory for review,
not legal advice and does not assign legal controller/processor roles.

| Data | Collected/processed | Stored/shared | Deletion and retention |
|---|---|---|---|
| Auth identity/session | Email, password-auth responses, user ID and session | Supabase Auth; session persisted locally by its client | Sign-out clears the local active session; account deletion is missing; retention unknown |
| Profile | Email and display name | Supabase `profiles` | Profile row can be deleted, but that is not Auth-user deletion; retention unknown |
| Subjects/materials | User titles, text, associations and processing state | Supabase database | Material deletion exists; subject deletion is missing |
| Private uploads | PDF/image bytes and metadata | User-scoped Supabase Storage paths and material metadata | Material lifecycle removes its Storage object; account-wide cleanup is missing |
| Extracted/OCR content | PDF/image text and processing metadata | Material database records; OCR may pass content to OpenAI through Edge Functions | Material deletion removes the material; provider/log retention unknown |
| Summaries/flashcards/quizzes | Source content processed for generated study output | OpenAI through Supabase Edge Functions; results stored in Supabase | Material-specific generated rows are removed by material deletion; retention otherwise unknown |
| Attempts/progress/weak topics | Answers, scores and derived learning state | Supabase database | Historical records may remain after material deletion; policy undecided |
| Sessions/history/favorites | Study activity and saved material links | Supabase database | Favorites for a material are removed; history retention is undecided |
| Usage/quota | Usage schema exists; some function TODOs show enforcement/logging is incomplete | Supabase tables when implemented | No defined user deletion/retention workflow |
| Local preferences | Language and appearance | Device SharedPreferences | Remain until app data is cleared; no in-app reset currently documented |
| Logs | Operation ID, stage, status and safe error class in current deletion flow; platform/provider logs may also exist | Edge Function/runtime providers | Exact provider contents and retention require configuration review |

OpenAI credentials remain server-side. The client communicates with Supabase;
Edge Functions send relevant content to OpenAI for supported OCR/generation
operations. Exact vendor regions, contractual terms, retention controls, legal
basis, export, and user-access processes remain owner/legal decisions.

## Deletion gaps

- Material deletion is implemented and removes the uploaded Storage object,
  material-specific favorites/flashcards/quizzes, and the material row.
- Historical attempts, progress, weak topics, and study history can remain with
  cleared or preserved relationships and need an explicit retention decision.
- Subject deletion has no current user/repository workflow.
- Account deletion has no trusted server workflow or in-app action.
- Deleting `profiles` is not equivalent to deleting `auth.users`.
- Database cascades from an Auth user do not delete Storage objects; an account
  workflow must enumerate and remove user-owned objects, handle retries, then
  remove database/Auth state in an approved order.

Phase 12.1 now implements subject and account deletion locally through migration
007, trusted Edge Functions, and localized Flutter flows. Remote migration and
function deployment remain pending. Provider logs, backups/PITR, vendor
retention, and legal review remain unresolved; local implementation does not
establish complete-erasure or legal compliance.

## Supabase production release runbook

1. Hash every immutable migration and record its ordered filename/hash set.
2. Apply reviewed migrations local, then staging, then the identical set to
   production. Never edit an applied migration.
3. Compare schema, RLS enablement/policies, Storage buckets/policies, Auth
   providers/settings, and redirect URLs across environments.
4. Record and deploy reviewed Edge Function revisions by explicit project;
   configure server secrets independently and never expose them to Flutter.
5. Record frontend commit/version/build alongside migrations and functions.
6. Smoke-test auth/reset/sign-out, authorization denial, CRUD, upload/download,
   OCR/extraction, AI generation, quizzes/progress, and Storage-backed deletion.
7. Confirm backup/PITR availability, restoration constraints, and responsible
   incident owner before go-live.
8. Use a signed go/no-go record containing environment, evidence links, owners,
   known warnings, compatibility, and rollback/forward-fix decision.
9. Prefer forward-fix database migrations. Restore a recorded compatible Edge
   Function revision only when safe; document incident timestamps and evidence.

This runbook is documentation only; no remote command was run.

## Approval gates and remaining work

Approval is required before generating/importing signing material, configuring
protected secrets, selecting a host/domain, changing Supabase, creating store
records, uploading/deploying, adding installer dependencies, signing Windows,
changing versions, implementing deletion, or supplying legal/store answers.

Remaining submission work includes real Android signing/fingerprint/device
verification, macOS archive/signing/device testing, Windows publisher/signing or
installer decisions, Web host/security/redirect configuration, legal review,
final metadata/assets, and each store's review process.
