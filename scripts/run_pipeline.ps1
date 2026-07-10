param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$FromPhase = "intake",
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$ToPhase = "export",
  [ValidateSet("manual","command")]
  [string]$Mode = "manual",
  [string]$ConfigPath = "",
  [switch]$EnableDictionaryCheck,
  [switch]$NoWait
)

$ErrorActionPreference = "Stop"

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Read-JsonFile {
  param([string]$Path)
  Ensure-File $Path
  return Read-Utf8 -Path $Path | ConvertFrom-Json
}

function Assert-ProjectIsolation {
  param([string]$Root)

  $rootFull = [System.IO.Path]::GetFullPath($Root)
  $gitDir = Join-Path $rootFull ".git"
  $markerPath = Join-Path $rootFull ".kithub-project.json"
  if ((Test-Path -LiteralPath $gitDir -PathType Container) -and -not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    throw "Project isolation blocked: do not run manuscript phases in the kit_hub application repository. Create a separate project with scripts/new_project.ps1 and run the pipeline there."
  }
}

function ConvertTo-RelativeContractPath {
  param([string]$Path)
  return (([string]$Path) -replace "\\", "/").Trim()
}

function Get-AgentRegistry {
  param([string]$Root)
  return Read-JsonFile -Path (Join-Path $Root "runtime/agent-registry.json")
}

function Get-AgentByName {
  param([object]$Registry, [string]$Name)
  return @($Registry.agents | Where-Object { $_.name -eq $Name } | Select-Object -First 1)[0]
}

function Get-AgentStatusContract {
  param([string]$Root)
  return Read-JsonFile -Path (Join-Path $Root "runtime/agent-status-contract.json")
}

function Get-PhaseContract {
  param([string]$Root, [string]$Phase)
  return Read-JsonFile -Path (Join-Path $Root ("runtime/phase-contracts/{0}.json" -f $Phase))
}

function Test-ContractPattern {
  param([string]$Value, [string]$Pattern)
  $normalizedValue = ConvertTo-RelativeContractPath -Path $Value
  $normalizedPattern = ConvertTo-RelativeContractPath -Path $Pattern
  return ($normalizedValue -like $normalizedPattern)
}

function Test-AnyContractPattern {
  param([string]$Value, [object[]]$Patterns)
  foreach ($pattern in @($Patterns)) {
    if (Test-ContractPattern -Value $Value -Pattern ([string]$pattern)) {
      return $true
    }
  }
  return $false
}

function Validate-AgentGovernanceCatalog {
  param([string]$Root)

  $registry = Get-AgentRegistry -Root $Root
  $status = Get-AgentStatusContract -Root $Root
  foreach ($field in @("schema_version","status_contract","agents")) {
    if (-not ($registry.PSObject.Properties.Name -contains $field)) {
      throw "Agent registry missing '$field'."
    }
  }
  if (@($registry.agents).Count -lt 1) {
    throw "Agent registry has no agents."
  }
  $names = @($registry.agents | ForEach-Object { [string]$_.name })
  if (($names | Sort-Object -Unique).Count -ne $names.Count) {
    throw "Agent registry contains duplicate agent names."
  }
  foreach ($agent in @($registry.agents)) {
    foreach ($field in @("name","allowed_phases","required_references","allowed_write_roots","timeout_seconds","max_turns")) {
      if (-not ($agent.PSObject.Properties.Name -contains $field)) {
        throw "Agent registry entry missing '$field'."
      }
    }
    Ensure-File (Join-Path $Root ("agents/{0}.md" -f $agent.name))
    foreach ($ref in @($agent.required_references)) {
      Ensure-File (Join-Path $Root ([string]$ref))
    }
    if (@($agent.allowed_phases).Count -lt 1) {
      throw "Agent '$($agent.name)' must declare allowed_phases."
    }
  }
  if (-not ($status.PSObject.Properties.Name -contains "valid_status_values") -or @($status.valid_status_values).Count -lt 3) {
    throw "Agent status contract must declare valid_status_values."
  }
}

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Get-FileSha256 {
  param([string]$Path)
  Ensure-File $Path
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
      $hash = $sha.ComputeHash($stream)
      return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($sha) { $sha.Dispose() }
  }
}

function Get-ArtifactHashRecords {
  param([string]$Root, [string[]]$Artifacts)
  $records = @()
  foreach ($rel in $Artifacts) {
    if ($rel -match "[\*\?]") {
      throw "Artifact hash gate refuses wildcard artifact path: $rel"
    }
    $path = Join-Path $Root $rel
    Ensure-File $path
    $records += [ordered]@{
      path = $rel
      sha256 = Get-FileSha256 -Path $path
    }
  }
  return $records
}

function Get-ContractHashRecords {
  param([string]$Root, [string]$Phase)

  $contractFiles = @(
    "runtime/agent-registry.json",
    "runtime/agent-status-contract.json",
    ("runtime/phase-contracts/{0}.json" -f $Phase)
  )
  $records = @()
  foreach ($rel in $contractFiles) {
    $path = Join-Path $Root $rel
    Ensure-File $path
    $records += [ordered]@{
      path = $rel
      sha256 = Get-FileSha256 -Path $path
    }
  }
  return $records
}

function Validate-ContractHashRecords {
  param(
    [string]$Root,
    [string]$Phase,
    [object[]]$Records,
    [string]$SourcePath
  )

  $expected = @(Get-ContractHashRecords -Root $Root -Phase $Phase)
  $expectedByPath = @{}
  foreach ($record in $expected) {
    $expectedByPath[[string]$record.path] = [string]$record.sha256
  }

  $seen = @{}
  foreach ($record in @($Records)) {
    foreach ($field in @("path","sha256")) {
      if (-not ($record.PSObject.Properties.Name -contains $field) -or -not ([string]$record.$field).Trim()) {
        throw "Contract hash entry missing '$field': $SourcePath"
      }
    }
    $rel = ConvertTo-RelativeContractPath -Path ([string]$record.path)
    $sha = [string]$record.sha256
    if ($sha -notmatch "^[a-f0-9]{64}$") {
      throw "Contract hash is not lowercase SHA-256 for '$rel': $SourcePath"
    }
    if (-not $expectedByPath.ContainsKey($rel)) {
      throw "Unexpected contract hash path '$rel': $SourcePath"
    }
    if ($seen.ContainsKey($rel)) {
      throw "Duplicate contract hash path '$rel': $SourcePath"
    }
    if ($expectedByPath[$rel] -ne $sha) {
      throw "Contract hash mismatch for '$rel'. Expected $($expectedByPath[$rel]), found $sha. Regenerate phase artifacts against the current contracts."
    }
    $seen[$rel] = $true
  }

  foreach ($rel in $expectedByPath.Keys) {
    if (-not $seen.ContainsKey($rel)) {
      throw "Missing contract hash for '$rel': $SourcePath"
    }
  }
}

