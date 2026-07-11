param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Assert-File {
  param([string]$RelativePath)
  $path = Join-Path $RepoRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing required user-flow file: $RelativePath"
  }
}

function Assert-Contains {
  param(
    [string]$RelativePath,
    [string]$Pattern,
    [string]$Label
  )
  $raw = Read-Utf8 -Path (Join-Path $RepoRoot $RelativePath)
  if ($raw -notmatch $Pattern) {
    throw "User-flow docs missing ${Label}: $RelativePath"
  }
}

function Assert-NotContains {
  param(
    [string]$RelativePath,
    [string]$Pattern,
    [string]$Label
  )
  $raw = Read-Utf8 -Path (Join-Path $RepoRoot $RelativePath)
  if ($raw -match $Pattern) {
    throw "User-flow docs contain forbidden ${Label}: $RelativePath"
  }
}

Assert-File "docs/USER_FLOW_TR.md"
Assert-File "docs/SMALL_E2E_RUNBOOK_TR.md"

Assert-Contains "README.md" "scripts/new_project\.ps1" "isolated project creation command"
Assert-Contains "README.md" "docs/USER_FLOW_TR\.md" "Turkish user flow link"
Assert-Contains "README.md" "docs/SMALL_E2E_RUNBOOK_TR\.md" "small E2E runbook link"
Assert-Contains "README.md" "scripts/export_final\.ps1" "guarded final export command"
Assert-Contains "README.md" "scripts/cleanup_project\.ps1" "guarded cleanup command"

Assert-Contains "docs/USER_FLOW_TR.md" "runtime/book-request\.md" "real user prompt source"
Assert-Contains "docs/USER_FLOW_TR.md" "book-brief-approval\.json" "brief approval gate"
Assert-Contains "docs/USER_FLOW_TR.md" "story-choice\.json" "story choice approval gate"
Assert-Contains "docs/USER_FLOW_TR.md" "book-plan-approval\.json" "book plan approval gate"
Assert-Contains "docs/USER_FLOW_TR.md" "export_final\.ps1" "final export command"
Assert-Contains "docs/USER_FLOW_TR.md" "cleanup-approval\.json" "cleanup approval gate"
Assert-Contains "docs/USER_FLOW_TR.md" "Eski DOCX dosyasini kopyalayip|Eski DOCX dosyas.n. kopyalay.p|Eski DOCX" "stale DOCX prohibition"

Assert-Contains "docs/SMALL_E2E_RUNBOOK_TR.md" "new_project\.ps1" "small E2E project creation"
Assert-Contains "docs/SMALL_E2E_RUNBOOK_TR.md" "run_pipeline\.ps1" "small E2E pipeline command"
Assert-Contains "docs/SMALL_E2E_RUNBOOK_TR.md" "export_final\.ps1" "small E2E final export"
Assert-Contains "docs/SMALL_E2E_RUNBOOK_TR.md" "cleanup_project\.ps1" "small E2E cleanup check"

Assert-Contains "docs/IDE_AGENT_WORKFLOW.md" "new_project\.ps1" "IDE workflow isolated project setup"
Assert-Contains "docs/IDE_AGENT_WORKFLOW.md" "export_final\.ps1" "IDE workflow guarded final export"
Assert-NotContains "docs/IDE_AGENT_WORKFLOW.md" "Copy-Item\s+-LiteralPath\s+`"?revision/export" "manual DOCX copy instruction"

Write-Host "[user-flow-docs-test] PASS"
