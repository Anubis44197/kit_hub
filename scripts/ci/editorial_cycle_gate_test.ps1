param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8Json {
  param(
    [string]$Path,
    [object]$Value
  )
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-EditorialCycleGateBlock {
  param([string]$RunnerPath)

  $raw = [System.IO.File]::ReadAllText($RunnerPath, [System.Text.Encoding]::UTF8)
  $match = [regex]::Match(
    $raw,
    "(?s)function Ensure-File\s*\{.*?\r?\nfunction Validate-MarkdownVerdictContract\s*\{"
  )
  if (-not $match.Success) {
    throw "Could not locate editorial cycle gate function block in $RunnerPath"
  }
  return ($match.Value -replace "\r?\nfunction Validate-MarkdownVerdictContract\s*\{$", "")
}

function Assert-ThrowsLike {
  param(
    [scriptblock]$Action,
    [string]$Pattern,
    [string]$Label
  )
  try {
    & $Action
  }
  catch {
    if ($_.Exception.Message -match $Pattern) {
      Write-Host "[editorial-cycle-test] PASS blocked: $Label"
      return
    }
    throw "Unexpected error for ${Label}: $($_.Exception.Message)"
  }
  throw "Expected failure did not occur: $Label"
}

$gateBlock = Get-EditorialCycleGateBlock -RunnerPath (Join-Path $RepoRoot "scripts/run_pipeline.ps1")
Invoke-Expression $gateBlock

$testRoot = Join-Path $RepoRoot (".tmp/editorial-cycle-gate-test-" + [guid]::NewGuid().ToString("N"))
$workspace = Join-Path $testRoot "revision/_workspace"
$state = Join-Path $testRoot "revision/_state"
[System.IO.Directory]::CreateDirectory($workspace) | Out-Null
[System.IO.Directory]::CreateDirectory($state) | Out-Null

try {
  Write-Utf8Json -Path (Join-Path $state "editorial-quality-scorecard.json") -Value ([ordered]@{
    schema_version = "1.2.0"
    run_id = "test-run"
    threshold_pass = 85
    axes = @("continuity", "progression", "style", "language", "publication-readiness", "type-fit")
  })

  Assert-ThrowsLike `
    -Label "missing editorial cycle report" `
    -Pattern "missing revision/_workspace/\*editorial-cycle\*\.json" `
    -Action { Validate-EditorialCycleContract -Root $testRoot -Phase "create" -Enabled $true }

  $reportPath = Join-Path $workspace "create_editorial-cycle_EP001.json"
  Write-Utf8Json -Path $reportPath -Value ([ordered]@{
    run_id = "test-run"
    step_id = "create-001"
    phase = "create"
    writing_type = "novel"
    verdict = "PASS"
    threshold_pass = 85
    scores = [ordered]@{
      continuity = 70
      progression = 90
      style = 90
      language = 90
      "publication-readiness" = 90
      "type-fit" = 90
    }
    issue_summary = [ordered]@{
      critical = 0
      major = 0
      minor = 1
      manual_review_required = $false
    }
    required_fixes = @()
    next_action = "continue"
    reviewed_artifacts = @("episode/ep001.md")
  })

  Assert-ThrowsLike `
    -Label "PASS below continuity threshold" `
    -Pattern "PASS with axis 'continuity' below threshold" `
    -Action { Validate-EditorialCycleContract -Root $testRoot -Phase "create" -Enabled $true }

  Write-Utf8Json -Path $reportPath -Value ([ordered]@{
    run_id = "test-run"
    step_id = "create-001"
    phase = "create"
    writing_type = "novel"
    verdict = "REWRITE"
    threshold_pass = 85
    scores = [ordered]@{
      continuity = 80
      progression = 82
      style = 84
      language = 88
      "publication-readiness" = 86
      "type-fit" = 83
    }
    issue_summary = [ordered]@{
      critical = 0
      major = 1
      minor = 2
      manual_review_required = $true
    }
    required_fixes = @()
    next_action = "rewrite_required"
    reviewed_artifacts = @("episode/ep001.md")
  })

  Assert-ThrowsLike `
    -Label "REWRITE without required fixes" `
    -Pattern "REWRITE/BLOCKED verdict must include required_fixes" `
    -Action { Validate-EditorialCycleContract -Root $testRoot -Phase "create" -Enabled $true }

  Write-Utf8Json -Path $reportPath -Value ([ordered]@{
    run_id = "test-run"
    step_id = "create-001"
    phase = "create"
    writing_type = "novel"
    verdict = "PASS"
    threshold_pass = 85
    scores = [ordered]@{
      continuity = 91
      progression = 90
      style = 89
      language = 93
      "publication-readiness" = 88
      "type-fit" = 90
    }
    issue_summary = [ordered]@{
      critical = 0
      major = 0
      minor = 1
      manual_review_required = $false
    }
    required_fixes = @()
    next_action = "continue"
    reviewed_artifacts = @("episode/ep001.md", "revision/_workspace/04_quality-verifier_verdict_EP001.md")
  })

  Validate-EditorialCycleContract -Root $testRoot -Phase "create" -Enabled $true
  Write-Host "[editorial-cycle-test] PASS accepted: valid editorial cycle report"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
