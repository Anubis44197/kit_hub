param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateSource = Join-Path (Split-Path -Parent $scriptRoot) "runtime/runner-config.template.json"

$runtimeDir = Join-Path $ProjectRoot "runtime"
$runsDir = Join-Path $runtimeDir "runs"
$templatePath = Join-Path $runtimeDir "runner-config.template.json"
$configPath = Join-Path $runtimeDir "runner-config.json"

if (-not (Test-Path -LiteralPath $runtimeDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (-not (Test-Path -LiteralPath $runsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $templateSource -PathType Leaf)) {
  throw "Missing template source: $templateSource"
}

if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
  Copy-Item -LiteralPath $templateSource -Destination $templatePath -Force
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  Copy-Item -LiteralPath $templatePath -Destination $configPath -Force
  Write-Host "[install] created $configPath"
}
else {
  Write-Host "[install] config already exists: $configPath"
}

Write-Host "[install] runtime bootstrap complete."
