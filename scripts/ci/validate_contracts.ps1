param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText((Join-Path $RepoRoot $Path), [System.Text.Encoding]::UTF8)
}

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Path) -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Assert-Contains {
  param([string]$Path, [string]$Pattern, [string]$Message)
  if ((Read-Utf8 -Path $Path) -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-NoUnexpectedMojibake {
  $allowed = @(
    "scripts/run_pipeline.ps1",
    "scripts/ci/tdk_local_rule_check.py",
    "skills/polish/references/tdk-official-writing-rules.md"
  )
  $roots = @("README.md", "RELEASE_CHECKLIST.md", "docs", "index.html", "runtime", "scripts", "skills")
  $mojibakePattern = ("[{0}{1}{2}]|{3}" -f [char]0x00C3, [char]0x00C4, [char]0x00C5, [char]0xFFFD)
  $files = foreach ($root in $roots) {
    $full = Join-Path $RepoRoot $root
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      Get-Item -LiteralPath $full
    }
    elseif (Test-Path -LiteralPath $full -PathType Container) {
      Get-ChildItem -LiteralPath $full -Recurse -File -Include "*.md", "*.html", "*.json", "*.ps1", "*.py", "*.sh"
    }
  }
  foreach ($file in $files) {
    $relative = $file.FullName.Substring($RepoRoot.Length).TrimStart("\") -replace "\\", "/"
    $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if (($allowed -notcontains $relative) -and ($raw -match $mojibakePattern)) {
      throw "Unexpected mojibake marker in $relative"
    }
  }
}

Write-Host "[contract-lint-ps] validating agent frontmatter..."
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $RepoRoot "agents") -Filter "*.md" -File) {
  $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
  if ($raw -notmatch "(?m)^---\s*$") { throw "Missing frontmatter marker in $($file.Name)" }
  if ($raw -notmatch "(?m)^name:\s*") { throw "Missing name in $($file.Name)" }
  if ($raw -notmatch "(?m)^description:\s*") { throw "Missing description in $($file.Name)" }
  if ($raw -notmatch "(?m)^prompt_version:\s*") { throw "Missing prompt_version in $($file.Name)" }
}

Write-Host "[contract-lint-ps] validating skill frontmatter..."
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $RepoRoot "skills") -Recurse -Filter "SKILL.md" -File) {
  $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
  if ($raw -notmatch "(?m)^---\s*$") { throw "Missing frontmatter marker in $($file.FullName)" }
  if ($raw -notmatch "(?m)^name:\s*") { throw "Missing name in $($file.FullName)" }
  if ($raw -notmatch "(?m)^description:\s*") { throw "Missing description in $($file.FullName)" }
  if ($raw -notmatch "(?m)^prompt_version:\s*") { throw "Missing prompt_version in $($file.FullName)" }
}

Write-Host "[contract-lint-ps] validating verdict vocabulary..."
$markdown = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "agents"), (Join-Path $RepoRoot "skills") -Recurse -Include "*.md" -File
if (Select-String -Path $markdown.FullName -Pattern "\bREVISE\b" -Quiet) {
  throw "Found forbidden verdict token: REVISE"
}

Write-Host "[contract-lint-ps] validating mojibake guard..."
Assert-NoUnexpectedMojibake

Write-Host "[contract-lint-ps] validating mandatory export gate..."
Assert-Contains "skills/export-word/SKILL.md" "export-approval-gate" "Missing export-approval-gate reference"
Assert-Contains "skills/export-word/SKILL.md" "export-validator" "Missing export-validator reference"

Write-Host "[contract-lint-ps] validating proposal-first revision gate..."
Assert-File "scripts/revision_proposals.ps1"
Assert-File "scripts/apply_revision.ps1"
Assert-File "scripts/ci/revision_proposal_gate_test.ps1"
Assert-Contains "skills/rewrite/SKILL.md" "Proposal-first revision" "Rewrite skill missing proposal-first revision rule"
Assert-Contains "skills/rewrite/SKILL.md" "revision-proposals-approval.json" "Rewrite skill missing revision proposal approval"
Assert-Contains "runtime/phase-contracts/rewrite.json" "revision/_workspace/revision-proposals.json" "Rewrite contract missing revision proposal artifact"
Assert-Contains "runtime/phase-contracts/rewrite.json" "revision-proposals-approval.json" "Rewrite contract missing revision proposal approval"

Write-Host "[contract-lint-ps] validating language policy blocks..."
foreach ($path in @("skills/create/SKILL.md", "skills/polish/SKILL.md", "skills/rewrite/SKILL.md", "skills/export-word/SKILL.md")) {
  Assert-Contains $path "Chapter/story content language must be Turkish\." "Missing language policy in $path"
}

Write-Host "[contract-lint-ps] validating context saliency boundary..."
foreach ($path in @(
  "agents/context-saliency-gate.md",
  "skills/polish/references/context-saliency-contract.md",
  "tests/golden/agents/context-saliency-gate/input.md",
  "tests/golden/agents/context-saliency-gate/expected.md"
)) {
  Assert-File $path
}
foreach ($path in @(
  "runtime/phase-contracts/design-small.json",
  "runtime/phase-contracts/create.json",
  "runtime/phase-contracts/polish.json",
  "runtime/phase-contracts/rewrite.json"
)) {
  Assert-Contains $path "context-saliency-gate" "Missing context-saliency-gate in $path"
  Assert-Contains $path "story-bible.json" "Missing story-bible state in $path"
  Assert-Contains $path "context-saliency-map.json" "Missing context saliency state in $path"
}
Assert-Contains "scripts/local_phase.ps1" "story-bible.json" "Local design scaffold must generate Story Bible state"
Assert-Contains "scripts/local_phase.ps1" "context-saliency-map.json" "Local design scaffold must generate context saliency state"
Assert-Contains "scripts/run_pipeline.ps1" "context-saliency-gate_" "Runner must discover context saliency artifacts"
Assert-Contains "scripts/ci/validate_state_reducers.ps1" "writer_may_use_full_story_bible" "State reducer must reject full raw Story Bible exposure"
Assert-Contains "scripts/ide_phase_prompt.ps1" "context-saliency-map.json" "IDE phase prompt must mention context saliency map"

