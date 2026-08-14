param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = ([Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-chapter-manager-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$stdoutPath = Join-Path $testRoot "bridge-stdout.log"
$stderrPath = Join-Path $testRoot "bridge-stderr.log"
$bridgeProcess = $null
$allowedOrigin = "http://127.0.0.1:$port"

function Invoke-StudioRequest {
  param([string]$Path,[string]$Method="GET",[object]$Body=$null,[string]$SessionToken="")
  $headers = @{ Origin = $allowedOrigin }
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $request = @{ Uri="http://127.0.0.1:$port$Path"; Method=$Method; Headers=$headers; UseBasicParsing=$true; TimeoutSec=20 }
  if ($null -ne $Body) {
    $request.ContentType = "application/json; charset=utf-8"
    $request.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20))
  }
  return Invoke-WebRequest @request
}

function Invoke-ChapterAction {
  param([object]$Body,[string]$SessionToken)
  return (Invoke-StudioRequest -Path "/api/manage-chapter" -Method "POST" -SessionToken $SessionToken -Body $Body).Content | ConvertFrom-Json
}

function Invoke-EntityAction {
  param([object]$Body,[string]$SessionToken)
  return (Invoke-StudioRequest -Path /api/manage-entity -Method POST -SessionToken $SessionToken -Body $Body).Content | ConvertFrom-Json
}

