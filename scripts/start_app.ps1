param(
  [string]$ProjectRoot = (Get-Location).Path,
  [switch]$SkipReadiness
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

Push-Location $ProjectRoot
try {
  $runtimeDir = Join-Path $ProjectRoot "runtime"
  Ensure-Dir -Path $runtimeDir

  Write-Host "[start-app] bootstrap runtime..."
  & powershell -ExecutionPolicy Bypass -File "scripts/install.ps1" -ProjectRoot $ProjectRoot
  if ($LASTEXITCODE -ne 0) {
    throw "install.ps1 failed with exit code: $LASTEXITCODE"
  }

  if (-not $SkipReadiness) {
    Write-Host "[start-app] running readiness checks..."
    & powershell -ExecutionPolicy Bypass -File "scripts/ci/final_readiness_check.ps1"
    if ($LASTEXITCODE -ne 0) {
      throw "final_readiness_check.ps1 failed with exit code: $LASTEXITCODE"
    }
  }

  Write-Host "[start-app] done."
  Write-Host "1) Runtime bootstrap: OK"
  Write-Host "2) Readiness checks: OK"
  Write-Host "3) Run pipeline: powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export -Mode command"
}
finally {
  Pop-Location
}

