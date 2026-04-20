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
    $relative += [System.IO.Path]::GetRelativePath($Root, $f)
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
    [ordered]$Pointer
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
    [ordered]$Evidence
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

Save-RunSummary -Path $summaryPath -Summary $summary
Save-CurrentRunPointer -Path $currentRunPointerPath -Pointer ([ordered]@{
  run_id = $runId
  status = "in_progress"
  updated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  summary_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $summaryPath)
  evidence_dir = [System.IO.Path]::GetRelativePath($ProjectRoot, $evidenceDirPath)
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

    Validate-PhaseArtifacts -Phase $phase -Root $ProjectRoot
    Invoke-DictionaryCheck -Phase $phase -Root $ProjectRoot -RunId $runId -Config $cfg -Enabled $dictionaryCheckEnabled

    $artifacts = Get-PhaseOutputArtifacts -Phase $phase -Root $ProjectRoot
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
      summary_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $summaryPath)
      evidence_dir = [System.IO.Path]::GetRelativePath($ProjectRoot, $evidenceDirPath)
      last_step_id = $stepId
      last_evidence_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $failedEvidencePath)
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
    summary_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $summaryPath)
    evidence_dir = [System.IO.Path]::GetRelativePath($ProjectRoot, $evidenceDirPath)
    last_step_id = $stepId
    last_evidence_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $step.evidence_path)
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
  summary_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $summaryPath)
  evidence_dir = [System.IO.Path]::GetRelativePath($ProjectRoot, $evidenceDirPath)
  last_step_id = $summary.steps[-1].step_id
  last_evidence_path = [System.IO.Path]::GetRelativePath($ProjectRoot, $summary.steps[-1].evidence_path)
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
