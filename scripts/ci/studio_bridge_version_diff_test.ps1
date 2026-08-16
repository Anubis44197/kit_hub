param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = ([Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()
$BaseUrl = "http://127.0.0.1:$port"
$stdoutPath = Join-Path ([IO.Path]::GetTempPath()) ("kithub-version-diff-bridge-" + [guid]::NewGuid().ToString("N") + ".log")
$stderrPath = Join-Path ([IO.Path]::GetTempPath()) ("kithub-version-diff-bridge-" + [guid]::NewGuid().ToString("N") + "-err.log")
$bridgeProcess = $null
$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-version-diff-" + [guid]::NewGuid().ToString("N"))
$episodeDir = Join-Path $projectRoot "episode"
New-Item -ItemType Directory -Path $episodeDir -Force | Out-Null

function Invoke-StudioRequest {
  param(
    [string]$Path,
    [string]$Method = "GET",
    [string]$SessionToken = "",
    [object]$Body = $null
  )
  $headers = @{}
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $params = @{ Uri = "$BaseUrl$Path"; Method = $Method; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 15 }
  if ($null -ne $Body) { $params.ContentType = "application/json"; $params.Body = ($Body | ConvertTo-Json -Depth 8) }
  return Invoke-WebRequest @params
}

try {
$bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$bridgeScript,"-RepoRoot",$RepoRoot,"-Port",$port) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
$ready = $false
for ($attempt=0; $attempt -lt 60; $attempt++) {
  Start-Sleep -Milliseconds 250
  try { if ((Invoke-StudioRequest -Path "/api/health").StatusCode -eq 200) { $ready=$true; break } } catch {}
}
if (-not $ready) { throw "Studio bridge did not become ready on port $port." }

$session = (Invoke-StudioRequest -Path "/api/session").Content | ConvertFrom-Json
if (-not $session.ok -or -not $session.token) { throw "Session token could not be obtained." }

$v1 = (Invoke-StudioRequest -Path "/api/save-episode" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot; filename = "ep001.md"; text = "# Ilk Bolum`n`nDefne kapiyi acti ve icine girdi.`n`nCem arkasindan seslendi: `"Bekle!`"`n"; createSnapshot = $true }).Content | ConvertFrom-Json
if (-not $v1.ok -or -not $v1.version) { throw "Snapshot v1 could not be created." }

$v2 = (Invoke-StudioRequest -Path "/api/save-episode" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot; filename = "ep001.md"; text = "# Ilk Bolum`n`nDefne kapiyi acti ve icine girdi. Sessizlik bogucuydu.`n`nCem arkasindan seslendi: `"Bekle!`"`n`nDefne durdu, arkasina dondu.`n"; createSnapshot = $true }).Content | ConvertFrom-Json
if (-not $v2.ok -or -not $v2.version) { throw "Snapshot v2 could not be created." }
$v2Id = [string]$v2.version.id
$v1Id = [string]$v1.version.id

$history = (Invoke-StudioRequest -Path "/api/version-history" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot }).Content | ConvertFrom-Json
if (-not $history.ok) { throw "Version history failed." }
if (@($history.versions).Count -lt 2) { throw "Expected at least 2 versions, got $(@($history.versions).Count)." }

$v2Files = (Invoke-StudioRequest -Path "/api/version-files" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot; versionId = $v2Id }).Content | ConvertFrom-Json
if (-not $v2Files.ok) { throw "version-files failed for $v2Id." }
$episodeEntry = @($v2Files.files | Where-Object { $_.relativePath -eq "episode/ep001.md" })[0]
if (-not $episodeEntry) { throw "episode/ep001.md missing from version-files." }
if ($episodeEntry.content -notmatch "Sessizlik bogucuydu") { throw "v2 content mismatch." }
if ($episodeEntry.currentContent -notmatch "Sessizlik bogucuydu") { throw "currentContent should reflect the latest saved state." }

$v1Files = (Invoke-StudioRequest -Path "/api/version-files" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot; versionId = $v1Id }).Content | ConvertFrom-Json
$episodeV1 = @($v1Files.files | Where-Object { $_.relativePath -eq "episode/ep001.md" })[0]
if ($episodeV1.content -notmatch "Cem arkasindan seslendi") { throw "v1 content mismatch." }
if ($episodeV1.content -match "Sessizlik bogucuydu") { throw "v1 should not contain the v2-only sentence." }

$traversalBlocked = $false
try {
  Invoke-StudioRequest -Path "/api/version-files" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $projectRoot; versionId = "..%2f..%2fetc" } | Out-Null
}
catch {
  $traversalBlocked = $true
}
if (-not $traversalBlocked) { throw "Version id path traversal was not blocked." }

Write-Host "[studio-bridge-version-diff] PASS version snapshot history; version-files content; current-vs-snapshot; traversal rejection (v1=$v1Id v2=$v2Id)"
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) { Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue; $bridgeProcess.WaitForExit(5000) | Out-Null }
  Remove-Item -LiteralPath $projectRoot -Recurse -Force -ErrorAction SilentlyContinue
}