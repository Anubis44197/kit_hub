param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [int]$Port = 8765,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) {
  throw "Studio bridge script not found: $bridgeScript"
}

$url = "http://127.0.0.1:$Port/"
if (-not $NoBrowser) {
  Start-Process $url | Out-Null
}

Set-Location -LiteralPath $RepoRoot
& $bridgeScript -RepoRoot $RepoRoot -Port $Port