function Validate-CommandSafety {
  param(
    [string]$Command,
    [string]$Root,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if (-not ([string]$Command).Trim()) {
    throw "Command safety gate received an empty command."
  }

  $blockedPatterns = @(
    @{ pattern = "(?i)\bInvoke-Expression\b|\biex\b"; reason = "nested Invoke-Expression is not allowed in configured phase commands" },
    @{ pattern = "(?i)\bRemove-Item\b[^\r\n]*(?:-Recurse|-Force)|\brm\s+-rf\b|\bdel\s+/[fsq]\b"; reason = "destructive delete commands are not allowed in phase commands" },
    @{ pattern = "(?i)\bgit\s+reset\s+--hard\b|\bgit\s+clean\b[^\r\n]*\s-[^\r\n]*f"; reason = "destructive git commands are not allowed in phase commands" },
    @{ pattern = "(?i)(?:curl|wget|Invoke-WebRequest|iwr)[^\r\n]*(?:\||;|&&)[^\r\n]*(?:sh|bash|powershell|pwsh|cmd|iex|Invoke-Expression)"; reason = "remote download piped into execution is not allowed" },
    @{ pattern = "(?i)\bSet-ExecutionPolicy\b|\bStart-Process\b|\bFormat-Volume\b|\bClear-Disk\b"; reason = "system-changing commands are not allowed in phase commands" },
    @{ pattern = "(?i)file://"; reason = "file:// source indirection is not allowed in phase commands" }
  )
  foreach ($rule in $blockedPatterns) {
    if ($Command -match $rule.pattern) {
      throw "Command safety gate blocked command: $($rule.reason). Command: $Command"
    }
  }

  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
  $absolutePathMatches = [regex]::Matches($Command, "(?i)([A-Z]:\\[^`"'\s]+)")
  foreach ($match in $absolutePathMatches) {
    $candidate = [string]$match.Groups[1].Value
    try {
      $full = [System.IO.Path]::GetFullPath($candidate).TrimEnd("\")
      if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Configured phase commands may not reference absolute paths outside the project root: $candidate"
      }
    }
    catch {
      throw $_
    }
  }
}

function Validate-ArtifactSizeBudget {
  param(
    [string]$Root,
    [string[]]$Artifacts,
    [int]$MaxBytes,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($MaxBytes -lt 1) {
    throw "Artifact size budget must be greater than zero."
  }
  foreach ($rel in @($Artifacts)) {
    if ($rel -match "[\*\?]") {
      continue
    }
    $normalizedRel = ConvertTo-RelativeContractPath -Path $rel
    if ($normalizedRel -like "episode/*") {
      continue
    }
    $path = Join-Path $Root $rel
    Ensure-File $path
    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -notin @(".md",".json",".txt",".yaml",".yml",".csv")) {
      continue
    }
    $size = (Get-Item -LiteralPath $path).Length
    if ($size -gt $MaxBytes) {
      throw "Artifact size budget exceeded for '$rel' ($size bytes > $MaxBytes). Split the artifact or move bulky evidence to a bounded summary."
    }
  }
}

function Ensure-Any {
  param([string[]]$Patterns, [string]$BasePath)
  foreach ($pattern in $Patterns) {
    $resolved = Join-Path $BasePath $pattern
    if (Get-ChildItem -Path $resolved -ErrorAction SilentlyContinue) {
      return
    }
  }
  throw "Missing required artifacts. Expected one of: $($Patterns -join ', ')"
}

function Get-RelativePathSafe {
  param(
    [string]$BasePath,
    [string]$TargetPath
  )

  try {
    return ([System.IO.Path]::GetRelativePath($BasePath, $TargetPath) -replace "\\", "/")
  }
  catch {
    $base = [System.IO.Path]::GetFullPath($BasePath)
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    if ($target.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
      return ($target.Substring($base.Length).TrimStart('\') -replace "\\", "/")
    }
    return $TargetPath
  }
}

function Validate-PhaseArtifacts {
  param([string]$Phase, [string]$Root)

  switch ($Phase) {
    "intake" {
      Ensure-File (Join-Path $Root "runtime/book-request.md")
      foreach ($requiredIntake in @(
        "runtime/book-brief.json",
        "runtime/book-dna.json",
        "runtime/layout-profile.json",
        "runtime/approvals/book-brief-approval.json"
      )) {
        Ensure-File (Join-Path $Root $requiredIntake)
      }
    }
    "propose" {
      Ensure-Any -Patterns @(
        "_workspace/01_proposals.md",
        "_workspace/01_proposals*.md",
        "*_proposal.md"
      ) -BasePath $Root
    }
    "design-big" {
      Ensure-File (Join-Path $Root "novel-config.md")
      foreach ($requiredDesign in @(
        "design/01_concept_bootstrap.md",
        "design/02_character_core.md",
        "design/03_macro_plot_hooks.md",
        "design/04_book_plan.md",
        "design/05_chapter_plan.md",
        "design/06_layout_plan.md",
        "runtime/approvals/book-plan-approval.json",
        "revision/_state/book-plan.json",
        "revision/_state/chapter-plan.json",
        "revision/_state/layout-plan.json",
        "revision/_state/longform-plan.json",
        "revision/_state/character-state.json",
        "revision/_state/plot-ledger.json",
        "revision/_state/chapter-summaries.json",
        "revision/_state/continuity-ledger.json",
        "revision/_state/world-state.json",
        "revision/_state/relationship-graph.json",
        "revision/_state/knowledge-graph.json",
        "revision/_state/promise-payoff-ledger.json",
        "revision/_state/timeline.json",
        "revision/_state/theme-ledger.json",
        "revision/_state/volume-plan.json",
        "revision/_state/style-profile.json",
        "revision/_state/writing-type-profile.json",
        "revision/_state/genre-structure-template.json",
        "revision/_state/editorial-quality-scorecard.json",
        "revision/_state/llm-adapter-contract.json"
      )) {
        Ensure-File (Join-Path $Root $requiredDesign)
      }
    }
    "design-small" {
      Ensure-Any -Patterns @(
        "design/*_character-detail_*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/*_plot-detail_*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/*scene_plan*.md"
      ) -BasePath $Root
      Ensure-File (Join-Path $Root "novel-config.md")
    }
    "create" {
      Ensure-Any -Patterns @(
        "design/*scene_plan*.md",
        "design/*_plot-detail_*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @("episode/ep*.md") -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/04_quality-verifier_verdict_EP*.md",
        "revision/_workspace/*quality*verdict*EP*.md",
        "revision/_workspace/quality-verifier_EP*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/08_tdk-polisher_issues_EP*.json",
        "revision/_workspace/*tdk-polisher*issues*EP*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_state/character-state.json",
        "revision/_state/plot-ledger.json",
        "revision/_state/chapter-summaries.json",
        "revision/_state/continuity-ledger.json",
        "revision/_state/world-state.json",
        "revision/_state/relationship-graph.json",
        "revision/_state/knowledge-graph.json",
        "revision/_state/promise-payoff-ledger.json",
        "revision/_state/timeline.json",
        "revision/_state/theme-ledger.json",
        "revision/_state/volume-plan.json",
        "revision/_state/style-profile.json",
        "revision/_state/longform-plan.json",
        "revision/_state/book-plan.json",
        "revision/_state/chapter-plan.json",
        "revision/_state/layout-plan.json"
      ) -BasePath $Root
    }
    "polish" {
      Ensure-Any -Patterns @("episode/ep*.md") -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/revision-reviewer_EP*.md",
        "revision/_workspace/*revision-reviewer*EP*.md",
        "revision/_workspace/*reviewer*EP*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/08_tdk-polisher_issues_EP*.json",
        "revision/_workspace/*tdk-polisher*issues*EP*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @("revision/_state/*.json") -BasePath $Root
    }
    "rewrite" {
      Ensure-Any -Patterns @("episode/ep*.md") -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/*rewrite*report*.md",
        "revision/_workspace/04_quality-verifier_verdict_EP*.md",
        "revision/_workspace/*quality*verdict*EP*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/08_tdk-polisher_issues_EP*.json",
        "revision/_workspace/*tdk-polisher*issues*EP*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @("revision/_state/*.json") -BasePath $Root
    }
    "export" {
      Ensure-Any -Patterns @(
        "revision/_workspace/10_export-word_manifest_EP*.json",
        "revision/_workspace/10_docx-style-profile_EP*.json",
        "revision/_workspace/10_docx-reader-clean_report_EP*.md",
        "revision/_workspace/*export-word*manifest*.json",
        "revision/_workspace/*export-manifest*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/10_export-validator_verdict_EP*.json",
        "revision/_workspace/10_export-validator_report_EP*.md",
        "revision/_workspace/*export-validator*verdict*.json",
        "revision/_workspace/*export-validator*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/11_front-matter_report.md",
        "revision/_workspace/11_front-matter_*.md",
        "revision/_workspace/11_front-matter_toc.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/12_cover-design_manifest.json",
        "revision/_workspace/12_cover-design_brief.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/13_final-proofreader_report_EP*.md",
        "revision/_workspace/*final-proofreader*report*.md",
        "revision/_workspace/*final-proofreader*verdict*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/14_publication-compliance_verdict_EP*.json",
        "revision/_workspace/14_publication-compliance_report_EP*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_state/character-state.json",
        "revision/_state/plot-ledger.json",
        "revision/_state/chapter-summaries.json",
        "revision/_state/continuity-ledger.json",
        "revision/_state/style-profile.json",
        "revision/_state/longform-plan.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @("revision/export/*.docx") -BasePath $Root
    }
    default {
      throw "Unsupported phase: $Phase"
    }
  }
}

function Get-PhaseOutputArtifacts {
  param([string]$Phase, [string]$Root)

  $patterns = @()
  switch ($Phase) {
    "intake" {
      $patterns = @("runtime/book-brief.json","runtime/book-dna.json","runtime/layout-profile.json","runtime/approvals/book-brief-approval.json")
    }
    "propose" {
      $patterns = @("_workspace/01_proposals*.md","*_proposal.md","runtime/approvals/story-choice.json")
    }
    "design-big" {
      $patterns = @("novel-config.md","design/*_bootstrap.md","design/02_character_core.md","design/*_character*.md","design/03_macro_plot_hooks.md","design/*plot*hook*.md","design/04_book_plan.md","design/05_chapter_plan.md","design/06_layout_plan.md","runtime/approvals/book-plan-approval.json","revision/_state/*.json")
    }
    "design-small" {
      $patterns = @("design/*_character-detail_*.md","design/*_plot-detail_*.md","design/*scene_plan*.md","design/*hook*table*.md")
    }
    "create" {
      $patterns = @("episode/ep*.md","revision/_workspace/04_quality-verifier_verdict_EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json","revision/_workspace/macro-continuity-audit_EP*.json","revision/_workspace/macro-continuity-audit_EP*.md","revision/_state/*.json")
    }
    "polish" {
      $patterns = @("episode/ep*.md","revision/_workspace/*revision-reviewer*EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json","revision/_workspace/10_tdk-dictionary-check_polish.json","revision/_workspace/macro-continuity-audit_EP*.json","revision/_workspace/macro-continuity-audit_EP*.md","revision/_state/*.json")
    }
    "rewrite" {
      $patterns = @(
        "episode/ep*.md",
        "revision/_workspace/*rewrite*report*.md",
        "revision/_workspace/04_quality-verifier_verdict_EP*.md",
        "revision/_workspace/08_tdk-polisher_issues_EP*.json",
        "revision/_workspace/10_tdk-dictionary-check_rewrite.json",
        "revision/_workspace/macro-continuity-audit_EP*.json",
        "revision/_workspace/macro-continuity-audit_EP*.md",
        "revision/_state/*.json"
      )
    }
    "export" {
      $patterns = @(
        "revision/_workspace/*export*manifest*.json",
        "revision/_workspace/*export-validator*verdict*.json",
        "revision/_workspace/*export-content-match*",
        "revision/_workspace/*docx-style-profile*",
        "revision/_workspace/*docx-reader-clean*",
        "revision/_workspace/11_front-matter*",
        "revision/_workspace/12_cover-design*",
        "revision/_workspace/13_final-proofreader*",
        "revision/_workspace/14_publication-compliance*",
        "revision/_state/*.json",
        "revision/export/*.docx"
      )
    }
    default { $patterns = @() }
  }

  $files = @()
  foreach ($pattern in $patterns) {
    $resolved = Join-Path $Root $pattern
    $hits = Get-ChildItem -Path $resolved -ErrorAction SilentlyContinue -File | Select-Object -ExpandProperty FullName
    if ($hits) {
      $files += $hits
    }
  }

  $files = $files | Sort-Object -Unique
  $relative = @()
  foreach ($f in $files) {
    $relative += Get-RelativePathSafe -BasePath $Root -TargetPath $f
  }
  return $relative
}

function Load-RunnerConfig {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $dir = Split-Path -Parent $Path
    $templatePath = Join-Path $dir "runner-config.template.json"
    if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
      if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
      }
      Copy-Item -LiteralPath $templatePath -Destination $Path -Force
      Write-Host "[runner] created missing config from template: $Path"
    }
    else {
      throw "Runner config not found: $Path"
    }
  }
  return Read-Utf8 -Path $Path | ConvertFrom-Json
}

function Save-RunSummary {
  param(
    [string]$Path,
    [object]$Summary
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  Write-Utf8Bom -Path $Path -Content ($Summary | ConvertTo-Json -Depth 10)
}

function Save-CurrentRunPointer {
  param(
    [string]$Path,
    [object]$Pointer
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  Write-Utf8Bom -Path $Path -Content ($Pointer | ConvertTo-Json -Depth 10)
}

function Invoke-RunRetention {
  param(
    [string]$RunsRoot,
    [string]$ActiveRunId,
    [int]$MaxRuns,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($MaxRuns -lt 1) {
    return
  }
  if (-not (Test-Path -LiteralPath $RunsRoot -PathType Container)) {
    return
  }

  $resolvedRoot = [System.IO.Path]::GetFullPath($RunsRoot)
  $runDirs = Get-ChildItem -LiteralPath $RunsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "RUN-*" } |
    Sort-Object Name -Descending

  if (-not $runDirs -or $runDirs.Count -le $MaxRuns) {
    return
  }

  $keep = @()
  $count = 0
  foreach ($dir in $runDirs) {
    if ($count -lt $MaxRuns) {
      $keep += $dir.Name
      $count++
    }
  }
  if ($ActiveRunId -and ($keep -notcontains $ActiveRunId)) {
    $keep += $ActiveRunId
  }

  foreach ($dir in $runDirs) {
    if ($keep -contains $dir.Name) {
      continue
    }
    try {
      $resolvedCandidate = [System.IO.Path]::GetFullPath($dir.FullName)
      if (-not $resolvedCandidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to prune directory outside runs root: $resolvedCandidate"
      }
      Remove-Item -LiteralPath $dir.FullName -Recurse -Force
      Write-Host "[runner] retention pruned: $($dir.Name)"
    }
    catch {
      Write-Warning ("[runner] retention prune failed for {0}: {1}" -f $dir.Name, $_.Exception.Message)
    }
  }
}

function Expand-Template {
  param(
    [string]$Template,
    [hashtable]$Values
  )
  $out = $Template
  foreach ($key in $Values.Keys) {
    $token = "{" + $key + "}"
    $val = [string]$Values[$key]
    $out = $out.Replace($token, $val)
  }
  return $out
}

function Save-PhaseEvidence {
  param(
    [string]$Path,
    [object]$Evidence
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  Write-Utf8Bom -Path $Path -Content ($Evidence | ConvertTo-Json -Depth 10)
}

function Write-RunJournalEvent {
  param(
    [string]$Path,
    [string]$RunId,
    [string]$Phase,
    [string]$StepId,
    [string]$EventType,
    [object]$Metadata = @{}
  )

  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $event = [ordered]@{
    run_id = $RunId
    phase = $Phase
    step_id = $StepId
    event_type = $EventType
    created_at = (Get-Date).ToString("o")
    metadata = $Metadata
  }
  $line = ($event | ConvertTo-Json -Depth 20 -Compress)
  [System.IO.File]::AppendAllText($Path, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

function Validate-PhaseEvidenceFile {
  param([string]$Path, [string]$Root)

  Ensure-File $Path
  $raw = Read-Utf8 -Path $Path
  $obj = $raw | ConvertFrom-Json

  $required = @(
    "run_id","step_id","phase","execution_claim_mode","artifact_gate_passed",
    "dictionary_check_enabled","started_at","finished_at","status","output_artifacts","artifact_hashes","contract_hashes","notes"
  )
  foreach ($k in $required) {
    if (-not ($obj.PSObject.Properties.Name -contains $k)) {
      throw "Phase evidence missing required field '$k': $Path"
    }
  }

  if ($obj.execution_claim_mode -notin @("executed","simulated")) {
    throw "Invalid execution_claim_mode in phase evidence: $Path"
  }
  if ($obj.status -eq "completed" -and (-not $obj.artifact_gate_passed)) {
    throw "Completed phase evidence must have artifact_gate_passed=true: $Path"
  }
  if ($obj.status -eq "completed" -and $obj.output_artifacts.Count -lt 1) {
    throw "Completed phase evidence must include output_artifacts: $Path"
  }
  if ($obj.status -eq "completed" -and $obj.artifact_hashes.Count -lt 1) {
    throw "Completed phase evidence must include artifact_hashes: $Path"
  }
  if ($obj.status -eq "completed" -and $obj.contract_hashes.Count -lt 1) {
    throw "Completed phase evidence must include contract_hashes: $Path"
  }
  if ($obj.status -eq "completed") {
    Validate-ContractHashRecords -Root $Root -Phase ([string]$obj.phase) -Records @($obj.contract_hashes) -SourcePath $Path
  }
  if ($obj.status -eq "completed") {
    $artifactPaths = @($obj.output_artifacts | ForEach-Object { [string]$_ })
    foreach ($record in @($obj.artifact_hashes)) {
      foreach ($field in @("path","sha256")) {
        if (-not ($record.PSObject.Properties.Name -contains $field) -or -not ([string]$record.$field).Trim()) {
          throw "Phase evidence artifact_hashes entry missing '$field': $Path"
        }
      }
      $rel = [string]$record.path
      if ($artifactPaths -notcontains $rel) {
        throw "Phase evidence hash path '$rel' not listed in output_artifacts: $Path"
      }
      if ($rel -match "[\*\?]") {
        throw "Phase evidence refuses wildcard artifact path: $rel"
      }
      $sha = [string]$record.sha256
      if ($sha -notmatch "^[a-f0-9]{64}$") {
        throw "Phase evidence artifact hash is not lowercase SHA-256 for '$rel': $Path"
      }
      $actual = Get-FileSha256 -Path (Join-Path $Root $rel)
      if ($actual -ne $sha) {
        throw "Phase evidence hash mismatch for '$rel'. Expected $sha, actual $actual."
      }
    }
  }
}

function Invoke-DictionaryCheck {
  param(
    [string]$Phase,
    [string]$Root,
    [string]$RunId,
    [object]$Config,
    [bool]$Enabled,
    [bool]$CommandSafetyEnabled
  )

  if (-not $Enabled) {
    return
  }

  if ($Phase -notin @("create","polish","rewrite")) {
    return
  }

  $requireProvider = $false
  if ($Config -and $Config.quality_flags -and ($Config.quality_flags.PSObject.Properties.Name -contains "require_dictionary_provider")) {
    $requireProvider = [bool]$Config.quality_flags.require_dictionary_provider
  }

  $template = ""
  if ($Config -and $Config.quality_flags -and $Config.quality_flags.dictionary_check_command) {
    $template = [string]$Config.quality_flags.dictionary_check_command
  }
  if (-not $template) {
    $template = "powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot ""{project_root}"" -Phase {phase} -RunId {run_id} {require_provider_arg}"
  }

  if ($template -match "tdk_dict_check\.ps1") {
    $scriptPath = Join-Path $Root "scripts/ci/tdk_dict_check.ps1"
    $argsList = @("-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-ProjectRoot", $Root, "-Phase", $Phase, "-RunId", $RunId)
    if ($requireProvider) {
      $argsList += "-RequireProvider"
    }
    Write-Host "[runner] dictionary-check: powershell $($argsList -join ' ')"
    & powershell @argsList
    if ($LASTEXITCODE -ne 0) {
      throw "Dictionary check failed (exit=$LASTEXITCODE): $scriptPath"
    }
    return
  }

  $cmd = Expand-Template -Template $template -Values @{
    phase = $Phase
    project_root = $Root
    run_id = $RunId
    require_provider_arg = $(if ($requireProvider) { "-RequireProvider" } else { "" })
  }

  Write-Host "[runner] dictionary-check: $cmd"
  Validate-CommandSafety -Command $cmd -Root $Root -Enabled $CommandSafetyEnabled
  Invoke-Expression $cmd
  if ($LASTEXITCODE -ne 0) {
    throw "Dictionary check failed (exit=$LASTEXITCODE): $cmd"
  }
}

function Ensure-UserApproval {
  param(
    [string]$Root,
    [string]$Phase,
    [object]$Config,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }

  $approvalMap = @{
    "propose" = "runtime/approvals/book-brief-approval.json"
    "design-big" = "runtime/approvals/story-choice.json"
    "design-small" = "runtime/approvals/book-plan-approval.json"
    "create" = "runtime/approvals/design-freeze.json"
    "rewrite" = "runtime/approvals/rewrite-approval.json"
    "export" = "runtime/approvals/export-approval.json"
  }

  if ($Config -and $Config.quality_flags -and $Config.quality_flags.approval_files) {
    $custom = $Config.quality_flags.approval_files
    foreach ($k in @("propose","design-big","design-small","create","rewrite","export")) {
      if ($custom.PSObject.Properties.Name -contains $k -and $custom.$k) {
        $approvalMap[$k] = [string]$custom.$k
      }
    }
  }

  if (-not $approvalMap.ContainsKey($Phase)) {
    return
  }

  $rel = $approvalMap[$Phase]
  $path = Join-Path $Root $rel
  Ensure-File $path

  $obj = Read-Utf8 -Path $Path | ConvertFrom-Json
  if (-not ($obj.PSObject.Properties.Name -contains "approved")) {
    throw "Approval gate missing 'approved' field: $rel"
  }
  if ($obj.approved -ne $true) {
    throw "Phase '$Phase' is BLOCKED by approval gate: $rel"
  }
  if ($Phase -eq "propose") {
    Validate-BookBriefApproval -Root $Root -Approval $obj -ApprovalRel $rel
  }
  if ($Phase -eq "design-big") {
    $briefApprovalRel = "runtime/approvals/book-brief-approval.json"
    $briefApprovalPath = Join-Path $Root $briefApprovalRel
    Ensure-File $briefApprovalPath
    $briefApproval = Read-Utf8 -Path $briefApprovalPath | ConvertFrom-Json
    if (-not ($briefApproval.PSObject.Properties.Name -contains "approved") -or $briefApproval.approved -ne $true) {
      throw "Design-big blocked: $briefApprovalRel must be approved before story design."
    }
    Validate-BookBriefApproval -Root $Root -Approval $briefApproval -ApprovalRel $briefApprovalRel
    $selected = Get-StringFieldValue -Object $obj -Field "selected_option"
    if ($selected -notin @("1","2","3")) {
      throw "Story choice approval blocked: $rel must include selected_option 1, 2, or 3 before design-big."
    }
  }
  if ($Phase -eq "design-small") {
    Validate-BookPlanApproval -Root $Root -Approval $obj -ApprovalRel $rel
  }
}

function Get-StringFieldValue {
  param([object]$Object, [string]$Field)
  if ($Object -and ($Object.PSObject.Properties.Name -contains $Field)) {
    return ([string]$Object.$Field).Trim()
  }
  return ""
}

function Test-AnsweredField {
  param([object]$Primary, [object]$Fallback, [string]$Field)
  $value = Get-StringFieldValue -Object $Primary -Field $Field
  if ($value) {
    if ($value -match "(?i)^\s*(ask_user|ask user|to_be_confirmed|tbd|todo|unknown|bilinmiyor|sorulacak)\s*$") { return $false }
    return $true
  }
  $fallbackValue = Get-StringFieldValue -Object $Fallback -Field $Field
  if (-not $fallbackValue) { return $false }
  if ($fallbackValue -match "(?i)^\s*(ask_user|ask user|to_be_confirmed|tbd|todo|unknown|bilinmiyor|sorulacak)\s*$") { return $false }
  return $true
}

function Validate-BookBriefApproval {
  param([string]$Root, [object]$Approval, [string]$ApprovalRel)

  $briefRel = "runtime/book-brief.json"
  $dnaRel = "runtime/book-dna.json"
  $layoutRel = "runtime/layout-profile.json"
  $brief = Read-JsonFile -Path (Join-Path $Root $briefRel)
  $dna = Read-JsonFile -Path (Join-Path $Root $dnaRel)
  $layout = Read-JsonFile -Path (Join-Path $Root $layoutRel)

  foreach ($field in @("required_user_questions","answers","approval_requirements","intake_policy")) {
    if (-not ($brief.PSObject.Properties.Name -contains $field)) {
      throw "Book brief approval blocked: $briefRel missing '$field'. Run intake again with the current contract."
    }
  }
  if (@($brief.required_user_questions).Count -lt 8) {
    throw "Book brief approval blocked: $briefRel must contain the full intake question set."
  }

  $acceptedAnswers = $null
  if ($Approval.PSObject.Properties.Name -contains "accepted_answers") {
    $acceptedAnswers = $Approval.accepted_answers
  }
  $answers = $brief.answers
  foreach ($field in @("writing_type","premise","target_reader","genre","character_policy","setting_period","pov_tense","style_tone","publication_package")) {
    if (-not (Test-AnsweredField -Primary $acceptedAnswers -Fallback $answers -Field $field)) {
      throw "Book brief approval blocked: required intake answer '$field' is empty. Fill runtime/book-brief.json answers or $ApprovalRel accepted_answers before approving."
    }
  }

  $targetLengthAnswered = (Test-AnsweredField -Primary $acceptedAnswers -Fallback $answers -Field "target_length") -or (Test-AnsweredField -Primary $acceptedAnswers -Fallback $answers -Field "target_pages")
  if (-not $targetLengthAnswered) {
    throw "Book brief approval blocked: target_length or target_pages must be answered before planning."
  }

  if (-not ($dna.PSObject.Properties.Name -contains "locked_answers_required")) {
    throw "Book brief approval blocked: $dnaRel missing locked_answers_required."
  }
  if (-not ($dna.PSObject.Properties.Name -contains "plan_before_writing_policy")) {
    throw "Book brief approval blocked: $dnaRel missing plan_before_writing_policy."
  }
  if (-not ($layout.PSObject.Properties.Name -contains "front_matter") -or -not ($layout.PSObject.Properties.Name -contains "cover") -or -not ($layout.PSObject.Properties.Name -contains "page_setup")) {
    throw "Book brief approval blocked: $layoutRel must declare front_matter, cover, and page_setup."
  }
}

function Validate-BookPlanApproval {
  param([string]$Root, [object]$Approval, [string]$ApprovalRel)

  foreach ($rel in @("revision/_state/book-plan.json","revision/_state/chapter-plan.json","revision/_state/layout-plan.json","revision/_state/longform-plan.json","revision/_state/volume-plan.json")) {
    Ensure-File (Join-Path $Root $rel)
  }
  $bookPlan = Read-JsonFile -Path (Join-Path $Root "revision/_state/book-plan.json")
  $plan = Read-JsonFile -Path (Join-Path $Root "revision/_state/longform-plan.json")
  foreach ($field in @("target_pages","target_words","target_chapters","max_chapters_per_batch","audit_interval_chapters","continuity_model")) {
    if (-not ($plan.PSObject.Properties.Name -contains $field)) {
      throw "Book plan approval blocked: longform-plan.json missing '$field'."
    }
  }
  $acceptedPlanSummary = Get-StringFieldValue -Object $Approval -Field "accepted_plan_summary"
  $acceptedTargets = $Approval.PSObject.Properties.Name -contains "accepted_targets"
  if (-not $acceptedPlanSummary -and -not $acceptedTargets) {
    throw "Book plan approval blocked: $ApprovalRel must include accepted_plan_summary or accepted_targets so the user approval is tied to the visible plan."
  }
  if ($acceptedTargets) {
    foreach ($field in @("target_pages","target_words","target_chapters")) {
      if (-not ($Approval.accepted_targets.PSObject.Properties.Name -contains $field)) {
        throw "Book plan approval blocked: accepted_targets missing '$field'."
      }
      if ([int]$Approval.accepted_targets.$field -ne [int]$plan.$field) {
        throw "Book plan approval blocked: accepted_targets.$field does not match longform-plan.json."
      }
    }
  }
  if ($Approval.PSObject.Properties.Name -contains "accepted_writing_type" -and $Approval.accepted_writing_type) {
    if ([string]$Approval.accepted_writing_type -ne [string]$bookPlan.writing_type) {
      throw "Book plan approval blocked: accepted_writing_type does not match book-plan.json."
    }
  }
  if ($Approval.PSObject.Properties.Name -contains "accepted_genre" -and $Approval.accepted_genre) {
    if ([string]$Approval.accepted_genre -ne [string]$bookPlan.genre) {
      throw "Book plan approval blocked: accepted_genre does not match book-plan.json."
    }
  }
}

function Validate-JsonIssueContract {
  param([string]$Path)

  Ensure-File $Path
  $obj = Read-Utf8 -Path $Path | ConvertFrom-Json
  if (-not ($obj.PSObject.Properties.Name -contains "issues")) {
    throw "Issue contract missing 'issues': $Path"
  }
  foreach ($it in $obj.issues) {
    foreach ($req in @("id","severity","auto_fixable")) {
      if (-not ($it.PSObject.Properties.Name -contains $req)) {
        throw "Issue contract missing '$req' in $Path"
      }
    }
    if ($it.severity -notin @("critical","major","minor")) {
      throw "Invalid severity enum '$($it.severity)' in $Path"
    }
  }
}

function Validate-MarkdownVerdictContract {
  param([string]$Path)

  Ensure-File $Path
  $raw = Read-Utf8 -Path $Path
  if ($raw -notmatch "(?i)\bVERDICT\b.*\b(PASS|FAIL|BLOCKED)\b") {
    throw "Verdict contract missing PASS/FAIL/BLOCKED token: $Path"
  }
}

function Validate-PhaseContracts {
  param(
    [string]$Root,
    [string]$Phase,
    [string[]]$Artifacts,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }

  $registry = Get-AgentRegistry -Root $Root
  $contract = Get-PhaseContract -Root $Root -Phase $Phase
  if ([string]$contract.phase -ne $Phase) {
    throw "Phase contract mismatch. Expected '$Phase', found '$($contract.phase)'."
  }
  foreach ($field in @("required_agents","required_references","required_state_files","allowed_output_patterns","denied_output_patterns","status_contract")) {
    if (-not ($contract.PSObject.Properties.Name -contains $field)) {
      throw "Phase contract '$Phase' missing '$field'."
    }
  }
  foreach ($agentName in @($contract.required_agents)) {
    $agent = Get-AgentByName -Registry $registry -Name ([string]$agentName)
    if ($null -eq $agent) {
      throw "Phase contract '$Phase' references unknown agent '$agentName'."
    }
    if (@($agent.allowed_phases) -notcontains $Phase) {
      throw "Agent '$agentName' is not allowed to run in phase '$Phase'."
    }
  }
  foreach ($rel in @($contract.required_references)) {
    Ensure-File (Join-Path $Root ([string]$rel))
  }
  foreach ($rel in @($contract.required_state_files)) {
    Ensure-File (Join-Path $Root ([string]$rel))
  }
  foreach ($rel in @($contract.required_approvals)) {
    Ensure-File (Join-Path $Root ([string]$rel))
  }
  foreach ($artifact in @($Artifacts)) {
    $relArtifact = ConvertTo-RelativeContractPath -Path $artifact
    if (Test-AnyContractPattern -Value $relArtifact -Patterns @($contract.denied_output_patterns)) {
      throw "Phase '$Phase' produced denied artifact '$relArtifact' according to runtime/phase-contracts/$Phase.json."
    }
    if (-not (Test-AnyContractPattern -Value $relArtifact -Patterns @($contract.allowed_output_patterns))) {
      throw "Phase '$Phase' produced artifact outside allowed output patterns: $relArtifact"
    }
  }

  if ($Phase -in @("create","polish","rewrite")) {
    $issueArtifacts = $Artifacts | Where-Object { $_ -match "tdk-polisher.*issues.*\.json$" -or $_ -match "layout.*issues.*\.json$" }
    if (-not $issueArtifacts -or $issueArtifacts.Count -lt 1) {
      throw "Phase '$Phase' missing mandatory issue JSON artifacts."
    }
    foreach ($rel in $issueArtifacts) {
      Validate-JsonIssueContract -Path (Join-Path $Root $rel)
    }

    $verdictArtifacts = $Artifacts | Where-Object { $_ -match "quality-verifier.*\.md$" -or $_ -match "revision-reviewer.*\.md$" }
    if (-not $verdictArtifacts -or $verdictArtifacts.Count -lt 1) {
      throw "Phase '$Phase' missing mandatory verdict markdown artifact."
    }
    foreach ($rel in $verdictArtifacts) {
      Validate-MarkdownVerdictContract -Path (Join-Path $Root $rel)
    }
  }

  if ($Phase -eq "export") {
    $manifestArtifacts = $Artifacts | Where-Object { $_ -match "manifest.*\.json$" }
    if (-not $manifestArtifacts -or $manifestArtifacts.Count -lt 1) {
      throw "Export phase missing manifest JSON artifact."
    }
    $publicationArtifacts = $Artifacts | Where-Object { $_ -match "publication-compliance.*\.(json|md)$" }
    if (-not $publicationArtifacts -or $publicationArtifacts.Count -lt 1) {
      throw "Export phase missing publication compliance artifacts."
    }
  }
}

function Validate-AgentCompliance {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled,
    [string[]]$Artifacts = @()
  )

  if (-not $Enabled) {
    return
  }

  $schemaPath = Join-Path $Root "runtime/agent-compliance.schema.json"
  Ensure-File $schemaPath
  $schemaRaw = Read-Utf8 -Path $schemaPath
  foreach ($schemaToken in @("artifact_hashes","contract_hashes","agent_statuses","phase_authority","completed_at","additionalProperties")) {
    if ($schemaRaw -notmatch [regex]::Escape($schemaToken)) {
      throw "Agent compliance schema missing required token '$schemaToken': $schemaPath"
    }
  }

  $path = Join-Path $Root ("runtime/agent-compliance/{0}.json" -f $Phase)
  Ensure-File $path
  $obj = Read-Utf8 -Path $Path | ConvertFrom-Json

  $requiredFields = @("run_id","phase","required_agents","agents_executed","required_references","loaded_state_files","output_artifacts","artifact_hashes","contract_hashes","agent_statuses","phase_authority","completed_at","contract_status","missing_items")
  $allowedFields = $requiredFields + @("generation_boundary","creative_authority","research_boundary")
  foreach ($prop in $obj.PSObject.Properties.Name) {
    if ($allowedFields -notcontains $prop) {
      throw "Agent compliance manifest has unexpected field '$prop': $path"
    }
  }
  foreach ($field in $requiredFields) {
    if (-not ($obj.PSObject.Properties.Name -contains $field)) {
      throw "Agent compliance manifest missing '$field': $path"
    }
  }
  foreach ($field in @("run_id","phase","contract_status","phase_authority","completed_at")) {
    if (-not ([string]$obj.$field).Trim()) {
      throw "Agent compliance field '$field' must be a non-empty string: $path"
    }
  }
  foreach ($field in @("required_agents","agents_executed","required_references","loaded_state_files","output_artifacts","artifact_hashes","contract_hashes","agent_statuses","missing_items")) {
    $items = @($obj.$field)
    if ($null -eq $obj.$field) {
      throw "Agent compliance field '$field' must be an array: $path"
    }
    if ($field -in @("required_agents","agents_executed","output_artifacts","artifact_hashes","contract_hashes","agent_statuses") -and $items.Count -lt 1) {
      throw "Agent compliance field '$field' must not be empty: $path"
    }
  }
  if ([string]$obj.phase -ne $Phase) {
    throw "Agent compliance phase mismatch. Expected '$Phase', found '$($obj.phase)': $path"
  }
  if ($obj.contract_status -ne "PASS") {
    throw "Agent compliance failed for phase '$Phase': status=$($obj.contract_status)"
  }
  if ($obj.phase_authority -notin @("local_adapter_scaffold","manual_ide_agent","provider_command","human_operator")) {
    throw "Agent compliance has invalid phase_authority '$($obj.phase_authority)': $path"
  }
  $completedAt = [datetime]::MinValue
  if (-not [datetime]::TryParse([string]$obj.completed_at, [ref]$completedAt)) {
    throw "Agent compliance completed_at is not a valid timestamp: $path"
  }
  if (@($obj.required_agents).Count -lt 1) {
    throw "Agent compliance required_agents is empty for phase '$Phase'."
  }
  foreach ($listName in @("required_agents","agents_executed","required_references","loaded_state_files","output_artifacts")) {
    $values = @($obj.$listName | ForEach-Object { [string]$_ })
    $bad = @($values | Where-Object { -not $_.Trim() })
    if ($bad.Count -gt 0) {
      throw "Agent compliance '$listName' contains empty value for phase '$Phase'."
    }
    $unique = @($values | Sort-Object -Unique)
    if ($unique.Count -ne $values.Count) {
      throw "Agent compliance '$listName' contains duplicate values for phase '$Phase'."
    }
  }
  $executed = @($obj.agents_executed)
  foreach ($agent in @($obj.required_agents)) {
    if ($executed -notcontains $agent) {
      throw "Agent compliance missing executed agent '$agent' for phase '$Phase'."
    }
  }

  $registry = Get-AgentRegistry -Root $Root
  $statusContract = Get-AgentStatusContract -Root $Root
  $phaseContract = Get-PhaseContract -Root $Root -Phase $Phase
  Validate-ContractHashRecords -Root $Root -Phase $Phase -Records @($obj.contract_hashes) -SourcePath $path
  foreach ($agent in @($phaseContract.required_agents)) {
    if (@($obj.required_agents) -notcontains $agent) {
      throw "Agent compliance required_agents omits phase-contract required agent '$agent' for phase '$Phase'."
    }
  }
  foreach ($ref in @($phaseContract.required_references)) {
    if (@($obj.required_references) -notcontains $ref) {
      throw "Agent compliance required_references omits phase-contract reference '$ref' for phase '$Phase'."
    }
  }
  foreach ($stateFile in @($phaseContract.required_state_files)) {
    if (@($obj.loaded_state_files) -notcontains $stateFile) {
      throw "Agent compliance loaded_state_files omits phase-contract state '$stateFile' for phase '$Phase'."
    }
  }

  $validStatuses = @($statusContract.valid_status_values | ForEach-Object { [string]$_ })
  $statusByAgent = @{}
  foreach ($record in @($obj.agent_statuses)) {
    foreach ($field in @("agent","status")) {
      if (-not ($record.PSObject.Properties.Name -contains $field) -or -not ([string]$record.$field).Trim()) {
        throw "Agent compliance agent_statuses entry missing '$field': $path"
      }
    }
    $agentName = [string]$record.agent
    $agentStatus = [string]$record.status
    if ($statusByAgent.ContainsKey($agentName)) {
      throw "Agent compliance duplicate agent_statuses entry for '$agentName': $path"
    }
    if ($validStatuses -notcontains $agentStatus) {
      throw "Agent compliance invalid status '$agentStatus' for agent '$agentName'."
    }
    if ($null -eq (Get-AgentByName -Registry $registry -Name $agentName)) {
      throw "Agent compliance references unknown agent '$agentName'."
    }
    $statusByAgent[$agentName] = $agentStatus
  }
  foreach ($agent in @($obj.required_agents)) {
    if (-not $statusByAgent.ContainsKey([string]$agent)) {
      throw "Agent compliance missing agent_statuses entry for required agent '$agent'."
    }
    if ($statusByAgent[[string]$agent] -ne "completed") {
      throw "Agent '$agent' did not complete successfully in phase '$Phase': status=$($statusByAgent[[string]$agent])"
    }
  }
  if (@($obj.missing_items).Count -gt 0) {
    throw "Agent compliance has missing_items for phase '$Phase': $($obj.missing_items -join ', ')"
  }

  foreach ($rel in @($obj.required_references)) {
    Ensure-File (Join-Path $Root ([string]$rel))
  }
  foreach ($rel in @($obj.loaded_state_files)) {
    Ensure-File (Join-Path $Root ([string]$rel))
  }

  $outputArtifacts = @($obj.output_artifacts | ForEach-Object { [string]$_ })
  foreach ($rel in $outputArtifacts) {
    if ($rel -match "[\*\?]") {
      throw "Agent compliance output_artifacts must list concrete files, not wildcard path '$rel'."
    }
    if (Test-AnyContractPattern -Value $rel -Patterns @($phaseContract.denied_output_patterns)) {
      throw "Agent compliance output artifact '$rel' is denied by phase contract '$Phase'."
    }
    if (-not (Test-AnyContractPattern -Value $rel -Patterns @($phaseContract.allowed_output_patterns))) {
      throw "Agent compliance output artifact '$rel' is outside allowed phase contract outputs for '$Phase'."
    }
    Ensure-File (Join-Path $Root $rel)
  }

  $hashByPath = @{}
  foreach ($record in @($obj.artifact_hashes)) {
    foreach ($field in @("path","sha256")) {
      if (-not ($record.PSObject.Properties.Name -contains $field) -or -not ([string]$record.$field).Trim()) {
        throw "Agent compliance artifact_hashes entry missing '$field': $path"
      }
    }
    $rel = [string]$record.path
    $sha = [string]$record.sha256
    if ($rel -match "[\*\?]") {
      throw "Agent compliance artifact_hashes must list concrete files, not wildcard path '$rel'."
    }
    if ($sha -notmatch "^[a-f0-9]{64}$") {
      throw "Agent compliance artifact hash is not lowercase SHA-256 for '$rel': $path"
    }
    if ($hashByPath.ContainsKey($rel)) {
      throw "Agent compliance duplicate artifact_hashes path '$rel': $path"
    }
    if ($outputArtifacts -notcontains $rel) {
      throw "Agent compliance artifact_hashes path '$rel' is not listed in output_artifacts."
    }
    $actual = Get-FileSha256 -Path (Join-Path $Root $rel)
    if ($actual -ne $sha) {
      throw "Agent compliance hash mismatch for '$rel'. Expected $sha, actual $actual."
    }
    $hashByPath[$rel] = $sha
  }
  foreach ($rel in $outputArtifacts) {
    if (-not $hashByPath.ContainsKey($rel)) {
      throw "Agent compliance output artifact '$rel' has no matching artifact_hashes entry."
    }
  }

  if ($Artifacts -and $Artifacts.Count -gt 0) {
    $artifactSet = @($Artifacts | Sort-Object -Unique)
    foreach ($rel in $outputArtifacts) {
      if ($artifactSet -notcontains $rel) {
        throw "Agent compliance output artifact '$rel' was not discovered by the phase artifact gate."
      }
    }
  }
}

function Validate-PublicationCompliance {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled -or $Phase -ne "export") {
    return
  }

  $verdicts = Get-ChildItem -Path (Join-Path $Root "revision/_workspace/14_publication-compliance_verdict_EP*.json") -File -ErrorAction SilentlyContinue
  if (-not $verdicts -or $verdicts.Count -lt 1) {
    throw "Publication compliance verdict is missing."
  }

  $metadataPath = Join-Path $Root "revision/_workspace/11_front-matter_publication-metadata.json"
  Ensure-File $metadataPath
  $metadata = Read-Utf8 -Path $metadataPath | ConvertFrom-Json
  foreach ($field in @("title","author_or_editor","copyright_owner","publication_year","format","metadata_status")) {
    if (-not ($metadata.PSObject.Properties.Name -contains $field)) {
      throw "Publication metadata missing '$field': $metadataPath"
    }
  }
  if ([string]$metadata.metadata_status -notin @("draft_user_review","publisher_review_required","final_publisher_supplied")) {
    throw "Publication metadata has invalid metadata_status: $metadataPath"
  }
  foreach ($field in @("isbn","barcode","publisher")) {
    if ($metadata.PSObject.Properties.Name -contains $field) {
      $value = ([string]$metadata.$field).Trim()
      if ($value -match "(?i)^(fake|placeholder|todo|tbd|123|000|isbn)$") {
        throw "Publication metadata contains fake or placeholder $field."
      }
    }
  }

  foreach ($file in $verdicts) {
    $obj = Read-Utf8 -Path $file.FullName | ConvertFrom-Json
    foreach ($field in @("run_id","step_id","verdict","print_ready","metadata_placeholders","isbn_status","barcode_status","kunye_status","bandrol_external","block_reasons")) {
      if (-not ($obj.PSObject.Properties.Name -contains $field)) {
        throw "Publication compliance verdict missing '$field': $($file.FullName)"
      }
    }
    if ($obj.verdict -notin @("READY","REVIEW_REQUIRED","BLOCKED")) {
      throw "Invalid publication compliance verdict '$($obj.verdict)': $($file.FullName)"
    }
    if ($obj.print_ready -eq $true -and $obj.verdict -ne "READY") {
      throw "Publication compliance cannot set print_ready=true unless verdict=READY: $($file.FullName)"
    }
  }
}

function Get-DocxText {
  param([string]$DocxPath)

  Ensure-File $DocxPath
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = $null
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $DocxPath))
    $entry = $zip.Entries | Where-Object { $_.FullName -eq "word/document.xml" } | Select-Object -First 1
    if (-not $entry) {
      throw "DOCX package is missing word/document.xml: $DocxPath"
    }
    $stream = $entry.Open()
    try {
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
      $xml = $reader.ReadToEnd()
    }
    finally {
      if ($reader) { $reader.Dispose() }
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($zip) { $zip.Dispose() }
  }

  $text = $xml -replace "<w:tab[^>]*/>", " "
  $text = $text -replace "</w:p>", "`n"
  $text = $text -replace "<[^>]+>", " "
  return [System.Net.WebUtility]::HtmlDecode($text)
}

function Normalize-ExportText {
  param([string]$Text)
  return (($Text.ToLowerInvariant() -replace "\s+", " ").Trim())
}

function Get-ManuscriptSnippets {
  param([string]$Text)

  $snippets = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($Text -split "\r?\n")) {
    $clean = ($line -replace "^#{1,6}\s*", "" -replace "^\s*[-*]\s+", "").Trim()
    if (-not $clean) { continue }
    if ($clean -match "(?i)^\s*(run_id|step_id)\s*:") { continue }
    if ($clean -match "(?i)^ep\d{3}$|^scene\s+\d+|^sahne\s+\d+") { continue }
    if ($clean.Length -ge 45) {
      $snippets.Add($clean.Substring(0, [Math]::Min(140, $clean.Length)))
    }
    if ($snippets.Count -ge 4) { break }
  }
  return $snippets
}

function Resolve-ExportManifestPath {
  param([string]$Root)
  $manifests = @(Get-ChildItem -Path (Join-Path $Root "revision/_workspace/10_export-word_manifest_EP*.json") -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if ($manifests.Count -lt 1) {
    throw "DOCX content match gate failed: export manifest is missing."
  }
  return $manifests[0].FullName
}

function Resolve-ProjectPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return (Join-Path $Root $Path)
}

function Validate-DocxContentMatch {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled -or $Phase -ne "export") {
    return
  }

  $manifestPath = Resolve-ExportManifestPath -Root $Root
  $manifest = Read-Utf8 -Path $manifestPath | ConvertFrom-Json
  foreach ($field in @("source_files","output_docx_path")) {
    if (-not ($manifest.PSObject.Properties.Name -contains $field)) {
      throw "DOCX content match gate failed: export manifest missing '$field'."
    }
  }

  $docxPath = Resolve-ProjectPath -Root $Root -Path ([string]$manifest.output_docx_path)
  $docxText = Normalize-ExportText -Text (Get-DocxText -DocxPath $docxPath)
  if (-not $docxText) {
    throw "DOCX content match gate failed: extracted DOCX text is empty."
  }

  $checked = 0
  $matched = 0
  $missing = New-Object System.Collections.Generic.List[string]
  foreach ($rel in @($manifest.source_files)) {
    $sourcePath = Resolve-ProjectPath -Root $Root -Path ([string]$rel)
    Ensure-File $sourcePath
    $sourceText = Read-Utf8 -Path $sourcePath
    $snippets = @(Get-ManuscriptSnippets -Text $sourceText)
    if ($snippets.Count -lt 1) {
      throw "DOCX content match gate failed: source file has no usable manuscript snippet: $rel"
    }

    $checked++
    $sourceMatched = $false
    foreach ($snippet in $snippets) {
      if ($docxText.Contains((Normalize-ExportText -Text $snippet))) {
        $sourceMatched = $true
        break
      }
    }
    if ($sourceMatched) {
      $matched++
    }
    else {
      $missing.Add([string]$rel)
    }
  }

  if ($checked -lt 1) {
    throw "DOCX content match gate failed: no source files declared in export manifest."
  }
  if ($missing.Count -gt 0) {
    throw "DOCX content match gate failed: DOCX does not contain current source manuscript snippets for $($missing -join ', '). Refusing stale/copied DOCX export."
  }

  $reportPath = Join-Path $Root "revision/_workspace/10_export-content-match_report.md"
  $report = "# DOCX Content Match`n`nVERDICT: PASS`n`nmanifest: $(Get-RelativePathSafe -BasePath $Root -TargetPath $manifestPath)`nsource_files_checked: $checked`nsource_files_matched: $matched`n"
  Write-Utf8Bom -Path $reportPath -Content $report
}

function Validate-DocxReaderClean {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled -or $Phase -ne "export") {
    return
  }

  $manifestPath = Resolve-ExportManifestPath -Root $Root
  $manifest = Read-Utf8 -Path $manifestPath | ConvertFrom-Json
  if (-not ($manifest.PSObject.Properties.Name -contains "output_docx_path")) {
    throw "DOCX reader-clean gate failed: export manifest missing output_docx_path."
  }

  $docxPath = Resolve-ProjectPath -Root $Root -Path ([string]$manifest.output_docx_path)
  $docxText = Get-DocxText -DocxPath $docxPath
  $blockedPatterns = @(
    "(?i)\bpublication\s+compliance\b",
    "(?i)\bfront\s+matter\s+report\b",
    "(?i)\bexport\s+validator\b",
    "(?i)\bfinal\s+proofreader\b",
    "(?i)\bVERDICT\s*:",
    "(?i)\bREVIEW_REQUIRED\b",
    "(?i)\bREADY_WITH_PUBLICATION_REVIEW\b",
    "(?i)\bBLOCKED\b",
    "(?i)\bblock_reasons\b",
    "(?i)\bprint_ready\b",
    "(?i)\brun_id\s*:",
    "(?i)\bstep_id\s*:",
    "(?i)ISBN.*(missing|eksik|not_assigned|placeholder|review)",
    "(?i)bandrol.*(external|eksik|review)",
    "(?i)yayı[nm]\s+not",
    "(?i)yayin\s+not",
    "(?i)inceleme\s+not",
    "(?i)test\s+dosya"
  )
  foreach ($pattern in $blockedPatterns) {
    if ($docxText -match $pattern) {
      throw "DOCX reader-clean gate failed: reader-facing DOCX contains review/control note pattern '$pattern'. Move review notes to revision/_workspace artifacts."
    }
  }

  $reportPath = Join-Path $Root "revision/_workspace/10_docx-reader-clean_report.md"
  Write-Utf8Bom -Path $reportPath -Content "# DOCX Reader Clean`n`nVERDICT: PASS`n`nReview notes and publication-control metadata were not found in the reader-facing DOCX.`n"
}

function Validate-ExportManifestContract {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled -or $Phase -ne "export") {
    return
  }

  $manifestPath = Resolve-ExportManifestPath -Root $Root
  $manifest = Read-Utf8 -Path $manifestPath | ConvertFrom-Json
  foreach ($field in @("project_name","episode_range","source_mode","source_files","source_hashes","style_profile","docx_style_profile","delivery_profiles","page_layout","typography","approval_artifact","front_matter_files","cover_design_manifest","cover_files","publication_compliance_verdict","blocked","block_reasons","output_docx_path","docx_sha256")) {
    if (-not ($manifest.PSObject.Properties.Name -contains $field)) {
      throw "Export manifest contract failed: missing '$field'."
    }
  }
  if ($manifest.blocked -eq $true) {
    throw "Export manifest contract failed: blocked export cannot be treated as completed."
  }
  if (@($manifest.source_files).Count -lt 1) {
    throw "Export manifest contract failed: source_files is empty."
  }
  if (@($manifest.front_matter_files).Count -lt 5) {
    throw "Export manifest contract failed: front_matter_files must include title, copyright, preface, toc, and metadata artifacts."
  }
  foreach ($rel in @($manifest.front_matter_files + $manifest.cover_files + @($manifest.cover_design_manifest, $manifest.publication_compliance_verdict, $manifest.output_docx_path, $manifest.docx_style_profile))) {
    if (-not [string]$rel) { continue }
    Ensure-File (Resolve-ProjectPath -Root $Root -Path ([string]$rel))
  }
  foreach ($hashRecord in @($manifest.source_hashes)) {
    foreach ($field in @("path","sha256")) {
      if (-not ($hashRecord.PSObject.Properties.Name -contains $field) -or -not ([string]$hashRecord.$field).Trim()) {
        throw "Export manifest contract failed: source_hashes entry missing '$field'."
      }
    }
    if ([string]$hashRecord.sha256 -notmatch "^[a-f0-9]{64}$") {
      throw "Export manifest contract failed: invalid sha256 for source '$($hashRecord.path)'."
    }
  }
  if (-not ($manifest.delivery_profiles.PSObject.Properties.Name -contains "publisher_submission") -or -not ($manifest.delivery_profiles.PSObject.Properties.Name -contains "print_preview")) {
    throw "Export manifest contract failed: delivery_profiles must declare publisher_submission and print_preview."
  }
  foreach ($field in @("width_mm","height_mm","margin_top_mm","margin_bottom_mm","margin_inside_mm","margin_outside_mm")) {
    if (-not ($manifest.page_layout.PSObject.Properties.Name -contains $field)) {
      throw "Export manifest contract failed: page_layout missing '$field'."
    }
  }
  foreach ($field in @("font_family","font_size_pt","line_spacing","paragraph_first_line_indent_cm","justification")) {
    if (-not ($manifest.typography.PSObject.Properties.Name -contains $field)) {
      throw "Export manifest contract failed: typography missing '$field'."
    }
  }
}

function Validate-DocxLayoutProfile {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled -or $Phase -ne "export") {
    return
  }

  $manifestPath = Resolve-ExportManifestPath -Root $Root
  $scriptPath = Join-Path $Root "scripts/ci/verify_docx_layout_profile.ps1"
  Ensure-File $scriptPath
  & powershell -ExecutionPolicy Bypass -File $scriptPath -ProjectRoot $Root -ManifestPath (Get-RelativePathSafe -BasePath $Root -TargetPath $manifestPath)
  if ($LASTEXITCODE -ne 0) {
    throw "DOCX layout profile gate failed with exit code $LASTEXITCODE."
  }
}

function Validate-LongformState {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("design-big","design-small","create","polish","rewrite","export")) {
    return
  }

  $stateDir = Join-Path $Root "revision/_state"
  $required = @(
    "book-plan.json",
    "chapter-plan.json",
    "layout-plan.json",
    "longform-plan.json",
    "character-state.json",
    "plot-ledger.json",
    "chapter-summaries.json",
    "continuity-ledger.json",
    "world-state.json",
    "relationship-graph.json",
    "knowledge-graph.json",
    "promise-payoff-ledger.json",
    "timeline.json",
    "theme-ledger.json",
    "volume-plan.json",
    "style-profile.json",
    "writing-type-profile.json",
    "genre-structure-template.json",
    "editorial-quality-scorecard.json",
    "llm-adapter-contract.json",
    "claim-ledger.json",
    "source-ledger.json",
    "term-glossary.json",
    "argument-ledger.json"
  )
  foreach ($name in $required) {
    Ensure-File (Join-Path $stateDir $name)
  }

  $planningFiles = @(
    "book-plan.json",
    "chapter-plan.json",
    "layout-plan.json",
    "character-state.json",
    "plot-ledger.json",
    "style-profile.json",
    "writing-type-profile.json",
    "genre-structure-template.json",
    "editorial-quality-scorecard.json",
    "llm-adapter-contract.json"
  )
  $planningPlaceholderPattern = "(?i)(plan_required|to_be_confirmed|placeholder|todo|tbd|fill\s*in|lorem ipsum|konu bekleniyor|buraya.*konu)"
  foreach ($planningFile in $planningFiles) {
    $planningPath = Join-Path $stateDir $planningFile
    $planningRaw = Read-Utf8 -Path $planningPath
    if ($planningRaw -match $planningPlaceholderPattern) {
      throw "Planning state contains unresolved placeholder text: revision/_state/$planningFile"
    }
  }

  $plan = Read-Utf8 -Path (Join-Path $stateDir "longform-plan.json") | ConvertFrom-Json
  foreach ($field in @("target_pages","target_words","target_chapters","chapters","required_state_files","scale_tier","structure_model","max_chapters_per_batch","audit_interval_chapters","continuity_model")) {
    if (-not ($plan.PSObject.Properties.Name -contains $field)) {
      throw "Longform plan missing '$field'."
    }
  }
  if ([int]$plan.target_pages -lt 1) {
    throw "Longform plan target_pages must be positive after a topic is provided; found $($plan.target_pages)."
  }
  if ([int]$plan.target_chapters -lt 1) {
    throw "Longform plan target_chapters must be positive after a topic is provided; found $($plan.target_chapters)."
  }
  if (-not ($plan.PSObject.Properties.Name -contains "required_state_files") -or @($plan.required_state_files).Count -lt 3) {
    throw "Longform plan must declare required_state_files for continuity and planning gates."
  }
  foreach ($requiredStateRel in @("revision/_state/world-state.json","revision/_state/relationship-graph.json","revision/_state/knowledge-graph.json","revision/_state/promise-payoff-ledger.json","revision/_state/timeline.json","revision/_state/theme-ledger.json","revision/_state/volume-plan.json","revision/_state/claim-ledger.json","revision/_state/source-ledger.json","revision/_state/term-glossary.json","revision/_state/argument-ledger.json")) {
    if (@($plan.required_state_files) -notcontains $requiredStateRel) {
      throw "Longform plan required_state_files missing '$requiredStateRel'."
    }
  }
  if ([int]$plan.max_chapters_per_batch -lt 1 -or [int]$plan.max_chapters_per_batch -gt 3) {
    throw "Longform plan max_chapters_per_batch must be between 1 and 3."
  }
  if ([int]$plan.audit_interval_chapters -lt 1) {
    throw "Longform plan audit_interval_chapters must be positive."
  }
  foreach ($field in @("memory_strategy","chapter_state_update_contract","reader_progression_policy")) {
    if (-not ($plan.PSObject.Properties.Name -contains $field)) {
      throw "Longform plan missing '$field' for long-book continuity memory."
    }
  }
  foreach ($stateUpdateName in @("chapter-summaries","character-state","plot-ledger","continuity-ledger","world-state","relationship-graph","knowledge-graph","promise-payoff-ledger","timeline","theme-ledger")) {
    if (@($plan.chapter_state_update_contract) -notcontains $stateUpdateName) {
      throw "Longform plan chapter_state_update_contract missing '$stateUpdateName'."
    }
  }

  $bookPlan = Read-Utf8 -Path (Join-Path $stateDir "book-plan.json") | ConvertFrom-Json
  if ($Phase -in @("design-big","design-small")) {
    $targetPages = [int]$plan.target_pages
    $characterCount = @($bookPlan.characters).Count
    $writingType = ""
    $genre = ""
    if ($bookPlan.PSObject.Properties.Name -contains "writing_type") { $writingType = [string]$bookPlan.writing_type }
    if ($bookPlan.PSObject.Properties.Name -contains "genre") { $genre = [string]$bookPlan.genre }
    $complexForm = ($writingType -match "(?i)novel|roman|novella|historical|tarihsel|agent|ajan" -or $genre -match "(?i)novel|roman|novella|historical|tarihsel|agent|ajan")
    if ($targetPages -le 20 -and $characterCount -ge 5 -and $complexForm) {
      $lengthApprovalPath = Join-Path $Root "runtime/approvals/length-depth-approval.json"
      Ensure-File $lengthApprovalPath
      $lengthApproval = Read-Utf8 -Path $lengthApprovalPath | ConvertFrom-Json
      if ($lengthApproval.approved -ne $true -or $lengthApproval.risk_acknowledged -ne $true) {
        throw "Length-depth gate blocked: $targetPages pages with $characterCount characters and '$writingType/$genre' can limit character depth, pacing, and genre complexity. Ask the user to increase length or approve runtime/approvals/length-depth-approval.json with risk_acknowledged=true."
      }
    }
  }
  foreach ($field in @("schema_version","run_id","plan_id","source_prompt","approved_story_option","title_working","writing_type","genre","theme","premise","scale_tier","target_pages","target_words","narrative_pov","tense","characters","plot_arc","chapter_count","max_chapters_per_batch","audit_interval_chapters","approval_required")) {
    if (-not ($bookPlan.PSObject.Properties.Name -contains $field)) {
      throw "book-plan.json missing '$field'."
    }
  }
  if ($bookPlan.approval_required -ne $true) {
    throw "book-plan.json must set approval_required=true before writing can start."
  }
  if ([int]$bookPlan.chapter_count -ne [int]$plan.target_chapters) {
    throw "book-plan.json chapter_count must match longform-plan target_chapters."
  }
  if ([int]$bookPlan.target_pages -ne [int]$plan.target_pages -or [int]$bookPlan.target_words -ne [int]$plan.target_words) {
    throw "book-plan.json page/word targets must match longform-plan."
  }
  $planWritingType = [string]$bookPlan.writing_type
  $fictionWritingTypes = @("novel","story","novella","children_book","young_adult")
  $nonfictionWritingTypes = @("essay","memoir","biography","research_book","self_help","business_book","academic")
  if (($fictionWritingTypes -contains $planWritingType) -and @($bookPlan.characters).Count -lt 1) {
    throw "book-plan.json must include at least one planned character before writing starts."
  }
  foreach ($characterPlan in @($bookPlan.characters)) {
    foreach ($field in @("role","name","desire","fear","arc")) {
      if (-not ($characterPlan.PSObject.Properties.Name -contains $field) -or -not ([string]$characterPlan.$field).Trim()) {
        throw "book-plan.json character entry missing concrete '$field'."
      }
    }
  }
  if ($nonfictionWritingTypes -contains $planWritingType) {
    $argumentArc = if ($bookPlan.PSObject.Properties.Name -contains "argument_arc") { $bookPlan.argument_arc } else { $bookPlan.plot_arc }
    foreach ($arcField in @("opening_promise","inciting_incident","midpoint_turn","climax","resolution")) {
      if (-not ($argumentArc.PSObject.Properties.Name -contains $arcField) -or -not ([string]$argumentArc.$arcField).Trim()) {
        throw "book-plan.json argument_arc/plot_arc missing concrete '$arcField'."
      }
    }
  }
  else {
    foreach ($arcField in @("opening_promise","inciting_incident","midpoint_turn","climax","resolution")) {
      if (-not ($bookPlan.plot_arc.PSObject.Properties.Name -contains $arcField) -or -not ([string]$bookPlan.plot_arc.$arcField).Trim()) {
        throw "book-plan.json plot_arc missing concrete '$arcField'."
      }
    }
  }

  $chapterPlan = Read-Utf8 -Path (Join-Path $stateDir "chapter-plan.json") | ConvertFrom-Json
  foreach ($field in @("schema_version","run_id","chapters")) {
    if (-not ($chapterPlan.PSObject.Properties.Name -contains $field)) {
      throw "chapter-plan.json missing '$field'."
    }
  }
  $chapterEntries = @($chapterPlan.chapters)
  if ($chapterEntries.Count -ne [int]$plan.target_chapters) {
    throw "chapter-plan.json chapter count ($($chapterEntries.Count)) must match target_chapters ($($plan.target_chapters))."
  }
  foreach ($chapter in $chapterEntries) {
    foreach ($field in @("id","reader_title","purpose","events","character_focus","continuity_promises","target_words")) {
      if (-not ($chapter.PSObject.Properties.Name -contains $field)) {
        throw "chapter-plan.json chapter entry missing '$field'."
      }
    }
    if ([string]$chapter.reader_title -match "(?i)\b(ep|episode|scene|sahne)\s*[-_#]?\d+") {
      throw "chapter-plan.json uses technical reader_title '$($chapter.reader_title)'. Use reader-facing chapter titles only."
    }
    if (@($chapter.events).Count -lt 1) {
      throw "chapter-plan.json chapter $($chapter.id) must include planned events."
    }
    if ([int]$chapter.target_words -lt 300) {
      throw "chapter-plan.json chapter $($chapter.id) target_words is too low for a book chapter."
    }
  }

  $layoutPlan = Read-Utf8 -Path (Join-Path $stateDir "layout-plan.json") | ConvertFrom-Json
  foreach ($field in @("schema_version","run_id","delivery_profiles","trim_size","width_mm","height_mm","margin_top_mm","margin_bottom_mm","margin_inside_mm","margin_outside_mm","font_family","font_size_pt","line_spacing","paragraph_first_line_indent_cm","words_per_page_estimate","target_pages","target_words","target_chapters","scale_tier","max_chapters_per_batch","audit_interval_chapters","front_matter_pages_estimate","back_matter_pages_estimate","chapter_start_policy")) {
    if (-not ($layoutPlan.PSObject.Properties.Name -contains $field)) {
      throw "layout-plan.json missing '$field'."
    }
  }
  foreach ($profileField in @("publisher_submission","print_preview")) {
    if (-not ($layoutPlan.delivery_profiles.PSObject.Properties.Name -contains $profileField)) {
      throw "layout-plan.json delivery_profiles missing '$profileField'."
    }
  }
  if ([double]$layoutPlan.width_mm -lt 100 -or [double]$layoutPlan.height_mm -lt 140) {
    throw "layout-plan.json page size is too small for a professional book layout."
  }
  foreach ($marginField in @("margin_top_mm","margin_bottom_mm","margin_inside_mm","margin_outside_mm")) {
    if ([double]$layoutPlan.$marginField -lt 10 -or [double]$layoutPlan.$marginField -gt 40) {
      throw "layout-plan.json $marginField must be between 10 and 40 mm."
    }
  }
  if ([int]$layoutPlan.target_pages -ne [int]$plan.target_pages -or [int]$layoutPlan.target_words -ne [int]$plan.target_words -or [int]$layoutPlan.target_chapters -ne [int]$plan.target_chapters) {
    throw "layout-plan.json targets must match longform-plan targets."
  }
  if ([int]$layoutPlan.words_per_page_estimate -lt 250 -or [int]$layoutPlan.words_per_page_estimate -gt 550) {
    throw "layout-plan.json words_per_page_estimate must be a realistic print estimate."
  }
  $estimatedWordsFromPages = [double]$layoutPlan.target_pages * [double]$layoutPlan.words_per_page_estimate
  $delta = [Math]::Abs($estimatedWordsFromPages - [double]$layoutPlan.target_words)
  $allowed = [Math]::Max(1000.0, [double]$layoutPlan.target_words * 0.18)
  if ($delta -gt $allowed) {
    throw "layout-plan.json page/word targets are inconsistent; adjust target_pages, target_words, or words_per_page_estimate."
  }
  foreach ($field in @("front_matter","back_matter","page_numbering","chapter_title_policy","publisher_submission_label")) {
    if (-not ($layoutPlan.PSObject.Properties.Name -contains $field)) {
      throw "layout-plan.json missing publication layout field '$field'."
    }
  }
  if ([string]$layoutPlan.chapter_title_policy -notmatch "(?i)reader|okur|no_ep|technical|scene|sahne") {
    throw "layout-plan.json chapter_title_policy must explicitly forbid technical reader-facing labels."
  }

  if ($Phase -in @("design-small","create","polish","rewrite","export")) {
    $approvalRel = "runtime/approvals/book-plan-approval.json"
    $approvalPath = Join-Path $Root $approvalRel
    Ensure-File $approvalPath
    $approval = Read-Utf8 -Path $approvalPath | ConvertFrom-Json
    if (-not ($approval.PSObject.Properties.Name -contains "approved") -or $approval.approved -ne $true) {
      throw "Book plan approval gate failed: $approvalRel must be approved before $Phase."
    }
    if (($approval.PSObject.Properties.Name -contains "approved_plan_id") -and $approval.approved_plan_id -and $approval.approved_plan_id -ne $bookPlan.plan_id) {
      throw "Book plan approval gate failed: approved_plan_id does not match book-plan.json plan_id."
    }
  }

  $character = Read-Utf8 -Path (Join-Path $stateDir "character-state.json") | ConvertFrom-Json
  if (-not ($character.PSObject.Properties.Name -contains "characters")) {
    throw "character-state.json missing characters."
  }

  $plot = Read-Utf8 -Path (Join-Path $stateDir "plot-ledger.json") | ConvertFrom-Json
  foreach ($field in @("main_question","open_threads","final_promises")) {
    if (-not ($plot.PSObject.Properties.Name -contains $field)) {
      throw "plot-ledger.json missing '$field'."
    }
  }

  $style = Read-Utf8 -Path (Join-Path $stateDir "style-profile.json") | ConvertFrom-Json
  foreach ($field in @("profile","narration","dialogue_policy","print_format")) {
    if (-not ($style.PSObject.Properties.Name -contains $field)) {
      throw "style-profile.json missing '$field'."
    }
  }

  $worldState = Read-Utf8 -Path (Join-Path $stateDir "world-state.json") | ConvertFrom-Json
  foreach ($field in @("locations","time_rules","objects","world_constraints")) {
    if (-not ($worldState.PSObject.Properties.Name -contains $field)) {
      throw "world-state.json missing '$field'."
    }
  }
  $relationshipGraph = Read-Utf8 -Path (Join-Path $stateDir "relationship-graph.json") | ConvertFrom-Json
  foreach ($field in @("nodes","edges","change_log","rule")) {
    if (-not ($relationshipGraph.PSObject.Properties.Name -contains $field)) {
      throw "relationship-graph.json missing '$field'."
    }
  }
  $knowledgeGraph = Read-Utf8 -Path (Join-Path $stateDir "knowledge-graph.json") | ConvertFrom-Json
  foreach ($field in @("character_knowledge","secrets","rule")) {
    if (-not ($knowledgeGraph.PSObject.Properties.Name -contains $field)) {
      throw "knowledge-graph.json missing '$field'."
    }
  }
  $promiseLedger = Read-Utf8 -Path (Join-Path $stateDir "promise-payoff-ledger.json") | ConvertFrom-Json
  foreach ($field in @("open_promises","paid_promises","abandoned_promises","rule")) {
    if (-not ($promiseLedger.PSObject.Properties.Name -contains $field)) {
      throw "promise-payoff-ledger.json missing '$field'."
    }
  }
  $timeline = Read-Utf8 -Path (Join-Path $stateDir "timeline.json") | ConvertFrom-Json
  foreach ($field in @("chronology","chapter_time_map","rule")) {
    if (-not ($timeline.PSObject.Properties.Name -contains $field)) {
      throw "timeline.json missing '$field'."
    }
  }
  $themeLedger = Read-Utf8 -Path (Join-Path $stateDir "theme-ledger.json") | ConvertFrom-Json
  foreach ($field in @("primary_theme","motifs","theme_progression","rule")) {
    if (-not ($themeLedger.PSObject.Properties.Name -contains $field)) {
      throw "theme-ledger.json missing '$field'."
    }
  }
  $volumePlan = Read-Utf8 -Path (Join-Path $stateDir "volume-plan.json") | ConvertFrom-Json
  foreach ($field in @("scale_tier","target_pages","target_words","target_chapters","words_per_page_estimate","words_per_chapter","max_chapters_per_batch","audit_interval_chapters","acts","audit_schedule","rule")) {
    if (-not ($volumePlan.PSObject.Properties.Name -contains $field)) {
      throw "volume-plan.json missing '$field'."
    }
  }
  if ([int]$volumePlan.target_pages -ne [int]$plan.target_pages -or [int]$volumePlan.target_chapters -ne [int]$plan.target_chapters) {
    throw "volume-plan.json targets must match longform-plan."
  }

  $writingProfile = Read-Utf8 -Path (Join-Path $stateDir "writing-type-profile.json") | ConvertFrom-Json
  foreach ($field in @("writing_type","target_reader","structure_model","voice_model","evidence_policy","continuity_policy","completion_criteria")) {
    if (-not ($writingProfile.PSObject.Properties.Name -contains $field)) {
      throw "writing-type-profile.json missing '$field'."
    }
  }
  $supportedWritingTypes = @("novel","story","novella","children_book","young_adult","essay","memoir","biography","research_book","self_help","business_book","academic")
  $activeWritingType = [string]$writingProfile.writing_type
  if ($supportedWritingTypes -notcontains $activeWritingType) {
    throw "writing-type-profile.json writing_type '$activeWritingType' is not supported or is not canonical."
  }
  if ([string]$bookPlan.writing_type -ne $activeWritingType) {
    throw "book-plan.json writing_type must match writing-type-profile.json writing_type."
  }
  if ([string]$writingProfile.target_reader -match "(?i)user_defined|to_be_confirmed|placeholder|tbd") {
    throw "writing-type-profile.json target_reader must be concrete before writing starts."
  }

  $structureTemplate = Read-Utf8 -Path (Join-Path $stateDir "genre-structure-template.json") | ConvertFrom-Json
  foreach ($field in @("template_id","acts","chapter_rules","mandatory_ledgers")) {
    if (-not ($structureTemplate.PSObject.Properties.Name -contains $field)) {
      throw "genre-structure-template.json missing '$field'."
    }
  }
  $fictionTypes = @("novel","story","novella","children_book","young_adult")
  $nonfictionTypes = @("essay","memoir","biography","research_book","self_help","business_book","academic")
  $requiredTypeLedgers = @("chapter-summaries.json","continuity-ledger.json")
  if ($fictionTypes -contains $activeWritingType) {
    $requiredTypeLedgers += @("character-state.json","plot-ledger.json","world-state.json","relationship-graph.json","knowledge-graph.json","promise-payoff-ledger.json","timeline.json","theme-ledger.json")
  }
  if ($nonfictionTypes -contains $activeWritingType) {
    $requiredTypeLedgers += @("claim-ledger.json","source-ledger.json","term-glossary.json","argument-ledger.json")
  }
  foreach ($ledgerName in $requiredTypeLedgers) {
    if (@($structureTemplate.mandatory_ledgers) -notcontains $ledgerName) {
      throw "genre-structure-template.json mandatory_ledgers missing type-required '$ledgerName'."
    }
  }

  $scorecard = Read-Utf8 -Path (Join-Path $stateDir "editorial-quality-scorecard.json") | ConvertFrom-Json
  foreach ($field in @("threshold_pass","axes","export_blockers")) {
    if (-not ($scorecard.PSObject.Properties.Name -contains $field)) {
      throw "editorial-quality-scorecard.json missing '$field'."
    }
  }
  foreach ($axis in @("type-fit","publication-readiness")) {
    if (@($scorecard.axes) -notcontains $axis) {
      throw "editorial-quality-scorecard.json axes missing '$axis'."
    }
  }
  if ($nonfictionTypes -contains $activeWritingType -and @($scorecard.axes) -notcontains "character_or_argument_depth") {
    throw "editorial-quality-scorecard.json axes missing nonfiction argument-depth axis."
  }

  $adapterContract = Read-Utf8 -Path (Join-Path $stateDir "llm-adapter-contract.json") | ConvertFrom-Json
  foreach ($field in @("adapter_contract","max_chapters_per_batch","required_input_state","required_output_state")) {
    if (-not ($adapterContract.PSObject.Properties.Name -contains $field)) {
      throw "llm-adapter-contract.json missing '$field'."
    }
  }
  foreach ($requiredOutputRel in @("revision/_state/chapter-summaries.json","revision/_state/character-state.json","revision/_state/plot-ledger.json","revision/_state/continuity-ledger.json","revision/_state/claim-ledger.json","revision/_state/source-ledger.json","revision/_state/term-glossary.json","revision/_state/argument-ledger.json")) {
    if (@($adapterContract.required_output_state) -notcontains $requiredOutputRel) {
      throw "llm-adapter-contract.json required_output_state missing '$requiredOutputRel'."
    }
  }

  if ($Phase -in @("create","polish","rewrite","export")) {
    $summaries = Read-Utf8 -Path (Join-Path $stateDir "chapter-summaries.json") | ConvertFrom-Json
    if (-not ($summaries.PSObject.Properties.Name -contains "chapters") -or @($summaries.chapters).Count -lt 1) {
      throw "chapter-summaries.json must include at least one generated chapter summary after create."
    }
  }
}

