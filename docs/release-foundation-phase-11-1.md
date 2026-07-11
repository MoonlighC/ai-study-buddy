# Phase 11.1 release foundation

## Product identity and targets

| Concern | Value |
|---|---|
| Display/product name | AI Study Buddy |
| Dart package and Windows executable | `ai_study_buddy`, `ai_study_buddy.exe` |
| Android/iOS identifier | `com.moonlightc.aistudybuddy` |
| iOS test identifier | `com.moonlightc.aistudybuddy.RunnerTests` |
| Future macOS identifier | `com.moonlightc.aistudybuddy` (documented only) |
| Version | `1.0.0+1` |

Android, web, and Windows are locally buildable release targets. iOS is
configuration-ready but requires macOS/Xcode for archive, signing, icon and
launch-screen rendering, and device verification. macOS and Linux scaffolds are
deferred. The product name and mark have not received legal trademark clearance.

## Deterministic environments

Environment selection uses compile-time Dart defines only. It is never inferred
from build mode, hostname, platform, project URL, or another value.

| `APP_ENV` | Backend rule | Release rule |
|---|---|---|
| `local` | mock by default; explicitly configured Supabase allowed | mock rejected |
| `staging` | Supabase required | Supabase required |
| `production` | Supabase required | Supabase required |

Required variables are `APP_ENV`, `APP_BACKEND_MODE`, `SUPABASE_URL`, and
`SUPABASE_ANON_KEY`. Staging and production use the same application identifier
and therefore cannot be installed side by side. Unknown modes and invalid,
missing, local, loopback, placeholder, non-HTTPS, or server-secret configuration
fail before repository initialization. Errors name fields but never values.

The checked-in `config/local.example.dart-defines.json` contains placeholders
only. Store actual define files outside Git or in ignored `*.dart-defines.json`
files. CI should expose variables with the same four names and assemble command
arguments without printing their values.

Public client configuration consists of the Supabase URL and anon/publishable
key. `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, database credentials,
signing material, and auth payloads are secret/server-only and must never enter
the Flutter bundle or logs.

## Builds and platform configuration

Example production build (PowerShell variables are supplied externally):

```powershell
$defines = @(
  '--dart-define=APP_ENV=production'
  '--dart-define=APP_BACKEND_MODE=supabase'
  "--dart-define=SUPABASE_URL=$env:SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY"
)
flutter build apk --release @defines
flutter build appbundle --release @defines
flutter build web --release @defines
flutter build windows --release @defines
```

Android resolves `minSdk 24`, `targetSdk 36`, and `compileSdk 36` with the
current Flutter 3.44.4 toolchain. It uses debug signing for
release compilation verification. Such APK/AAB files are non-distributable and
must not be uploaded. Authentication/session data is conservatively excluded
from Android backup and device transfer; cleartext networking is disabled.
Shrinking remains disabled pending a signed plugin smoke audit.

Web environment values are compiled into the application. Hosting origin,
`--base-href`, headers, and deployment topology remain Phase 11.2 decisions.
Each deployment must invalidate the Flutter service-worker/cache version so old
assets or compiled environment configuration are not retained.

Windows retains `ai_study_buddy.exe`; installer packaging, publisher identity,
and code signing remain deferred. Release artifacts stay untracked and must be
stored only in an approved artifact system with version, environment, commit,
checksum, signing status, build result, warnings, and size recorded.

## Icons, launch, and versioning

`assets/brand/guided_s_path.svg` is the editable master and
`tool/generate_brand_assets.py` deterministically regenerates platform rasters.
The mark is symbol-only with platform-safe padding. Android includes legacy,
adaptive, and monochrome assets plus Android 12 and legacy static splashes. iOS
uses opaque AppIcons and a static launch mark. Web removes its static loader on
Flutter's first frame. Windows deliberately has no splash.

Use `MAJOR.MINOR.PATCH+BUILD`. Android maps these to
`versionName`/`versionCode`, iOS to `CFBundleShortVersionString`/
`CFBundleVersion`, and Windows to semantic version plus the fourth build
component. Increment build for every externally tested artifact. Label release
candidates in artifact/release metadata (`rc.N`), not pubspec prerelease syntax.

## Supabase promotion checklist

1. Maintain separate local, staging, and production projects.
2. Validate reviewed migrations locally, apply the exact set to staging, test,
   then promote the same set to production. Never edit an applied migration.
3. Compare schema, RLS policies, Auth settings/redirects, Storage buckets and
   policies, and Edge Function versions across staging and production.
4. Deploy reviewed Edge Function source by explicit project reference. Configure
   server-only secrets independently per project and verify callers/RLS.
5. Smoke-test authentication, CRUD, upload/download, AI/OCR calls, lifecycle
   cleanup, authorization denial, and sign-out for each promoted environment.
6. Record application version/build, commit, migration list, function versions,
   project/environment, and verification results without recording secrets.
7. Rotate leaked/expired secrets per project, redeploy affected functions, and
   revoke old credentials. Public client key rotation still requires rebuilding.
8. Prefer forward-fix migrations. Roll back function deployments to a known
   reviewed version where safe. Confirm provider/database backups before risky
   promotion and document restoration constraints.

No remote project is created or modified by Phase 11.1.

## Windows-host verification record

Verified on 2026-07-11 with non-secret, synthetic production-shaped public
configuration. This proves compilation and configuration validation only; it
does not prove connectivity to a Supabase project.

| Artifact | Result | Size |
|---|---|---:|
| Release APK (debug-signed) | Pass | 56,353,161 bytes |
| Release AAB (debug-signed) | Pass | 55,134,974 bytes |
| Web release directory | Pass | 43,539,130 bytes |
| Windows release directory | Pass | 32,535,101 bytes |

The Android build warns that `file_picker` still uses the Kotlin Gradle Plugin
under AGP 9 compatibility mode. A narrow Java/Kotlin 17 compatibility rule is
applied in the root Android build until `file_picker` and `app_links` support a
common built-in-Kotlin configuration. Web's successful Wasm dry run recommends
separate `--wasm` testing; this remains optional Phase 11.2 coverage.

## Phase 11.2 gates

- Android upload key, secure signing configuration, signed-device verification,
  Play packaging/policy review, and artifact provenance.
- macOS/Xcode archive, Apple developer membership, signing, provisioning,
  privacy manifest review, and physical iOS device verification.
- Web hosting, base path, caching headers, deployment/rollback, and browser matrix.
- Windows installer format, publisher/legal wording, code signing, install/update,
  and secure-storage verification.
- Store metadata/submission and final name/trademark review.
