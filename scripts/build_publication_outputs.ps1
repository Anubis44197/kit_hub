param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$Formats = "pdf,epub",
  [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$formatList = if ($PreflightOnly) { @() } else { @($Formats.Split(",") | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }) }
if ((-not $formatList.Count -and -not $PreflightOnly) -or @($formatList | Where-Object { $_ -notin @("pdf","epub") }).Count) {
  throw "Formats must contain pdf, epub, or both."
}
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw "Missing KitHub project marker: .kithub-project.json" }
$episodeDir = Join-Path $ProjectRoot "episode"
$chapters = @(Get-ChildItem -LiteralPath $episodeDir -Filter "*.md" -File | Sort-Object Name)
if (-not $chapters.Count) { throw "No Markdown chapters found under episode/." }
$pandoc = if ($formatList.Count) { Get-Command pandoc -ErrorAction Stop } else { $null }
$edge = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($formatList -contains "pdf" -and -not $edge) { throw "Microsoft Edge is required for print PDF generation." }

$marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$layoutPath = Join-Path $ProjectRoot "revision/_state/layout-plan.json"
$layout = if (Test-Path -LiteralPath $layoutPath -PathType Leaf) {
  Get-Content -LiteralPath $layoutPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else { [pscustomobject]@{} }
$title = if ($marker.project_name) { [string]$marker.project_name } else { Split-Path $ProjectRoot -Leaf }
$safeName = ([regex]::Replace($title, '[^\p{L}\p{N}._-]+', '-')).Trim("-")
if (-not $safeName) { $safeName = "kithub-book" }
$font = if ($layout.font_family) { [string]$layout.font_family } else { "Garamond" }
$fontSize = if ($layout.font_size_pt) { [double]$layout.font_size_pt } else { 11.5 }
$lineSpacing = if ($layout.line_spacing) { [double]$layout.line_spacing } else { 1.15 }
$width = if ($layout.width_mm) { [double]$layout.width_mm } else { 148 }
$height = if ($layout.height_mm) { [double]$layout.height_mm } else { 210 }
$top = if ($layout.margin_top_mm) { [double]$layout.margin_top_mm } else { 18 }
$inside = if ($layout.margin_inside_mm) { [double]$layout.margin_inside_mm } else { 20 }
$outside = if ($layout.margin_outside_mm) { [double]$layout.margin_outside_mm } else { 16 }
$indent = if ($layout.paragraph_first_line_indent_cm -ne $null) { [double]$layout.paragraph_first_line_indent_cm } else { 0.55 }
$after = if ($layout.paragraph_spacing_after_pt -ne $null) { [double]$layout.paragraph_spacing_after_pt } else { 0 }
$pageDesign = if ($layout.page_design) { [string]$layout.page_design } else { "classicFrame" }
$widowOrphanPolicy = if ($layout.widow_orphan_control) { [string]$layout.widow_orphan_control } else { "strict" }
$widowOrphanLines = switch ($widowOrphanPolicy) {
  "off" { 1 }
  "standard" { 2 }
  default { 3 }
}
$chapterStartPolicy = if ($layout.chapter_start_policy) { [string]$layout.chapter_start_policy } else { "new_page" }
$chapterBreak = switch ($chapterStartPolicy) {
  "continuous" { "auto" }
  "recto" { "right" }
  default { "page" }
}
$runningHeaderPolicy = if ($layout.running_header_policy) { [string]$layout.running_header_policy } else { "none" }
$pageNumberPosition = if ($layout.page_number_position) { [string]$layout.page_number_position } else { "bottom_center" }
$cssTitle = $title.Replace("\", "\\").Replace('"', '\"')
$runningHeaderValue = if ($runningHeaderPolicy -eq "book_title") { '"' + $cssTitle + '"' } elseif ($runningHeaderPolicy -eq "chapter_title") { "string(chapter-title)" } else { "" }
$runningHeaderCss = if ($runningHeaderValue) {
  @"
@page:left { @top-center { content: $runningHeaderValue; color: #6a5a41; font-size: 8.5pt; letter-spacing: 0.08em; } }
@page:right { @top-center { content: $runningHeaderValue; color: #6a5a41; font-size: 8.5pt; letter-spacing: 0.08em; } }
"@
} else { "" }
$pageNumberCss = switch ($pageNumberPosition) {
  "none" { "" }
  "bottom_outer" {
    @"
@page:left { @bottom-left { content: counter(page); color: #6a5a41; font-size: 8.5pt; } }
@page:right { @bottom-right { content: counter(page); color: #6a5a41; font-size: 8.5pt; } }
"@
  }
  "top_outer" {
    @"
@page:left { @top-left { content: counter(page); color: #6a5a41; font-size: 8.5pt; } }
@page:right { @top-right { content: counter(page); color: #6a5a41; font-size: 8.5pt; } }
"@
  }
  default {
    @"
@page { @bottom-center { content: counter(page); color: #6a5a41; font-size: 8.5pt; } }
"@
  }
}
$decoration = switch ($pageDesign) {
  "minimalEditorial" { "border-bottom: 1px solid #777; text-align: left; padding-bottom: 0.35em;" }
  "artDeco" { "border: 3px double #8a6a38; padding: 0.55em; letter-spacing: 0.08em;" }
  "botanical" { "border-bottom: 1px solid #68734e; color: #435033; padding-bottom: 0.4em;" }
  default { "text-align: center; border-bottom: 1px solid #8a7a62; padding-bottom: 0.35em;" }
}

$workspace = Join-Path $ProjectRoot "revision/_workspace/publication"
$exportDir = Join-Path $ProjectRoot "revision/export"
New-Item -ItemType Directory -Path $workspace,$exportDir -Force | Out-Null
$cssPath = Join-Path $workspace "publication.css"
$htmlPath = Join-Path $workspace "publication.html"
$matterPlan = $layout.matter_plan
function Write-MatterMarkdown {
  param([string]$Side, [string]$Format)
  if (-not $matterPlan) { return $null }
  $items = @($matterPlan.$Side | Where-Object { $_.$Format -eq $true })
  if (-not $items.Count) { return $null }
  $path = Join-Path $workspace "$Side-$Format.md"
  $parts = @()
  foreach ($item in $items) {
    $heading = ([string]$item.title).Trim()
    $content = ([string]$item.content).Trim()
    if (-not $heading) { continue }
    $parts += "# $heading"
    if ($content) { $parts += $content } else { $parts += "_İçerik yayın öncesinde tamamlanmalıdır._" }
    $parts += "\newpage"
  }
  $separator = [Environment]::NewLine + [Environment]::NewLine
  [IO.File]::WriteAllText($path, ($parts -join $separator), [Text.UTF8Encoding]::new($false))
  return $path
}
$frontPrintPath = Write-MatterMarkdown -Side "front" -Format "print"
$backPrintPath = Write-MatterMarkdown -Side "back" -Format "print"
$frontEpubPath = Write-MatterMarkdown -Side "front" -Format "epub"
$backEpubPath = Write-MatterMarkdown -Side "back" -Format "epub"
$css = @"
@page { size: ${width}mm ${height}mm; margin: ${top}mm ${outside}mm ${top}mm ${inside}mm; }
@page:left { margin-left: ${outside}mm; margin-right: ${inside}mm; }
@page:right { margin-left: ${inside}mm; margin-right: ${outside}mm; }
$runningHeaderCss
$pageNumberCss
html { font-family: "$font", Garamond, "Times New Roman", serif; color: #17130f; background: white; }
body { font-size: ${fontSize}pt; line-height: $lineSpacing; text-rendering: optimizeLegibility; }
h1 { string-set: chapter-title content(text); break-before: $chapterBreak; page-break-before: $(if ($chapterBreak -eq "auto") { "auto" } else { "always" }); break-after: avoid; page-break-after: avoid; $decoration }
h2, h3 { break-after: avoid; page-break-after: avoid; break-inside: avoid; }
p, li { widows: $widowOrphanLines; orphans: $widowOrphanLines; }
p { margin: 0 0 ${after}pt; text-align: justify; text-indent: ${indent}cm; hyphens: auto; }
h1 + p, h2 + p, h3 + p, blockquote p { text-indent: 0; }
blockquote { margin: 1em 1.5em; }
a { color: inherit; text-decoration: none; }
nav#TOC { break-after: page; page-break-after: always; }
nav#TOC ul { margin: 1.2em 0 0; padding: 0; list-style: none; }
nav#TOC ul ul { margin: 0.35em 0 0 1.25em; }
nav#TOC li { margin: 0.35em 0; }
img { max-width: 100%; max-height: 80vh; break-inside: avoid; }
figure, table, pre { break-inside: avoid; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #999; padding: 0.35em; }
"@
[IO.File]::WriteAllText($cssPath, $css, [Text.UTF8Encoding]::new($false))

$common = @("--from=commonmark_x","--standalone","--toc","--section-divs","--metadata","lang=tr-TR","--metadata","title=$title")
$chapterInputs = @($chapters | ForEach-Object { $_.FullName })
$printInputs = @(@($frontPrintPath) + $chapterInputs + @($backPrintPath) | Where-Object { $_ })
$epubInputs = @(@($frontEpubPath) + $chapterInputs + @($backEpubPath) | Where-Object { $_ })
$results = @()
$epubCheckStatus = "not_run"
$epubCheckOutput = ""
$pdfFontStatus = "not_run"
$pdfFontOutput = ""
if ($formatList -contains "epub") {
  $epubPath = Join-Path $exportDir "$safeName-dijital.epub"
  $args = @($common + @("--css=$cssPath","--output=$epubPath") + $epubInputs)
  $cover = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "design") -File -ErrorAction SilentlyContinue | Where-Object Extension -Match '^\.(png|jpe?g)$' | Select-Object -First 1)
  if ($cover.Count) { $args = @("--epub-cover-image=$($cover[0].FullName)") + $args }
  & $pandoc.Source @args
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $epubPath -PathType Leaf)) { throw "Pandoc EPUB generation failed." }
  $epubCheck = Get-Command epubcheck -ErrorAction SilentlyContinue
  if ($epubCheck) {
    $epubCheckOutput = ((& $epubCheck.Source $epubPath 2>&1) | Out-String).Trim()
    $epubCheckStatus = if ($LASTEXITCODE -eq 0) { "pass" } else { "fail" }
  } else {
    $epubCheckStatus = "unavailable"
  }
  $results += [ordered]@{ format = "EPUB"; path = $epubPath; bytes = (Get-Item -LiteralPath $epubPath).Length }
}
if ($formatList -contains "pdf") {
  & $pandoc.Source @common "--css=$cssPath" "--output=$htmlPath" @printInputs
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { throw "Pandoc HTML generation failed." }
  $pdfPath = Join-Path $exportDir "$safeName-baski.pdf"
  $htmlUri = ([Uri]$htmlPath).AbsoluteUri
  $process = Start-Process -FilePath $edge -ArgumentList @("--headless=new","--disable-gpu","--no-pdf-header-footer","--print-to-pdf=$pdfPath",$htmlUri) -WindowStyle Hidden -Wait -PassThru
  if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pdfPath -PathType Leaf)) { throw "Edge print PDF generation failed." }
  $pdfFonts = Get-Command pdffonts -ErrorAction SilentlyContinue
  if ($pdfFonts) {
    $pdfFontOutput = ((& $pdfFonts.Source $pdfPath 2>&1) | Out-String).Trim()
    $fontRows = @($pdfFontOutput -split [Environment]::NewLine | Where-Object { $_ -match '\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+\d+\s+\d+\s*$' })
    $unembeddedFonts = @($fontRows | Where-Object { $_ -notmatch '\s+yes\s+(yes|no)\s+(yes|no)\s+\d+\s+\d+\s*$' })
    $pdfFontStatus = if ($fontRows.Count -gt 0 -and $unembeddedFonts.Count -eq 0) { "pass" } else { "fail" }
  } else {
    $pdfFontStatus = "unavailable"
  }
  $results += [ordered]@{ format = "PDF"; path = $pdfPath; bytes = (Get-Item -LiteralPath $pdfPath).Length }

  if ($layout.cover_spec) {
    function Escape-Html([string]$Value) { return [System.Net.WebUtility]::HtmlEncode($Value) }
    $coverSpec = $layout.cover_spec
    $coverBleed = [double]$coverSpec.bleed_mm
    $spineWidth = [double]$coverSpec.spine_width_mm
    if ($spineWidth -le 0) {
      $factor = if ($coverSpec.paper_type -eq "white") { 0.0572 } elseif ($coverSpec.paper_type -eq "color") { 0.0596 } else { 0.0635 }
      $spineWidth = [double]$coverSpec.page_count * $factor
    }
    $coverWidth = ($width * 2) + $spineWidth + ($coverBleed * 2)
    $coverHeight = $height + ($coverBleed * 2)
    $coverHtmlPath = Join-Path $workspace "cover.html"
    $coverPdfPath = Join-Path $exportDir "$safeName-kapak.pdf"
    $coverTitle = Escape-Html ([string]$coverSpec.title)
    $coverAuthor = Escape-Html ([string]$coverSpec.author)
    $coverBack = (Escape-Html ([string]$coverSpec.back_cover_copy)).Replace([Environment]::NewLine, "<br>")
    $coverSpineText = if ([int]$coverSpec.page_count -ge 80) { "$coverTitle · $coverAuthor" } else { "" }
    $barcode = if ($coverSpec.barcode_mode -eq "placeholder") { '<div class="barcode">BARKOD / ISBN ALANI</div>' } else { "" }
    $coverHtml = @"
<!doctype html><html lang="tr"><head><meta charset="utf-8"><style>
@page { size: ${coverWidth}mm ${coverHeight}mm; margin: 0; }
* { box-sizing: border-box; }
html, body { width: ${coverWidth}mm; height: ${coverHeight}mm; margin: 0; }
body { font-family: "$font", Garamond, serif; color: #1f1a14; background: #e8dfcf; }
.wrap { position: absolute; inset: ${coverBleed}mm; display: grid; grid-template-columns: ${width}mm ${spineWidth}mm ${width}mm; height: ${height}mm; }
.back, .front { padding: 16mm 12mm; position: relative; overflow: hidden; }
.front { display: grid; place-content: center; gap: 8mm; text-align: center; border-left: .2mm solid rgba(0,0,0,.16); }
.front h1 { margin: 0; font-size: 30pt; line-height: 1.08; }
.front p { margin: 0; font-size: 13pt; letter-spacing: .08em; }
.back { font: 11pt/1.55 "$font", Garamond, serif; border-right: .2mm solid rgba(0,0,0,.16); }
.spine { display: grid; place-content: center; padding: 4mm 1mm; color: #f5ead7; background: #29241e; writing-mode: vertical-rl; text-orientation: mixed; letter-spacing: .04em; text-align: center; }
.barcode { position: absolute; right: 12mm; bottom: 12mm; width: 36mm; height: 25mm; display: grid; place-content: center; border: .25mm dashed #655d52; background: #fff; color: #655d52; font: 7pt/1 Arial; }
</style></head><body><main class="wrap"><section class="back">$coverBack$barcode</section><section class="spine">$coverSpineText</section><section class="front"><h1>$coverTitle</h1><p>$coverAuthor</p></section></main></body></html>
"@
    [IO.File]::WriteAllText($coverHtmlPath, $coverHtml, [Text.UTF8Encoding]::new($false))
    $coverUri = ([Uri]$coverHtmlPath).AbsoluteUri
    $coverProcess = Start-Process -FilePath $edge -ArgumentList @("--headless=new","--disable-gpu","--no-pdf-header-footer","--print-to-pdf=$coverPdfPath",$coverUri) -WindowStyle Hidden -Wait -PassThru
    if ($coverProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $coverPdfPath -PathType Leaf)) { throw "Full-wrap cover PDF generation failed." }
    $results += [ordered]@{ format = "COVER_PDF"; path = $coverPdfPath; bytes = (Get-Item -LiteralPath $coverPdfPath).Length; width_mm = [Math]::Round($coverWidth, 3); height_mm = [Math]::Round($coverHeight, 3); spine_width_mm = [Math]::Round($spineWidth, 3) }
  }
}

$frontItems = @($layout.matter_plan.front)
$backItems = @($layout.matter_plan.back)
$emptyMatter = @($frontItems + $backItems | Where-Object { ($_.print -eq $true -or $_.epub -eq $true) -and -not ([string]$_.content).Trim() })
$coverConfigured = $null -ne $layout.cover_spec -and ([string]$layout.cover_spec.title).Trim() -and ([string]$layout.cover_spec.author).Trim() -and ([string]$layout.cover_spec.back_cover_copy).Trim()
$coverGenerated = @($results | Where-Object { $_.format -eq "COVER_PDF" }).Count -gt 0
$interiorGenerated = @($results | Where-Object { $_.format -eq "PDF" }).Count -gt 0
$epubGenerated = @($results | Where-Object { $_.format -eq "EPUB" }).Count -gt 0
$checks = @(
  [ordered]@{ key = "manuscript"; ok = ($chapters.Count -gt 0); severity = "blocker"; detail = "$($chapters.Count) bölüm" },
  [ordered]@{ key = "front_matter"; ok = ($frontItems.Count -gt 0); severity = "blocker"; detail = "$($frontItems.Count) ön sayfa" },
  [ordered]@{ key = "matter_content"; ok = ($emptyMatter.Count -eq 0); severity = "blocker"; detail = if ($emptyMatter.Count) { "$($emptyMatter.Count) etkin sayfa içeriği boş" } else { "etkin sayfalar dolu" } },
  [ordered]@{ key = "cover_spec"; ok = [bool]$coverConfigured; severity = "blocker"; detail = if ($coverConfigured) { "başlık, yazar ve arka kapak yazısı var" } else { "kapak başlığı, yazar veya arka kapak yazısı eksik" } },
  [ordered]@{ key = "interior_pdf"; ok = [bool]$interiorGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "baskı iç bloğu" } },
  [ordered]@{ key = "cover_pdf"; ok = [bool]$coverGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "tam sargı kapak" } },
  [ordered]@{ key = "font_embedding"; ok = ($pdfFontStatus -eq "pass"); severity = if ($pdfFontStatus -eq "fail") { "blocker" } elseif ($pdfFontStatus -eq "pass") { "output" } else { "external" }; detail = $pdfFontStatus },
  [ordered]@{ key = "pdf_x"; ok = $false; severity = "external"; detail = "Edge PDF normal PDF üretir; PDF/X dönüştürme ve matbaa profili gerekir" },
  [ordered]@{ key = "epub"; ok = [bool]$epubGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "EPUB paketi" } },
  [ordered]@{ key = "epubcheck"; ok = ($epubCheckStatus -eq "pass"); severity = "external"; detail = $epubCheckStatus }
)
$blockers = @($checks | Where-Object { $_.severity -eq "blocker" -and -not $_.ok } | ForEach-Object { $_.key })
$externalReviews = @($checks | Where-Object { $_.severity -eq "external" -and -not $_.ok } | ForEach-Object { $_.key })
$preflight = [ordered]@{
  schema_version = "1.0.0"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  status = if ($blockers.Count) { "BLOCKED" } else { "REVIEW_REQUIRED" }
  print_ready = $false
  retailer_ready = $false
  preflight_only = [bool]$PreflightOnly
  checks = [object[]]$checks
  blockers = [object[]]$blockers
  external_reviews = [object[]]$externalReviews
  epubcheck_output = $epubCheckOutput
  pdf_font_output = $pdfFontOutput
  note = "KitHub dosyaları üretir; PDF/X, ISBN/barkod/bandrol ve son matbaa provası tamamlanmadan baskıya hazır iddiası kurulmaz."
}
$preflightPath = Join-Path $ProjectRoot "runtime/publication-preflight-report.json"
[IO.File]::WriteAllText($preflightPath, ($preflight | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($true))

$report = [ordered]@{
  schema_version = "1.0.0"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  title = $title
  preflight_only = [bool]$PreflightOnly
  preflight_status = $preflight.status
  matter = [ordered]@{ front_count = $frontItems.Count; back_count = $backItems.Count; empty_enabled_count = $emptyMatter.Count }
  cover = $layout.cover_spec
  page_design = $pageDesign
  typography = [ordered]@{ font_family = $font; font_size_pt = $fontSize; line_spacing = $lineSpacing }
  font_embedding = $pdfFontStatus
  page = [ordered]@{ width_mm = $width; height_mm = $height; margin_top_mm = $top; margin_inside_mm = $inside; margin_outside_mm = $outside }
  flow = [ordered]@{
    widow_orphan_control = $widowOrphanPolicy
    minimum_lines = $widowOrphanLines
    chapter_start_policy = $chapterStartPolicy
    running_header_policy = $runningHeaderPolicy
    running_header_strategy = if ($runningHeaderPolicy -eq "chapter_title") { "css_named_string_best_effort" } elseif ($runningHeaderPolicy -eq "book_title") { "paged_media_margin_box" } else { "none" }
    page_number_position = $pageNumberPosition
  }
  outputs = [object[]]$results
}
$reportPath = Join-Path $ProjectRoot "runtime/publication-build-report.json"
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($true))
Write-Host "[publication-build] $($preflight.status) $(@($results | ForEach-Object { $_.format }) -join ', ')"
Write-Output ($report | ConvertTo-Json -Depth 10 -Compress)
