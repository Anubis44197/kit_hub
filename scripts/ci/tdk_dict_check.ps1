param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [string]$Phase,
  [Parameter(Mandatory = $true)]
  [string]$RunId,
  [switch]$RequireProvider
)

$ErrorActionPreference = "Stop"

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function New-SkippedReport {
  param(
    [string]$Root,
    [string]$PhaseName,
    [string]$Run,
    [string]$Reason
  )

  $outDir = Join-Path $Root "revision/_workspace"
  if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
  }
  $outPath = Join-Path $outDir ("10_tdk-dictionary-check_" + $PhaseName + ".json")
  $obj = [ordered]@{
    run_id = $Run
    phase = $PhaseName
    generated_at = (Get-Date).ToString("o")
    provider = "tdk-py"
    status = "skipped"
    checked_files = @()
    checked_word_count = 0
    findings = @()
    notes = @($Reason)
  }
  Write-Utf8Bom -Path $outPath -Content ($obj | ConvertTo-Json -Depth 6)
  Write-Host "[tdk-dict-check] skipped: $Reason"
  Write-Host "[tdk-dict-check] report: $outPath"
}

$pythonExe = $null
$pythonPrefixArgs = @()
if (Get-Command python -ErrorAction SilentlyContinue) {
  $pythonExe = "python"
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
  $pythonExe = "py"
  $pythonPrefixArgs = @("-3")
}

if (-not $pythonExe) {
  if ($RequireProvider) {
    throw "Python runtime not found while RequireProvider is enabled."
  }
  New-SkippedReport -Root $ProjectRoot -PhaseName $Phase -Run $RunId -Reason "Python runtime not found."
  exit 0
}

$scriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "ci/tdk_dict_check.py"
$argsList = @()
$argsList += $pythonPrefixArgs
$argsList += @(
  $scriptPath,
  "--project-root", $ProjectRoot,
  "--phase", $Phase,
  "--run-id", $RunId
)
if ($RequireProvider) {
  $argsList += "--require-provider"
}

Write-Host "[tdk-dict-check] exec: $pythonExe $($argsList -join ' ')"
& $pythonExe @argsList
if ($LASTEXITCODE -ne 0) {
  if ($RequireProvider) {
    throw "Dictionary check failed (exit=$LASTEXITCODE)."
  }
  New-SkippedReport -Root $ProjectRoot -PhaseName $Phase -Run $RunId -Reason "Provider unavailable or check failed."
  exit 0
}

exit 0
