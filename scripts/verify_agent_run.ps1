param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [string]$TaskId = "",
  [string]$JevClientPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $JevClientPath) { $JevClientPath = Join-Path $PSScriptRoot "typesafe_jev_client.js" }
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$runRoot = Join-Path $ProjectRoot ("runtime/agent-runs/{0}" -f $RunId)
$contextPath = Join-Path $runRoot "context-pack.json"
$checks = @()
$verdict = "pass"
$reasons = @()

if (-not (Test-Path -LiteralPath $contextPath -PathType Leaf)) { $verdict = "revision_required"; $reasons += "Context Pack is missing." }
else {
  $pack = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
  foreach ($source in @($pack.files)) {
    $path = Join-Path $ProjectRoot ($source.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $verdict = "revision_required"; $reasons += "Context source missing: $($source.path)"; continue }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne [string]$source.sha256) { $verdict = "revision_required"; $reasons += "Context source changed: $($source.path)" }
  }
}
$evidencePath = Join-Path $ProjectRoot ("runtime/agent-compliance/{0}.json" -f $Phase)
if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { $verdict = "revision_required"; $reasons += "Agent compliance evidence is missing for phase: $Phase" }
else {
  # Bagimsiz icerik kapisi: kanit dosyalari var olmali ve anlamlı içerik barindirmali.
  try {
    $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
    foreach ($item in @($evidence.evidence_files)) {
      $p = Join-Path $ProjectRoot (([string]$item.path) -replace '/', '\')
      if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $verdict = "revision_required"; $reasons += "Evidence file missing: $($item.path)"; continue }
      $len = (Get-Item -LiteralPath $p).Length
      if ($len -lt 64) { $verdict = "revision_required"; $reasons += "Evidence file is trivially small ($len bytes): $($item.path)" }
    }
  } catch { $verdict = "revision_required"; $reasons += "Compliance evidence unreadable: $($_.Exception.Message)" }
}

# Critical phases use the same evidence-backed Jev gate as the main pipeline.
$jevDecision = $null
$jevGate = $null
$gatePath = Join-Path $PSScriptRoot "jev_phase_gate.ps1"
$gateReportPath = Join-Path $runRoot "jev-decision.json"
if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) {
  $verdict = "revision_required"
  $reasons += "Jev phase gate is missing."
}
else {
  $gateOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $gatePath -ProjectRoot $ProjectRoot -RunId $RunId -Phase $Phase -EvidencePath $evidencePath -ReportPath $gateReportPath -ClientPath $JevClientPath
  if (Test-Path -LiteralPath $gateReportPath -PathType Leaf) {
    $jevGate = Get-Content -LiteralPath $gateReportPath -Raw | ConvertFrom-Json
    $jevDecision = $jevGate.jev_decision
    if ($jevGate.status -notin @("pass", "not_applicable")) {
      $verdict = "revision_required"
      $reasons += "Jev phase gate: $($jevGate.status): $($jevGate.reason)"
    }
  }
  else {
    $verdict = "revision_required"
    $reasons += "Jev phase gate produced no decision report."
  }
  if ($LASTEXITCODE -ne 0) { $verdict = "revision_required" }
}

$result = [ordered]@{ schema_version = "1.0.0"; run_id = $RunId; task_id = $TaskId; phase = $Phase; verdict = $verdict; checked_at = (Get-Date).ToString("o"); reasons = @($reasons); context_pack = $contextPath; evidence = $evidencePath; jev_decision = $jevDecision; jev_gate = $jevGate }
$resultPath = Join-Path $runRoot "verification.json"
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result | ConvertTo-Json -Depth 20 -Compress
if ($verdict -ne "pass") { exit 2 }

