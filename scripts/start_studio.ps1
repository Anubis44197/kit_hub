param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [int]$Port = 8765,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$url = "http://127.0.0.1:$Port/"
$healthUrl = "$url" + "api/health"
$wizardAssetUrl = "$url" + "assets/studio-wizard.js"
$ready = $false
$launchedWithFallback = $false

function Test-StudioBridgeReady {
  try {
    $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
    if ($health.StatusCode -ne 200) { return $false }
    $wizardAsset = Invoke-WebRequest -Uri $wizardAssetUrl -UseBasicParsing -TimeoutSec 2
    return ($wizardAsset.StatusCode -eq 200)
  } catch {
    return $false
  }
}

function Stop-StudioPortListener {
  $pids = @()
  $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($conn) {
    $pids += @($conn.OwningProcess)
  }
  if (-not $pids.Count) {
    $netstat = netstat -ano | Select-String (":$Port\s+.*LISTENING\s+(\d+)")
    foreach ($line in $netstat) {
      $match = [regex]::Match([string]$line, "LISTENING\s+(\d+)\s*$")
      if ($match.Success) { $pids += [int]$match.Groups[1].Value }
    }
  }
  $pids | Sort-Object -Unique | Where-Object { $_ -gt 0 } | ForEach-Object {
    Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 600
}

try {
  $ready = Test-StudioBridgeReady
} catch {}

if (-not $ready) {
  Stop-StudioPortListener

  $stdout = Join-Path $RepoRoot "studio-stdout.log"
  $stderr = Join-Path $RepoRoot "studio-stderr.log"
  Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue

  # Konsol kapanınca ölmesin diye köprüyü tamamen bağımsız (WMI) süreç olarak başlat.
  $inner = "`"$PSHOME\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$bridgeScript`" -RepoRoot `"$RepoRoot`" -Port $Port"
  $wrapped = "cmd.exe /c `"$inner > `"$stdout`" 2> `"$stderr`"`""
  try {
    $null = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
      CommandLine = $wrapped
      CurrentDirectory = $RepoRoot
    }
  }
  catch {
    $launchedWithFallback = $true
    $fallbackCommand = "start `"KitHub Studio Bridge`" /min cmd.exe /c `"$inner > `"$stdout`" 2> `"$stderr`"`""
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "cmd.exe"
    $startInfo.Arguments = "/c $fallbackCommand"
    $startInfo.WorkingDirectory = $RepoRoot
    $startInfo.UseShellExecute = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    [void][System.Diagnostics.Process]::Start($startInfo)
  }

  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 300
    try {
      if (Test-StudioBridgeReady) { $ready = $true; break }
    } catch {}
  }
}
if (-not $ready) {
  Write-Host "[start-studio] Studio baslatilamadi. Son hata loglari:"
  if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr | Select-Object -Last 20 }
  throw "Studio Bridge did not become ready at $healthUrl"
}
Write-Host "[start-studio] bridge ready: $healthUrl"
if ($launchedWithFallback) {
  Write-Host "[start-studio] WMI unavailable; used cmd/start detached fallback."
}
if (-not $NoBrowser) { Start-Process $url | Out-Null }
