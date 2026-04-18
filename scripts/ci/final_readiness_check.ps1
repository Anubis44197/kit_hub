param(
  [string]$ConfigPath = "tests/fixtures/sample-project/novel-config.md"
)

$ErrorActionPreference = "Stop"

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
  $raw = Get-Content -LiteralPath $Path -Raw
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
  $raw = Get-Content -LiteralPath $file.FullName -Raw
  if ($raw -notmatch "(?m)^---\s*$") { throw "Missing frontmatter marker in $($file.FullName)" }
  if ($raw -notmatch "(?m)^name:\s*") { throw "Missing name in $($file.FullName)" }
  if ($raw -notmatch "(?m)^description:\s*") { throw "Missing description in $($file.FullName)" }
  if ($raw -notmatch "(?m)^prompt_version:\s*") { throw "Missing prompt_version in $($file.FullName)" }
}

Write-Host "[final-readiness-ps] validating skill frontmatter..."
$skillFiles = Get-ChildItem -LiteralPath "skills" -Recurse -Filter "SKILL.md" -File
foreach ($file in $skillFiles) {
  $raw = Get-Content -LiteralPath $file.FullName -Raw
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

Write-Host "[final-readiness-ps] validating quality-verifier strict metadata contract..."
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "## Required Report Metadata \(Strict\)" -ErrorMessage "Missing strict metadata contract section in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "(?m)run_id" -ErrorMessage "Missing run_id requirement in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "(?m)step_id" -ErrorMessage "Missing step_id requirement in quality-verifier"
Assert-Contains -Path "agents/quality-verifier.md" -Pattern "## Minimal Markdown Verdict Template \(Required\)" -ErrorMessage "Missing markdown verdict template section in quality-verifier"

Write-Host "[final-readiness-ps] validating language policy blocks..."
$policyPattern = [regex]::Escape("Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana.")
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

Write-Host "[final-readiness-ps] checking fixture presence..."
Assert-File "tests/fixtures/sample-project/novel-config.md"
Assert-Directory "tests/fixtures/sample-project/design"
Assert-Directory "tests/fixtures/sample-project/episode"
Assert-Directory "tests/fixtures/sample-project/revision"

Write-Host "[final-readiness-ps] validating novel-config schema keys..."
Assert-File $ConfigPath
$cfgRaw = Get-Content -LiteralPath $ConfigPath -Raw

$requiredKeys = @(
  "project","name","target_platform","target_genre","episode_dir","work_dir","design_dir",
  "language_profile","locale","content_language","interface_language","disallowed_scripts",
  "book_mode","enabled","profile"
)
foreach ($key in $requiredKeys) {
  [void](Get-KeyValue -Raw $cfgRaw -Key $key)
}

$platform = Get-KeyValue -Raw $cfgRaw -Key "target_platform"
if ($platform -notin @("NOVELPIA","MUNPIA","KAKAO_PAGE","NAVER_SERIES","RIDI","GENERIC_BOOK")) {
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
if ($profile -notin @("web_novel","print_preview","ebook")) {
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
Assert-Contains -Path "skills/polish/SKILL.md" -Pattern "platform-optimizer" -ErrorMessage "Missing platform-optimizer in polish flow"
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

Write-Host "[final-readiness-ps] checking agent golden placeholders..."
foreach ($agent in $agentFiles) {
  $agentName = [System.IO.Path]::GetFileNameWithoutExtension($agent.Name)
  Assert-File "tests/golden/agents/$agentName/input.md"
  Assert-File "tests/golden/agents/$agentName/expected.md"
}

Write-Host "[final-readiness-ps] verifying plan has no open TODO tasks..."
$planLines = Get-Content -LiteralPath "YAPILACAKLAR_PLAN.md"
$openTodoCount = 0
foreach ($line in $planLines) {
  if ($line -match '- \[ \] `TODO`' -and $line -notmatch 'TODO\|IN_PROGRESS\|BLOCKED\|DONE') {
    $openTodoCount++
  }
}
if ($openTodoCount -ne 0) {
  throw "Open TODO tasks found in YAPILACAKLAR_PLAN.md: $openTodoCount"
}

Write-Host "[final-readiness-ps] done"