function Validate-StateReducers {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("design-big","design-small","create","polish","rewrite","export")) {
    return
  }
  $scriptPath = Join-Path $Root "scripts/ci/validate_state_reducers.ps1"
  Ensure-File $scriptPath
  & powershell -ExecutionPolicy Bypass -File $scriptPath -ProjectRoot $Root -Phase $Phase
  if ($LASTEXITCODE -ne 0) {
    throw "State reducer validation failed (exit=$LASTEXITCODE)."
  }
}

function Assert-NoForbiddenPatterns {
  param(
    [string]$Root,
    [string]$Phase,
    [string[]]$Patterns,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("create","polish","rewrite")) {
    return
  }

  $episodeDir = Join-Path $Root "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    return
  }

  $episodes = @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name)
  foreach ($ep in $episodes) {
    $raw = Read-Utf8 -Path $ep.FullName
    foreach ($p in $Patterns) {
      if ($raw -match $p) {
        throw "Negative enforcement BLOCKED in $($ep.Name): pattern '$p'"
      }
    }
  }
}

function Get-NovelConfigNumericValue {
  param(
    [string]$ConfigRaw,
    [string]$Key,
    [double]$Default
  )

  $m = [regex]::Match($ConfigRaw, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*$")
  if ($m.Success) {
    return [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
  }
  return $Default
}

function Get-NovelConfigStringValue {
  param(
    [string]$ConfigRaw,
    [string]$Key,
    [string]$Default
  )

  $m = [regex]::Match($ConfigRaw, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*""?([^""#\r\n]+)""?\s*$")
  if ($m.Success) {
    return $m.Groups[1].Value.Trim()
  }
  return $Default
}

function Get-TokenSet {
  param([string]$Text)
  $tokens = [regex]::Matches($Text.ToLowerInvariant(), "[a-z0-9ğüşöçı]+") | ForEach-Object { $_.Value } | Where-Object { $_.Length -gt 3 }
  return @($tokens | Sort-Object -Unique)
}

function Get-JaccardSimilarity {
  param([string]$A, [string]$B)
  $setA = @(Get-TokenSet -Text $A)
  $setB = @(Get-TokenSet -Text $B)
  if ($setA.Count -eq 0 -or $setB.Count -eq 0) {
    return 0.0
  }
  $hashA = @{}
  foreach ($t in $setA) { $hashA[$t] = $true }
  $intersection = 0
  foreach ($t in $setB) {
    if ($hashA.ContainsKey($t)) { $intersection++ }
  }
  $union = ($setA + $setB | Sort-Object -Unique).Count
  return ($intersection / [double]$union)
}

function Validate-CrossChapterProgression {
  param(
    [string]$Root,
    [string]$Phase,
    [object]$Config,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("create","polish","rewrite")) {
    return
  }

  $episodeDir = Join-Path $Root "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    return
  }
  $episodes = @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($episodes.Count -lt 2) {
    return
  }

  $maxChapterSimilarity = 0.72
  $maxOpeningPrefixRepeat = 1
  $minEventMarkersPerChapter = 4
  if ($Config -and $Config.quality_flags -and ($Config.quality_flags.PSObject.Properties.Name -contains "cross_chapter_gates")) {
    $q = $Config.quality_flags.cross_chapter_gates
    if ($q.PSObject.Properties.Name -contains "max_chapter_similarity") { $maxChapterSimilarity = [double]$q.max_chapter_similarity }
    if ($q.PSObject.Properties.Name -contains "max_opening_prefix_repeat") { $maxOpeningPrefixRepeat = [int]$q.max_opening_prefix_repeat }
    if ($q.PSObject.Properties.Name -contains "min_event_markers_per_chapter") { $minEventMarkersPerChapter = [int]$q.min_event_markers_per_chapter }
  }

  $texts = @{}
  foreach ($ep in $episodes) {
    $texts[$ep.Name] = Read-Utf8 -Path $ep.FullName
  }

  for ($i = 0; $i -lt $episodes.Count; $i++) {
    for ($j = $i + 1; $j -lt $episodes.Count; $j++) {
      $a = $episodes[$i].Name
      $b = $episodes[$j].Name
      $sim = Get-JaccardSimilarity -A $texts[$a] -B $texts[$b]
      if ($sim -gt $maxChapterSimilarity) {
        throw "Cross-chapter progression gate failed: $a and $b are too similar (similarity=$([math]::Round($sim,3)), max=$maxChapterSimilarity)."
      }
    }
  }

  $prefixCounts = @{}
  foreach ($ep in $episodes) {
    $lines = @($texts[$ep.Name] -split "\r?\n" | Where-Object { $_.Trim() -ne "" })
    if ($lines.Count -lt 2) { continue }
    $firstBody = $lines | Where-Object { $_ -notmatch "^\s*BÖLÜM\s+\d+\b" } | Select-Object -First 1
    if (-not $firstBody) { continue }
    $m = [regex]::Match($firstBody.Trim(), "^(.{0,90})")
    $prefix = $m.Groups[1].Value
    if (-not $prefixCounts.ContainsKey($prefix)) { $prefixCounts[$prefix] = 0 }
    $prefixCounts[$prefix]++
  }
  foreach ($key in $prefixCounts.Keys) {
    if ($prefixCounts[$key] -gt $maxOpeningPrefixRepeat) {
      throw "Cross-chapter progression gate failed: repeated chapter opening pattern detected ($($prefixCounts[$key]) times): $key"
    }
  }

  $eventMarkers = @(
    "öğren", "ogrend", "sordu", "söyledi", "soyledi", "verdi", "aldı", "aldi",
    "açıklad", "aciklad", "itiraf", "karar", "durdur", "değiş", "degis",
    "gitti", "geldi", "çıktı", "cikti", "başladı", "basladi", "kapandı", "kapandi"
  )
  foreach ($ep in $episodes) {
    $markerHits = 0
    foreach ($marker in $eventMarkers) {
      if ([regex]::IsMatch($texts[$ep.Name], [regex]::Escape($marker), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $markerHits++
      }
    }
    if ($markerHits -lt $minEventMarkersPerChapter) {
      throw "Cross-chapter progression gate failed in $($ep.Name): narrative event marker coverage=$markerHits below minimum=$minEventMarkersPerChapter."
    }
  }

  $summaryPath = Join-Path $Root "revision/_state/chapter-summaries.json"
  if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
    $summary = Read-Utf8 -Path $summaryPath | ConvertFrom-Json
    $chapters = @($summary.chapters)
    if ($chapters.Count -ge 2) {
      foreach ($chapter in $chapters) {
        foreach ($field in @("id","summary","previous_chapter_result","new_event","new_information","irreversible_change","next_causal_link","state_updates")) {
          if (-not ($chapter.PSObject.Properties.Name -contains $field)) {
            throw "Cross-chapter progression gate failed: chapter-summaries.json entry missing '$field'."
          }
        }
        foreach ($field in @("previous_chapter_result","new_event","irreversible_change","next_causal_link")) {
          if (-not ([string]$chapter.$field).Trim()) {
            throw "Cross-chapter progression gate failed: $($chapter.id) has empty '$field'."
          }
        }
        $stateUpdates = @($chapter.state_updates)
        if ($stateUpdates.Count -lt 1) {
          throw "Cross-chapter progression gate failed: $($chapter.id) must declare state_updates."
        }
      }
      $uniqueSummaries = @($chapters | ForEach-Object { [string]$_.summary } | Sort-Object -Unique)
      if ($uniqueSummaries.Count -lt $chapters.Count) {
        throw "Cross-chapter progression gate failed: chapter summaries are duplicated."
      }
      $uniqueEvents = @($chapters | ForEach-Object { [string]$_.new_event } | Where-Object { $_.Trim() -ne "" } | Sort-Object -Unique)
      if ($uniqueEvents.Count -lt $chapters.Count) {
        throw "Cross-chapter progression gate failed: every chapter must record a unique new_event."
      }
      $uniqueChanges = @($chapters | ForEach-Object { [string]$_.irreversible_change } | Where-Object { $_.Trim() -ne "" } | Sort-Object -Unique)
      if ($uniqueChanges.Count -lt $chapters.Count) {
        throw "Cross-chapter progression gate failed: every chapter must record a unique irreversible_change."
      }
      foreach ($chapter in $chapters) {
        $newInfo = @($chapter.new_information)
        if ($newInfo.Count -lt 1) {
          throw "Cross-chapter progression gate failed: $($chapter.id) missing new_information in chapter-summaries.json."
        }
      }
      for ($idx = 1; $idx -lt $chapters.Count; $idx++) {
        $prev = $chapters[$idx - 1]
        $current = $chapters[$idx]
        $expected = [string]$prev.next_causal_link
        $actual = [string]$current.previous_chapter_result
        $linkSimilarity = Get-JaccardSimilarity -A $expected -B $actual
        if ($linkSimilarity -lt 0.12) {
          throw "Cross-chapter progression gate failed: $($current.id) previous_chapter_result does not connect to previous next_causal_link."
        }
      }
    }
  }

  $plotPath = Join-Path $Root "revision/_state/plot-ledger.json"
  if (Test-Path -LiteralPath $plotPath -PathType Leaf) {
    $plot = Read-Utf8 -Path $plotPath | ConvertFrom-Json
    $chain = @($plot.cause_effect_chain)
    if ($chain.Count -lt $episodes.Count) {
      throw "Cross-chapter progression gate failed: plot-ledger cause_effect_chain has $($chain.Count) entries for $($episodes.Count) chapters."
    }
    $uniqueEffects = @($chain | ForEach-Object { [string]$_.effect } | Where-Object { $_.Trim() -ne "" } | Sort-Object -Unique)
    if ($uniqueEffects.Count -lt $chain.Count) {
      throw "Cross-chapter progression gate failed: plot-ledger cause_effect_chain effects are duplicated."
    }
  }
}

function Validate-EpisodeTextQuality {
  param(
    [string]$Root,
    [string]$Phase,
    [object]$Config,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("create","polish","rewrite")) {
    return
  }

  $episodeDir = Join-Path $Root "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    throw "Text quality gate failed: episode directory missing."
  }
  $episodes = Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File -ErrorAction SilentlyContinue
  if (-not $episodes -or $episodes.Count -lt 1) {
    throw "Text quality gate failed: no episode files found."
  }

  $cfgPath = Join-Path $Root "novel-config.md"
  Ensure-File $cfgPath
  $cfgRaw = Read-Utf8 -Path $cfgPath

  $minCharacters = [int](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "min_characters" -Default 6500)
  $maxCharacters = [int](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "max_characters" -Default 14000)
  $dialogueRatioMin = [double](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "dialogue_ratio_min" -Default 0.35)
  $dialogueRatioMax = [double](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "dialogue_ratio_max" -Default 0.65)
  $targetGenre = Get-NovelConfigStringValue -ConfigRaw $cfgRaw -Key "target_genre" -Default ""
  $isPsychological = $targetGenre -match "(?i)psych|psikolojik|gerilim"

  $maxDuplicateLineRatio = 0.28
  $maxRepeatedParagraphPrefix = 1
  $paragraphPrefixLength = 95
  $tellSensoryRatioMax = 2.40
  $requireDashDialogue = $true
  $forbidMixedDialogue = $true
  $minPsychologicalMarkers = 6
  $bridgeParagraphMinCharacters = 160

  if ($Config -and $Config.quality_flags -and ($Config.quality_flags.PSObject.Properties.Name -contains "text_quality_gates")) {
    $q = $Config.quality_flags.text_quality_gates
    if ($q.PSObject.Properties.Name -contains "max_duplicate_line_ratio") { $maxDuplicateLineRatio = [double]$q.max_duplicate_line_ratio }
    if ($q.PSObject.Properties.Name -contains "max_repeated_paragraph_prefix") { $maxRepeatedParagraphPrefix = [int]$q.max_repeated_paragraph_prefix }
    if ($q.PSObject.Properties.Name -contains "paragraph_prefix_length") { $paragraphPrefixLength = [int]$q.paragraph_prefix_length }
    if ($q.PSObject.Properties.Name -contains "tell_sensory_ratio_max") { $tellSensoryRatioMax = [double]$q.tell_sensory_ratio_max }
    if ($q.PSObject.Properties.Name -contains "require_dash_dialogue") { $requireDashDialogue = [bool]$q.require_dash_dialogue }
    if ($q.PSObject.Properties.Name -contains "forbid_mixed_dialogue_styles") { $forbidMixedDialogue = [bool]$q.forbid_mixed_dialogue_styles }
    if ($q.PSObject.Properties.Name -contains "min_psychological_markers") { $minPsychologicalMarkers = [int]$q.min_psychological_markers }
    if ($q.PSObject.Properties.Name -contains "bridge_paragraph_min_characters") { $bridgeParagraphMinCharacters = [int]$q.bridge_paragraph_min_characters }
  }

  $bookPlanPath = Join-Path $Root "revision/_state/book-plan.json"
  Ensure-File $bookPlanPath
  $bookPlan = Read-Utf8 -Path $bookPlanPath | ConvertFrom-Json
  $plannedCharacterAliases = @()
  if ($bookPlan.PSObject.Properties.Name -contains "characters") {
    foreach ($character in @($bookPlan.characters)) {
      $name = ""
      if ($character.PSObject.Properties.Name -contains "name") { $name = [string]$character.name }
      $parts = @($name -split "\s+" | Where-Object { $_ -and $_.Trim() })
      foreach ($part in $parts) {
        $clean = $part.Trim()
        if ($clean -and $clean -notin @("Doktor","Dr","Madam","Bay","Bayan","Hanım","Hanim","Bey")) {
          $plannedCharacterAliases += $clean
          break
        }
      }
    }
  }
  $plannedCharacterAliases = @($plannedCharacterAliases | Select-Object -Unique)
  $allEpisodeText = (($episodes | ForEach-Object { Read-Utf8 -Path $_.FullName }) -join "`n")
  foreach ($alias in $plannedCharacterAliases) {
    if ($allEpisodeText -notmatch "(?<!\p{L})$([regex]::Escape($alias))(?!\p{L})") {
      throw "Text quality gate failed: planned character '$alias' is not present in manuscript text."
    }
  }

  $episodeIndex = 0
  foreach ($ep in $episodes) {
    $episodeIndex++
    $rawText = Read-Utf8 -Path $ep.FullName

    if ($rawText -match "[ÃÅÄ]") {
      throw "Text quality gate failed in $($ep.Name): mojibake/encoding corruption detected."
    }
    if ($rawText -match "(?m)^\s*(EP\d{3}|Sahne\s+\d+\.|Ara\s+kırılma\s+\d+\.|Ara\s+kirilma\s+\d+\.|Scene\s+\d+\.|Beat\s+\d+\.|TODO|FIXME)\b") {
      throw "Text quality gate failed in $($ep.Name): reader-facing technical labels detected."
    }
    if ($rawText -match "\b(ep\d{3}\.md|EP\d{3}-EP\d{3})\b") {
      throw "Text quality gate failed in $($ep.Name): internal episode/file label leaked into reader-facing text."
    }
    if ($episodeIndex -gt 1) {
      $paragraphs = @($rawText -split "\r?\n\s*\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch "^#\s+" })
      if ($paragraphs.Count -lt 1 -or $paragraphs[0].Length -lt $bridgeParagraphMinCharacters) {
        throw "Text quality gate failed in $($ep.Name): chapter bridge paragraph is too thin or missing."
      }
    }

    $charCount = $rawText.Length
    if ($charCount -lt $minCharacters) {
      throw "Text quality gate failed in $($ep.Name): character_count=$charCount below min_characters=$minCharacters."
    }
    if ($charCount -gt $maxCharacters) {
      throw "Text quality gate failed in $($ep.Name): character_count=$charCount above max_characters=$maxCharacters."
    }

    $lines = @($rawText -split "(\r?\n)+" | Where-Object { $_ -and $_.Trim() -ne "" })
    if ($lines.Count -gt 0) {
      $normalized = @($lines | ForEach-Object { $_.Trim().ToLowerInvariant() })
      $uniqueCount = @($normalized | Sort-Object -Unique).Count
      $duplicateRatio = 1.0 - ($uniqueCount / [double]$normalized.Count)
      if ($duplicateRatio -gt $maxDuplicateLineRatio) {
        throw "Text quality gate failed in $($ep.Name): duplicate_line_ratio=$([math]::Round($duplicateRatio,3)) exceeds limit=$maxDuplicateLineRatio."
      }

      $paragraphPrefixes = @{}
      foreach ($line in $normalized) {
        if ($line.Length -lt $paragraphPrefixLength) { continue }
        if ($line -match "^\s*(?:-|—)\s+") { continue }
        $prefix = $line.Substring(0, [math]::Min($paragraphPrefixLength, $line.Length))
        if (-not $paragraphPrefixes.ContainsKey($prefix)) { $paragraphPrefixes[$prefix] = 0 }
        $paragraphPrefixes[$prefix]++
      }
      foreach ($prefix in $paragraphPrefixes.Keys) {
        if ($paragraphPrefixes[$prefix] -gt $maxRepeatedParagraphPrefix) {
          throw "Text quality gate failed in $($ep.Name): repeated paragraph opening pattern detected ($($paragraphPrefixes[$prefix]) times): $prefix"
        }
      }
    }

    $dashDialogueLines = [regex]::Matches($rawText, "(?m)^\s*(?:-|—)\s+").Count
    $quoteDialogueHints = [regex]::Matches($rawText, '[""]').Count
    if ($requireDashDialogue -and $dashDialogueLines -lt 1) {
      throw "Text quality gate failed in $($ep.Name): required dash dialogue style not found."
    }
    if ($forbidMixedDialogue -and $dashDialogueLines -gt 0 -and $quoteDialogueHints -gt 0) {
      throw "Text quality gate failed in $($ep.Name): mixed dialogue styles detected."
    }

    $dialogueLineCount = [regex]::Matches($rawText, "(?m)^\s*(?:-|—)\s+.*$").Count
    $nonEmptyLineCount = [regex]::Matches($rawText, "(?m)^\s*\S+.*$").Count
    if ($nonEmptyLineCount -gt 0) {
      $dialogueRatio = $dialogueLineCount / [double]$nonEmptyLineCount
      if ($dialogueRatio -lt $dialogueRatioMin -or $dialogueRatio -gt $dialogueRatioMax) {
        throw "Text quality gate failed in $($ep.Name): dialogue_ratio=$([math]::Round($dialogueRatio,3)) outside [$dialogueRatioMin, $dialogueRatioMax]."
      }
    }

    $tellWords = @(
      "korkuyordu","hissediyordu","düşünüyordu","dusunuyordu","biliyordu","anladı","anladi",
      "fark etti","üzgündü","uzgundu","sinirliydi","şaşırdı","sasirdi","gerildi"
    )
    $sensoryWords = @(
      "koku","ses","nefes","dokunuş","dokunus","soğuk","soguk","sıcak","sicak","ıslak","islak",
      "karanlık","karanlik","ışık","isik","çarpıntı","carpinti","ter","titreme"
    )
    $tellCount = 0
    foreach ($w in $tellWords) { $tellCount += [regex]::Matches($rawText, [regex]::Escape($w), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count }
    $sensoryCount = 0
    foreach ($w in $sensoryWords) { $sensoryCount += [regex]::Matches($rawText, [regex]::Escape($w), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count }
    if ($tellCount -gt 0) {
      $ratio = $tellCount / [double]([math]::Max(1, $sensoryCount))
      if ($ratio -gt $tellSensoryRatioMax) {
        throw "Text quality gate failed in $($ep.Name): show-dont-tell ratio=$([math]::Round($ratio,3)) exceeds max=$tellSensoryRatioMax."
      }
    }

    if ($isPsychological) {
      $psychMarkers = @(
        "paranoya","halüsinasyon","halusinasyon","gerçek mi","gercek mi","sanrı","sanri",
        "suçluluk","sucluluk","vicdan","panik","çöküş","cokus","çözül","cozul",
        "şüphe","suphe","kaygı","kaygi","karabasan","takıntı","takinti",
        "derealizasyon","depersonalizasyon"
      )
      $hit = 0
      foreach ($w in $psychMarkers) {
        if ([regex]::IsMatch($rawText, [regex]::Escape($w), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
          $hit++
        }
      }
      if ($hit -lt $minPsychologicalMarkers) {
        throw "Text quality gate failed in $($ep.Name): psychological marker coverage=$hit below minimum=$minPsychologicalMarkers."
      }
    }
  }
}
$phases = @("intake","propose","design-big","design-small","create","polish","rewrite","export")
$fromIdx = [Array]::IndexOf($phases, $FromPhase)
$toIdx = [Array]::IndexOf($phases, $ToPhase)
if ($fromIdx -lt 0 -or $toIdx -lt 0 -or $fromIdx -gt $toIdx) {
  throw "Invalid phase range: $FromPhase -> $ToPhase"
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$runtimeDir = Join-Path $ProjectRoot "runtime"
if (-not $ConfigPath) {
  $ConfigPath = Join-Path $runtimeDir "runner-config.json"
}

Assert-ProjectIsolation -Root $ProjectRoot

$cfg = Load-RunnerConfig -Path $ConfigPath
$effectiveMode = $Mode
if ($Mode -eq "manual" -and $cfg.execution_mode -eq "command") {
  $effectiveMode = "command"
}

$dictionaryCheckEnabled = $false
if ($cfg -and $cfg.quality_flags -and $cfg.quality_flags.enable_dictionary_check -eq $true) {
  $dictionaryCheckEnabled = $true
}
if ($EnableDictionaryCheck) {
  $dictionaryCheckEnabled = $true
}

$requirePhaseEvidence = $true
if ($cfg -and $cfg.quality_flags -and $cfg.quality_flags.require_phase_evidence -eq $false) {
  $requirePhaseEvidence = $false
}

$configuredClaimMode = ""
if ($cfg -and $cfg.quality_flags -and $cfg.quality_flags.execution_claim_mode) {
  $configuredClaimMode = [string]$cfg.quality_flags.execution_claim_mode
}
if ($configuredClaimMode -notin @("executed","simulated")) {
  $configuredClaimMode = ""
}

$retentionEnabled = $true
$retentionMaxRuns = 20
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "retention")) {
  $retention = $cfg.quality_flags.retention
  if ($retention -and ($retention.PSObject.Properties.Name -contains "enabled") -and $retention.enabled -eq $false) {
    $retentionEnabled = $false
  }
  if ($retention -and ($retention.PSObject.Properties.Name -contains "max_runs")) {
    $parsedMaxRuns = 0
    if ([int]::TryParse([string]$retention.max_runs, [ref]$parsedMaxRuns) -and $parsedMaxRuns -ge 1) {
      $retentionMaxRuns = $parsedMaxRuns
    }
  }
}

$requireUserApprovals = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "require_user_approvals")) {
  if ($cfg.quality_flags.require_user_approvals -eq $false) {
    $requireUserApprovals = $false
  }
}

$enforcePhaseContracts = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "enforce_phase_contracts")) {
  if ($cfg.quality_flags.enforce_phase_contracts -eq $false) {
    $enforcePhaseContracts = $false
  }
}

$enableNegativeEnforcement = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "enable_negative_enforcement")) {
  if ($cfg.quality_flags.enable_negative_enforcement -eq $false) {
    $enableNegativeEnforcement = $false
  }
}

