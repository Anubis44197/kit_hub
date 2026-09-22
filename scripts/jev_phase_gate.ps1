param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [Parameter(Mandatory = $true)][string]$ReportPath,
  [string]$EvidencePath = "",
  [string]$CandidatePath = "",
  [string]$ClientPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $ClientPath) { $ClientPath = Join-Path $PSScriptRoot "typesafe_jev_client.js" }
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$status = "revision_required"
$reason = ""
$candidate = ""
$decision = $null
$exportDecision = $null
$critical = $Phase -in @("create", "polish", "rewrite", "export")

function Resolve-ProjectText {
  param([string]$Path)
  if (-not $Path) { return "" }
  $full = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
  $prefix = $ProjectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return "" }
  if ($full -notmatch '\.(md|txt)$' -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { return "" }
  if ((Get-Item -LiteralPath $full).Length -lt 64) { return "" }
  return $full
}

try {
  if (-not $critical) {
    $status = "not_applicable"
    $reason = "Jev phase gate applies to create, polish, rewrite and export."
  }
  else {
    $candidate = Resolve-ProjectText -Path $CandidatePath
    if (-not $candidate -and $EvidencePath -and (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
      $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
      foreach ($item in @($evidence.evidence_files)) {
        $candidate = Resolve-ProjectText -Path ([string]$item.path)
        if ($candidate) { break }
      }
    }
    if (-not $candidate) {
      $candidate = Resolve-ProjectText -Path ("revision/_workspace/00_chief-editor-orchestrator_{0}.md" -f $Phase)
    }
    if (-not $candidate) { throw "No phase-specific text evidence available for Jev review." }
    if (-not (Test-Path -LiteralPath $ClientPath -PathType Leaf)) { throw "Jev client is missing." }

    $raw = & node $ClientPath judge $candidate $Phase 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Jev judge process failed (exit=$LASTEXITCODE)." }
    $decision = ($raw | Out-String | ConvertFrom-Json)
    if ($decision.isFallback -or $decision.source -ne "jev") {
      $status = "review_required"
      $reason = "Jev is unavailable; local heuristic cannot approve a critical phase."
    }
    elseif ($decision.verdict -eq "BLOCKED") {
      $status = "blocked"
      $reason = "Jev blocked the phase."
    }
    elseif ($decision.verdict -eq "REWRITE") {
      $status = "revision_required"
      $reason = "Jev requested a rewrite."
    }
    elseif ($decision.verdict -eq "PASS") {
      $status = "pass"
      $reason = "Jev approved the phase text."
    }
    else {
      throw "Jev returned an invalid verdict."
    }

    if ($Phase -eq "export" -and $status -eq "pass") {
      $raw = & node $ClientPath gate $candidate 2>&1
      if ($LASTEXITCODE -ne 0) { throw "Jev export gate process failed (exit=$LASTEXITCODE)." }
      $exportDecision = ($raw | Out-String | ConvertFrom-Json)
      if ($exportDecision.isFallback -or $exportDecision.source -ne "jev") {
        $status = "review_required"
        $reason = "Jev export gate is unavailable; publication needs review."
      }
      elseif ($exportDecision.approved -ne $true) {
        $status = "revision_required"
        $reason = "Jev export gate did not approve publication."
      }
    }
  }
}
catch {
  $status = "review_required"
  $reason = $_.Exception.Message
}

$candidateHash = if ($candidate) { (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant() } else { "" }
$relativeCandidate = if ($candidate) { $candidate.Substring($ProjectRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/') } else { "" }
$report = [ordered]@{
  schema_version = "1.0.0"
  run_id = $RunId
  phase = $Phase
  checked_at = (Get-Date).ToString("o")
  status = $status
  reason = $reason
  candidate = $relativeCandidate
  candidate_sha256 = $candidateHash
  jev_decision = $decision
  export_decision = $exportDecision
}
$parent = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
[IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
$report | ConvertTo-Json -Depth 20 -Compress
if ($status -notin @("pass", "not_applicable")) { exit 2 }
