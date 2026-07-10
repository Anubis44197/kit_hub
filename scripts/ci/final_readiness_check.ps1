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
Assert-File "docs/AGENT_ORCHESTRATION_ARCHITECTURE.md"
Assert-File "runtime/agent-compliance.schema.json"
Assert-File "runtime/agent-registry.json"
Assert-File "runtime/agent-status-contract.json"
Assert-File "runtime/book-brief.schema.json"
Assert-File "runtime/layout-profile.schema.json"
Assert-File "runtime/phase-contracts/intake.json"
Assert-File "runtime/phase-contracts/propose.json"
Assert-File "runtime/phase-contracts/design-big.json"
Assert-File "runtime/phase-contracts/design-small.json"
Assert-File "runtime/phase-contracts/create.json"
Assert-File "runtime/phase-contracts/polish.json"
Assert-File "runtime/phase-contracts/rewrite.json"
Assert-File "runtime/phase-contracts/export.json"
Assert-File "runtime/runner-config.ide-manual.template.json"
Assert-File "scripts/ide_phase_prompt.ps1"
Assert-File "scripts/ci/write_agent_compliance.ps1"
Assert-File "scripts/ci/validate_agent_governance.ps1"
Assert-File "scripts/ci/validate_state_reducers.ps1"
Assert-File "scripts/ci/verify_docx_content_match.ps1"
Assert-File "scripts/new_project.ps1"
Assert-File "scripts/export_final.ps1"
Assert-File "scripts/cleanup_project.ps1"
Assert-File "docs/PROJECT_LIFECYCLE_TR.md"
Assert-File "agents/brief-interviewer.md"
Assert-File "agents/book-dna-locker.md"
Assert-File "agents/layout-profile-planner.md"
Assert-File "skills/intake/SKILL.md"
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
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Assert-ProjectIsolation" -ErrorMessage "Missing project isolation gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Length-depth gate blocked" -ErrorMessage "Missing length-depth fit gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "claim-ledger.json" -ErrorMessage "Missing nonfiction claim ledger gate"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "chapter_state_update_contract" -ErrorMessage "Missing longform memory contract gate"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "publisher_submission_label" -ErrorMessage "Missing publication layout label gate"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-WritingTypeProfileFromSeed" -ErrorMessage "Local design scaffold must infer canonical writing type"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-RequestedCharacterCount" -ErrorMessage "Local design scaffold must preserve requested character count"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-BriefAnswerValue" -ErrorMessage "Local design scaffold must consume approved brief answers"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Design-big blocked:" -ErrorMessage "Design-big must validate approved brief before planning"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "accepted_writing_type" -ErrorMessage "Book plan approval must bind accepted writing type"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-ExportManifestContract" -ErrorMessage "Missing strict export manifest contract"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Publication metadata missing" -ErrorMessage "Missing publication metadata validation"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Assert-PublicationMetadataClean" -ErrorMessage "Local export must validate publication metadata before DOCX"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Assert-ReaderArtifactClean" -ErrorMessage "Local export must validate reader-facing front/cover artifacts"
Assert-Contains -Path "skills/polish/references/writing-type-profiles.md" -Pattern "Canonical Type Rules" -ErrorMessage "Writing type profile reference missing canonical rules"
Assert-Contains -Path "scripts/install.ps1" -Pattern "cleanup-approval.json" -ErrorMessage "Install must create cleanup approval"
Assert-Contains -Path "scripts/install.ps1" -Pattern "length-depth-approval.json" -ErrorMessage "Install must create length-depth approval"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Ensure-UserApproval" -ErrorMessage "Missing user approval gate enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-PhaseContracts" -ErrorMessage "Missing phase contract enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-AgentCompliance" -ErrorMessage "Missing agent compliance validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-AgentGovernanceCatalog" -ErrorMessage "Missing agent governance catalog validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Get-PhaseContract" -ErrorMessage "Missing phase contract JSON loading in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Write-RunJournalEvent" -ErrorMessage "Missing run journal event writer in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "artifact_hashes" -ErrorMessage "Missing artifact hash validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "contract_hashes" -ErrorMessage "Missing contract hash validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-CommandSafety" -ErrorMessage "Missing command safety validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-ArtifactSizeBudget" -ErrorMessage "Missing artifact size budget validation in runner"
Assert-Contains -Path "runtime/agent-compliance.schema.json" -Pattern "agent_statuses" -ErrorMessage "Agent compliance schema missing agent_statuses"
Assert-Contains -Path "runtime/agent-compliance.schema.json" -Pattern "contract_hashes" -ErrorMessage "Agent compliance schema missing contract_hashes"
Assert-Contains -Path "runtime/agent-status-contract.json" -Pattern "invalid_output" -ErrorMessage "Agent status contract missing invalid_output"
Assert-Contains -Path "runtime/agent-registry.json" -Pattern "contract-bound-agent-orchestration" -ErrorMessage "Agent registry missing governance model"
Assert-Contains -Path "docs/AGENT_ORCHESTRATION_ARCHITECTURE.md" -Pattern "Agent Registry" -ErrorMessage "Agent orchestration docs missing Agent Registry"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-DocxContentMatch" -ErrorMessage "Missing DOCX content provenance validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-DocxReaderClean" -ErrorMessage "Missing reader-facing DOCX cleanliness validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Assert-NoForbiddenPatterns" -ErrorMessage "Missing negative enforcement in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-EpisodeTextQuality" -ErrorMessage "Missing text quality hard gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-LongformState" -ErrorMessage "Missing longform state validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-StateReducers" -ErrorMessage "Missing state reducer validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-MacroContinuityAudits" -ErrorMessage "Missing macro continuity audit validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "book-plan-approval.json" -ErrorMessage "Missing book plan approval gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "book-brief-approval.json" -ErrorMessage "Missing book brief approval gate in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-BookBriefApproval" -ErrorMessage "Missing strict book brief approval validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-BookPlanApproval" -ErrorMessage "Missing strict book plan approval validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "\$phases = @\(""intake""," -ErrorMessage "Runner phase order missing intake"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "layout-plan.json" -ErrorMessage "Missing layout plan validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Planning state contains unresolved placeholder text" -ErrorMessage "Missing unresolved planning placeholder rejection in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-PublicationCompliance" -ErrorMessage "Missing publication compliance validation in runner"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "Validate-DocxLayoutProfile" -ErrorMessage "Missing DOCX layout profile validation in runner"
Assert-File "scripts/local_phase.ps1"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "book-plan.json" -ErrorMessage "Missing book plan generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Invoke-Intake" -ErrorMessage "Missing intake phase in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "runtime/book-brief.json" -ErrorMessage "Missing book brief generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "required_user_questions" -ErrorMessage "Missing structured intake questions in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "accepted_targets" -ErrorMessage "Missing plan approval target binding in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "macro-continuity-audit_EPxxx" -ErrorMessage "Missing macro continuity audit instruction in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "10_docx-reader-clean_report" -ErrorMessage "Missing DOCX reader clean report artifact generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "runtime/book-dna.json" -ErrorMessage "Missing book DNA generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "runtime/layout-profile.json" -ErrorMessage "Missing layout profile generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "delivery_profiles" -ErrorMessage "Missing publisher/print preview delivery profiles in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "10_docx-style-profile" -ErrorMessage "Missing DOCX style profile artifact generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "chapter-plan.json" -ErrorMessage "Missing chapter plan generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "layout-plan.json" -ErrorMessage "Missing layout plan generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "longform-plan.json" -ErrorMessage "Missing longform plan generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "character-state.json" -ErrorMessage "Missing character state generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "plot-ledger.json" -ErrorMessage "Missing plot ledger generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "chapter-summaries.json" -ErrorMessage "Missing chapter summaries generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-LongformScalePlan" -ErrorMessage "Missing scale-aware longform plan in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "promise-payoff-ledger.json" -ErrorMessage "Missing promise/payoff ledger generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "knowledge-graph.json" -ErrorMessage "Missing knowledge graph generation in local adapter"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "volume-plan.json" -ErrorMessage "Missing volume-plan validation in runner"
Assert-Contains -Path "docs/LONGFORM_ENGINE.md" -Pattern "Scale-Aware Planning" -ErrorMessage "Missing scale-aware longform documentation"
Assert-Contains -Path "docs/LONGFORM_ENGINE.md" -Pattern "Reader DOCX Cleanliness" -ErrorMessage "Missing reader DOCX cleanliness documentation"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "style-profile.json" -ErrorMessage "Missing style profile generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "writing-type-profile.json" -ErrorMessage "Missing writing type profile generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "editorial-quality-scorecard.json" -ErrorMessage "Missing editorial scorecard generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Write-AgentCompliance" -ErrorMessage "Missing agent compliance manifest generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "Get-FileSha256" -ErrorMessage "Missing artifact hash generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "14_publication-compliance_verdict" -ErrorMessage "Missing publication compliance verdict generation in local adapter"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "front-matter-editor" -ErrorMessage "Local export compliance missing front-matter-editor"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "cover-designer" -ErrorMessage "Local export compliance missing cover-designer"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "revision/_state/book-plan.json" -ErrorMessage "Local export compliance missing book-plan loaded state"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "revision/_state/chapter-plan.json" -ErrorMessage "Local export compliance missing chapter-plan loaded state"
Assert-Contains -Path "scripts/local_phase.ps1" -Pattern "revision/_state/layout-plan.json" -ErrorMessage "Local export compliance missing layout-plan loaded state"
Assert-Contains -Path "scripts/run_pipeline.ps1" -Pattern "llm-adapter-contract.json" -ErrorMessage "Missing LLM adapter contract validation in runner"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "scripts/local_phase.ps1" -ErrorMessage "Missing local phase adapter command in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern '"intake"' -ErrorMessage "Missing intake in runner config template"
Assert-Contains -Path "runtime/runner-config.ide-manual.template.json" -Pattern "manual_ide_agent" -ErrorMessage "Missing manual IDE adapter strategy"
Assert-Contains -Path "runtime/runner-config.ide-manual.template.json" -Pattern "book-brief-approval.json" -ErrorMessage "Missing book brief approval mapping in IDE manual template"
Assert-Contains -Path "README.md" -Pattern "No API Key / IDE Agent Mode" -ErrorMessage "README missing no-API IDE workflow"
Assert-Contains -Path "README.md" -Pattern "runtime/agent-compliance/\{phase\}\.json" -ErrorMessage "README missing agent compliance manifest"
Assert-Contains -Path "README.md" -Pattern "DOCX content" -ErrorMessage "README missing DOCX content match gate"
Assert-Contains -Path "docs/RUNNER_USAGE.md" -Pattern "ide_phase_prompt.ps1" -ErrorMessage "Runner docs missing IDE phase prompt helper"
Assert-Contains -Path "docs/AGENT_COMPLIANCE_ENFORCEMENT.md" -Pattern "artifact_hashes" -ErrorMessage "Agent compliance docs missing artifact hashes"
Assert-Contains -Path "docs/AGENT_COMPLIANCE_ENFORCEMENT.md" -Pattern "contract_hashes" -ErrorMessage "Agent compliance docs missing contract hashes"
Assert-Contains -Path "docs/PHASE_EVIDENCE_SCHEMA.md" -Pattern "artifact_hashes" -ErrorMessage "Phase evidence docs missing artifact hashes"
Assert-Contains -Path "docs/PHASE_EVIDENCE_SCHEMA.md" -Pattern "contract_hashes" -ErrorMessage "Phase evidence docs missing contract hashes"
Assert-Contains -Path "runtime/agent-compliance.schema.json" -Pattern "artifact_hashes" -ErrorMessage "Agent compliance schema missing artifact hashes"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "require_user_approvals" -ErrorMessage "Missing require_user_approvals in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enforce_phase_contracts" -ErrorMessage "Missing enforce_phase_contracts in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_negative_enforcement" -ErrorMessage "Missing enable_negative_enforcement in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_text_quality_gates" -ErrorMessage "Missing enable_text_quality_gates in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_command_safety" -ErrorMessage "Missing enable_command_safety in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "enable_artifact_size_budget" -ErrorMessage "Missing enable_artifact_size_budget in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "text_quality_gates" -ErrorMessage "Missing text_quality_gates block in runner config template"
Assert-Contains -Path "runtime/runner-config.template.json" -Pattern "book-plan-approval.json" -ErrorMessage "Missing book plan approval mapping in runner config template"
Assert-Contains -Path "runtime/runner-config.ide-manual.template.json" -Pattern "book-plan-approval.json" -ErrorMessage "Missing book plan approval mapping in IDE manual template"
Assert-Contains -Path "scripts/ide_phase_prompt.ps1" -Pattern "revision/_state/book-plan.json" -ErrorMessage "IDE phase prompt missing book-plan state output"
Assert-Contains -Path "scripts/ide_phase_prompt.ps1" -Pattern "runtime/approvals/book-plan-approval.json" -ErrorMessage "IDE phase prompt missing book-plan approval gate"
Assert-Contains -Path "skills/design-big/SKILL.md" -Pattern "revision/_state/book-plan.json" -ErrorMessage "design-big skill missing book plan output contract"
Assert-Contains -Path "skills/design-small/SKILL.md" -Pattern "book-plan-approval.json" -ErrorMessage "design-small skill missing book plan approval prerequisite"

