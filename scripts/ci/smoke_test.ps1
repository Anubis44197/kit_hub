param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Path) -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Assert-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Path) -PathType Container)) {
    throw "Missing required directory: $Path"
  }
}

Write-Host "[smoke-ps] checking fixture presence..."
Assert-File "tests/fixtures/sample-project/novel-config.md"
Assert-Directory "tests/fixtures/sample-project/design"
Assert-Directory "tests/fixtures/sample-project/episode"
Assert-Directory "tests/fixtures/sample-project/revision"

Write-Host "[smoke-ps] checking mandatory agents..."
foreach ($path in @(
  "agents/tdk-polisher.md",
  "agents/tdk-layout-agent.md",
  "agents/export-approval-gate.md",
  "agents/export-validator.md",
  "agents/book-exporter.md"
)) {
  Assert-File $path
}

Write-Host "[smoke-ps] checking mandatory skills and revision scripts..."
foreach ($path in @(
  "skills/create/SKILL.md",
  "skills/polish/SKILL.md",
  "skills/rewrite/SKILL.md",
  "skills/export-word/SKILL.md",
  "scripts/revision_proposals.ps1",
  "scripts/apply_revision.ps1"
)) {
  Assert-File $path
}

Write-Host "[smoke-ps] checking runtime references..."
foreach ($path in @(
  "skills/polish/references/run-summary-schema.md",
  "skills/polish/references/error-code-glossary.md",
  "skills/polish/references/pipeline-metrics-spec.md"
)) {
  Assert-File $path
}

Write-Host "[smoke-ps] validating pipeline contract through PowerShell lint..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/ci/validate_contracts.ps1") -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) {
  throw "validate_contracts.ps1 failed with exit code: $LASTEXITCODE"
}

Write-Host "[smoke-ps] PASS"
