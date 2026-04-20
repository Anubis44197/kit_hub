param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateSource = Join-Path (Split-Path -Parent $scriptRoot) "runtime/runner-config.template.json"

$runtimeDir = Join-Path $ProjectRoot "runtime"
$runsDir = Join-Path $runtimeDir "runs"
$approvalsDir = Join-Path $runtimeDir "approvals"
$templatePath = Join-Path $runtimeDir "runner-config.template.json"
$configPath = Join-Path $runtimeDir "runner-config.json"

if (-not (Test-Path -LiteralPath $runtimeDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (-not (Test-Path -LiteralPath $runsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $approvalsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $approvalsDir | Out-Null
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

function Ensure-ApprovalFile {
  param(
    [string]$Path,
    [string]$Title
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $payload = [ordered]@{
      approved = $false
      title = $Title
      approved_by = ""
      approved_at = ""
      note = "Set approved=true only after explicit user confirmation."
    } | ConvertTo-Json -Depth 5
    $payload | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Host "[install] created approval file: $Path"
  }
}

Ensure-ApprovalFile -Path (Join-Path $approvalsDir "design-freeze.json") -Title "Design Freeze Approval"
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "rewrite-approval.json") -Title "Rewrite Approval"
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "export-approval.json") -Title "Export Approval"

Write-Host "[install] runtime bootstrap complete."
