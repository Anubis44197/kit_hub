param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = ([Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-publication-build-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$stdoutPath = Join-Path $testRoot "bridge-stdout.log"
$stderrPath = Join-Path $testRoot "bridge-stderr.log"
$bridgeProcess = $null
$allowedOrigin = "http://127.0.0.1:$port"

function Invoke-StudioRequest {
  param([string]$Path,[string]$Method="GET",[object]$Body=$null,[string]$SessionToken="")
  $headers = @{ Origin = $allowedOrigin }
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $request = @{ Uri="http://127.0.0.1:$port$Path"; Method=$Method; Headers=$headers; UseBasicParsing=$true; TimeoutSec=90 }
  if ($null -ne $Body) {
    $request.ContentType = "application/json; charset=utf-8"
    $request.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20))
  }
  return Invoke-WebRequest @request
}

function Write-Utf8([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($true))
}

try {
  $episodeDir = Join-Path $projectRoot "episode"
  $stateDir = Join-Path $projectRoot "revision/_state"
  $runtimeDir = Join-Path $projectRoot "runtime"
  New-Item -ItemType Directory -Path $episodeDir,$stateDir,$runtimeDir -Force | Out-Null
  Write-Utf8 (Join-Path $projectRoot ".kithub-project.json") '{"schema_version":"1.0.0"}'
  $longText = ((1..420) | ForEach-Object { "Bridge publication build keeps measured page flow intact number $_." }) -join " "
  Write-Utf8 (Join-Path $episodeDir "ep001.md") "# First Chapter`n`n$longText"
  $layout = [ordered]@{
    font_family = "Garamond"
    font_size_pt = 11.5
    line_spacing = 1.15
    width_mm = 148
    height_mm = 210
    margin_top_mm = 18
    margin_inside_mm = 20
    margin_outside_mm = 16
    paragraph_first_line_indent_cm = 0.55
    paragraph_spacing_after_pt = 0
    page_design = "classicFrame"
    widow_orphan_control = "strict"
    chapter_start_policy = "new_page"
    running_header_policy = "book_title"
    page_number_position = "bottom_center"
    matter_plan = [ordered]@{
      front = @(
        [pscustomobject]@{ id = "copyright"; title = "Copyright Page"; content = "All rights reserved. First edition."; print = $true; epub = $true }
      )
      back = @(
        [pscustomobject]@{ id = "author"; title = "About the Author"; content = "The author writes measured publication fixtures."; print = $true; epub = $true }
      )
    }
    cover_spec = [ordered]@{
      title = "Bridge Publication Fixture"
      author = "KitHub Test Author"
      paper_type = "cream"
      page_count = 320
      bleed_mm = 3.2
      barcode_mode = "ean13"
      back_cover_copy = "Bridge-level publication build fixture."
      spine_width_mm = 20.32
    }
  }
  Write-Utf8 (Join-Path $stateDir "layout-plan.json") ($layout | ConvertTo-Json -Depth 8)
  $professional = [ordered]@{
    schema_version = "1.0.0"
    comments = @()
    changes = @()
    collaboration = [ordered]@{ current_role = "author"; current_name = "KitHub Test Author"; members = @() }
    writing = [ordered]@{ daily_goal_words = 1000; project_goal_words = 80000; deadline = ""; sessions = @() }
    publication = [ordered]@{ profile = "kdp"; isbn = "9780306406157"; imprint = "KitHub Test"; language = "tr-TR"; cover_asset = $null }
  }
  Write-Utf8 (Join-Path $stateDir "studio-professional.json") ($professional | ConvertTo-Json -Depth 8)

  $bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$bridgeScript,"-RepoRoot",$RepoRoot,"-Port",$port) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
  $ready = $false
  for ($attempt=0; $attempt -lt 60; $attempt++) {
    Start-Sleep -Milliseconds 250
    try { if ((Invoke-StudioRequest -Path "/api/health").StatusCode -eq 200) { $ready=$true; break } } catch {}
  }
  if (-not $ready) { throw "Studio bridge did not become ready on port $port." }
  $session = (Invoke-StudioRequest -Path "/api/session").Content | ConvertFrom-Json
  if (-not $session.token) { throw "Studio session token was not returned." }

  $unsupportedRejected = $false
  try {
    Invoke-StudioRequest -Path "/api/build-publication" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;formats=@("docx")} | Out-Null
  } catch {
    $unsupportedRejected = ([int]$_.Exception.Response.StatusCode -eq 500)
  }
  if (-not $unsupportedRejected) { throw "Unsupported publication format was not rejected by the bridge." }

  $build = (Invoke-StudioRequest -Path "/api/build-publication" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;formats=@("pdf","epub")}).Content | ConvertFrom-Json
  if (-not $build.ok -or $build.exitCode -ne 0) { throw "Bridge publication build failed: $($build.output)" }
  $report = $build.report
  if (-not $report) { throw "Bridge publication build did not return a report." }
  $preflight = $build.preflight
  if (-not $preflight) { throw "Bridge publication build did not return a preflight report." }
  if ([string]$report.preflight_status -notin @("READY","REVIEW_REQUIRED")) { throw "Publication build was not READY." }
  $formats = @($report.outputs | ForEach-Object { $_.format })
  if ("PDF" -notin $formats -or "EPUB" -notin $formats -or "COVER_PDF" -notin $formats) { throw "Expected PDF, EPUB, and COVER_PDF outputs; got: $($formats -join ',')" }
  foreach ($output in $report.outputs) {
    if (-not (Test-Path -LiteralPath ([string]$output.path) -PathType Leaf)) { throw "Reported output was not created: $($output.path)" }
  }
  $pdfOutput = @($report.outputs | Where-Object { $_.format -eq "PDF" }) | Select-Object -First 1
  if ((Get-Item -LiteralPath ([string]$pdfOutput.path)).Length -lt 10000) { throw "Print PDF is unexpectedly small." }
  $epubOutput = @($report.outputs | Where-Object { $_.format -eq "EPUB" }) | Select-Object -First 1
  if ((Get-Item -LiteralPath ([string]$epubOutput.path)).Length -lt 1000) { throw "EPUB package is unexpectedly small." }
  $coverOutput = @($report.outputs | Where-Object { $_.format -eq "COVER_PDF" }) | Select-Object -First 1
  if ([Math]::Abs([double]$coverOutput.spine_width_mm - 20.32) -gt 0.01) { throw "Cover spine width was not preserved through the bridge." }

  if (@($preflight.blockers).Count -ne 0) { throw "Complete fixture has unexpected publication blockers." }

  Write-Host "[studio-bridge-publication-build] PASS pdf+epub+cover via bridge; unsupported-format=rejected; preflight=PREFLIGHT_PASS; spine=$($coverOutput.spine_width_mm)mm"
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) { Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue; $bridgeProcess.WaitForExit(5000) | Out-Null }
  if (Test-Path -LiteralPath $testRoot -PathType Container) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}