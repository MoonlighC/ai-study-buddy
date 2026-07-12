# Phase 12.2: staging beta distribution

## Approved strategy and status

The first beta is a private, direct signed Android APK. Google Play Internal Testing, paid Apple Developer membership, TestFlight, store records, public releases, and production deployment are deferred. iOS validation uses the owner's Mac, Xcode Personal Team, and physical iPhone only.

The shared Android/iOS build sequence is recorded in `docs/beta-build-history.json`. `1.0.0+2` is reserved for the first staging beta and is **not distributed**. Change a record to `distributed` and add its UTC distribution time only after an artifact has actually left owner custody. Never reuse or lower a build number.

Preflight on 2026-07-12 found a clean synchronized `main` at `bdcd9ac4dc79dad22bd0e95c0f4900ee5339554d`. The owner reported GitHub Actions Validate green; attach the exact run URL/ID to the beta evidence before distribution because it was unavailable through the local connector.

## Staging configuration contract

Every beta uses build-time configuration only:

```text
APP_ENV=staging
APP_BACKEND_MODE=supabase
SUPABASE_URL=<staging public URL>
SUPABASE_ANON_KEY=<staging public anon/publishable key>
```

The project ref must be `xwweqmvowhhlfefkulap`. Store values in an ignored `*.dart-defines.json` file; never track or print them. Mock mode, localhost, the production project, service-role keys, OpenAI keys, and Supabase secret keys are forbidden. The build manifest may record `staging` and `supabase`, but never URLs, keys, aliases, passwords, or credential/configuration paths.

The Settings diagnostics section displays a localized, accessible `Staging build` chip only when `AppConfig.environment` is staging. It exposes no backend details.

## Android signing approval gate

Do not generate a keystore until the owner has confirmed all of:

- key owner;
- storage location outside Git;
- password-manager entry;
- encrypted backup location 1;
- encrypted backup location 2;
- permanent alias;
- approved private delivery channel;
- named tester list.

After approval, use Android Studio/keytool interactively so passwords are not placed in shell history. Never put passwords in screenshots, Git, chat, command arguments, or copied logs. Record the creation date and certificate SHA-1/SHA-256 in a private operational record. Verify both encrypted backups can be recovered.

The developer key signs direct APKs and uploads to Google Play. Play App Signing would manage the Play-distributed signing key later. Direct APK updates require the same package ID, the same developer signing key, and a higher version code. Losing/changing that key prevents in-place updates. Debug-signed APKs are forbidden. Verify the certificate SHA-256 before every distribution.

Use the existing ignored `android/key.properties` only after approval:

```properties
storeFile=<absolute path outside repository>
keyAlias=<approved alias>
storePassword=<password manager value>
keyPassword=<password manager value>
```

## Android validation and future build

The current `staging-android` mode is intentionally validation/dry-run only:

```powershell
.\tool\release.ps1 `
  -Mode staging-android `
  -DartDefinesFile "<ignored path>" `
  -BuildNumber 2 `
  -ExpectedProjectRef "xwweqmvowhhlfefkulap" `
  -ExpectedSignerSha256 "<approved SHA-256>" `
  -Artifacts apk,aab
```

It validates field names, staging project, reserved build, and fingerprint structure without requiring signing material or invoking Flutter. A future explicitly approved execution path must validate a clean commit, signing configuration, package ID `com.moonlightc.aistudybuddy`, version `1.0.0+2`, release/non-debug signer, cleartext policy, checksums, and migrations `001–009` before producing:

- `AI-Study-Buddy-1.0.0+2-staging-android.apk`
- `AI-Study-Buddy-1.0.0+2-staging-android.aab`

The manifest must contain only safe artifact/build metadata. Validate the APK on a clean physical device before it leaves owner custody.

## Direct APK tester guide

This is a private staging beta. Use test data only; do not upload confidential or sensitive documents. Accounts and data may be deleted, AI output may be inaccurate, and production availability is not promised.

