param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$pandoc = Get-Command pandoc -ErrorAction Stop
$pdfInfo = Get-Command pdfinfo -ErrorAction Stop
$pdfText = Get-Command pdftotext -ErrorAction Stop
$pdfToPpm = Get-Command pdftoppm -ErrorAction Stop
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-publication-typesetting-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $fixtureRoot "project"
$episodeDir = Join-Path $projectRoot "episode"
$stateDir = Join-Path $projectRoot "revision/_state"
$runtimeDir = Join-Path $projectRoot "runtime"
$renderDir = Join-Path $fixtureRoot "rendered"
New-Item -ItemType Directory -Path $episodeDir,$stateDir,$runtimeDir,$renderDir -Force | Out-Null

function Write-Utf8([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($true))
}
function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

try {
  Write-Utf8 (Join-Path $projectRoot ".kithub-project.json") (([ordered]@{
    schema_version = "1.0.0"
    project_name = "Measured Typesetting Fixture"
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
      title = "Measured Typesetting Fixture"
      author = "KitHub Test Author"
      paper_type = "cream"
      page_count = 320
      bleed_mm = 3.2
      barcode_mode = "placeholder"
      back_cover_copy = "A complete cover fixture for print package verification."
      spine_width_mm = 20.32
    }
  }
  Write-Utf8 (Join-Path $stateDir "layout-plan.json") ($layout | ConvertTo-Json -Depth 8)
  $fixturePath = Join-Path $PSScriptRoot "fixtures/publication-typesetting.md"
  $source = [IO.File]::ReadAllText($fixturePath, [Text.Encoding]::UTF8)
  $longText = ((1..420) | ForEach-Object { "Measured page flow keeps paragraph line groups together and prevents accidental overflow number $_." }) -join " "
  Write-Utf8 (Join-Path $episodeDir "ep001.md") ($source.Replace("{{LONG_TEXT}}", $longText))

  $output = & (Join-Path $RepoRoot "scripts/build_publication_outputs.ps1") -ProjectRoot $projectRoot -Formats "pdf,epub"
  Assert-True ($LASTEXITCODE -eq 0) "Publication builder returned a non-zero exit code."
  $report = Get-Content -LiteralPath (Join-Path $runtimeDir "publication-build-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($report.flow.widow_orphan_control -eq "strict") "Widow/orphan policy was not reported."
  Assert-True ([int]$report.flow.minimum_lines -eq 3) "Strict minimum line count was not reported."
  Assert-True ($report.flow.running_header_policy -eq "book_title") "Running header policy was not reported."
  Assert-True ($report.flow.running_header_strategy -eq "paged_media_margin_box") "Running header strategy was not reported."
  Assert-True ($report.flow.page_number_position -eq "bottom_center") "Page number policy was not reported."
  Assert-True ($report.preflight_status -eq "REVIEW_REQUIRED") "Complete package should require only external review."
  Assert-True ([int]$report.matter.front_count -eq 1 -and [int]$report.matter.back_count -eq 1) "Front/back matter counts were not reported."
  Assert-True ([int]$report.matter.empty_enabled_count -eq 0) "Complete matter was incorrectly reported empty."
  $pdfOutput = @($report.outputs | Where-Object { $_.format -eq "PDF" }) | Select-Object -First 1
  $pdfPath = [string]$pdfOutput.path
  Assert-True (Test-Path -LiteralPath $pdfPath -PathType Leaf) "Print PDF was not created."
  Assert-True ((Get-Item -LiteralPath $pdfPath).Length -gt 10000) "Print PDF is unexpectedly small."
  $epubOutput = @($report.outputs | Where-Object { $_.format -eq "EPUB" }) | Select-Object -First 1
  Assert-True ($null -ne $epubOutput) "EPUB output was not reported."
  Assert-True (Test-Path -LiteralPath ([string]$epubOutput.path) -PathType Leaf) "EPUB package was not created."
  Assert-True ((Get-Item -LiteralPath ([string]$epubOutput.path)).Length -gt 1000) "EPUB package is unexpectedly small."

  $info = & $pdfInfo.Source $pdfPath | Out-String
  $pageMatch = [regex]::Match($info, "(?m)^Pages:\s+(\d+)")
  Assert-True ($pageMatch.Success -and [int]$pageMatch.Groups[1].Value -ge 4) "Print PDF did not paginate into at least four pages."
  $sizeMatch = [regex]::Match($info, "(?m)^Page size:\s+([\d.]+) x ([\d.]+) pts")
  Assert-True ($sizeMatch.Success) "PDF page size was not reported."
  Assert-True ([Math]::Abs([double]$sizeMatch.Groups[1].Value - 419.5) -lt 2) "PDF width is not A5."
  Assert-True ([Math]::Abs([double]$sizeMatch.Groups[2].Value - 595.3) -lt 2) "PDF height is not A5."

  $textPath = Join-Path $fixtureRoot "publication.txt"
  & $pdfText.Source -layout $pdfPath $textPath
  $renderedText = [IO.File]::ReadAllText($textPath, [Text.Encoding]::UTF8)
  Assert-True ($renderedText.Contains("Measured Typesetting Fixture")) "Book title is missing from the PDF."
  Assert-True ($renderedText.Contains("Measured page flow")) "Body text is missing from the PDF."
  Assert-True ($renderedText.Contains("Copyright Page")) "Front matter is missing from the print PDF."
  Assert-True ($renderedText.Contains("About the Author")) "Back matter is missing from the print PDF."
  $pageCount = [int]$pageMatch.Groups[1].Value
  Assert-True ([regex]::Matches($renderedText, "Measured Typesetting Fixture").Count -ge ($pageCount - 1)) "Running book-title header is not present across PDF pages."
  & $pdfToPpm.Source -f 1 -l 1 -png -r 120 $pdfPath (Join-Path $renderDir "first") | Out-Null
  & $pdfToPpm.Source -f $pageCount -l $pageCount -png -r 120 $pdfPath (Join-Path $renderDir "last") | Out-Null
  Assert-True (@(Get-ChildItem -LiteralPath $renderDir -Filter "*.png" -File).Count -eq 2) "First/last page render count mismatch."

  $coverOutput = @($report.outputs | Where-Object { $_.format -eq "COVER_PDF" }) | Select-Object -First 1
  Assert-True ($null -ne $coverOutput) "Full-wrap cover output was not reported."
  Assert-True (Test-Path -LiteralPath ([string]$coverOutput.path) -PathType Leaf) "Full-wrap cover PDF was not created."
  Assert-True ((Get-Item -LiteralPath ([string]$coverOutput.path)).Length -gt 5000) "Full-wrap cover PDF is unexpectedly small."
  Assert-True ([Math]::Abs([double]$coverOutput.spine_width_mm - 20.32) -lt 0.01) "Cover spine width was not preserved."
  $preflight = Get-Content -LiteralPath (Join-Path $runtimeDir "publication-preflight-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True (@($preflight.blockers).Count -eq 0) "Complete fixture has unexpected publication blockers."
  Assert-True (@($preflight.external_reviews).Count -ge 1) "External print/retailer reviews were not retained."

  Write-Host "[publication-typesetting] PASS A5 PDF+EPUB; front/back matter; full-wrap cover; measured flow; PDF pages=$pageCount; external review retained"
  if ($KeepFixture) {
    Write-Host "[publication-typesetting] fixture=$fixtureRoot"
    Write-Host "[publication-typesetting] pdf=$pdfPath"
  }
}
finally {
  if (-not $KeepFixture -and (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
