param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Message
  )
  $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  if ($raw -notmatch $Pattern) {
    throw $Message
  }
}

Assert-Contains -Path (Join-Path $RepoRoot "scripts/run_pipeline.ps1") -Pattern "function Validate-LengthFulfillment" -Message "Missing Validate-LengthFulfillment gate."
Assert-Contains -Path (Join-Path $RepoRoot "scripts/run_pipeline.ps1") -Pattern "export blocked because total_words" -Message "Length gate must block under-length export."
Assert-Contains -Path (Join-Path $RepoRoot "scripts/run_pipeline.ps1") -Pattern "export blocked because written_chapters" -Message "Length gate must block missing chapter count."
Assert-Contains -Path (Join-Path $RepoRoot "scripts/run_pipeline.ps1") -Pattern "below chapter minimum" -Message "Length gate must block short completed chapters."
Assert-Contains -Path (Join-Path $RepoRoot "runtime/runner-config.template.json") -Pattern "length_fulfillment_gates" -Message "Default runner config missing length_fulfillment_gates."
Assert-Contains -Path (Join-Path $RepoRoot "runtime/runner-config.ide-manual.template.json") -Pattern "length_fulfillment_gates" -Message "IDE manual config missing length_fulfillment_gates."
Assert-Contains -Path (Join-Path $RepoRoot "skills/create/SKILL.md") -Pattern "Length Fulfillment" -Message "Create skill must explain length fulfillment."
Assert-Contains -Path (Join-Path $RepoRoot "docs/LONGFORM_ENGINE.md") -Pattern "Length Fulfillment" -Message "Longform docs must explain length fulfillment."

Write-Host "[length-fulfillment-gate-test] PASS"