1. Download the APK only from the owner-approved private source; do not forward it.
2. Compare its SHA-256 with the separately provided checksum where practical.
3. Permit installation from that selected source when Android shows the unknown-source warning, then install.
4. Open Settings and confirm `Staging build` and the supplied build number.
5. Submit feedback through the private form below. Remove personal data from screenshots.
6. Install updates only from the owner; they must have the same signer and a higher version code.
7. Test account deletion only once, on a disposable final account.

Staging and production share the app ID and cannot be installed side by side. Uninstalling deletes local app data and the session. Never send passwords, emails, tokens, keys, IDs, complete documents, or raw private logs.

## Private feedback form

Allowed severity: `blocker`, `high`, `medium`, `low`, or `suggestion`.

Required fields: severity; build number; platform; device model; OS version; locale; light/dark mode; exact steps; expected result; actual result; redacted screenshot (optional when unavailable); approximate timestamp and timezone; whether retry, restart, or network restoration fixed it.

The form must not request password, email, user ID, access token, API key, complete uploaded document, or raw private Supabase/function log. The owner assigns a private issue ID and records resolution/retest status.

## Owner iPhone with free Personal Team

Windows cannot establish iOS readiness. On the Mac:

1. Clone the reviewed commit and confirm a clean synchronized tree.
2. Install/verify Xcode and Flutter; run `flutter doctor -v` and `flutter pub get`.
3. Create the ignored staging dart-defines JSON locally.
4. Open `ios/Runner.xcworkspace` and select the owner's Apple Account Personal Team with automatic signing.
5. Keep `com.moonlightc.aistudybuddy`. If Personal Team requires another development-only identifier, stop and document it; do not silently change the permanent release ID.
6. Connect/trust the iPhone, enable Developer Mode if requested, and run the app with the ignored staging defines.
7. Verify icon, launch screen, file picker, uploads, selectable PDF extraction, OCR, summary/flashcards/quiz, dark mode, en/de/ru, deletion, restart, and session restore.

Free provisioning generally expires and requires rebuilding. TestFlight and an App Store distribution archive require paid Apple Developer membership, so this run makes no App Store archive/readiness claim.

## One-week QA and safe monitoring

| Day | Ordinary-use focus | Evidence |
|---|---|---|
| 0 | Install, staging label/build, signup/login/session restore | Device/OS/build and result |
| 1 | Create/edit subject, paste material | Counts, sizes, failures/retries |
| 2 | PDF/image upload, selectable extraction, OCR | File type/size and duration |
| 3 | Summary, flashcards, training, quiz | Result and safe error code |
| 4 | Progress, favorites/search, light/dark, en/de/ru | Locale/theme coverage |
| 5 | Restart and network interruption/retry | Recovery result |
| 6 | Material/subject deletion with realistic data | Duration, retries, remaining Storage count |
| 7 | Final disposable account deletion and update check | Auth removal, signed-out state, cleanup/update result |

Record the largest tested account: file/material counts, approximate total and maximum sizes, extraction/deletion durations, failures/retries, and final Storage cleanup counts.

Use existing safe Supabase and Edge Function diagnostics for HTTP status distributions, safe error codes/stages, AI quota/rate failures, extraction failures, deletion retries, duration, and cleanup counts. Never log document content, OpenAI responses, credentials, emails, full user IDs, or Storage paths. No analytics/crash SDK is approved.

## Production exit criteria and deferred decisions

Production stays blocked until there are no critical/high beta defects; material/subject/account deletion evidence is complete; backup/PITR and production Auth/Storage/RLS are reviewed; the production ref is confirmed; migrations/functions are approved; privacy/support URLs exist; Android signing/device verification passes; and iOS device/archive verification passes for an iOS release.

Still deferred: keystore generation, real `key.properties`, signed builds, private delivery, Play Console/Internal Testing, paid Apple membership, TestFlight/App Store Connect, public store metadata, production deployment, and production versioning.