Write-Host "[final-readiness-ps] validating agent governance contracts..."
& powershell -ExecutionPolicy Bypass -File "scripts/ci/validate_agent_governance.ps1" -ProjectRoot (Get-Location).Path
if ($LASTEXITCODE -ne 0) {
  throw "Agent governance validation failed."
}

$staleContractFiles = @(
  "scripts/run_pipeline.ps1",
  "docs/REAL_E2E_TEST_RUNBOOK_TR.md",
  "docs/IDE_AGENT_WORKFLOW.md",
  "scripts/ide_phase_prompt.ps1",
  "skills/design-big/SKILL.md",
  "skills/design-small/SKILL.md"
)
foreach ($staleFile in $staleContractFiles) {
  $staleRaw = Read-Utf8 -Path $staleFile
  if ($staleRaw -match "EP001-EP005|hook_table_EP001-EP005|design/\*_plot_hook\.md") {
    throw "Stale output contract remains in $staleFile"
  }
}

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
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "final-proofreader" -ErrorMessage "Missing final-proofreader in polish flow"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "rule-checker" -ErrorMessage "Polish phase contract missing rule-checker"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "story-analyst" -ErrorMessage "Polish phase contract missing story-analyst"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "book-structure-optimizer" -ErrorMessage "Polish phase contract missing book-structure-optimizer"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "alive-enhancer" -ErrorMessage "Polish phase contract missing alive-enhancer"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "revision-executor" -ErrorMessage "Polish phase contract missing revision-executor"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "tdk-layout-agent" -ErrorMessage "Polish phase contract missing tdk-layout-agent"
Assert-Contains -Path "runtime/phase-contracts/polish.json" -Pattern "final-proofreader" -ErrorMessage "Polish phase contract missing final-proofreader"
Assert-Contains -Path "runtime/agent-registry.json" -Pattern '"book-structure-optimizer".*"polish"' -ErrorMessage "Agent registry does not allow book-structure-optimizer in polish"
Assert-Contains -Path "runtime/agent-registry.json" -Pattern '"revision-executor".*"polish"' -ErrorMessage "Agent registry does not allow revision-executor in polish"
Assert-Contains -Path "runtime/agent-registry.json" -Pattern '"final-proofreader".*"polish"' -ErrorMessage "Agent registry does not allow final-proofreader in polish"

Write-Host "[final-readiness-ps] validating rewrite flow contract..."
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "revision-analyst" -ErrorMessage "Missing revision-analyst in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "character-sculptor" -ErrorMessage "Missing character-sculptor in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "episode-rewriter" -ErrorMessage "Missing episode-rewriter in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "tdk-polisher" -ErrorMessage "Missing tdk-polisher in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "tdk-layout-agent" -ErrorMessage "Missing tdk-layout-agent in rewrite flow"
Assert-Contains -Path "skills/rewrite/SKILL.md" -Pattern "quality-verifier" -ErrorMessage "Missing quality-verifier in rewrite flow"
Assert-Contains -Path "runtime/phase-contracts/rewrite.json" -Pattern "character-sculptor" -ErrorMessage "Rewrite phase contract missing character-sculptor"
Assert-Contains -Path "runtime/phase-contracts/rewrite.json" -Pattern "tdk-layout-agent" -ErrorMessage "Rewrite phase contract missing tdk-layout-agent"
Assert-Contains -Path "runtime/agent-registry.json" -Pattern '"character-sculptor".*"rewrite"' -ErrorMessage "Agent registry does not allow character-sculptor in rewrite"

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
Assert-File "scripts/ci/verify_docx_layout_profile.ps1"
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
