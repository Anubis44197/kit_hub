param(
  [string]$WorkspaceRoot = (Get-Location).Path,
  [string]$TestRunPath = "test-run",
  [switch]$RequireDocx
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$finalReadinessScript = Join-Path $scriptRoot "final_readiness_check.ps1"
$docxIntegrityScript = Join-Path $scriptRoot "verify_docx_integrity.ps1"

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Assert-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Missing required directory: $Path"
  }
}

Push-Location $WorkspaceRoot
try {
  Write-Host "[external-smoke] workspace=$WorkspaceRoot"

  git rev-parse --is-inside-work-tree 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Current workspace is not a git repository."
  }

  Write-Host "[external-smoke] running final readiness..."
  & powershell -ExecutionPolicy Bypass -File $finalReadinessScript
  if ($LASTEXITCODE -ne 0) {
    throw "final_readiness_check.ps1 failed with exit code: $LASTEXITCODE"
  }

  $resolvedTestRun = Join-Path $WorkspaceRoot $TestRunPath
  if (-not (Test-Path -LiteralPath $resolvedTestRun)) {
    Write-Host "[external-smoke] test-run folder not found, skipping run-artifact checks."
    Write-Host "[external-smoke] PASS (repo-level checks only)"
    return
  }

  Write-Host "[external-smoke] checking external run artifacts..."
  Assert-Directory (Join-Path $resolvedTestRun "design")
  Assert-Directory (Join-Path $resolvedTestRun "episode")
  Assert-Directory (Join-Path $resolvedTestRun "revision")
  Assert-Directory (Join-Path $resolvedTestRun "revision\_workspace")
  Assert-File (Join-Path $resolvedTestRun "novel-config.md")

  Assert-File (Join-Path $resolvedTestRun "revision\_workspace\08_tdk-polisher_issues_EP001.json")
  Assert-File (Join-Path $resolvedTestRun "revision\_workspace\09_tdk-layout_issues_EP001.json")
  Assert-File (Join-Path $resolvedTestRun "revision\_workspace\quality-verifier_EP001.md")
  Assert-File (Join-Path $resolvedTestRun "episode\ep001.md")

  if ($RequireDocx) {
    $docxPath = Join-Path $resolvedTestRun "revision\export\EP001.docx"
    Assert-File $docxPath
    Write-Host "[external-smoke] validating DOCX integrity..."
    & powershell -ExecutionPolicy Bypass -File $docxIntegrityScript -DocxPath $docxPath
    if ($LASTEXITCODE -ne 0) {
      throw "verify_docx_integrity.ps1 failed with exit code: $LASTEXITCODE"
    }
  }

  Write-Host "[external-smoke] PASS"
}
finally {
  Pop-Location
}
