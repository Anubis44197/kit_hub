param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [int]$Port = 8765,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$url = "http://127.0.0.1:$Port/"
if (-not $NoBrowser) {
  Start-Process $url | Out-Null
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/studio_bridge.ps1") -RepoRoot $RepoRoot -Port $Port