$enableTextQualityGates = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "enable_text_quality_gates")) {
  if ($cfg.quality_flags.enable_text_quality_gates -eq $false) {
    $enableTextQualityGates = $false
  }
}

$requireExecutedClaimsForCriticalPhases = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "require_executed_claims_for_critical_phases")) {
  if ($cfg.quality_flags.require_executed_claims_for_critical_phases -eq $false) {
    $requireExecutedClaimsForCriticalPhases = $false
  }
}

function Get-EpisodeNumberFromName {
  param([string]$Name)
  $m = [regex]::Match($Name, "(?i)ep(\d{3})")
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}

function Validate-MacroContinuityAudits {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("create","polish","rewrite","export")) {
    return
  }

  $episodeDir = Join-Path $Root "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    return
  }
  $episodes = @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($episodes.Count -lt 1) {
    return
  }

  $maxEpisode = 0
  foreach ($ep in $episodes) {
    $n = Get-EpisodeNumberFromName -Name $ep.Name
    if ($n -gt $maxEpisode) { $maxEpisode = $n }
  }

  $volumePlanPath = Join-Path $Root "revision/_state/volume-plan.json"
  Ensure-File $volumePlanPath
  $volumePlan = Read-Utf8 -Path $volumePlanPath | ConvertFrom-Json
  if (-not ($volumePlan.PSObject.Properties.Name -contains "audit_schedule")) {
    throw "Macro continuity audit gate failed: volume-plan.json missing audit_schedule."
  }

  foreach ($marker in @($volumePlan.audit_schedule)) {
    $markerText = [string]$marker
    $markerNumber = Get-EpisodeNumberFromName -Name $markerText
    if ($markerNumber -lt 1 -or $markerNumber -gt $maxEpisode) {
      continue
    }

    $jsonPath = Join-Path $Root ("revision/_workspace/macro-continuity-audit_{0}.json" -f $markerText)
    $reportPath = Join-Path $Root ("revision/_workspace/macro-continuity-audit_{0}.md" -f $markerText)
    Ensure-File $jsonPath
    Ensure-File $reportPath
    $audit = Read-Utf8 -Path $jsonPath | ConvertFrom-Json
    foreach ($field in @("run_id","through_chapter","verdict","checked_ledgers","open_risks","required_fixes")) {
      if (-not ($audit.PSObject.Properties.Name -contains $field)) {
        throw "Macro continuity audit gate failed: $jsonPath missing '$field'."
      }
    }
    if ([string]$audit.through_chapter -ne $markerText) {
      throw "Macro continuity audit gate failed: $jsonPath through_chapter must be $markerText."
    }
    if ($audit.verdict -ne "PASS") {
      throw "Macro continuity audit gate failed: $jsonPath verdict must be PASS before continuing."
    }
    foreach ($ledger in @("character-state.json","plot-ledger.json","chapter-summaries.json","continuity-ledger.json","world-state.json","relationship-graph.json","knowledge-graph.json","promise-payoff-ledger.json","timeline.json","theme-ledger.json")) {
      if (@($audit.checked_ledgers) -notcontains $ledger) {
        throw "Macro continuity audit gate failed: $jsonPath checked_ledgers missing $ledger."
      }
    }
    $reportRaw = Read-Utf8 -Path $reportPath
    if ($reportRaw -notmatch "(?i)\bVERDICT\b.*\bPASS\b") {
      throw "Macro continuity audit report missing VERDICT: PASS: $reportPath"
    }
  }
}

