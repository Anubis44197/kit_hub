param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Write-Host "[stop-app] local preview is disabled by project policy."
Write-Host "[stop-app] nothing to stop."
