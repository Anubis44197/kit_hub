param(
  [string]$ProjectRoot = (Get-Location).Path,
  [int]$Port = 8765,
  [switch]$SkipReadiness,
  [switch]$NoBrowser,
  [switch]$NoStudio
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
  if ($SkipReadiness) {
    Write-Host "2) Readiness checks: SKIPPED"
  }
  else {
    Write-Host "2) Readiness checks: OK"
  }

  if ($NoStudio) {
    Write-Host "3) Studio launch: SKIPPED"
    Write-Host "Run Studio manually: powershell -ExecutionPolicy Bypass -File scripts/start_studio.ps1 -RepoRoot . -Port $Port"
    return
  }

  $studioScript = Join-Path $ProjectRoot "scripts/start_studio.ps1"
  if (-not (Test-Path -LiteralPath $studioScript -PathType Leaf)) {
    throw "Studio launcher missing: $studioScript"
  }

  Write-Host "[start-app] launching KitHub Studio at http://127.0.0.1:$Port/"
  Write-Host "[start-app] keep this terminal open while using Studio. Press Ctrl+C to stop."
  $args = @("-ExecutionPolicy", "Bypass", "-File", "scripts/start_studio.ps1", "-RepoRoot", $ProjectRoot, "-Port", "$Port")
  if ($NoBrowser) {
    $args += "-NoBrowser"
  }
  & powershell @args
}
finally {
  Pop-Location
}
