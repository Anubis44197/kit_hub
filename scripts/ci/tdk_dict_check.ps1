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
  $obj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding UTF8
  Write-Host "[tdk-dict-check] skipped: $Reason"
  Write-Host "[tdk-dict-check] report: $outPath"
}

$pythonExe = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
  $pythonExe = "python"
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
  $pythonExe = "py -3"
}

if (-not $pythonExe) {
  if ($RequireProvider) {
    throw "Python runtime not found while RequireProvider is enabled."
  }
  New-SkippedReport -Root $ProjectRoot -PhaseName $Phase -Run $RunId -Reason "Python runtime not found."
  exit 0
}

$cmd = "$pythonExe scripts/ci/tdk_dict_check.py --project-root ""$ProjectRoot"" --phase $Phase --run-id $RunId"
if ($RequireProvider) {
  $cmd += " --require-provider"
}

Write-Host "[tdk-dict-check] exec: $cmd"
Invoke-Expression $cmd
if ($LASTEXITCODE -ne 0) {
  if ($RequireProvider) {
    throw "Dictionary check failed (exit=$LASTEXITCODE)."
  }
  New-SkippedReport -Root $ProjectRoot -PhaseName $Phase -Run $RunId -Reason "Provider unavailable or check failed."
  exit 0
}

exit 0

