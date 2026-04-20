param(
  [string]$ProjectRoot = (Get-Location).Path,
  [int]$Port = 3000,
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

  $python = Get-Command python -ErrorAction SilentlyContinue
  if (-not $python) {
    throw "Python not found. Install Python 3.x and retry."
  }

  $pidFile = Join-Path $runtimeDir "preview.pid"
  if (Test-Path -LiteralPath $pidFile -PathType Leaf) {
    $existingPidRaw = Get-Content -LiteralPath $pidFile -Raw
    $existingPid = 0
    if ([int]::TryParse($existingPidRaw, [ref]$existingPid)) {
      $running = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
      if ($running) {
        Write-Host "[start-app] preview already running."
        Write-Host "[start-app] url: http://localhost:$Port/"
        exit 0
      }
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  }

  Write-Host "[start-app] starting local preview server on port $Port..."
  $proc = Start-Process -FilePath "python" -ArgumentList @("-m","http.server",$Port) -PassThru
  $proc.Id.ToString() | Set-Content -LiteralPath $pidFile -Encoding ASCII

  Write-Host ""
  Write-Host "RUNNING"
  Write-Host "1) Preview URL: http://localhost:$Port/"
  Write-Host "2) Stop command: powershell -ExecutionPolicy Bypass -File scripts/stop_app.ps1 -ProjectRoot ."
  Write-Host "3) Pipeline command: powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export -Mode command"
}
finally {
  Pop-Location
}