$enableCommandSafety = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "enable_command_safety")) {
  if ($cfg.quality_flags.enable_command_safety -eq $false) {
    $enableCommandSafety = $false
  }
}

$enableArtifactSizeBudget = $true
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "enable_artifact_size_budget")) {
  if ($cfg.quality_flags.enable_artifact_size_budget -eq $false) {
    $enableArtifactSizeBudget = $false
  }
}

$maxTextArtifactBytes = 1500000
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "max_text_artifact_bytes")) {
  $parsedArtifactBudget = 0
  if ([int]::TryParse([string]$cfg.quality_flags.max_text_artifact_bytes, [ref]$parsedArtifactBudget) -and $parsedArtifactBudget -ge 10000) {
    $maxTextArtifactBytes = $parsedArtifactBudget
  }
}

$negativePatterns = @("(?i)TL;DR","(?im)^\\s*Ozet\\s*:","(?im)^\\s*Summary\\s*:","\\[TODO\\]","(?i)lorem ipsum")
if ($cfg -and $cfg.quality_flags -and ($cfg.quality_flags.PSObject.Properties.Name -contains "forbidden_content_patterns")) {
  $customPatterns = @($cfg.quality_flags.forbidden_content_patterns)
  if ($customPatterns.Count -gt 0) {
    $negativePatterns = $customPatterns
  }
}

