param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$pidFile = Join-Path $ProjectRoot "runtime\preview.pid"
if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) {
  Write-Host "[stop-app] no preview pid file found."
  exit 0
}

$pidRaw = Get-Content -LiteralPath $pidFile -Raw
$processId = 0
if (-not [int]::TryParse($pidRaw, [ref]$processId)) {
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  Write-Host "[stop-app] invalid pid file removed."
  exit 0
}

$proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
if (-not $proc) {
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  Write-Host "[stop-app] process not running, pid file removed."
  exit 0
}

Stop-Process -Id $processId -Force
Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
Write-Host "[stop-app] preview stopped (PID=$processId)."
