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

$runId = "RUN-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + (Get-Random -Minimum 1000 -Maximum 10000)
$summaryPath = Join-Path $runtimeDir ("runs/" + $runId + "/run-summary.json")
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
    message = $null
  }

  try {
    Write-Host ""
    Write-Host "=== PHASE: $phase ==="

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
    }
    else {
      Write-Host "[runner] manual mode: run phase '$phase' in your IDE/agent."
      if (-not $NoWait) {
        [void](Read-Host "Press Enter after completing '$phase'")
      }
    }

    Validate-PhaseArtifacts -Phase $phase -Root $ProjectRoot
    Invoke-DictionaryCheck -Phase $phase -Root $ProjectRoot -RunId $runId -Config $cfg -Enabled $dictionaryCheckEnabled
    $step.status = "completed"
    $step.message = "Artifact validation passed."
  }
  catch {
    $step.status = "failed"
    $step.message = $_.Exception.Message
    $step.finished_at = (Get-Date).ToString("o")
    $summary.steps += $step
    $summary.status = "failed"
    $summary.updated_at = (Get-Date).ToString("o")
    Save-RunSummary -Path $summaryPath -Summary $summary
    throw
  }

  $step.finished_at = (Get-Date).ToString("o")
  $summary.steps += $step
  $summary.updated_at = (Get-Date).ToString("o")
  Save-RunSummary -Path $summaryPath -Summary $summary
}

$summary.status = "completed"
$summary.finished_at = (Get-Date).ToString("o")
Save-RunSummary -Path $summaryPath -Summary $summary

Write-Host ""
Write-Host "[runner] completed: $runId"
Write-Host "[runner] summary: $summaryPath"
