param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-print-proof-" + [guid]::NewGuid().ToString("N"))
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
    project_name = "Print Proof Fixture"
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
      title = "Print Proof Fixture"
      author = "KitHub Test Author"
      paper_type = "cream"
      page_count = 320
      bleed_mm = 3.2
      barcode_mode = "ean13"
      back_cover_copy = "A complete cover fixture for print proof verification."
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
  $longText = ((1..300) | ForEach-Object { "Print proof checks measure the rendered page flow and keep Turkish diacritics like omuz and gol inside the content area paragraph $_." }) -join " "
  Write-Utf8 (Join-Path $episodeDir "ep001.md") "# Bolum 1`n`n$longText`n`n# Bolum 2`n`nIkinci bolumun icerigi de ayni sayfa akisindan gecer. $longText"

  $output = & (Join-Path $RepoRoot "scripts/build_publication_outputs.ps1") -ProjectRoot $projectRoot -Formats "pdf"
  Assert-True ($LASTEXITCODE -eq 0) "Publication builder returned a non-zero exit code."

  $proof = & (Join-Path $RepoRoot "scripts/print_proof_check.ps1") -ProjectRoot $projectRoot
  Assert-True ($LASTEXITCODE -eq 0) "Print proof check returned a non-zero exit code."
  $report = Get-Content -LiteralPath (Join-Path $runtimeDir "print-proof-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json

  Assert-True ($report.status -eq "PASS") "Print proof did not PASS: $($report.blockers -join ', ')"
  Assert-True (@($report.blockers).Count -eq 0) "Print proof reported blockers: $($report.blockers -join ', ')"
  $chapterChecks = @($report.checks | Where-Object { $_.key -eq "chapter_starts" })
  Assert-True ($chapterChecks.Count -eq 1 -and $chapterChecks[0].ok -eq $true) "Chapter start detection failed on the printed PDF."
  Assert-True (@($report.chapters).Count -ge 2) "Expected at least two detected chapters."
  foreach ($chapter in @($report.chapters)) {
    Assert-True ($null -ne $chapter.page -and [int]$chapter.page -gt 0) "Chapter '$($chapter.title)' was not located on any page."
    Assert-True ($chapter.policy_ok -eq $true) "Chapter '$($chapter.title)' violated the chapter start policy."
  }
  Assert-True ($null -ne $report.cover) "Cover dimensions were not reported."
  Assert-True ($report.cover.actual_width_mm -gt 0 -and $report.cover.actual_height_mm -gt 0) "Cover dimensions are not positive."
  $coverSizeCheck = @($report.checks | Where-Object { $_.key -eq "cover_size" })
  Assert-True ($coverSizeCheck.Count -eq 1 -and $coverSizeCheck[0].ok -eq $true) "Cover size check did not pass."
  $overflowCheck = @($report.checks | Where-Object { $_.key -eq "overflow" })
  Assert-True ($overflowCheck.Count -eq 1 -and $overflowCheck[0].ok -eq $true) "Overflow check did not pass."

  Write-Host "[print-proof-test] PASS; chapters=$(@($report.chapters).Count); pages=$($report.interior.pages); cover=$($report.cover.actual_width_mm)x$($report.cover.actual_height_mm) mm"
  if ($KeepFixture) {
    Write-Host "[print-proof-test] fixture=$fixtureRoot"
  }
}
finally {
  if (-not $KeepFixture -and (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
