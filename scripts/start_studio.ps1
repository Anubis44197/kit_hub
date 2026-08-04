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
$ready = $false
try {
  $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
  $ready = ($health.StatusCode -eq 200)
} catch {}

if (-not $ready) {
  $stdout = Join-Path $RepoRoot "studio-stdout.log"
  $stderr = Join-Path $RepoRoot "studio-stderr.log"
  Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$bridgeScript,"-RepoRoot",$RepoRoot,"-Port",$Port) -WorkingDirectory $RepoRoot -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden | Out-Null
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 200
    try {
      $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
      if ($health.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
  }
}
if (-not $ready) { throw "Studio Bridge did not become ready at $healthUrl" }
Write-Host "[start-studio] bridge ready: $healthUrl"
if (-not $NoBrowser) { Start-Process $url | Out-Null }
