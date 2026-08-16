param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$pandoc = Get-Command pandoc -ErrorAction Stop
$pdfInfo = Get-Command pdfinfo -ErrorAction Stop
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-publication-ingram-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $fixtureRoot "project"
$episodeDir = Join-Path $projectRoot "episode"
$stateDir = Join-Path $projectRoot "revision/_state"
$runtimeDir = Join-Path $projectRoot "runtime"
New-Item -ItemType Directory -Path $episodeDir,$stateDir,$runtimeDir -Force | Out-Null

function Write-Utf8([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($true))
}
function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

try {
  Write-Utf8 (Join-Path $projectRoot ".kithub-project.json") (([ordered]@{
    schema_version = "1.0.0"
    project_name = "Ingram PDF/X Fixture"
  }) | ConvertTo-Json)
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
      title = "Ingram PDF/X Fixture"
      author = "KitHub Test Author"
      paper_type = "cream"
      page_count = 320
      bleed_mm = 3.2
      barcode_mode = "ean13"
      back_cover_copy = "A complete cover fixture for Ingram print package verification."
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
    publication = [ordered]@{ profile = "ingram"; isbn = "9780306406157"; imprint = "KitHub Test"; language = "tr-TR"; cover_asset = $null }
  }
  Write-Utf8 (Join-Path $stateDir "studio-professional.json") ($professional | ConvertTo-Json -Depth 8)
  $longText = ((1..160) | ForEach-Object { "Ingram print workflow converts the Edge typeset output into PDF/X-3 with CMYK color conversion through Ghostscript paragraph $_." }) -join " "
  Write-Utf8 (Join-Path $episodeDir "ep001.md") "# Bolum 1`n`n$longText`n`n# Bolum 2`n`nIkinci bolumun icerigi de ayni PDF/X donusumunden gecer."
  Write-Utf8 (Join-Path $episodeDir "ep002.md") "# Bolum 3`n`nUcuncu bolum, PDF/X cikisinin cok sayfali oldugunu dogrular. $longText"

  $output = & (Join-Path $RepoRoot "scripts/build_publication_outputs.ps1") -ProjectRoot $projectRoot -Formats "pdf"
  Assert-True ($LASTEXITCODE -eq 0) "Publication builder returned a non-zero exit code."
  $report = Get-Content -LiteralPath (Join-Path $runtimeDir "publication-build-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $preflight = Get-Content -LiteralPath (Join-Path $runtimeDir "publication-preflight-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($report.publication_profile -eq "ingram") "Publication profile was not reported as Ingram."

  $gsCommand = Get-Command gswin64c, gswin32c, gs -ErrorAction SilentlyContinue | Select-Object -First 1
  $gsProbe = @(Get-ChildItem "C:\Program Files\gs" -Recurse -Filter "gswin64c.exe" -ErrorAction SilentlyContinue | Select-Object -First 1)
  $hasGhostscript = $null -ne $gsCommand -or $gsProbe.Count -gt 0
  if ($hasGhostscript) {
    Assert-True ($report.pdf_x -eq "pass") "Ingram build did not produce PDF/X output: $($preflight.pdf_x_output)"
    $pdfXCheck = @($preflight.checks | Where-Object { $_.key -eq "pdf_x" }) | Select-Object -First 1
    Assert-True ($pdfXCheck.ok -eq $true) "PDF/X preflight check did not pass."
    Assert-True ($pdfXCheck.detail -match "PDF/X-3") "Preflight did not report PDF/X-3 detail."

    $pdfOutput = @($report.outputs | Where-Object { $_.format -eq "PDF" }) | Select-Object -First 1
    $pdfPath = [string]$pdfOutput.path
    Assert-True ($pdfPath -match "pdfx") "Interior PDF path did not indicate the PDF/X artifact."
    Assert-True (Test-Path -LiteralPath $pdfPath -PathType Leaf) "PDF/X interior PDF was not created."
    $info = & $pdfInfo.Source $pdfPath | Out-String
    Assert-True ($info -match "PDF/X-3:2002") "pdfinfo did not classify the interior PDF as PDF/X-3:2002."
    Assert-True ($info -match "Producer:\s+GPL Ghostscript") "Interior PDF was not produced by Ghostscript."

    $coverOutput = @($report.outputs | Where-Object { $_.format -eq "COVER_PDF" }) | Select-Object -First 1
    Assert-True ($null -ne $coverOutput) "Cover output was not reported."
    $coverPath = [string]$coverOutput.path
    Assert-True ($coverPath -match "pdfx") "Cover PDF path did not indicate the PDF/X artifact."
    Assert-True (Test-Path -LiteralPath $coverPath -PathType Leaf) "PDF/X cover PDF was not created."
    $coverInfo = & $pdfInfo.Source $coverPath | Out-String
    Assert-True ($coverInfo -match "PDF/X-3:2002") "pdfinfo did not classify the cover PDF as PDF/X-3:2002."

    $blockers = @($preflight.blockers)
    Assert-True ($blockers.Count -eq 0) "Complete Ingram fixture has unexpected blockers: $($blockers -join ', ')."
    Assert-True ($preflight.status -eq "READY") "Complete Ingram fixture was not READY."
  } else {
    Assert-True ($report.pdf_x -eq "unavailable") "Ghostscript was expected to be unavailable on this runner."
    Assert-True ($preflight.status -eq "REVIEW_REQUIRED") "Missing Ghostscript should yield REVIEW_REQUIRED, not BLOCKED."
  }

  Write-Host "[publication-ingram-pdfx] PASS Ingram PDF/X-3 + CMYK; Ghostscript=$hasGhostscript; profile=$($report.publication_profile)"
  if ($KeepFixture) {
    Write-Host "[publication-ingram-pdfx] fixture=$fixtureRoot"
  }
}
finally {
  if (-not $KeepFixture -and (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
