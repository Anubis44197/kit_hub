param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw "Missing KitHub project marker: .kithub-project.json" }

function Read-Utf8JsonIfExists([string]$Path) {
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  return $null
}

$pdfInfo = Get-Command pdfinfo -ErrorAction Stop
$pdfText = Get-Command pdftotext -ErrorAction Stop

$layout = Read-Utf8JsonIfExists (Join-Path $ProjectRoot "revision/_state/layout-plan.json")
if (-not $layout) { throw "Missing layout plan: revision/_state/layout-plan.json" }
$professional = Read-Utf8JsonIfExists (Join-Path $ProjectRoot "revision/_state/studio-professional.json")
$exportDir = Join-Path $ProjectRoot "revision/export"
if (-not (Test-Path -LiteralPath $exportDir -PathType Container)) { throw "Missing export directory: revision/export" }

$marker = Read-Utf8JsonIfExists $markerPath
$title = if ($marker.project_name) { [string]$marker.project_name } else { Split-Path $ProjectRoot -Leaf }
$safeName = ([regex]::Replace($title, '[^\p{L}\p{N}._-]+', '-')).Trim("-")
if (-not $safeName) { $safeName = "kithub-book" }

$width = if ($layout.width_mm) { [double]$layout.width_mm } else { 148 }
$height = if ($layout.height_mm) { [double]$layout.height_mm } else { 210 }
$top = if ($layout.margin_top_mm) { [double]$layout.margin_top_mm } else { 18 }
$inside = if ($layout.margin_inside_mm) { [double]$layout.margin_inside_mm } else { 20 }
$outside = if ($layout.margin_outside_mm) { [double]$layout.margin_outside_mm } else { 16 }
$chapterStartPolicy = if ($layout.chapter_start_policy) { [string]$layout.chapter_start_policy } else { "new_page" }
$publicationProfile = if ($professional.publication -and [string]$professional.publication.profile -in @("kdp","ingram","custom")) { [string]$professional.publication.profile } else { "kdp" }

$episodeDir = Join-Path $ProjectRoot "episode"
$chapterFiles = @(Get-ChildItem -LiteralPath $episodeDir -Filter "*.md" -File | Sort-Object Name)
$chapterTitles = @()
foreach ($chapterFile in $chapterFiles) {
  $content = [IO.File]::ReadAllText($chapterFile.FullName, [Text.Encoding]::UTF8)
  foreach ($titleMatch in [regex]::Matches($content, '(?m)^#\s+(.+?)\s*$')) {
    $chapterTitles += $titleMatch.Groups[1].Value.Trim()
  }
}

