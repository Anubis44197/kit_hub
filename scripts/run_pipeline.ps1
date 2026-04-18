param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$FromPhase = "propose",
  [ValidateSet("propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$ToPhase = "export",
  [ValidateSet("manual","command")]
  [string]$Mode = "manual",
  [string]$ConfigPath = "",
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
      Ensure-File (Join-Path $Root "novel-config.md")
    }
    "design-big" {
      Ensure-Any -Patterns @(
        "design/arc_master.md",
        "design/01_concept_bootstrap.md"
      ) -BasePath $Root
    }
    "design-small" {
      Ensure-Any -Patterns @(
        "design/EP001-EP005_scene_plan.md",
        "design/*scene_plan*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/continuity_map_EP001-EP005.md",
        "design/*continuity*map*.md"
      ) -BasePath $Root
      Ensure-Any -Patterns @(
        "design/hook_table_EP001-EP005.md",
        "design/*hook*table*.md"
      ) -BasePath $Root
    }
    "create" {
      Ensure-Any -Patterns @("episode/ep001.md","episode/ep001*.md") -BasePath $Root
      Ensure-Any -Patterns @("revision/_workspace/quality-verifier_EP001.md","revision/_workspace/*quality*EP001*.md") -BasePath $Root
    }
    "polish" {
      Ensure-Any -Patterns @("revision/_workspace/revision-reviewer_EP001.md","revision/_workspace/*reviewer*EP001*.md") -BasePath $Root
      Ensure-Any -Patterns @("episode/ep001.md","episode/ep001*.md") -BasePath $Root
    }
    "rewrite" {
      Ensure-Any -Patterns @("revision/_workspace/*rewrite*report*.md","revision/_workspace/*quality*verdict*EP001*.md") -BasePath $Root
    }
    "export" {
      Ensure-Any -Patterns @("revision/_workspace/export-manifest*.json") -BasePath $Root
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

$runId = "RUN-" + (Get-Date -Format "yyyyMMdd-HHmmss")
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

for ($i = $fromIdx; $i -le $toIdx; $i++) {
  $phase = $phases[$i]
  $stepId = "step-" + ($i + 1).ToString("00")
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
