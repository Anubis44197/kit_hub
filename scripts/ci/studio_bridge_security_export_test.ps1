param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = ([Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-bridge-security-export-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$destinationRoot = Join-Path $testRoot "destination"
$settingsPath = Join-Path $testRoot "provider-settings.json"
$stdoutPath = Join-Path $testRoot "bridge-stdout.log"
$stderrPath = Join-Path $testRoot "bridge-stderr.log"
$bridgeProcess = $null
$allowedOrigin = "http://127.0.0.1:$port"

function Invoke-StudioRequest {
  param([string]$Path,[string]$Method="GET",[object]$Body=$null,[string]$SessionToken="",[string]$Origin=$allowedOrigin,[hashtable]$ExtraHeaders=@{})
  $headers = @{ Origin = $Origin }
  foreach ($key in $ExtraHeaders.Keys) { $headers[$key] = $ExtraHeaders[$key] }
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $request = @{ Uri="http://127.0.0.1:$port$Path"; Method=$Method; Headers=$headers; UseBasicParsing=$true; TimeoutSec=20 }
  if ($null -ne $Body) {
    $request.ContentType = "application/json; charset=utf-8"
    $request.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20))
  }
  return Invoke-WebRequest @request
}

try {
  New-Item -ItemType Directory -Path (Join-Path $projectRoot "runtime/approvals") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $projectRoot "revision/export") -Force | Out-Null
  New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $projectRoot ".kithub-project.json"), '{"schema_version":"1.0.0"}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $projectRoot "runtime/approvals/export-approval.json"), '{"approved":true}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $projectRoot "runtime/project-status.json"), '{"schema_version":"1.0.0","status":"ready"}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllBytes((Join-Path $projectRoot "revision/export/final-book.docx"), [byte[]](80,75,3,4,75,105,116,72,117,98))

  $bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$bridgeScript,"-RepoRoot",$RepoRoot,"-Port",$port,"-ProviderSettingsPath",$settingsPath) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
  $ready = $false
  for ($attempt=0; $attempt -lt 40; $attempt++) { Start-Sleep -Milliseconds 250; try { if ((Invoke-StudioRequest -Path "/api/health").StatusCode -eq 200) { $ready=$true; break } } catch {} }
  if (-not $ready) { throw "Studio bridge did not become ready on port $port." }
  $session = (Invoke-StudioRequest -Path "/api/session").Content | ConvertFrom-Json
  if (-not $session.token) { throw "Studio session token was not returned." }

  $evilRejected = $false
  try { Invoke-StudioRequest -Path "/api/health" -Origin "https://evil.example" | Out-Null }
  catch { $evilRejected = ([int]$_.Exception.Response.StatusCode -eq 403 -and -not $_.Exception.Response.Headers["Access-Control-Allow-Origin"]) }
  if (-not $evilRejected) { throw "Disallowed origin was not rejected without CORS reflection." }
  $preflight = Invoke-StudioRequest -Path "/api/provider-settings" -Method "OPTIONS" -ExtraHeaders @{"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="content-type, x-kithub-session"}
  if ($preflight.Headers["Access-Control-Allow-Origin"] -ne $allowedOrigin) { throw "Allowed origin was not echoed exactly." }
  if ([string]$preflight.Headers["Access-Control-Allow-Headers"] -notmatch '(?i)x-kithub-session') { throw "Preflight does not allow X-KitHub-Session." }

  $fakeKey = "test-key-that-must-never-be-returned"
  $initial = (Invoke-StudioRequest -Path "/api/provider-settings" -Method "POST" -SessionToken $session.token -Body @{provider="custom-openai";model="test-model";baseUrl="https://one.example/v1/chat/completions";apiKey=$fakeKey;test=$false}).Content | ConvertFrom-Json
  if (-not $initial.ok -or -not $initial.hasApiKey) { throw "Initial provider settings were not saved." }
  $endpointChangeRejected = $false
  try { Invoke-StudioRequest -Path "/api/provider-settings" -Method "POST" -SessionToken $session.token -Body @{provider="custom-openai";model="test-model";baseUrl="https://two.example/v1/chat/completions";test=$false} | Out-Null }
  catch { $endpointChangeRejected = ([int]$_.Exception.Response.StatusCode -eq 500) }
  if (-not $endpointChangeRejected) { throw "Provider endpoint changed while preserving an old API key." }
  $publicSettings = (Invoke-StudioRequest -Path "/api/provider-settings" -SessionToken $session.token).Content
  if ($publicSettings -match [regex]::Escape($fakeKey) -or $publicSettings -match 'apiKeyProtected') { throw "Provider settings endpoint leaked secret material." }
  $savedSettings = [IO.File]::ReadAllText($settingsPath,[Text.Encoding]::UTF8)
  if ($savedSettings -match [regex]::Escape($fakeKey)) { throw "Provider settings file stored plaintext API key." }

  $firstExport = (Invoke-StudioRequest -Path "/api/export-final" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;outputTarget="Selected folder";destinationDirectory=$destinationRoot}).Content | ConvertFrom-Json
  if (-not $firstExport.ok -or $firstExport.destinationDirectory -ne $destinationRoot) { throw "Selected export directory was not honored." }
  $firstPath = [string]$firstExport.manifest.final_output_path
  if (-not (Test-Path -LiteralPath $firstPath -PathType Leaf) -or (Split-Path -Parent $firstPath) -ne $destinationRoot) { throw "First export was not written to selected directory." }
  $secondExport = (Invoke-StudioRequest -Path "/api/export-final" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;outputTarget="Selected folder";destinationDirectory=$destinationRoot}).Content | ConvertFrom-Json
  $secondPath = [string]$secondExport.manifest.final_output_path
  if (-not $secondExport.ok -or $secondPath -eq $firstPath -or -not $secondExport.manifest.collision_renamed) { throw "Second export silently overwrote first DOCX." }
  if (-not (Test-Path -LiteralPath $firstPath) -or -not (Test-Path -LiteralPath $secondPath)) { throw "Both collision-safe exports were not preserved." }
  Write-Host "[studio-bridge-security-export] PASS cors=session-header; endpoint-key=fail-closed; selected-folder=honored; collision=renamed"
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) { Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue; $bridgeProcess.WaitForExit(5000) | Out-Null }
  if (Test-Path -LiteralPath $testRoot -PathType Container) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
