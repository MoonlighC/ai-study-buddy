param(
  [Parameter(Mandatory = $true)][string]$Psql,
  [int]$Port = 55432,
  [string]$Database = 'c1_dev'
)

$ErrorActionPreference = 'Stop'

function Query-Scalar([string]$Sql) {
  $value = & $Psql -h 127.0.0.1 -p $Port -U postgres -d $Database -At -v ON_ERROR_STOP=1 -c $Sql
  if ($LASTEXITCODE -ne 0) { throw "psql query failed: $Sql" }
  return ($value | Select-Object -Last 1).Trim()
}

function Start-Sql([string]$Sql) {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $Psql
  $info.UseShellExecute = $false
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $escapedSql = $Sql.Replace('"', '\"')
  $info.Arguments = "-h 127.0.0.1 -p $Port -U postgres -d $Database -At -v ON_ERROR_STOP=1 -c `"$escapedSql`""
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $info
  [void]$process.Start()
  return $process
}

function Wait-Sql([System.Diagnostics.Process]$Process) {
  $stdout = $Process.StandardOutput.ReadToEndAsync()
  $stderr = $Process.StandardError.ReadToEndAsync()
  $Process.WaitForExit()
  return [pscustomobject]@{
    ExitCode = $Process.ExitCode
    Stdout = $stdout.Result.Trim()
    Stderr = $stderr.Result.Trim()
  }
}

$jobs = @{}
foreach ($material in @(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'
)) {
  $jobs[$material] = Query-Scalar "select id from public.material_processing_jobs where material_id='$material'"
}

$claim = {
  param([string]$Job)
  "set role service_role; select batch_id,lease_token from public.claim_material_processing_batch_internal('$Job','page_text');"
}

# A held coordination lock for user one must not delay a claim for user two.
$holder = Start-Sql "begin; select pg_advisory_xact_lock(hashtextextended('11111111-1111-1111-1111-111111111111',0)); select pg_sleep(2); commit;"
Start-Sleep -Milliseconds 250
$watch = [System.Diagnostics.Stopwatch]::StartNew()
$differentUser = Wait-Sql (Start-Sql (& $claim $jobs['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2']))
$watch.Stop()
if ($differentUser.ExitCode -ne 0 -or $watch.ElapsedMilliseconds -ge 1500) {
  throw "different-user claim blocked or failed: $($differentUser.Stderr)"
}
[void](Wait-Sql $holder)

# Two separate connections racing for one batch produce exactly one winner.
$sameBatchProcesses = @(
  (Start-Sql (& $claim $jobs['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'])),
  (Start-Sql (& $claim $jobs['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1']))
)
$sameBatchResults = $sameBatchProcesses | ForEach-Object { Wait-Sql $_ }
if (@($sameBatchResults | Where-Object ExitCode -eq 0).Count -ne 1) {
  throw "same-batch race did not produce exactly one winner: $($sameBatchResults | ConvertTo-Json -Compress)"
}

# Three separate connections claiming three jobs for one user are serialized by
# the advisory lock; exactly two leases are granted and the third fails safely.
$sameUserProcesses = @(
  (Start-Sql (& $claim $jobs['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'])),
  (Start-Sql (& $claim $jobs['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'])),
  (Start-Sql (& $claim $jobs['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3']))
)
$sameUserResults = $sameUserProcesses | ForEach-Object { Wait-Sql $_ }
if (@($sameUserResults | Where-Object ExitCode -eq 0).Count -ne 2) {
  throw "same-user race did not enforce exactly two active materials: $($sameUserResults | ConvertTo-Json -Compress)"
}
if (@($sameUserResults | Where-Object { $_.Stderr -match 'user_concurrency_limit' }).Count -ne 1) {
  throw "same-user loser did not fail with user_concurrency_limit"
}

Write-Output 'PHASE_C1_CONCURRENCY_OK same_batch=1/2 same_user=2/3 different_user_nonblocking=true'