try {
  $episodeDir = Join-Path $projectRoot "episode"
  $stateDir = Join-Path $projectRoot "revision/_state"
  New-Item -ItemType Directory -Path $episodeDir,$stateDir -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $projectRoot ".kithub-project.json"), '{"schema_version":"1.0.0"}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $episodeDir "ep001.md"), "# Birinci bölüm", [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $episodeDir "ep002.md"), "# İkinci bölüm", [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $stateDir "character-state.json"), '{"characters":[{"id":"author","name":"Test Author","arc_position":"draft"}]}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $stateDir "world-state.json"), '{"locations":[{"id":"desk","name":"Writing Desk","introduced_in":"EP001"}]}', [Text.UTF8Encoding]::new($true))
  [IO.File]::WriteAllText((Join-Path $stateDir "plot-ledger.json"), '{"open_threads":["Finish the manuscript"],"closed_threads":["Create the project"]}', [Text.UTF8Encoding]::new($true))

  $bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$bridgeScript,"-RepoRoot",$RepoRoot,"-Port",$port) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
  $ready = $false
  for ($attempt=0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    try { if ((Invoke-StudioRequest -Path "/api/health").StatusCode -eq 200) { $ready=$true; break } } catch {}
  }
  if (-not $ready) { throw "Studio bridge did not become ready on port $port." }
  $session = (Invoke-StudioRequest -Path "/api/session").Content | ConvertFrom-Json
  if (-not $session.token) { throw "Studio session token was not returned." }

  $mutualPrintMode = "Kar$([char]0x015F)$([char]0x0131)l$([char]0x0131)kl$([char]0x0131) sayfa"
  $defaultFrontMatter = "K$([char]0x00FC)nye + $([char]0x0130)$([char]0x00E7)indekiler"
  $layoutPayload = @{
    projectRoot = $projectRoot
    layout_profile = "classicNovel"
    book_template = "classicNovel"
    book_template_label = "Classic Novel"
    page_size = "A5 (148 x 210 mm)"
    page_design = "classicFrame"
    print_mode = $mutualPrintMode
    front_matter = $defaultFrontMatter
    font_family = "Garamond"
    font_size_pt = 11.5
    line_spacing = 1.15
    margin_top_mm = 18
    margin_inside_mm = 20
    margin_outside_mm = 16
    paragraph_first_line_indent_cm = 0.55
    paragraph_spacing_after_pt = 0
    widow_orphan_control = "strict"
    chapter_start_policy = "new_page"
    running_header_policy = "book_title"
    page_number_position = "bottom_center"
    matter_plan = @{
      front = @(@{ id="copyright"; title="Copyright"; content="All rights reserved."; print=$true; epub=$true })
      back = @(@{ id="author"; title="About the Author"; content="Author biography."; print=$true; epub=$true })
    }
    cover_spec = @{ title="Bridge Fixture"; author="KitHub"; paper_type="cream"; page_count=240; bleed_mm=3.2; barcode_mode="placeholder"; back_cover_copy="Bridge publication package fixture." }
  }
  $layoutSave = (Invoke-StudioRequest -Path "/api/save-layout-plan" -Method "POST" -SessionToken $session.token -Body $layoutPayload).Content | ConvertFrom-Json
  if (-not $layoutSave.ok) { throw "Publication matter and cover settings were not saved." }
  $professionalState = @{
    comments = @(@{ id="comment-fixture"; chapter="ep001.md"; quote="Birinci"; text="Netlestir."; author="Test Editor"; created_at="2026-08-14T10:00:00Z"; resolved=$false; replies=@() })
    changes = @(@{ id="change-fixture"; chapter="ep001.md"; original="Birinci"; replacement="Ilk"; reason="Tutarlilik"; author="Test Editor"; status="pending"; created_at="2026-08-14T10:00:00Z" })
    collaboration = @{ current_role="editor"; current_name="Test Editor"; members=@(@{ id="member-author"; name="Test Author"; role="author" }) }
    writing = @{ daily_goal_words=1000; project_goal_words=80000; deadline=""; sessions=@() }
    publication = @{ profile="kdp"; isbn="9780306406157"; imprint="KitHub Test"; language="tr-TR"; cover_asset=$null }
  }
  $professionalPayload = @{ projectRoot = $projectRoot; state = $professionalState }
  $professionalSave = (Invoke-StudioRequest -Path "/api/professional-state/save" -Method "POST" -SessionToken $session.token -Body $professionalPayload).Content | ConvertFrom-Json
  if (-not $professionalSave.ok) { throw "Professional Studio state was not saved." }
  Add-Type -AssemblyName System.Drawing
  $coverBitmap = [Drawing.Bitmap]::new(1800,2700)
  $coverStream = [IO.MemoryStream]::new()
  try {
    $coverBitmap.Save($coverStream, [Drawing.Imaging.ImageFormat]::Png)
    $coverBase64 = [Convert]::ToBase64String($coverStream.ToArray())
  }
  finally {
    $coverBitmap.Dispose()
    $coverStream.Dispose()
  }
  $coverUpload = (Invoke-StudioRequest -Path "/api/cover-asset/upload" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;filename="fixture-cover.png";contentBase64=$coverBase64}).Content | ConvertFrom-Json
  $coverReplace = (Invoke-StudioRequest -Path "/api/cover-asset/upload" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;filename="fixture-cover-v2.png";contentBase64=$coverBase64}).Content | ConvertFrom-Json
  $coverRead = (Invoke-StudioRequest -Path "/api/cover-asset/read" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot}).Content | ConvertFrom-Json
  if (-not $coverUpload.ok -or -not $coverReplace.ok -or -not $coverRead.ok -or $coverReplace.asset.width_px -ne 1800 -or $coverReplace.asset.height_px -ne 2700 -or -not $coverRead.contentBase64) { throw "Atomic cover upload/replace/read validation failed." }
  $preflight = (Invoke-StudioRequest -Path "/api/build-publication" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;formats=@();preflightOnly=$true}).Content | ConvertFrom-Json
  if (-not $preflight.ok -or $preflight.preflight.status -ne "PREFLIGHT_PASS") { throw "KDP preflight-only validation did not pass." }
  if (@($preflight.preflight.blockers).Count -ne 0) { throw "Complete publication fixture has unexpected blockers." }

  $autosave = (Invoke-StudioRequest -Path "/api/save-episode" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot;filename="ep001.md";text="# Birinci bölüm güncel";createSnapshot=$false}).Content | ConvertFrom-Json
  if (-not $autosave.ok -or $null -ne $autosave.version) { throw "Autosave did not suppress version snapshot." }
  $leftovers = @(Get-ChildItem -LiteralPath $episodeDir -Force | Where-Object { $_.Name -match "^\.ep001\.md\..+\.(tmp|bak)$" })
  if ($leftovers.Count -ne 0) { throw "Atomic save left temporary files behind." }

  $created = Invoke-ChapterAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="create";title="Yeni bölüm"}
  $renamed = Invoke-ChapterAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="rename";filename=$created.filename;title="Yeniden adlandırıldı"}
  $duplicated = Invoke-ChapterAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="duplicate";filename="ep001.md";title="Birinci bölüm kopyası"}
  $wantedOrder = @($duplicated.filename,"ep002.md","ep001.md",$created.filename)
  $reordered = Invoke-ChapterAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="reorder";filename=$duplicated.filename;order=$wantedOrder}
  $deleted = Invoke-ChapterAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="delete";filename="ep002.md"}
  if (-not ($created.ok -and $renamed.ok -and $duplicated.ok -and $reordered.ok -and $deleted.ok)) { throw "One or more chapter operations failed." }

  $character = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="create";kind="characters";label="Editor";detail="Manuscript editor";role="editor";notes="Continuity owner"}
  $location = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="create";kind="locations";label="Library";detail="Primary setting";notes="Quiet room"}
  $plot = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="create";kind="plot";label="Resolve the mystery";detail="Final reveal";status="open";notes="Chapter three"}
  $research = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="create";kind="research";label="Archive source";detail="Primary source";status="verified";notes="Checked"}
  $researchUpdate = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="update";kind="research";id=$research.id;label="Archive source";detail="Primary source updated";status="verified";notes="Checked twice"}
  $researchDelete = Invoke-EntityAction -SessionToken $session.token -Body @{projectRoot=$projectRoot;action="delete";kind="research";id=$research.id;label="Archive source"}
  if (-not ($character.ok -and $location.ok -and $plot.ok -and $research.ok -and $researchUpdate.ok -and $researchDelete.ok)) { throw "One or more professional entity operations failed." }

  $summary = (Invoke-StudioRequest -Path "/api/project-summary" -Method "POST" -SessionToken $session.token -Body @{projectRoot=$projectRoot}).Content | ConvertFrom-Json
  $entityCounts = "characters=$(@($summary.entities.characters).Count) locations=$(@($summary.entities.locations).Count) plot=$(@($summary.entities.plot).Count) research=$(@($summary.entities.research).Count) researchItems=$($summary.entities.research | ConvertTo-Json -Compress)"
  if (@($summary.entities.characters).Count -ne 2 -or @($summary.entities.locations).Count -ne 2 -or @($summary.entities.plot).Count -ne 3 -or @($summary.entities.research).Count -ne 0) { throw "Project entity CRUD counts were not derived from canonical state files: $entityCounts" }
  if ($summary.professional.publication.isbn -ne "9780306406157" -or @($summary.professional.comments).Count -ne 1 -or @($summary.professional.changes).Count -ne 1) { throw "Professional Studio state was not returned in the project summary." }
  $actualOrder = @($summary.chapters | ForEach-Object { $_.filename })
  $expectedOrder = @($duplicated.filename,"ep001.md",$created.filename)
  if (($actualOrder -join ",") -ne ($expectedOrder -join ",")) { throw "Chapter order was not persisted." }
  if (@($summary.chapters | Where-Object { $_.title -eq "Yeniden adlandırıldı" }).Count -ne 1) { throw "Renamed chapter title was not persisted." }
  $trashRelative = $deleted.trashRelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar)
  $trashPath = Join-Path $projectRoot $trashRelative
  if (-not $deleted.trashRelativePath -or -not (Test-Path -LiteralPath $trashPath -PathType Leaf)) { throw "Deleted chapter was not moved to recoverable trash." }

  Write-Host "[studio-bridge-chapter-manager] PASS publication/preflight; professional-state; cover upload/read; entity CRUD; atomic-save; chapter CRUD/reorder/recoverable-delete"
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) { Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue; $bridgeProcess.WaitForExit(5000) | Out-Null }
  if (Test-Path -LiteralPath $testRoot -PathType Container) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
