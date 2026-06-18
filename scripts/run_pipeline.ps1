param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$FromPhase = "propose",
  [ValidateSet("propose","design-big","design-small","create","polish","rewrite","export")]
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

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
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
    return [System.IO.Path]::GetRelativePath($BasePath, $TargetPath)
  }
  catch {
    $base = [System.IO.Path]::GetFullPath($BasePath)
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    if ($target.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $target.Substring($base.Length).TrimStart('\')
    }
    return $TargetPath
  }
}

function Validate-PhaseArtifacts {
  param([string]$Phase, [string]$Root)

  switch ($Phase) {
    "propose" {
      Ensure-Any -Patterns @(
        "_workspace/01_proposals.md",
        "_workspace/01_proposals*.md",
        "*_proposal.md"
      ) -BasePath $Root
    }
    "design-big" {
      Ensure-File (Join-Path $Root "novel-config.md")
      Ensure-Any -Patterns @(
        "design/*_bootstrap.md",
        "design/01_concept_bootstrap.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/*_character.md",
        "design/02_character_core.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/*_plot-hook.md",
        "design/03_macro_plot_hooks.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_state/longform-plan.json",
        "revision/_state/style-profile.json",
        "revision/_state/writing-type-profile.json",
        "revision/_state/genre-structure-template.json",
        "revision/_state/editorial-quality-scorecard.json",
        "revision/_state/llm-adapter-contract.json"
      ) -BasePath $Root
    }
    "design-small" {
      Ensure-Any -Patterns @(
        "design/*_character-detail_*.md",
        "design/*character*detail*.md",
        "design/EP001-EP005_scene_plan.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/*_plot-detail_*.md",
        "design/*plot*detail*.md",
        "design/hook_table_EP001-EP005.md"
      ) -BasePath $Root
      Ensure-File (Join-Path $Root "novel-config.md")
    }
    "create" {
      Ensure-Any -Patterns @(
        "design/*scene_plan*.md",
        "design/EP001-EP005_scene_plan.md",
        "design/*_plot-detail_*.md",
        "design/hook_table_EP001-EP005.md"
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
        "revision/_state/style-profile.json",
        "revision/_state/longform-plan.json"
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
        "revision/_workspace/*export-word*manifest*.json",
        "revision/_workspace/*export-manifest*.json"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "revision/_workspace/10_export-validator_verdict_EP*.json",
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
    "propose" {
      $patterns = @("_workspace/01_proposals*.md","*_proposal.md")
    }
    "design-big" {
      $patterns = @("novel-config.md","design/*_bootstrap.md","design/*_character.md","design/*_plot-hook.md","revision/_state/*.json")
    }
    "design-small" {
      $patterns = @("design/*_character-detail_*.md","design/*_plot-detail_*.md","design/*scene_plan*.md","design/*hook*table*.md")
    }
    "create" {
      $patterns = @("episode/ep*.md","revision/_workspace/04_quality-verifier_verdict_EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json","revision/_state/*.json")
    }
    "polish" {
      $patterns = @("episode/ep*.md","revision/_workspace/*revision-reviewer*EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json","revision/_workspace/10_tdk-dictionary-check_polish.json","revision/_state/*.json")
    }
    "rewrite" {
      $patterns = @(
        "episode/ep*.md",
        "revision/_workspace/*rewrite*report*.md",
        "revision/_workspace/04_quality-verifier_verdict_EP*.md",
        "revision/_workspace/08_tdk-polisher_issues_EP*.json",
        "revision/_workspace/10_tdk-dictionary-check_rewrite.json",
        "revision/_state/*.json"
      )
    }
    "export" {
      $patterns = @(
        "revision/_workspace/*export*manifest*.json",
        "revision/_workspace/*export-validator*verdict*.json",
        "revision/_workspace/11_front-matter*",
        "revision/_workspace/12_cover-design*",
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

function Validate-PhaseEvidenceFile {
  param([string]$Path)

  Ensure-File $Path
  $raw = Read-Utf8 -Path $Path
  $obj = $raw | ConvertFrom-Json

  $required = @(
    "run_id","step_id","phase","execution_claim_mode","artifact_gate_passed",
    "dictionary_check_enabled","started_at","finished_at","status","output_artifacts","notes"
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
}

function Invoke-DictionaryCheck {
  param(
    [string]$Phase,
    [string]$Root,
    [string]$RunId,
    [object]$Config,
    [bool]$Enabled
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
    "create" = "runtime/approvals/design-freeze.json"
    "rewrite" = "runtime/approvals/rewrite-approval.json"
    "export" = "runtime/approvals/export-approval.json"
  }

  if ($Config -and $Config.quality_flags -and $Config.quality_flags.approval_files) {
    $custom = $Config.quality_flags.approval_files
    foreach ($k in @("create","rewrite","export")) {
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
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }

  $path = Join-Path $Root ("runtime/agent-compliance/{0}.json" -f $Phase)
  Ensure-File $path
  $obj = Read-Utf8 -Path $Path | ConvertFrom-Json
  foreach ($field in @("run_id","phase","required_agents","agents_executed","required_references","loaded_state_files","output_artifacts","contract_status","missing_items")) {
    if (-not ($obj.PSObject.Properties.Name -contains $field)) {
      throw "Agent compliance manifest missing '$field': $path"
    }
  }
  if ([string]$obj.phase -ne $Phase) {
    throw "Agent compliance phase mismatch. Expected '$Phase', found '$($obj.phase)': $path"
  }
  if ($obj.contract_status -ne "PASS") {
    throw "Agent compliance failed for phase '$Phase': status=$($obj.contract_status)"
  }
  if (@($obj.required_agents).Count -lt 1) {
    throw "Agent compliance required_agents is empty for phase '$Phase'."
  }
  $executed = @($obj.agents_executed)
  foreach ($agent in @($obj.required_agents)) {
    if ($executed -notcontains $agent) {
      throw "Agent compliance missing executed agent '$agent' for phase '$Phase'."
    }
  }
  if (@($obj.missing_items).Count -gt 0) {
    throw "Agent compliance has missing_items for phase '$Phase': $($obj.missing_items -join ', ')"
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

function Validate-LongformState {
  param(
    [string]$Root,
    [string]$Phase,
    [bool]$Enabled
  )

  if (-not $Enabled) {
    return
  }
  if ($Phase -notin @("design-big","create","polish","rewrite","export")) {
    return
  }

  $stateDir = Join-Path $Root "revision/_state"
  $required = @(
    "longform-plan.json",
    "character-state.json",
    "plot-ledger.json",
    "chapter-summaries.json",
    "continuity-ledger.json",
    "style-profile.json",
    "writing-type-profile.json",
    "genre-structure-template.json",
    "editorial-quality-scorecard.json",
    "llm-adapter-contract.json"
  )
  foreach ($name in $required) {
    Ensure-File (Join-Path $stateDir $name)
  }

  $plan = Read-Utf8 -Path (Join-Path $stateDir "longform-plan.json") | ConvertFrom-Json
  foreach ($field in @("target_pages","target_words","target_chapters","chapters","required_state_files")) {
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

  $writingProfile = Read-Utf8 -Path (Join-Path $stateDir "writing-type-profile.json") | ConvertFrom-Json
  foreach ($field in @("writing_type","target_reader","structure_model","voice_model","evidence_policy","continuity_policy","completion_criteria")) {
    if (-not ($writingProfile.PSObject.Properties.Name -contains $field)) {
      throw "writing-type-profile.json missing '$field'."
    }
  }

  $structureTemplate = Read-Utf8 -Path (Join-Path $stateDir "genre-structure-template.json") | ConvertFrom-Json
  foreach ($field in @("template_id","acts","chapter_rules","mandatory_ledgers")) {
    if (-not ($structureTemplate.PSObject.Properties.Name -contains $field)) {
      throw "genre-structure-template.json missing '$field'."
    }
  }

  $scorecard = Read-Utf8 -Path (Join-Path $stateDir "editorial-quality-scorecard.json") | ConvertFrom-Json
  foreach ($field in @("threshold_pass","axes","export_blockers")) {
    if (-not ($scorecard.PSObject.Properties.Name -contains $field)) {
      throw "editorial-quality-scorecard.json missing '$field'."
    }
  }

  $adapterContract = Read-Utf8 -Path (Join-Path $stateDir "llm-adapter-contract.json") | ConvertFrom-Json
  foreach ($field in @("adapter_contract","max_chapters_per_batch","required_input_state","required_output_state")) {
    if (-not ($adapterContract.PSObject.Properties.Name -contains $field)) {
      throw "llm-adapter-contract.json missing '$field'."
    }
  }

  if ($Phase -in @("create","polish","rewrite","export")) {
    $summaries = Read-Utf8 -Path (Join-Path $stateDir "chapter-summaries.json") | ConvertFrom-Json
    if (-not ($summaries.PSObject.Properties.Name -contains "chapters") -or @($summaries.chapters).Count -lt 1) {
      throw "chapter-summaries.json must include at least one generated chapter summary after create."
    }
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

  $episodes = Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File -ErrorAction SilentlyContinue
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
      $uniqueSummaries = @($chapters | ForEach-Object { [string]$_.summary } | Sort-Object -Unique)
      if ($uniqueSummaries.Count -lt $chapters.Count) {
        throw "Cross-chapter progression gate failed: chapter summaries are duplicated."
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

  if ($Config -and $Config.quality_flags -and ($Config.quality_flags.PSObject.Properties.Name -contains "text_quality_gates")) {
    $q = $Config.quality_flags.text_quality_gates
    if ($q.PSObject.Properties.Name -contains "max_duplicate_line_ratio") { $maxDuplicateLineRatio = [double]$q.max_duplicate_line_ratio }
    if ($q.PSObject.Properties.Name -contains "max_repeated_paragraph_prefix") { $maxRepeatedParagraphPrefix = [int]$q.max_repeated_paragraph_prefix }
    if ($q.PSObject.Properties.Name -contains "paragraph_prefix_length") { $paragraphPrefixLength = [int]$q.paragraph_prefix_length }
    if ($q.PSObject.Properties.Name -contains "tell_sensory_ratio_max") { $tellSensoryRatioMax = [double]$q.tell_sensory_ratio_max }
    if ($q.PSObject.Properties.Name -contains "require_dash_dialogue") { $requireDashDialogue = [bool]$q.require_dash_dialogue }
    if ($q.PSObject.Properties.Name -contains "forbid_mixed_dialogue_styles") { $forbidMixedDialogue = [bool]$q.forbid_mixed_dialogue_styles }
    if ($q.PSObject.Properties.Name -contains "min_psychological_markers") { $minPsychologicalMarkers = [int]$q.min_psychological_markers }
  }

  foreach ($ep in $episodes) {
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
$phases = @("propose","design-big","design-small","create","polish","rewrite","export")
$fromIdx = [Array]::IndexOf($phases, $FromPhase)
$toIdx = [Array]::IndexOf($phases, $ToPhase)
if ($fromIdx -lt 0 -or $toIdx -lt 0 -or $fromIdx -gt $toIdx) {
  throw "Invalid phase range: $FromPhase -> $ToPhase"
}

$runtimeDir = Join-Path $ProjectRoot "runtime"
if (-not $ConfigPath) {
  $ConfigPath = Join-Path $runtimeDir "runner-config.json"
}

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
$currentRunPointerPath = Join-Path $runtimeDir "current-run.json"
$summary = [ordered]@{
  run_id = $runId
  started_at = (Get-Date).ToString("o")
  status = "in_progress"
  project_root = $ProjectRoot
  mode = $effectiveMode
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

Save-RunSummary -Path $summaryPath -Summary $summary
Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
  run_id = $runId
  status = "in_progress"
  updated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
  evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
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

  try {
    Write-Host ""
    Write-Host "=== PHASE: $phase ==="

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
    Invoke-DictionaryCheck -Phase $phase -Root $ProjectRoot -RunId $runId -Config $cfg -Enabled $dictionaryCheckEnabled

    if ($requireExecutedClaimsForCriticalPhases -and $phase -in @("create","polish","rewrite","export") -and $phaseClaimMode -ne "executed") {
      throw "Phase '$phase' requires execution_claim_mode=executed. Configure command mode and real phase commands."
    }

    $artifacts = Get-PhaseOutputArtifacts -Phase $phase -Root $ProjectRoot
    Validate-PhaseContracts -Root $ProjectRoot -Phase $phase -Artifacts $artifacts -Enabled $enforcePhaseContracts
    Validate-AgentCompliance -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
    Validate-LongformState -Root $ProjectRoot -Phase $phase -Enabled $enforcePhaseContracts
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
      started_at = $step.started_at
      finished_at = (Get-Date).ToString("o")
      status = "completed"
      executed_command = $step.command
      output_artifacts = $artifacts
      notes = @("artifact gate passed")
    }
    Save-PhaseEvidence -Path $evidencePath -Evidence $evidence
    if ($requirePhaseEvidence) {
      Validate-PhaseEvidenceFile -Path $evidencePath
    }

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
      started_at = $step.started_at
      finished_at = $failedFinishedAt
      status = "failed"
      executed_command = $step.command
      output_artifacts = @()
      notes = @($_.Exception.Message)
    }
    Save-PhaseEvidence -Path $failedEvidencePath -Evidence $failedEvidence
    if ($requirePhaseEvidence) {
      Validate-PhaseEvidenceFile -Path $failedEvidencePath
    }
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
Save-RunSummary -Path $summaryPath -Summary $summary
Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
  run_id = $runId
  status = "completed"
  updated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  summary_path = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $summaryPath
  evidence_dir = Get-RelativePathSafe -BasePath $ProjectRoot -TargetPath $evidenceDirPath
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
