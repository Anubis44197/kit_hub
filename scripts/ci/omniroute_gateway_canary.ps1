[CmdletBinding()]
param(
  [string]$ProjectRoot=(Get-Location).Path,
  [int]$TimeoutSeconds=180
)

$ErrorActionPreference='Stop'

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$omniRoot = Join-Path $ProjectRoot '_external/omniroute-work'
$dataDir = Join-Path $ProjectRoot 'runtime/omniroute-data'
$reportDir = Join-Path $ProjectRoot 'runtime/fixture-reports'
$stdoutPath = Join-Path $reportDir 'omniroute-gateway-canary.stdout.log'
$stderrPath = Join-Path $reportDir 'omniroute-gateway-canary.stderr.log'

if (-not (Test-Path -LiteralPath (Join-Path $omniRoot 'package.json') -PathType Leaf)) {
  throw "OmniRoute workspace missing: $omniRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $omniRoot '.build/next/BUILD_ID') -PathType Leaf)) {
  throw "OmniRoute production build missing: $omniRoot\.build\next\BUILD_ID"
}

New-Item -ItemType Directory -Force -Path $dataDir, $reportDir | Out-Null
Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

$initialPassword = [guid]::NewGuid().ToString('N')
$cmd = @(
  'set NEXT_TELEMETRY_DISABLED=1',
  'set HOST=127.0.0.1',
  'set PORT=20128',
  'set DASHBOARD_PORT=20128',
  'set API_PORT=8787',
  "set DATA_DIR=$dataDir",
  "set INITIAL_PASSWORD=$initialPassword",
  'set PRICING_SYNC_ENABLED=false',
  "npm run start > `"$stdoutPath`" 2> `"$stderrPath`""
) -join '&& '

$process = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $cmd) -WorkingDirectory $omniRoot -PassThru -WindowStyle Hidden
$startedAt = Get-Date
$health = $null

try {
  while (((Get-Date) - $startedAt).TotalSeconds -lt $TimeoutSeconds) {
    Start-Sleep -Seconds 2
    foreach ($url in @('http://127.0.0.1:8787/v1/models', 'http://127.0.0.1:20128/v1/models')) {
      try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 4
        $health = [ordered]@{
          url = $url
          status = [int]$response.StatusCode
          body_prefix = $response.Content.Substring(0, [Math]::Min(300, $response.Content.Length))
        }
        break
      } catch {
        $null = $_
      }
    }
    if ($health) { break }
    if ($process.HasExited) { break }
  }
}
finally {
  if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
}

$stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
$stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
$stdout = if ($null -eq $stdout) { '' } else { $stdout }
$stderr = if ($null -eq $stderr) { '' } else { $stderr }
$exitCode = if ($process.HasExited) { $process.ExitCode } else { $null }

if (-not $health) {
  throw "OmniRoute gateway canary failed. exitCode=$exitCode stdout_tail=$($stdout.Substring([Math]::Max(0, $stdout.Length - 1000))) stderr_tail=$($stderr.Substring([Math]::Max(0, $stderr.Length - 1000)))"
}

[ordered]@{
  schema_version = '1.0.0'
  status = 'pass'
  process_id = $process.Id
  health = $health
  stdout = $stdoutPath
  stderr = $stderrPath
} | ConvertTo-Json -Depth 6