$runId = "RUN-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + (Get-Random -Minimum 1000 -Maximum 10000)
$runsRoot = Join-Path $runtimeDir "runs"
$summaryPath = Join-Path $runtimeDir ("runs/" + $runId + "/run-summary.json")
$evidenceDirPath = Join-Path $runtimeDir ("runs/" + $runId + "/evidence")
$runJournalPath = Join-Path $runtimeDir ("runs/" + $runId + "/run-journal.jsonl")
$currentRunPointerPath = Join-Path $runtimeDir "current-run.json"
$summary = [ordered]@{
  run_id = $runId
  started_at = (Get-Date).ToString("o")
  status = "in_progress"
  project_root = $ProjectRoot
  mode = $effectiveMode
  run_journal_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $runJournalPath
  steps = @()
}

Write-Host "[runner] run_id=$runId"
Write-Host "[runner] phase range: $FromPhase -> $ToPhase"
Write-Host "[runner] mode: $effectiveMode"
Write-Host "[runner] dictionary_check: $dictionaryCheckEnabled"
Write-Host "[runner] require_phase_evidence: $requirePhaseEvidence"
Write-Host "[runner] retention.enabled: $retentionEnabled"
Write-Host "[runner] retention.max_runs: $retentionMaxRuns"
Write-Host "[runner] require_user_approvals: $requireUserApprovals"
Write-Host "[runner] enforce_phase_contracts: $enforcePhaseContracts"
Write-Host "[runner] enable_negative_enforcement: $enableNegativeEnforcement"
Write-Host "[runner] enable_text_quality_gates: $enableTextQualityGates"
Write-Host "[runner] require_executed_claims_for_critical_phases: $requireExecutedClaimsForCriticalPhases"
Write-Host "[runner] enable_command_safety: $enableCommandSafety"
Write-Host "[runner] enable_artifact_size_budget: $enableArtifactSizeBudget"
Write-Host "[runner] max_text_artifact_bytes: $maxTextArtifactBytes"

