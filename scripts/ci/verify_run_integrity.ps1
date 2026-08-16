param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$runtime = Join-Path $ProjectRoot "runtime"
$pointerPath = Join-Path $runtime "current-run.json"
if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) { throw "Missing current-run.json" }
$pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
$runId = [string]$pointer.run_id
if (-not $runId) { throw "current-run.json missing run_id" }
$summaryPath = Join-Path $ProjectRoot ([string]$pointer.summary_path -replace "/", "\")
if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) { throw "Missing run summary: $summaryPath" }
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$issues = @()
if ([string]$summary.run_id -ne $runId) { $issues += "Pointer/summary run_id mismatch." }
$evidenceDir = Join-Path $ProjectRoot ([string]$pointer.evidence_dir -replace "/", "\")
$evidence = @(Get-ChildItem -LiteralPath $evidenceDir -Filter "*.json" -File -ErrorAction SilentlyContinue)
$artifactRecords = @()
foreach ($file in $evidence) {
  $obj = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
  if ([string]$obj.run_id -ne $runId) { $issues += "$($file.Name): run_id mismatch." }
  foreach ($artifact in @($obj.output_artifacts)) {
    $relative = [string]$artifact
    $full = Join-Path $ProjectRoot ($relative -replace "/", "\")
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
      $artifactRecords += [ordered]@{ path = $relative; sha256 = $hash; age_seconds = [math]::Round(((Get-Date) - (Get-Item -LiteralPath $full).LastWriteTime).TotalSeconds, 0) }
    } else { $issues += "$($file.Name): missing artifact $relative" }
  }
}
$hashInputs = @("novel-config.md","runtime/runner-config.json","runtime/agent-registry.json","runtime/agent-status-contract.json") | ForEach-Object { Join-Path $ProjectRoot $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
$combined = (($hashInputs | Sort-Object | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) -join "|")
$inputHash = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($combined))
$report = [ordered]@{ schema_version = "1.0.0"; run_id = $runId; checked_at = (Get-Date).ToString("o"); input_hash = $inputHash; config_hash = if(Test-Path -LiteralPath (Join-Path $ProjectRoot "runtime/runner-config.json")){(Get-FileHash -LiteralPath (Join-Path $ProjectRoot "runtime/runner-config.json") -Algorithm SHA256).Hash}else{""}; artifact_count = $artifactRecords.Count; artifact_records = $artifactRecords; issues = @($issues); verdict = if($issues.Count -eq 0){"PASS"}else{"BLOCKED"} }
$out = Join-Path $runtime "run-integrity-report.json"
[IO.File]::WriteAllText($out, ($report | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($true))
if ($issues.Count -gt 0) { Write-Error ($issues -join "; "); exit 1 }
Write-Host "[run-integrity] PASS run_id=$runId artifacts=$($artifactRecords.Count)"
