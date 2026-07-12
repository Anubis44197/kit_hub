param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [string]$RunId
)

$ErrorActionPreference = "Stop"

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Assert-InProjectRoot {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd("\") + "\"
  $targetFull = [System.IO.Path]::GetFullPath($Path)
  if (-not ($targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Provider phase refused project-external path: $targetFull"
  }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw "Provider phase must run inside a KitHub project created by scripts/new_project.ps1."
}

$providerExe = [string]$env:KITHUB_PROVIDER_EXE
if (-not $providerExe.Trim()) {
  throw "Provider phase blocked: KITHUB_PROVIDER_EXE is not set. Configure a real model/agent CLI before using automatic provider mode."
}

$promptDir = Join-Path $ProjectRoot "runtime/provider-prompts"
$promptPath = Join-Path $promptDir ("{0}_{1}.md" -f $RunId, $Phase)
$phasePrompt = @"
# KitHub Provider Phase

run_id: $RunId
phase: $Phase
project_root: $ProjectRoot

You are running KitHub in automatic provider mode. Produce the exact artifacts required by:
- runtime/phase-contracts/$Phase.json
- runtime/agent-registry.json
- runtime/agent-status-contract.json
- skills for this phase

Rules:
- Load required state files before writing.
- Follow agent_sequence exactly.
- Write only allowed output roots for the phase.
- Emit runtime/agent-compliance/$Phase.json with concrete agent evidence.
- For create/polish/rewrite, update all required state ledgers.
- For export, do not invent missing manuscript, front matter, cover, or publication data.
- Never claim official TDK/web/source research without source artifacts.
- Never mark the book complete while length fulfillment, chapter coverage, or export gates are under target.
"@
Write-Utf8Bom -Path $promptPath -Content $phasePrompt
Assert-InProjectRoot -Root $ProjectRoot -Path $promptPath

$providerArgsTemplate = [string]$env:KITHUB_PROVIDER_ARGS
if (-not $providerArgsTemplate.Trim()) {
  $providerArgsTemplate = "--project-root `"{project_root}`" --phase {phase} --run-id `"{run_id}`" --prompt-file `"{prompt_file}`""
}

$providerArgs = $providerArgsTemplate.Replace("{project_root}", $ProjectRoot).Replace("{phase}", $Phase).Replace("{run_id}", $RunId).Replace("{prompt_file}", $promptPath)

$logDir = Join-Path $ProjectRoot "runtime/provider-logs"
$logPath = Join-Path $logDir ("{0}_{1}.log" -f $RunId, $Phase)
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}

Write-Host "[provider-phase] executing provider for phase=$Phase"
Write-Host "[provider-phase] prompt: $promptPath"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $providerExe
$psi.Arguments = $providerArgs
$psi.WorkingDirectory = $ProjectRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::Start($psi)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()
Write-Utf8Bom -Path $logPath -Content ("STDOUT:`r`n$stdout`r`n`r`nSTDERR:`r`n$stderr")

if ($process.ExitCode -ne 0) {
  throw "Provider phase failed for '$Phase' with exit code $($process.ExitCode). See $logPath"
}

Write-Host "[provider-phase] completed phase=$Phase log=$logPath"
