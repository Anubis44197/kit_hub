param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [string]$TaskId = ""
)

$ErrorActionPreference = "Stop"
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

# Jev Karar Hakemligi (System One Entegrasyonu - Fail-Safe / Kota Korumali)
$jevDecision = $null
$jevClientPath = Join-Path $PSScriptRoot "typesafe_jev_client.js"
if (Test-Path -LiteralPath $jevClientPath -PathType Leaf) {
  try {
    $evalCandidate = $null
    if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
      $evObj = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
      foreach ($item in @($evObj.evidence_files)) {
        $cand = Join-Path $ProjectRoot (([string]$item.path) -replace '/', '\')
        if ((Test-Path -LiteralPath $cand -PathType Leaf) -and ($cand -match '\.(md|txt)$')) {
          $evalCandidate = $cand
          break
        }
      }
    }
    if (-not $evalCandidate) {
      $wsCandidate = Join-Path $ProjectRoot "revision/_workspace"
      if (Test-Path -LiteralPath $wsCandidate -PathType Container) {
        $recent = Get-ChildItem -LiteralPath $wsCandidate -Filter "*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($recent) { $evalCandidate = $recent.FullName }
      }
    }

    if ($evalCandidate) {
      $nodeOutput = & node $jevClientPath "judge" $evalCandidate $Phase 2>$null
      if ($nodeOutput) {
        $jevDecision = $nodeOutput | ConvertFrom-Json
        if ($jevDecision.verdict -eq "REWRITE" -and $jevDecision.confidence -ge 0.80) {
          $verdict = "revision_required"
          $reasons += "Jev Hakemi revizyon karari verdi (Guven: $($jevDecision.confidence), Skor: $($jevDecision.qualityScore))."
        }
        elseif ($jevDecision.verdict -eq "BLOCKED") {
          $verdict = "revision_required"
          $reasons += "Jev Hakemi faza bloke karari verdi."
        }
      }
    }
  } catch {
    # Fail-safe: Jev hatası veya kota sonu durumunda ana süreç aksamaz
    Write-Host "[verifier] Jev hakemligi yedek moda gecti: $($_.Exception.Message)"
  }
}

$result = [ordered]@{ schema_version = "1.0.0"; run_id = $RunId; task_id = $TaskId; phase = $Phase; verdict = $verdict; checked_at = (Get-Date).ToString("o"); reasons = @($reasons); context_pack = $contextPath; evidence = $evidencePath; jev_decision = $jevDecision }
$resultPath = Join-Path $runRoot "verification.json"
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result | ConvertTo-Json -Depth 20 -Compress
if ($verdict -ne "pass") { exit 2 }