function Get-WordBoxes([string]$PdfPath) {
  $tempHtml = Join-Path ([IO.Path]::GetTempPath()) ("kithub-bbox-" + [guid]::NewGuid().ToString("N") + ".html")
  & $pdfText.Source -bbox $PdfPath $tempHtml
  $raw = [IO.File]::ReadAllText($tempHtml, [Text.Encoding]::UTF8)
  if (Test-Path -LiteralPath $tempHtml -PathType Leaf) { Remove-Item -LiteralPath $tempHtml -Force }
  $pages = [System.Collections.Generic.List[object]]::new()
  $pageMatches = [regex]::Matches($raw, '<page width="([\d.]+)" height="([\d.]+)">(.*?)</page>', [Text.RegularExpressions.RegexOptions]::Singleline)
  foreach ($pm in $pageMatches) {
    $pageWidth = [double]$pm.Groups[1].Value
    $pageHeight = [double]$pm.Groups[2].Value
    $words = [System.Collections.Generic.List[object]]::new()
    $wordMatches = [regex]::Matches($pm.Groups[3].Value, '<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>', [Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($wm in $wordMatches) {
      $words.Add([pscustomobject]@{
        xMin = [double]$wm.Groups[1].Value
        yMin = [double]$wm.Groups[2].Value
        xMax = [double]$wm.Groups[3].Value
        yMax = [double]$wm.Groups[4].Value
        text = [System.Net.WebUtility]::HtmlDecode($wm.Groups[5].Value)
      })
    }
    $pages.Add([pscustomobject]@{ width = $pageWidth; height = $pageHeight; words = [object[]]$words })
  }
  return ,[object[]]$pages
}

function Get-PageCount([string]$PdfPath) {
  $info = & $pdfInfo.Source $PdfPath | Out-String
  $m = [regex]::Match($info, '(?m)^Pages:\s+(\d+)')
  return [int]$m.Groups[1].Value
}

function Test-Isbn13 {
  param([string]$Value)
  $digits = ($Value -replace '[^0-9]', '')
  if ($digits.Length -ne 13) { return $false }
  $sum = 0
  for ($index = 0; $index -lt 12; $index++) {
    $digit = [int]::Parse($digits[$index].ToString())
    $sum += $digit * $(if ($index % 2 -eq 0) { 1 } else { 3 })
  }
  $check = (10 - ($sum % 10)) % 10
  return $check -eq [int]::Parse($digits[12].ToString())
}

$interiorCandidates = @(Get-ChildItem -LiteralPath $exportDir -File | Where-Object { $_.Name -like "$safeName-baski*.pdf" } | Sort-Object LastWriteTime -Descending)
$coverCandidates = @(Get-ChildItem -LiteralPath $exportDir -File | Where-Object { $_.Name -like "$safeName-kapak*.pdf" } | Sort-Object LastWriteTime -Descending)

$checks = @()
$interiorInfo = $null
$coverInfo = $null
$results = @()

if ($interiorCandidates.Count) {
  $interiorPdf = $interiorCandidates[0].FullName
  $pages = Get-WordBoxes -PdfPath $interiorPdf
  $pageCount = $pages.Count
  $interiorInfo = [ordered]@{ path = $interiorPdf; pages = $pageCount; width_pts = $pages[0].width; height_pts = $pages[0].height }

  $marginTopPts = $top * 72.0 / 25.4
  $marginBottomPts = $top * 72.0 / 25.4
  $contentTop = $marginTopPts - 8
  $contentBottom = $pages[0].height - $marginBottomPts + 8

  $overflowWords = @()
  $blankPages = @()
  $pageNumberY = $pages[0].height - 14
  for ($pi = 0; $pi -lt $pages.Count; $pi++) {
    $page = $pages[$pi]
    $wordCount = $page.words.Count
    if ($wordCount -eq 0) { $blankPages += ($pi + 1) }
    foreach ($w in $page.words) {
      $tolerance = 0.5
      if ($w.xMin -lt -$tolerance -or $w.xMax -gt ($page.width + $tolerance) -or $w.yMin -lt -$tolerance -or $w.yMax -gt ($page.height + $tolerance)) {
        $overflowWords += [pscustomobject]@{ page = ($pi + 1); text = $w.text; xMin = [Math]::Round($w.xMin,1); xMax = [Math]::Round($w.xMax,1); yMin = [Math]::Round($w.yMin,1); yMax = [Math]::Round($w.yMax,1) }
      }
    }
  }

  $literalArtifacts = @()
  $tempPlain = Join-Path ([IO.Path]::GetTempPath()) ("kithub-plain-" + [guid]::NewGuid().ToString("N") + ".txt")
  & $pdfText.Source $interiorPdf $tempPlain
  $plainText = [IO.File]::ReadAllText($tempPlain, [Text.Encoding]::UTF8)
  if (Test-Path -LiteralPath $tempPlain -PathType Leaf) { Remove-Item -LiteralPath $tempPlain -Force }
  foreach ($pm in [regex]::Matches($plainText, '(\\newpage|\[TOC\]|TODO|FIXME)')) {
    $literalArtifacts += $pm.Groups[1].Value
  }

  $chapterStarts = @()
  foreach ($chapterTitle in $chapterTitles) {
    $foundPage = $null
    for ($pi = 0; $pi -lt $pages.Count; $pi++) {
      $pageWords = $pages[$pi].words | Where-Object { $_.yMin -ge $contentTop -and $_.yMax -le $contentBottom }
      $contentLines = $pageWords | Group-Object { [Math]::Round($_.yMin / 12) } | ForEach-Object { (($_.Group | Sort-Object xMin | ForEach-Object { $_.text }) -join " ").Trim() }
      $firstLine = $contentLines | Select-Object -First 1
      if ($firstLine -and $firstLine -eq $chapterTitle) {
        $foundPage = ($pi + 1)
        break
      }
    }
    $chapterStarts += [pscustomobject]@{
      title = $chapterTitle
      page = $foundPage
      parity = if ($foundPage) { if (($foundPage % 2) -eq 1) { "odd" } else { "even" } } else { "not_found" }
      policy_ok = if ($chapterStartPolicy -eq "recto" -and $foundPage) { (($foundPage % 2) -eq 1) } elseif ($chapterStartPolicy -eq "continuous") { $true } elseif ($foundPage) { $true } else { $false }
    }
  }

  $pageSizeOk = ([Math]::Abs($pages[0].width - ($width * 72.0 / 25.4)) -lt 2) -and ([Math]::Abs($pages[0].height - ($height * 72.0 / 25.4)) -lt 2)

  $checks += [ordered]@{ key = "page_count"; ok = ($pageCount -ge ($chapterTitles.Count + 2)); severity = "blocker"; detail = "$pageCount sayfa / en az $($chapterTitles.Count + 2)" }
  $checks += [ordered]@{ key = "page_size"; ok = $pageSizeOk; severity = "blocker"; detail = if ($pageSizeOk) { "$($width)x$($height) mm ($([Math]::Round($pages[0].width,1))x$([Math]::Round($pages[0].height,1)) pts)" } else { "beklenen ${width}mm x ${height}mm; alinan $([Math]::Round($pages[0].width,1))x$([Math]::Round($pages[0].height,1)) pts" } }
  $checks += [ordered]@{ key = "overflow"; ok = ($overflowWords.Count -eq 0); severity = "blocker"; detail = if ($overflowWords.Count) { "$($overflowWords.Count) kelime sayfa disina tasiyor" } else { "sayfa disina tasan kelime yok" } }
  $checks += [ordered]@{ key = "blank_pages"; ok = ($blankPages.Count -eq 0); severity = "warning"; detail = if ($blankPages.Count) { "bos sayfalar: $($blankPages -join ', ')" } else { "bos sayfa yok" } }
  $checks += [ordered]@{ key = "literal_artifacts"; ok = ($literalArtifacts.Count -eq 0); severity = "warning"; detail = if ($literalArtifacts.Count) { "basilmis surat sablonlari: $($literalArtifacts -join ', ')" } else { "surat sablonu yok" } }
  $checks += [ordered]@{ key = "chapter_starts"; ok = (@($chapterStarts | Where-Object { -not $_.policy_ok }).Count -eq 0); severity = "blocker"; detail = if (@($chapterStarts | Where-Object { -not $_.policy_ok }).Count) { "uygun olmayan bolum baslangici: $(@($chapterStarts | Where-Object { -not $_.policy_ok } | ForEach-Object { "$($_.title)@p$($_.page)" }) -join ', ')" } else { "$(@($chapterStarts).Count) bolum, $chapterStartPolicy politikasi" } }
}

if ($coverCandidates.Count) {
  $coverPdf = $coverCandidates[0].FullName
  $coverPages = Get-WordBoxes -PdfPath $coverPdf
  if ($coverPages.Count) {
    $coverWidthPts = $coverPages[0].width
    $coverHeightPts = $coverPages[0].height
    $coverInfo = [ordered]@{ path = $coverPdf; width_pts = $coverWidthPts; height_pts = $coverHeightPts }

    $coverSpec = $layout.cover_spec
    $spineWidth = 0.0
    $bleed = 0.0
    if ($coverSpec) {
      $bleed = if ($null -ne $coverSpec.bleed_mm) { [double]$coverSpec.bleed_mm } else { 3.2 }
      $spineWidth = if ($coverSpec.spine_width_mm -gt 0) { [double]$coverSpec.spine_width_mm } else { 0 }
      $paperType = if ($coverSpec.paper_type) { [string]$coverSpec.paper_type } else { "cream" }
      if ($spineWidth -le 0) {
        $factor = if ($paperType -eq "white") { 0.0572 } elseif ($paperType -eq "color") { 0.0596 } else { 0.0635 }
        $spineWidth = [double]$coverSpec.page_count * $factor
      }
      $expectedWidthMm = ($width * 2) + $spineWidth + ($bleed * 2)
      $expectedHeightMm = $height + ($bleed * 2)
      $actualWidthMm = $coverWidthPts * 25.4 / 72.0
      $actualHeightMm = $coverHeightPts * 25.4 / 72.0
      $widthOk = [Math]::Abs($actualWidthMm - $expectedWidthMm) -lt 0.6
      $heightOk = [Math]::Abs($actualHeightMm - $expectedHeightMm) -lt 0.6
      $isbn = if ($professional.publication) { ([string]$professional.publication.isbn -replace '[^0-9]', '') } else { "" }
      $barcodeMode = if ($coverSpec.barcode_mode) { [string]$coverSpec.barcode_mode } else { "none" }
      $barcodeOk = $barcodeMode -eq "none" -or (Test-Isbn13 -Value $isbn)
      $checks += [ordered]@{ key = "cover_size"; ok = ($widthOk -and $heightOk); severity = "blocker"; detail = if ($widthOk -and $heightOk) { "kapak $([Math]::Round($actualWidthMm,2))x$([Math]::Round($actualHeightMm,2)) mm (sirt $([Math]::Round($spineWidth,2)) mm)" } else { "beklenen $([Math]::Round($expectedWidthMm,2))x$([Math]::Round($expectedHeightMm,2)) mm; alinan $([Math]::Round($actualWidthMm,2))x$([Math]::Round($actualHeightMm,2)) mm" } }
      $checks += [ordered]@{ key = "cover_barcode"; ok = $barcodeOk; severity = "blocker"; detail = if ($barcodeOk) { if ($barcodeMode -eq "none") { "barkod kapali" } else { "gercek EAN-13 ISBN" } } else { "13 haneli gecerli ISBN-13 gerekli (kontrol basamagi)" } }
      $coverInfo.spine_width_mm = [Math]::Round($spineWidth, 2)
      $coverInfo.expected_width_mm = [Math]::Round($expectedWidthMm, 2)
      $coverInfo.expected_height_mm = [Math]::Round($expectedHeightMm, 2)
      $coverInfo.actual_width_mm = [Math]::Round($actualWidthMm, 2)
      $coverInfo.actual_height_mm = [Math]::Round($actualHeightMm, 2)
    }
  }
}

$blockers = @($checks | Where-Object { $_.severity -eq "blocker" -and -not $_.ok } | ForEach-Object { $_.key })
$warnings = @($checks | Where-Object { $_.severity -eq "warning" -and -not $_.ok } | ForEach-Object { $_.key })
$status = if ($blockers.Count) { "BLOCKED" } elseif ($warnings.Count) { "REVIEW_REQUIRED" } else { "PASS" }

$report = [ordered]@{
  schema_version = "1.0.0"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  title = $title
  publication_profile = $publicationProfile
  chapter_start_policy = $chapterStartPolicy
  page_mm = [ordered]@{ width_mm = $width; height_mm = $height; margin_top_mm = $top; margin_inside_mm = $inside; margin_outside_mm = $outside }
  status = $status
  interior = $interiorInfo
  cover = $coverInfo
  chapters = [object[]]$chapterStarts
  overflow_words = [object[]]$overflowWords
  blank_pages = [object[]]$blankPages
  literal_artifacts = [object[]]$literalArtifacts
  checks = [object[]]$checks
  blockers = [object[]]$blockers
  warnings = [object[]]$warnings
}

$runtimeDir = Join-Path $ProjectRoot "runtime"
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$reportPath = Join-Path $runtimeDir "print-proof-report.json"
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($true))
Write-Host "[print-proof] $status ($(@($checks | Where-Object { $_.severity -eq 'blocker' }).Count) blocker, $(@($checks | Where-Object { $_.severity -eq 'warning' }).Count) warning)"
Write-Output ($report | ConvertTo-Json -Depth 12 -Compress)