Validate-AgentGovernanceCatalog -Root $ProjectRoot
Save-RunSummary -Path $summaryPath -Summary $summary
Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
  run_id = $runId
  status = "in_progress"
  updated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
  evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
  run_journal_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $runJournalPath
  last_step_id = $null
  last_evidence_path = $null
  message = "Run started."
  retention = [ordered]@{
    enabled = $retentionEnabled
    max_runs = $retentionMaxRuns
  }
})

for ($i = $fromIdx; $i -le $toIdx; $i++) {
  $phase = $phases[$i]
  $phaseOrdinal = ($i - $fromIdx + 1).ToString("00")
  $stepId = "$phase-$phaseOrdinal"
  $step = [ordered]@{
    step_id = $stepId
    phase = $phase
    status = "in_progress"
    started_at = (Get-Date).ToString("o")
    command = $null
    evidence_path = $null
    execution_claim_mode = $null
    message = $null
  }
  $contractHashes = @()

  try {
    Write-Host ""
    Write-Host "=== PHASE: $phase ==="
    $contractHashes = @(Get-ContractHashRecords -Root $ProjectRoot -Phase $phase)
    Write-RunJournalEvent -Path $runJournalPath -RunId $runId -Phase $phase -StepId $stepId -EventType "phase.started" -Metadata ([ordered]@{
      mode = $effectiveMode
      contract_hashes = $contractHashes
    })
    Ensure-UserApproval -Root $ProjectRoot -Phase $phase -Config $cfg -Enabled $requireUserApprovals

    $phaseClaimMode = "simulated"
    if ($configuredClaimMode) {
      $phaseClaimMode = $configuredClaimMode
    }

    if ($effectiveMode -eq "command") {
      $cmd = $null
      $phaseCommand = $cfg.phase_commands.$phase
      if ($phaseCommand) {
        $cmd = $phaseCommand
      }
      elseif ($cfg.adapter -and $cfg.adapter.command_template) {
        $phasePrompt = ""
        if ($cfg.phase_prompts) {
          $phasePrompt = [string]$cfg.phase_prompts.$phase
        }
        $cmd = Expand-Template -Template ([string]$cfg.adapter.command_template) -Values @{
          phase = $phase
          project_root = $ProjectRoot
          run_id = $runId
          from_phase = $FromPhase
          to_phase = $ToPhase
          phase_prompt = $phasePrompt
        }
      }

      if (-not $cmd) {
        throw "Missing command for phase '$phase'. Set phase_commands.$phase or adapter.command_template in runner-config.json"
      }
      $step.command = $cmd
      Validate-CommandSafety -Command $cmd -Root $ProjectRoot -Enabled $enableCommandSafety
      Write-Host "[runner] executing: $cmd"
      Invoke-Expression $cmd
      if ($LASTEXITCODE -ne 0) {
        throw "Phase command failed (exit=$LASTEXITCODE): $cmd"
      }
      $phaseClaimMode = "executed"
    }
    else {
      Write-Host "[runner] manual mode: run phase '$phase' in your IDE/agent."
      if (-not $NoWait) {
        [void](Read-Host "Press Enter after completing '$phase'")
      }
    }

    Ensure-UserApproval -Root $ProjectRoot -Phase $phase -Config $cfg -Enabled $requireUserApprovals
    Validate-PhaseArtifacts -Phase $phase -Root $ProjectRoot
    Invoke-DictionaryCheck -Phase $phase -Root $ProjectRoot -RunId $runId -Config $cfg -Enabled $dictionaryCheckEnabled -CommandSafetyEnabled $enableCommandSafety

    if ($requireExecutedClaimsForCriticalPhases -and $phase -in @("create","polish","rewrite","export") -and $phaseClaimMode -ne "executed") {
      throw "Phase '$phase' requires execution_claim_mode=executed. Configure command mode and real phase commands."
    }

    Validate-ExportManifestContract -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-DocxContentMatch -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-DocxReaderClean -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-DocxLayoutProfile -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    $artifacts = Get-PhaseOutputArtifacts -Phase $phase -Root $ProjectRoot
    Validate-ArtifactSizeBudget -Root $ProjectRoot -Artifacts $artifacts -MaxBytes $maxTextArtifactBytes -Enabled $enableArtifactSizeBudget
    $artifactHashes = @(Get-ArtifactHashRecords -Root $ProjectRoot -Artifacts $artifacts)
    Validate-PhaseContracts -Root $ProjectRoot -Phase $phase -Artifacts $artifacts -Enabled $enforcePhaseContracts
    Validate-AgentCompliance -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts -Artifacts $artifacts
    Validate-LongformState -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-StateReducers -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-MacroContinuityAudits -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-PublicationCompliance -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Assert-NoForbiddenPatterns -Root $ProjectRoot -Phase $phase -Patterns $negativePatterns -Enabled $enableNegativeEnforcement
    Validate-EpisodeTextQuality -Root $ProjectRoot -Phase $phase -Config $cfg -Enabled $enableTextQualityGates
    Validate-CrossChapterProgression -Root $ProjectRoot -Phase $phase -Config $cfg -Enabled $enableTextQualityGates
    $evidencePath = Join-Path $runtimeDir ("runs/" + $runId + "/evidence/" + $stepId + ".json")
    $evidence = [ordered]@{
      run_id = $runId
      step_id = $stepId
      phase = $phase
      execution_claim_mode = $phaseClaimMode
      artifact_gate_passed = $true
      dictionary_check_enabled = $dictionaryCheckEnabled
      generation_boundary = if ($Mode -eq "manual") { "manual IDE/human writing; runner validated artifacts" } elseif ($step.command -match "scripts/local_phase\.ps1") { "local deterministic adapter; validates pipeline/export but is not autonomous provider authorship" } else { "external command mode; authorship depends on configured provider/CLI command" }
      research_boundary = "No internet/source research is claimed unless source artifacts are emitted by a dedicated research phase/tool."
      started_at = $step.started_at
      finished_at = (Get-Date).ToString("o")
      status = "completed"
      executed_command = $step.command
      output_artifacts = $artifacts
      artifact_hashes = $artifactHashes
      contract_hashes = $contractHashes
      notes = @("artifact gate passed")
    }
    Save-PhaseEvidence -Path $evidencePath -Evidence $evidence
    if ($requirePhaseEvidence) {
      Validate-PhaseEvidenceFile -Path $evidencePath -Root $ProjectRoot
    }
    Write-RunJournalEvent -Path $runJournalPath -RunId $runId -Phase $phase -StepId $stepId -EventType "phase.completed" -Metadata ([ordered]@{
      execution_claim_mode = $phaseClaimMode
      output_artifacts = $artifacts
      contract_hashes = $contractHashes
    })

    $step.evidence_path = $evidencePath
    $step.execution_claim_mode = $phaseClaimMode
    $step.status = "completed"
    $step.message = "Artifact validation passed."
  }
  catch {
    $failedFinishedAt = (Get-Date).ToString("o")
    $failedEvidencePath = Join-Path $runtimeDir ("runs/" + $runId + "/evidence/" + $stepId + ".json")
    $failedEvidence = [ordered]@{
      run_id = $runId
      step_id = $stepId
      phase = $phase
      execution_claim_mode = "simulated"
      artifact_gate_passed = $false
      dictionary_check_enabled = $dictionaryCheckEnabled
      generation_boundary = if ($Mode -eq "manual") { "manual IDE/human writing; runner validated artifacts" } elseif ($step.command -match "scripts/local_phase\.ps1") { "local deterministic adapter; validates pipeline/export but is not autonomous provider authorship" } else { "external command mode; authorship depends on configured provider/CLI command" }
      research_boundary = "No internet/source research is claimed unless source artifacts are emitted by a dedicated research phase/tool."
      started_at = $step.started_at
      finished_at = $failedFinishedAt
      status = "failed"
      executed_command = $step.command
      output_artifacts = @()
      artifact_hashes = @()
      contract_hashes = $contractHashes
      notes = @($_.Exception.Message)
    }
    Save-PhaseEvidence -Path $failedEvidencePath -Evidence $failedEvidence
    if ($requirePhaseEvidence) {
      Validate-PhaseEvidenceFile -Path $failedEvidencePath -Root $ProjectRoot
    }
    Write-RunJournalEvent -Path $runJournalPath -RunId $runId -Phase $phase -StepId $stepId -EventType "phase.failed" -Metadata ([ordered]@{
      message = $_.Exception.Message
      executed_command = $step.command
    })
    $step.evidence_path = $failedEvidencePath
    $step.execution_claim_mode = "simulated"
    $step.status = "failed"
    $step.message = $_.Exception.Message
    $step.finished_at = $failedFinishedAt
    $summary.steps += $step
    $summary.status = "failed"
    $summary.updated_at = (Get-Date).ToString("o")
    Save-RunSummary -Path $summaryPath -Summary $summary
    Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
      run_id = $runId
      status = "failed"
      updated_at = (Get-Date).ToString("o")
      project_root = $ProjectRoot
      summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
      evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
      run_journal_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $runJournalPath
      last_step_id = $stepId
      last_evidence_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $failedEvidencePath
      message = $step.message
      retention = [ordered]@{
        enabled = $retentionEnabled
        max_runs = $retentionMaxRuns
      }
    })
    Invoke-RunRetention -RunsRoot $runsRoot -ActiveRunId $runId -MaxRuns $retentionMaxRuns -Enabled $retentionEnabled
    throw
  }

  $step.finished_at = (Get-Date).ToString("o")
  $summary.steps += $step
  $summary.updated_at = (Get-Date).ToString("o")
  Save-RunSummary -Path $summaryPath -Summary $summary
  Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
    run_id = $runId
    status = "in_progress"
    updated_at = (Get-Date).ToString("o")
    project_root = $ProjectRoot
    summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
    evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
    run_journal_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $runJournalPath
    last_step_id = $stepId
    last_evidence_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $step.evidence_path
    message = "Phase completed."
    retention = [ordered]@{
      enabled = $retentionEnabled
      max_runs = $retentionMaxRuns
    }
  })
}

$summary.status = "completed"
$summary.finished_at = (Get-Date).ToString("o")
Write-RunJournalEvent -Path $runJournalPath -RunId $runId -Phase "run" -StepId "run" -EventType "run.completed" -Metadata ([ordered]@{ steps = @($summary.steps).Count })
Save-RunSummary -Path $summaryPath -Summary $summary
Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
  run_id = $runId
  status = "completed"
  updated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
  evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
  run_journal_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $runJournalPath
  last_step_id = $summary.steps[-1].step_id
  last_evidence_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summary.steps[-1].evidence_path
  message = "Run completed."
  retention = [ordered]@{
    enabled = $retentionEnabled
    max_runs = $retentionMaxRuns
  }
})
Invoke-RunRetention -RunsRoot $runsRoot -ActiveRunId $runId -MaxRuns $retentionMaxRuns -Enabled $retentionEnabled

Write-Host ""
Write-Host "[runner] completed: $runId"
Write-Host "[runner] summary: $summaryPath"
