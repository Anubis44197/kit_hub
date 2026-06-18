param(
  [string]$ConfigPath = "tests/fixtures/sample-project/novel-config.md"
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

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

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$ErrorMessage
  )
  $raw = Read-Utf8 -Path $Path
  if ($raw -notmatch $Pattern) {
    throw $ErrorMessage
  }
}

function Get-KeyValue {
  param(
    [string]$Raw,
    [string]$Key
  )
  $match = [regex]::Match($Raw, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*`"?([^`"#\r\n]+)`"?")
  if (-not $match.Success) {
    throw "Missing required key: $Key"
  }
  return $match.Groups[1].Value.Trim()
}

Write-Host "[final-readiness-ps] validating agent frontmatter..."
$agentFiles = Get-ChildItem -LiteralPath "agents" -Filter "*.md" -File
foreach ($file in $agentFiles) {
  $raw = Read-Utf8 -Path $file.FullName
  if ($raw -notmatch "(?m)^---\s*$") { throw "Missing frontmatter marker in $($file.FullName)" }
  if ($raw -notmatch "(?m)^name:\s*") { throw "Missing name in $($file.FullName)" }
  if ($raw -notmatch "(?m)^description:\s*") { throw "Missing description in $($file.FullName)" }
  if ($raw -notmatch "(?m)^prompt_version:\s*") { throw "Missing prompt_version in $($file.FullName)" }
}

Write-Host "[final-readiness-ps] validating skill frontmatter..."
$skillFiles = Get-ChildItem -LiteralPath "skills" -Recurse -Filter "SKILL.md" -File
foreach ($file in $skillFiles) {
  $raw = Read-Utf8 -Path $file.FullName
  if ($raw -notmatch "(?m)^---\s*$") { throw "Missing frontmatter marker in $($file.FullName)" }
  if ($raw -notmatch "(?m)^name:\s*") { throw "Missing name in $($file.FullName)" }
  if ($raw -notmatch "(?m)^description:\s*") { throw "Missing description in $($file.FullName)" }
  if ($raw -notmatch "(?m)^prompt_version:\s*") { throw "Missing prompt_version in $($file.FullName)" }
}

Write-Host "[final-readiness-ps] validating verdict vocabulary..."
$allMarkdown = Get-ChildItem -LiteralPath "agents","skills" -Recurse -Include "*.md" -File
$reviseHits = Select-String -Path $allMarkdown.FullName -Pattern "\bREVISE\b" -SimpleMatch:$false
if ($reviseHits) {
  throw "Found forbidden verdict token: REVISE"
}

Write-Host "[final-readiness-ps] validating mandatory export gate..."
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern "export-approval-gate" -ErrorMessage "Missing export-approval-gate reference"
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern "export-validator" -ErrorMessage "Missing export-validator reference"
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern "front-matter-editor" -ErrorMessage "Missing front-matter-editor reference"
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern "cover-designer" -ErrorMessage "Missing cover-designer reference"
Assert-File "agents/front-matter-editor.md"
Assert-File "agents/cover-designer.md"

Write-Host "[final-readiness-ps] validating quality-verifier strict metadata contract..."
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "## Required Report Metadata \(Strict\)" -ErrorMessage "Missing strict metadata contract section in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "(?m)run_id" -ErrorMessage "Missing run_id requirement in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "(?m)step_id" -ErrorMessage "Missing step_id requirement in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "## Minimal Markdown Verdict Template \(Required\)" -ErrorMessage "Missing markdown verdict template section in quality-verifier"

Write-Host "[final-readiness-ps] validating language policy blocks..."
$policyPattern = [regex]::Escape("Chapter/story content language must be Turkish.")
Assert-Contains -Path "skills/create/SKILL.md" -Pattern $policyPattern -ErrorMessage "Missing language policy in skills/create/SKILL.md"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern $policyPattern -ErrorMessage "Missing language policy in skills/polish/SKILL.md"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern $policyPattern -ErrorMessage "Missing language policy in skills/rewrite/SKILL.md"
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern $policyPattern -ErrorMessage "Missing language policy in skills/export-word/SKILL.md"

Write-Host "[final-readiness-ps] validating adapter references..."
Assert-File "skills/polish/references/shared-task-schema.md"
Assert-File "skills/polish/references/agent-skill-schema-mapping.md"
Assert-File "skills/polish/references/adapter-claude-codex.md"
Assert-File "skills/polish/references/adapter-generic-ide-model.md"
Assert-File "skills/polish/references/verdict-report-standard.md"
Assert-File "skills/polish/references/multi-model-comparison-test-spec.md"
Assert-File "skills/polish/references/tdk-source-assurance-chain.md"
Assert-File "docs/STRICT_EXECUTION_POLICY.md"
Assert-File "docs/PHASE_EVIDENCE_SCHEMA.md"
Assert-File "docs/WORKSPACE_RETENTION_POLICY.md"
Assert-File "docs/LONGFORM_ENGINE.md"
Assert-File "docs/PROFESSIONAL_WRITING_SYSTEM.md"
Assert-File "docs/IDE_AGENT_WORKFLOW.md"
Assert-File "docs/AGENT_COMPLIANCE_ENFORCEMENT.md"
Assert-File "runtime/agent-compliance.schema.json"
Assert-File "runtime/runner-config.ide-manual.template.json"
Assert-File "scripts/ide_phase_prompt.ps1"
Assert-File "scripts/ci/write_agent_compliance.ps1"
Assert-File "scripts/ci/verify_docx_content_match.ps1"
Assert-File "skills/polish/references/writing-type-profiles.md"
Assert-File "skills/polish/references/genre-structure-templates.md"
Assert-File "skills/polish/references/editorial-quality-scorecard.md"
Assert-File "skills/polish/references/llm-adapter-contract.md"
Assert-File "skills/polish/references/docx-professional-style-contract.md"
Assert-File "skills/polish/references/tdk-official-writing-rules.md"
Assert-File "skills/polish/references/tdk-print-submission-rules.md"
Assert-File "skills/polish/references/source-citation-style-tdk.md"
Assert-File "skills/polish/references/publication-metadata-checklist.md"
Assert-File "skills/polish/references/isbn-kunye-bandrol-checklist.md"
Assert-File "agents/publication-compliance-checker.md"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "current-run.json" -ErrorMessage "Missing current-run pointer contract in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Invoke-RunRetention" -ErrorMessage "Missing retention invocation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Ensure-UserApproval" -ErrorMessage "Missing user approval gate enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-PhaseContracts" -ErrorMessage "Missing phase contract enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-AgentCompliance" -ErrorMessage "Missing agent compliance validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "artifact_hashes" -ErrorMessage "Missing artifact hash validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-DocxContentMatch" -ErrorMessage "Missing DOCX content provenance validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Assert-NoForbiddenPatterns" -ErrorMessage "Missing negative enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-EpisodeTextQuality" -ErrorMessage "Missing text quality hard gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-LongformState" -ErrorMessage "Missing longform state validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-PublicationCompliance" -ErrorMessage "Missing publication compliance validation in runner"
Assert-File "scripts/local_phase.ps1"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "longform-plan.json" -ErrorMessage "Missing longform plan generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "character-state.json" -ErrorMessage "Missing character state generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "plot-ledger.json" -ErrorMessage "Missing plot ledger generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "chapter-summaries.json" -ErrorMessage "Missing chapter summaries generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "style-profile.json" -ErrorMessage "Missing style profile generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "writing-type-profile.json" -ErrorMessage "Missing writing type profile generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "editorial-quality-scorecard.json" -ErrorMessage "Missing editorial scorecard generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Write-AgentCompliance" -ErrorMessage "Missing agent compliance manifest generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-FileSha256" -ErrorMessage "Missing artifact hash generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "14_publication-compliance_verdict" -ErrorMessage "Missing publication compliance verdict generation in local adapter"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "llm-adapter-contract.json" -ErrorMessage "Missing LLM adapter contract validation in runner"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "scripts/local_phase.ps1" -ErrorMessage "Missing local phase adapter command in runner config template"
Assert-Contains -Path "runtime/runner-config.ide-manual.template.json" -Pattern "manual_ide_agent" -ErrorMessage "Missing manual IDE adapter strategy"
Assert-Contains -Path "README.md" -Pattern "No API Key / IDE Agent Mode" -ErrorMessage "README missing no-API IDE workflow"
Assert-Contains -Path "README.md" -Pattern "runtime/agent-compliance/\{phase\}\.json" -ErrorMessage "README missing agent compliance manifest"
Assert-Contains -Path "README.md" -Pattern "DOCX content" -ErrorMessage "README missing DOCX content match gate"
Assert-Contains -Path "docs/RUNNER_USAGE.md" -Pattern "ide_phase_prompt.ps1" -ErrorMessage "Runner docs missing IDE phase prompt helper"
Assert-Contains -Path "docs/AGENT_COMPLIANCE_ENFORCEMENT.md" -Pattern "artifact_hashes" -ErrorMessage "Agent compliance docs missing artifact hashes"
Assert-Contains -Path "docs/PHASE_EVIDENCE_SCHEMA.md" -Pattern "artifact_hashes" -ErrorMessage "Phase evidence docs missing artifact hashes"
Assert-Contains -Path "runtime/agent-compliance.schema.json" -Pattern "artifact_hashes" -ErrorMessage "Agent compliance schema missing artifact hashes"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "require_user_approvals" -ErrorMessage "Missing require_user_approvals in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enforce_phase_contracts" -ErrorMessage "Missing enforce_phase_contracts in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_negative_enforcement" -ErrorMessage "Missing enable_negative_enforcement in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_text_quality_gates" -ErrorMessage "Missing enable_text_quality_gates in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "text_quality_gates" -ErrorMessage "Missing text_quality_gates block in runner config template"

Write-Host "[final-readiness-ps] checking fixture presence..."
Assert-File "tests/fixtures/sample-project/novel-config.md"
Assert-Directory "tests/fixtures/sample-project/design"
Assert-Directory "tests/fixtures/sample-project/episode"
Assert-Directory "tests/fixtures/sample-project/revision"

Write-Host "[final-readiness-ps] validating novel-config schema keys..."
Assert-File $ConfigPath
$cfgRaw = Read-Utf8 -Path $ConfigPath

$requiredKeys = @(
  "project","name","target_platform","target_genre","episode_dir","work_dir","design_dir",
  "language_profile","locale","content_language","interface_language",
  "book_mode","enabled","profile"
)
foreach ($key in $requiredKeys) {
  [void](Get-KeyValue -Raw $cfgRaw -Key $key)
}

$platform = Get-KeyValue -Raw $cfgRaw -Key "target_platform"
if ($platform -notin @("GENERIC_BOOK","PRINT_BOOK","EBOOK")) {
  throw "Invalid target_platform: $platform"
}

$locale = Get-KeyValue -Raw $cfgRaw -Key "locale"
if ($locale -ne "tr-TR") {
  throw "Invalid locale: $locale"
}

$contentLanguage = Get-KeyValue -Raw $cfgRaw -Key "content_language"
if ($contentLanguage -ne "Turkish") {
  throw "Invalid content_language: $contentLanguage"
}

$profile = Get-KeyValue -Raw $cfgRaw -Key "profile"
if ($profile -notin @("print_preview","ebook")) {
  throw "Invalid book_mode.profile: $profile"
}

Write-Host "[final-readiness-ps] validating episode ranges..."
$ranges = [regex]::Matches($cfgRaw, "EP\d{3}-EP\d{3}") | ForEach-Object { $_.Value }
if ($ranges.Count -gt 0) {
  $parsed = @()
  foreach ($range in $ranges) {
    $parts = $range.Split("-")
    $start = [int]$parts[0].Substring(2)
    $end = [int]$parts[1].Substring(2)
    if ($start -gt $end) {
      throw "Invalid range order: $range"
    }
    $parsed += [pscustomobject]@{ Start = $start; End = $end; Raw = $range }
  }
  for ($i = 0; $i -lt $parsed.Count; $i++) {
    for ($j = $i + 1; $j -lt $parsed.Count; $j++) {
      $a = $parsed[$i]
      $b = $parsed[$j]
      if (-not ($a.End -lt $b.Start -or $b.End -lt $a.Start)) {
        throw "Overlapping ranges: $($a.Raw) and $($b.Raw)"
      }
    }
  }
}

Write-Host "[final-readiness-ps] validating create flow contract..."
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "episode-architect" -ErrorMessage "Missing episode-architect in create flow"
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "continuity-bridge" -ErrorMessage "Missing continuity-bridge in create flow"
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "episode-creator" -ErrorMessage "Missing episode-creator in create flow"
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "tdk-polisher" -ErrorMessage "Missing tdk-polisher in create flow"
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "tdk-layout-agent" -ErrorMessage "Missing tdk-layout-agent in create flow"
Assert-Contains -Path "skills/create/SKILL.md" -Pattern "quality-verifier" -ErrorMessage "Missing quality-verifier in create flow"

Write-Host "[final-readiness-ps] validating polish flow contract..."
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "rule-checker" -ErrorMessage "Missing rule-checker in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "story-analyst" -ErrorMessage "Missing story-analyst in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "book-structure-optimizer" -ErrorMessage "Missing book-structure-optimizer in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "developmental-editor" -ErrorMessage "Missing developmental-editor in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "continuity-editor" -ErrorMessage "Missing continuity-editor in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "line-editor" -ErrorMessage "Missing line-editor in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "copy-editor" -ErrorMessage "Missing copy-editor in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "final-proofreader" -ErrorMessage "Missing final-proofreader in polish flow"
Assert-Contains -Path "skills/export-word/SKILL.md" -Pattern "publication-compliance-checker" -ErrorMessage "Missing publication-compliance-checker in export flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "alive-enhancer" -ErrorMessage "Missing alive-enhancer in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "revision-executor" -ErrorMessage "Missing revision-executor in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "tdk-polisher" -ErrorMessage "Missing tdk-polisher in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "tdk-layout-agent" -ErrorMessage "Missing tdk-layout-agent in polish flow"
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "revision-reviewer" -ErrorMessage "Missing revision-reviewer in polish flow"

Write-Host "[final-readiness-ps] validating rewrite flow contract..."
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "revision-analyst" -ErrorMessage "Missing revision-analyst in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "character-sculptor" -ErrorMessage "Missing character-sculptor in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "episode-rewriter" -ErrorMessage "Missing episode-rewriter in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "tdk-polisher" -ErrorMessage "Missing tdk-polisher in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "tdk-layout-agent" -ErrorMessage "Missing tdk-layout-agent in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "quality-verifier" -ErrorMessage "Missing quality-verifier in rewrite flow"

Write-Host "[final-readiness-ps] checking regression spec docs..."
Assert-File "skills/polish/references/regression-test-spec.md"
Assert-File "skills/polish/references/tdk-regression-test-spec.md"
Assert-File "skills/polish/references/layout-regression-test-spec.md"
Assert-File "skills/polish/references/report-snapshot-test-spec.md"

Write-Host "[final-readiness-ps] checking regression fixtures..."
Assert-File "tests/regression/core/case-001/input.md"
Assert-File "tests/regression/core/case-001/expected.json"
Assert-File "tests/regression/tdk/case-001/input.md"
Assert-File "tests/regression/tdk/case-001/expected_issues.json"
Assert-File "tests/regression/layout/case-001/input.md"
Assert-File "tests/regression/layout/case-001/expected_issues.json"

Write-Host "[final-readiness-ps] checking snapshot fixtures..."
Assert-File "tests/snapshots/create/case-001/expected/verdict.md"
Assert-File "tests/snapshots/create/case-001/expected/issues.json"

Write-Host "[final-readiness-ps] checking Windows validation utilities..."
Assert-File "scripts/ci/verify_docx_integrity.ps1"
Assert-File "scripts/ci/external_smoke_test.ps1"
Assert-File "scripts/ci/tdk_dict_check.py"
Assert-File "scripts/ci/tdk_dict_check.ps1"

Write-Host "[final-readiness-ps] checking agent golden placeholders..."
foreach ($agent in $agentFiles) {
  $agentName = [System.IO.Path]::GetFileNameWithoutExtension($agent.Name)
  Assert-File "tests/golden/agents/$agentName/input.md"
  Assert-File "tests/golden/agents/$agentName/expected.md"
  Assert-Contains -Path "tests/golden/agents/$agentName/expected.md" -Pattern "Expected contract" -ErrorMessage "Golden expected output is not contract-backed: $agentName"
  $expectedRaw = Read-Utf8 -Path "tests/golden/agents/$agentName/expected.md"
  if ($expectedRaw -match "Placeholder expected output") {
    throw "Golden expected output still contains placeholder text: $agentName"
  }
}

Write-Host "[final-readiness-ps] done"
