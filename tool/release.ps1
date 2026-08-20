param(
  [ValidateSet('validate','dry-run','package-web','package-windows','production-android','staging-android')][string]$Mode = 'validate',
  [ValidateSet('local','staging','production')][string]$Environment = 'production',
  [string]$RcLabel = '',
  [string]$DartDefinesFile = '',
  [int]$BuildNumber = 0,
  [string]$ExpectedProjectRef = '',
  [string]$ExpectedSignerSha256 = '',
  [ValidateSet('apk','aab')][string[]]$Artifacts = @('apk','aab'),
  [switch]$Execute
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $dart = 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe'; if (-not (Test-Path $dart)) { $dart = 'dart' }
  foreach ($command in @('metadata','version','android-structure','template-assets')) {
    & $dart run tool/release_validation_cli.dart $command
    if ($LASTEXITCODE -ne 0) { throw "$command validation failed." }
  }
  if ($Mode -eq 'validate') { Write-Output 'Release validation completed. No build or packaging was performed.'; exit 0 }
  if ($Mode -eq 'dry-run') {
    Write-Output 'Dry run fields: APP_ENV, APP_BACKEND_MODE, SUPABASE_URL, SUPABASE_ANON_KEY.'
    Write-Output 'Dry run signing fields: keystorePath, keyAlias, storePassword, keyPassword.'
    Write-Output 'Planned steps: validate metadata; validate configuration; build; validate output; package; checksum; manifest.'
    Write-Output 'No supplied values, build, signing, or packaging operation was performed.'; exit 0
  }
  if ($Mode -eq 'staging-android') {
    if (-not $DartDefinesFile -or -not (Test-Path -LiteralPath $DartDefinesFile -PathType Leaf)) { throw 'Ignored staging dart-defines file is required.' }
    if ($BuildNumber -le 0) { throw 'A positive reserved build number is required.' }
    if (-not $ExpectedProjectRef) { throw 'ExpectedProjectRef is required.' }
    if (-not $ExpectedSignerSha256) { throw 'ExpectedSignerSha256 is required.' }
    $config = Get-Content -LiteralPath $DartDefinesFile -Raw | ConvertFrom-Json
    foreach ($field in @('APP_ENV','APP_BACKEND_MODE','SUPABASE_URL','SUPABASE_ANON_KEY')) {
      if (-not $config.PSObject.Properties[$field]) { throw "Staging configuration is missing field: $field." }
    }
    $previous = @{}
    foreach ($field in @('APP_ENV','APP_BACKEND_MODE','SUPABASE_URL','SUPABASE_ANON_KEY')) {
      $previous[$field] = [Environment]::GetEnvironmentVariable($field, 'Process')
      [Environment]::SetEnvironmentVariable($field, [string]$config.$field, 'Process')
    }
    try {
      & $dart run tool/release_validation_cli.dart staging-beta-config "--expected-project-ref=$ExpectedProjectRef"
      if ($LASTEXITCODE -ne 0) { throw 'Staging beta configuration validation failed.' }
    } finally {
      foreach ($field in $previous.Keys) { [Environment]::SetEnvironmentVariable($field, $previous[$field], 'Process') }
    }
    & $dart run tool/release_validation_cli.dart reserved-build '--ledger=docs/internal/beta-build-history.json' "--number=$BuildNumber"
    if ($LASTEXITCODE -ne 0) { throw 'Reserved build-number validation failed.' }
    & $dart run tool/release_validation_cli.dart signer-fingerprint "--actual=$ExpectedSignerSha256" "--expected=$ExpectedSignerSha256"
    if ($LASTEXITCODE -ne 0) { throw 'Signer fingerprint structure validation failed.' }
    Write-Output 'Staging Android validation completed using fields: APP_ENV, APP_BACKEND_MODE, SUPABASE_URL, SUPABASE_ANON_KEY.'
    Write-Output 'Planned artifacts: APK/AAB as selected; package metadata; release signer; SHA-256; manifest; migration revisions.'
    if (-not $Execute) {
      Write-Output 'Execution is disabled. No build, signing, packaging, checksum, manifest, or distribution occurred.'
      exit 0
    }
    $signingFile = Join-Path $root 'android/key.properties'
    if (-not (Test-Path -LiteralPath $signingFile -PathType Leaf)) { throw 'Ignored local signing configuration is required for execution.' }
    git -c "safe.directory=$($root.Replace('\','/'))" check-ignore --quiet android/key.properties
    if ($LASTEXITCODE -ne 0) { throw 'Local signing configuration must be ignored by Git.' }
    $flutter = 'C:\src\flutter\bin\flutter.bat'; if (-not (Test-Path $flutter)) { $flutter = 'flutter' }
    $resolvedDefines = (Resolve-Path -LiteralPath $DartDefinesFile).Path
    $env:RELEASE_SIGNING_SOURCE = 'local'
    if ($Artifacts -contains 'apk') {
      & $flutter build apk --release '--build-name=1.0.0' "--build-number=$BuildNumber" "--dart-define-from-file=$resolvedDefines"
      if ($LASTEXITCODE -ne 0) { throw 'Signed staging APK build failed.' }
    }
    if ($Artifacts -contains 'aab') {
      & $flutter build appbundle --release '--build-name=1.0.0' "--build-number=$BuildNumber" "--dart-define-from-file=$resolvedDefines"
      if ($LASTEXITCODE -ne 0) { throw 'Signed staging AAB build failed.' }
    }
    Write-Output 'Approved staging Android build completed. Verification and packaging are still required before distribution.'
    exit 0
  }
  if ($Mode -eq 'production-android') { throw 'Production Android execution requires separately approved real signing material and is intentionally disabled.' }
  if ($Mode -eq 'package-web') { $source=Join-Path $root 'build/web'; $platform='web' }
  else { $source=Join-Path $root 'build/windows/x64/runner/Release'; $platform='windows-x64' }
  & $dart run tool/release_validation_cli.dart package-input "--platform=$platform" "--path=$source"
  if ($LASTEXITCODE -ne 0) { throw 'Package input validation failed.' }
  $name = & $dart run tool/release_validation_cli.dart artifact-name "--environment=$Environment" "--platform=$platform"
  if ($LASTEXITCODE -ne 0) { throw 'Artifact name validation failed.' }
  $output=Join-Path $root 'release-artifacts'; New-Item -ItemType Directory -Force $output | Out-Null
  $destination=Join-Path $output $name
  Compress-Archive -Path (Join-Path $source '*') -DestinationPath $destination -Force
  $checksum = & $dart run tool/release_validation_cli.dart checksum "--file=$destination"
  $checksum | Set-Content -Encoding ascii "$destination.sha256"
  Get-ChildItem $output -Filter '*.zip' | Sort-Object Name | ForEach-Object {
    & $dart run tool/release_validation_cli.dart checksum "--file=$($_.FullName)"
  } | Set-Content -Encoding ascii (Join-Path $output 'checksums.txt')
  $commit = git -c "safe.directory=$($root.Replace('\','/'))" rev-parse HEAD
  $timestamp = (Get-Date).ToUniversalTime().ToString('o')
  $architecture = if ($platform -eq 'windows-x64') { 'x64' } else { '' }
  & $dart run tool/release_validation_cli.dart manifest "--artifact=$destination" "--commit=$commit" "--environment=$Environment" '--backend=supabase' "--platform=$platform" "--architecture=$architecture" "--timestamp=$timestamp" '--flutter-version=3.44.4' '--signing-status=unsigned' "--rc=$RcLabel" | Set-Content -Encoding utf8 "$destination.manifest.json"
  if ($LASTEXITCODE -ne 0) { throw 'Build manifest generation failed.' }
  Write-Output "Package created in release-artifacts: $name"
} finally { Pop-Location }
