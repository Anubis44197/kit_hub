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
      $patterns = @("novel-config.md","design/*_bootstrap.md","design/*_character.md","design/*_plot-hook.md")
    }
    "design-small" {
      $patterns = @("design/*_character-detail_*.md","design/*_plot-detail_*.md","design/*scene_plan*.md","design/*hook*table*.md")
    }
    "create" {
      $patterns = @("episode/ep*.md","revision/_workspace/04_quality-verifier_verdict_EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json")
    }
    "polish" {
      $patterns = @("episode/ep*.md","revision/_workspace/*revision-reviewer*EP*.md","revision/_workspace/08_tdk-polisher_issues_EP*.json","revision/_workspace/10_tdk-dictionary-check_polish.json")
    }
    "rewrite" {
      $patterns = @("episode/ep*.md","revision/_workspace/*rewrite*report*.md","revision/_workspace/04_quality-verifier_verdict_EP*.md","revision/_workspace/10_tdk-dictionary-check_rewrite.json")
    }
    "export" {
      $patterns = @("revision/_workspace/*export*manifest*.json","revision/_workspace/*export-validator*verdict*.json","revision/export/*.docx")
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
    throw "Runner config not found: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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
  $Summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
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
  $Pointer | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
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
  $Evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Validate-PhaseEvidenceFile {
  param([string]$Path)

  Ensure-File $Path
  $raw = Get-Content -LiteralPath $Path -Raw
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

  $template = ""
  if ($Config -and $Config.quality_flags -and $Config.quality_flags.dictionary_check_command) {
    $template = [string]$Config.quality_flags.dictionary_check_command
  }
  if (-not $template) {
    $template = "python scripts/ci/tdk_dict_check.py --project-root ""{project_root}"" --phase {phase} --run-id {run_id}"
  }

  $cmd = Expand-Template -Template $template -Values @{
    phase = $Phase
    project_root = $Root
    run_id = $RunId
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

  $obj = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
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
  $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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
  $raw = Get-Content -LiteralPath $Path -Raw
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
    $raw = Get-Content -LiteralPath $ep.FullName -Raw
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
  $cfgRaw = Get-Content -LiteralPath $cfgPath -Raw

  $minCharacters = [int](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "min_characters" -Default 6500)
  $maxCharacters = [int](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "max_characters" -Default 14000)
  $dialogueRatioMin = [double](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "dialogue_ratio_min" -Default 0.35)
  $dialogueRatioMax = [double](Get-NovelConfigNumericValue -ConfigRaw $cfgRaw -Key "dialogue_ratio_max" -Default 0.65)
  $targetGenre = Get-NovelConfigStringValue -ConfigRaw $cfgRaw -Key "target_genre" -Default ""
  $isPsychological = $targetGenre -match "(?i)psych|psikolojik|gerilim"

  $maxDuplicateLineRatio = 0.28
  $tellSensoryRatioMax = 2.40
  $requireDashDialogue = $true
  $forbidMixedDialogue = $true
  $minPsychologicalMarkers = 6

  if ($Config -and $Config.quality_flags -and ($Config.quality_flags.PSObject.Properties.Name -contains "text_quality_gates")) {
    $q = $Config.quality_flags.text_quality_gates
    if ($q.PSObject.Properties.Name -contains "max_duplicate_line_ratio") { $maxDuplicateLineRatio = [double]$q.max_duplicate_line_ratio }
    if ($q.PSObject.Properties.Name -contains "tell_sensory_ratio_max") { $tellSensoryRatioMax = [double]$q.tell_sensory_ratio_max }
    if ($q.PSObject.Properties.Name -contains "require_dash_dialogue") { $requireDashDialogue = [bool]$q.require_dash_dialogue }
    if ($q.PSObject.Properties.Name -contains "forbid_mixed_dialogue_styles") { $forbidMixedDialogue = [bool]$q.forbid_mixed_dialogue_styles }
    if ($q.PSObject.Properties.Name -contains "min_psychological_markers") { $minPsychologicalMarkers = [int]$q.min_psychological_markers }
  }

  foreach ($ep in $episodes) {
    $rawText = Get-Content -LiteralPath $ep.FullName -Raw

    if ($rawText -match "[ÃÅÄ]") {
      throw "Text quality gate failed in $($ep.Name): mojibake/encoding corruption detected."
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

    $tellWords = @("korkuyordu","hissediyordu","dusunuyordu","biliyordu","anladi","fark etti","uzgundu","sinirliydi","sasirdi","gerildi")
    $sensoryWords = @("koku","ses","nefes","dokunus","soguk","sicak","islak","karanlik","isik","carpinti","ter","titreme")
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
        "paranoya","halusinasyon","gercek mi","sanri","sucluluk","vicdan","panik","cokus","cozul",
        "suphe","kaygi","karabasan","takinti","derealizasyon","depersonalizasyon"
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
    Assert-NoForbiddenPatterns -Root $ProjectRoot -Phase $phase -Patterns $negativePatterns -Enabled $enableNegativeEnforcement
    Validate-EpisodeTextQuality -Root $ProjectRoot -Phase $phase -Config $cfg -Enabled $enableTextQualityGates
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