Write-Host "[contract-lint-ps] validating model adapter references..."
foreach ($path in @(
  "skills/polish/references/shared-task-schema.md",
  "skills/polish/references/agent-skill-schema-mapping.md",
  "skills/polish/references/adapter-claude-codex.md",
  "skills/polish/references/adapter-generic-ide-model.md",
  "skills/polish/references/verdict-report-standard.md",
  "skills/polish/references/multi-model-comparison-test-spec.md",
  "skills/polish/references/tdk-source-assurance-chain.md",
  "docs/STRICT_EXECUTION_POLICY.md",
  "docs/PHASE_EVIDENCE_SCHEMA.md",
  "docs/WORKSPACE_RETENTION_POLICY.md",
  "agents/brief-interviewer.md",
  "agents/book-dna-locker.md",
  "agents/layout-profile-planner.md",
  "skills/intake/SKILL.md",
  "runtime/book-brief.schema.json",
  "runtime/layout-profile.schema.json",
  "runtime/phase-contracts/intake.json"
)) {
  Assert-File $path
}

Write-Host "[contract-lint-ps] validating runner contracts..."
foreach ($check in @(
  @("scripts/run_pipeline.ps1", "current-run.json"),
  @("scripts/run_pipeline.ps1", "Invoke-RunRetention"),
  @("scripts/run_pipeline.ps1", "Ensure-UserApproval"),
  @("scripts/run_pipeline.ps1", "Validate-PhaseContracts"),
  @("scripts/run_pipeline.ps1", "Validate-AgentCompliance"),
  @("scripts/run_pipeline.ps1", "Validate-AgentGovernanceCatalog"),
  @("scripts/run_pipeline.ps1", "Write-RunJournalEvent"),
  @("scripts/run_pipeline.ps1", "contract_hashes"),
  @("scripts/run_pipeline.ps1", "Validate-CommandSafety"),
  @("scripts/run_pipeline.ps1", "Validate-ArtifactSizeBudget"),
  @("scripts/run_pipeline.ps1", "Assert-NoForbiddenPatterns"),
  @("scripts/run_pipeline.ps1", "Validate-EpisodeTextQuality"),
  @("scripts/run_pipeline.ps1", "Validate-StateReducers"),
  @("scripts/local_phase.ps1", "Invoke-Intake"),
  @("scripts/local_phase.ps1", "runtime/book-brief.json"),
  @("scripts/local_phase.ps1", "runtime/book-dna.json"),
  @("scripts/local_phase.ps1", "runtime/layout-profile.json"),
  @("scripts/local_phase.ps1", "front-matter-editor"),
  @("scripts/local_phase.ps1", "cover-designer"),
  @("scripts/local_phase.ps1", "revision/_state/book-plan.json"),
  @("scripts/local_phase.ps1", "revision/_state/chapter-plan.json"),
  @("scripts/local_phase.ps1", "revision/_state/layout-plan.json"),
  @("runtime/runner-config.template.json", "require_user_approvals"),
  @("runtime/runner-config.template.json", "enforce_phase_contracts"),
  @("runtime/runner-config.template.json", "enable_negative_enforcement"),
  @("runtime/runner-config.template.json", "enable_text_quality_gates"),
  @("runtime/runner-config.template.json", "enable_command_safety"),
  @("runtime/runner-config.template.json", "enable_artifact_size_budget"),
  @("runtime/runner-config.template.json", "text_quality_gates"),
  @("runtime/agent-compliance.schema.json", "contract_hashes"),
  @("docs/PHASE_EVIDENCE_SCHEMA.md", "contract_hashes"),
  @("docs/AGENT_COMPLIANCE_ENFORCEMENT.md", "contract_hashes"),
  @("scripts/ci/write_agent_compliance.ps1", "contract_hashes")
)) {
  Assert-Contains $check[0] ([regex]::Escape($check[1])) "Missing '$($check[1])' in $($check[0])"
}

Write-Host "[contract-lint-ps] validating quality-verifier strict metadata contract..."
Assert-Contains "agents/quality-verifier.md" "## Required Report Metadata \(Strict\)" "Missing strict metadata contract"
Assert-Contains "agents/quality-verifier.md" "run_id" "Missing run_id requirement"
Assert-Contains "agents/quality-verifier.md" "step_id" "Missing step_id requirement"
Assert-Contains "agents/quality-verifier.md" "## Minimal Markdown Verdict Template \(Required\)" "Missing verdict template"

Write-Host "[contract-lint-ps] validating Windows validation scripts..."
foreach ($path in @(
  "scripts/ci/verify_docx_integrity.ps1",
  "scripts/ci/external_smoke_test.ps1",
  "scripts/ci/extended_readiness_check.ps1",
  "scripts/ci/tdk_dict_check.py",
  "scripts/ci/tdk_dict_check.ps1"
)) {
  Assert-File $path
}

Write-Host "[contract-lint-ps] PASS"
