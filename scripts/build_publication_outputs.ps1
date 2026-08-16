param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$Formats = "pdf,epub",
  [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"

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

function Get-Ean13Svg {
  param([string]$Value)
  $digits = ($Value -replace '[^0-9]', '')
  if (-not (Test-Isbn13 -Value $digits)) { return "" }
  $leftOdd = @("0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011")
  $leftEven = @("0100111","0110011","0011011","0100001","0011101","0111001","0000101","0010001","0001001","0010111")
  $right = @("1110010","1100110","1101100","1000010","1011100","1001110","1010000","1000100","1001000","1110100")
  $parity = @("LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG","LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL")
  $bits = "101"
  $first = [int]::Parse($digits[0].ToString())
  for ($index = 1; $index -le 6; $index++) {
    $digit = [int]::Parse($digits[$index].ToString())
    $bits += if ($parity[$first][$index - 1] -eq "L") { $leftOdd[$digit] } else { $leftEven[$digit] }
  }
  $bits += "01010"
  for ($index = 7; $index -le 12; $index++) {
    $bits += $right[[int]::Parse($digits[$index].ToString())]
  }
  $bits += "101"
  $rects = [System.Collections.Generic.List[string]]::new()
  for ($index = 0; $index -lt $bits.Length; $index++) {
    if ($bits[$index] -ne "1") { continue }
    $height = if ($index -lt 3 -or ($index -ge 45 -and $index -lt 50) -or $index -ge 92) { 58 } else { 52 }
    $rects.Add("<rect x='$($index + 10)' y='4' width='1' height='$height'/>")
  }
  $human = "$($digits.Substring(0,1)) $($digits.Substring(1,6)) $($digits.Substring(7,6))"
  return "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 115 72' role='img' aria-label='EAN-13 $digits'><rect width='115' height='72' fill='white'/><g fill='black'>$($rects -join '')</g><text x='57.5' y='69' text-anchor='middle' font-family='Arial, sans-serif' font-size='8'>$human</text></svg>"
}

function Get-EpubCheckRunner {
  $command = Get-Command epubcheck -ErrorAction SilentlyContinue
  if ($command) { return [ordered]@{ mode = "command"; path = $command.Source } }
  $candidates = @()
  if ($env:KITHUB_EPUBCHECK_JAR) { $candidates += $env:KITHUB_EPUBCHECK_JAR }
  if ($env:LOCALAPPDATA) {
    $manifestPath = Join-Path $env:LOCALAPPDATA "KitHub/tools/epubcheck/installation.json"
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      try { $candidates += [string]((Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).jar) } catch {}
    }
    $candidates += Join-Path $env:LOCALAPPDATA "KitHub/tools/epubcheck/5.3.0/epubcheck.jar"
  }
  $jar = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1)
  $java = Get-Command java -ErrorAction SilentlyContinue
  if ($jar.Count -and $java) { return [ordered]@{ mode = "jar"; path = $jar[0]; java = $java.Source } }
  return $null
}
function Get-Ghostscript {
  $command = Get-Command gswin64c, gswin32c, gs -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($command) { return [ordered]@{ binary = $command.Source; lib = (Split-Path $command.Source) } }
  $exe = @(Get-ChildItem "C:\Program Files\gs" -Recurse -Filter "gswin64c.exe" -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($exe.Count) {
    $binDir = Split-Path $exe[0].FullName
    return [ordered]@{ binary = $exe[0].FullName; lib = (Split-Path $binDir -Parent) }
  }
  return $null
}

function ConvertTo-PrintPdfX {
  param(
    [string]$InputPdf,
    [string]$OutputPdf,
    [string]$GhostscriptBinary,
    [string]$GhostscriptHome
  )
  $iccDir = Join-Path $GhostscriptHome "iccprofiles"
  $libDir = Join-Path $GhostscriptHome "lib"
  if (-not (Test-Path -LiteralPath $iccDir -PathType Container) -or -not (Test-Path -LiteralPath (Join-Path $iccDir "default_cmyk.icc") -PathType Leaf)) { throw "Ghostscript iccprofiles/default_cmyk.icc not found under $GhostscriptHome." }
  if (-not (Test-Path -LiteralPath (Join-Path $libDir "PDFX_def.ps") -PathType Leaf)) { throw "Ghostscript lib/PDFX_def.ps not found under $GhostscriptHome." }
  $def = Get-Content -LiteralPath (Join-Path $libDir "PDFX_def.ps") -Raw
  $def = $def -replace '/ICCProfile \(ISO Coated sb\.icc\) def', '/ICCProfile (default_cmyk.icc) def'
  $def = $def -replace '/OutputConditionIdentifier \(CGATS TR001\)', '/OutputConditionIdentifier (ISO Coated v2 300\%)'
  $defPath = Join-Path ([IO.Path]::GetTempPath()) ("kithub-pdfx-" + [guid]::NewGuid().ToString("N") + ".ps")
  [IO.File]::WriteAllText($defPath, $def, [Text.UTF8Encoding]::new($false))
  $outputPath = [IO.Path]::GetFullPath($OutputPdf)
  $previous = Get-Location
  try {
    Set-Location -LiteralPath $iccDir
    $stdout = (& $GhostscriptBinary "-dNOSAFER" "-dPDFX=3" "-dBATCH" "-dNOPAUSE" "-dPreserveAnnots=false" "-dSubsetFonts=false" "-sColorConversionStrategy=CMYK" "-sDEVICE=pdfwrite" "-sOutputFile=$outputPath" $defPath $InputPdf 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath -PathType Leaf) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) {
      throw "Ghostscript PDF/X conversion failed: $stdout"
    }
  }
  finally {
    if ($previous) { Set-Location -LiteralPath $previous.Path }
    if (Test-Path -LiteralPath $defPath -PathType Leaf) { Remove-Item -LiteralPath $defPath -Force -ErrorAction SilentlyContinue }
  }
  return $outputPath
}
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
$professionalPath = Join-Path $ProjectRoot "revision/_state/studio-professional.json"
$professional = if (Test-Path -LiteralPath $professionalPath -PathType Leaf) {
  Get-Content -LiteralPath $professionalPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else { [pscustomobject]@{} }
$publicationProfile = if ([string]$professional.publication.profile -in @("kdp","ingram","custom")) { [string]$professional.publication.profile } else { "kdp" }
$isbn = ([string]$professional.publication.isbn -replace '[^0-9]', '')
$imprint = ([string]$professional.publication.imprint).Trim()
$coverAsset = $professional.publication.cover_asset
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
$coverAssetStatus = "not_used"
$coverAssetDpi = 0
if ($formatList -contains "epub") {
  $epubPath = Join-Path $exportDir "$safeName-dijital.epub"
  $args = @($common + @("--css=$cssPath","--output=$epubPath") + $epubInputs)
  $cover = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "design") -File -ErrorAction SilentlyContinue | Where-Object Extension -Match '^\.(png|jpe?g)$' | Select-Object -First 1)
  if ($coverAsset -and [string]$coverAsset.relative_path) {
    $preferredCoverPath = Join-Path $ProjectRoot (([string]$coverAsset.relative_path).Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $preferredCoverPath -PathType Leaf) { $cover = @(Get-Item -LiteralPath $preferredCoverPath) }
  }
  if ($cover.Count) { $args = @("--epub-cover-image=$($cover[0].FullName)") + $args }
  & $pandoc.Source @args
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $epubPath -PathType Leaf)) { throw "Pandoc EPUB generation failed." }
  $epubCheck = Get-EpubCheckRunner
  if ($epubCheck) {
    if ($epubCheck.mode -eq "command") {
      $epubCheckOutput = ((& $epubCheck.path $epubPath 2>&1) | Out-String).Trim()
    } else {
      $epubCheckOutput = ((& $epubCheck.java "-Dfile.encoding=UTF8" "-jar" $epubCheck.path $epubPath 2>&1) | Out-String).Trim()
    }
    $epubCheckStatus = if ($LASTEXITCODE -eq 0) { "pass" } else { "fail" }
  } else {
    $epubCheckStatus = "unavailable"
  }
  $results += [ordered]@{ format = "EPUB"; path = $epubPath; bytes = (Get-Item -LiteralPath $epubPath).Length }
}
if ($formatList -contains "pdf") {
  $ghostscript = Get-Ghostscript
  $pdfXStatus = "not_run"
  $pdfXOutput = ""
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

  if ($publicationProfile -eq "ingram") {
    if (-not $ghostscript) { $ghostscript = Get-Ghostscript }
    if ($ghostscript) {
      $ghHome = [IO.Path]::GetFullPath((Join-Path ([string]$ghostscript.lib) ".."))
      $pdfxPath = Join-Path $exportDir "$safeName-baski-pdfx.pdf"
      try {
        ConvertTo-PrintPdfX -InputPdf $pdfPath -OutputPdf $pdfxPath -GhostscriptBinary ([string]$ghostscript.binary) -GhostscriptHome $ghHome | Out-Null
        $pdfXStatus = "pass"
        $pdfPath = $pdfxPath
        $results[-1].path = $pdfPath
        $results[-1].bytes = (Get-Item -LiteralPath $pdfPath).Length
        $results[-1].pdf_x = "PDF/X-3:2002"
      } catch {
        $pdfXStatus = "fail"
        $pdfXOutput = $_.Exception.Message
      }
    } else {
      $pdfXStatus = "unavailable"
    }
  }

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
    $coverSpineText = if ([int]$coverSpec.page_count -ge 79) { "$coverTitle · $coverAuthor" } else { "" }
    $barcodeMode = [string]$coverSpec.barcode_mode
    $barcodeSvg = if (Test-Isbn13 -Value $isbn) { Get-Ean13Svg -Value $isbn } else { "" }
    $barcode = if ($barcodeMode -eq "none") { "" } elseif ($barcodeSvg) { "<div class='barcode barcode-real'>$barcodeSvg</div>" } else { '<div class="barcode barcode-missing">GEÇERLİ ISBN-13 GEREKLİ</div>' }
    $coverArtHtml = ""
    if ($coverAsset -and [string]$coverAsset.relative_path) {
      $assetCandidate = [IO.Path]::GetFullPath((Join-Path $ProjectRoot (([string]$coverAsset.relative_path) -replace "/", "")))
      $projectPrefix = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd("") + ""
      if ($assetCandidate.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $assetCandidate -PathType Leaf)) {
        $artWidthMm = $width + ($coverBleed * 2)
        $artHeightMm = $height + ($coverBleed * 2)
        if ([int]$coverAsset.width_px -gt 0 -and [int]$coverAsset.height_px -gt 0) {
          $horizontalDpi = [int]$coverAsset.width_px / ($artWidthMm / 25.4)
          $verticalDpi = [int]$coverAsset.height_px / ($artHeightMm / 25.4)
          $coverAssetDpi = [Math]::Round([Math]::Min($horizontalDpi, $verticalDpi), 1)
          $coverAssetStatus = if ($coverAssetDpi -ge 300) { "pass" } else { "fail" }
        } else {
          $coverAssetStatus = "unknown_dimensions"
        }
        $assetUri = [Net.WebUtility]::HtmlEncode(([Uri]$assetCandidate).AbsoluteUri)
        $coverArtHtml = "<img class='cover-art' src='$assetUri' alt=''/>"
      } else {
        $coverAssetStatus = "missing"
      }
    }
    $coverHtml = @"
<!doctype html><html lang="tr"><head><meta charset="utf-8"><style>
@page { size: ${coverWidth}mm ${coverHeight}mm; margin: 0; }
* { box-sizing: border-box; }
html, body { width: ${coverWidth}mm; height: ${coverHeight}mm; margin: 0; }
body { font-family: "$font", Garamond, serif; color: #1f1a14; background: #e8dfcf; }
.wrap { position: absolute; inset: ${coverBleed}mm; display: grid; grid-template-columns: ${width}mm ${spineWidth}mm ${width}mm; height: ${height}mm; }
.back, .front { padding: 16mm 12mm; position: relative; overflow: hidden; }
.front { display: grid; place-content: center; gap: 8mm; text-align: center; border-left: .2mm solid rgba(0,0,0,.16); isolation: isolate; }
.front-content { position: relative; z-index: 2; display: grid; gap: 8mm; padding: 7mm; background: rgba(255,255,255,.86); }
.cover-art { position: absolute; inset: 0; z-index: 1; width: 100%; height: 100%; object-fit: cover; }
.front h1 { margin: 0; font-size: 30pt; line-height: 1.08; }
.front p { margin: 0; font-size: 13pt; letter-spacing: .08em; }
.back { font: 11pt/1.55 "$font", Garamond, serif; border-right: .2mm solid rgba(0,0,0,.16); }
.spine { display: grid; place-content: center; padding: 4mm 1mm; color: #f5ead7; background: #29241e; writing-mode: vertical-rl; text-orientation: mixed; letter-spacing: .04em; text-align: center; }
.barcode { position: absolute; right: 12mm; bottom: 12mm; width: 38mm; min-height: 25mm; display: grid; place-content: center; background: #fff; color: #17130f; font: 7pt/1 Arial; }
.barcode svg { display: block; width: 38mm; height: auto; }
.barcode-missing { border: .25mm solid #8f332d; color: #8f332d; padding: 2mm; text-align: center; }
</style></head><body><main class="wrap"><section class="back">$coverBack$barcode</section><section class="spine">$coverSpineText</section><section class="front"><h1>$coverTitle</h1><p>$coverAuthor</p></section></main></body></html>
"@
    $coverHtml = $coverHtml.Replace("<section class=""front""><h1>$coverTitle</h1><p>$coverAuthor</p></section>", "<section class=""front"">$coverArtHtml<div class=""front-content""><h1>$coverTitle</h1><p>$coverAuthor</p></div></section>")
    [IO.File]::WriteAllText($coverHtmlPath, $coverHtml, [Text.UTF8Encoding]::new($false))
    $coverUri = ([Uri]$coverHtmlPath).AbsoluteUri
    $coverProcess = Start-Process -FilePath $edge -ArgumentList @("--headless=new","--disable-gpu","--no-pdf-header-footer","--print-to-pdf=$coverPdfPath",$coverUri) -WindowStyle Hidden -Wait -PassThru
    if ($coverProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $coverPdfPath -PathType Leaf)) { throw "Full-wrap cover PDF generation failed." }
    if ($publicationProfile -eq "ingram" -and $ghostscript) {
      $coverPdfxPath = Join-Path $exportDir "$safeName-kapak-pdfx.pdf"
      $ghHome = [IO.Path]::GetFullPath((Join-Path ([string]$ghostscript.lib) ".."))
      try {
        ConvertTo-PrintPdfX -InputPdf $coverPdfPath -OutputPdf $coverPdfxPath -GhostscriptBinary ([string]$ghostscript.binary) -GhostscriptHome $ghHome | Out-Null
        $coverPdfPath = $coverPdfxPath
      } catch {
        $pdfXStatus = if ($pdfXStatus -eq "pass") { "fail" } else { "fail" }
        $pdfXOutput = $_.Exception.Message
      }
    }
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
$barcodeMode = if ($layout.cover_spec) { [string]$layout.cover_spec.barcode_mode } else { "none" }
$isbnRequired = $barcodeMode -ne "none"
$isbnValid = Test-Isbn13 -Value $isbn
$requiredBleed = if ($publicationProfile -eq "ingram") { 3.175 } else { 3.2 }
$bleedValue = if ($layout.cover_spec) { [double]$layout.cover_spec.bleed_mm } else { 0 }
$bleedOk = $bleedValue -ge ($requiredBleed - 0.01)
$pdfXRequired = $publicationProfile -eq "ingram"
$pdfXPassed = $pdfXStatus -eq "pass"
$pdfXAvailable = $pdfXStatus -in @("pass","fail")
$epubCheckRequired = $formatList -contains "epub"
$pdfFontRequired = $formatList -contains "pdf"
$coverAssetOk = $coverAssetStatus -in @("not_used","pass")
$checks = @(
  [ordered]@{ key = "manuscript"; ok = ($chapters.Count -gt 0); severity = "blocker"; detail = "$($chapters.Count) bölüm" },
  [ordered]@{ key = "front_matter"; ok = ($frontItems.Count -gt 0); severity = "blocker"; detail = "$($frontItems.Count) ön sayfa" },
  [ordered]@{ key = "matter_content"; ok = ($emptyMatter.Count -eq 0); severity = "blocker"; detail = if ($emptyMatter.Count) { "$($emptyMatter.Count) etkin sayfa içeriği boş" } else { "etkin sayfalar dolu" } },
  [ordered]@{ key = "cover_spec"; ok = [bool]$coverConfigured; severity = "blocker"; detail = if ($coverConfigured) { "başlık, yazar ve arka kapak yazısı var" } else { "kapak başlığı, yazar veya arka kapak yazısı eksik" } },
  [ordered]@{ key = "interior_pdf"; ok = [bool]$interiorGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "baskı iç bloğu" } },
  [ordered]@{ key = "cover_pdf"; ok = [bool]$coverGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "tam sargı kapak" } },
  [ordered]@{ key = "publication_profile"; ok = ($publicationProfile -in @("kdp","ingram","custom")); severity = "blocker"; detail = $publicationProfile },
  [ordered]@{ key = "bleed"; ok = $bleedOk; severity = "blocker"; detail = "$bleedValue mm / gereken en az $requiredBleed mm" },
  [ordered]@{ key = "isbn_ean13"; ok = (-not $isbnRequired -or $isbnValid); severity = "blocker"; detail = if (-not $isbnRequired) { "barkod kapalı" } elseif ($isbnValid) { "geçerli ISBN-13" } else { "13 haneli ISBN ve doğru kontrol basamağı gerekli" } },
  [ordered]@{ key = "cover_asset_dpi"; ok = $coverAssetOk; severity = if ($coverAssetStatus -eq "fail") { "blocker" } else { "output" }; detail = if ($coverAssetStatus -eq "not_used") { "tipografik/vektör kapak" } elseif ($coverAssetDpi) { "$coverAssetDpi DPI" } else { $coverAssetStatus } },
  [ordered]@{ key = "font_embedding"; ok = (-not $pdfFontRequired -or $pdfFontStatus -eq "pass"); severity = if ($pdfFontRequired -and $pdfFontStatus -eq "fail") { "blocker" } elseif ($pdfFontRequired -and $pdfFontStatus -eq "unavailable") { "external" } else { "output" }; detail = $pdfFontStatus },
  [ordered]@{ key = "pdf_x"; ok = (-not $pdfXRequired -or $pdfXPassed); severity = if (-not $pdfXRequired) { "output" } elseif ($pdfXPassed) { "output" } elseif ($pdfXAvailable) { "blocker" } else { "external" }; detail = if (-not $pdfXRequired) { "KDP profili PDF/X zorunlu tutmaz" } elseif ($pdfXPassed) { "PDF/X-3:2002 + CMYK (Ghostscript)" } elseif ($pdfXAvailable) { "Ghostscript PDF/X donusumu basarisiz: $pdfXOutput" } else { "Ingram PDF/X-3 + CMYK icin Ghostscript kurulu degil" } },
  [ordered]@{ key = "epub"; ok = [bool]$epubGenerated; severity = "output"; detail = if ($PreflightOnly) { "preflight-only çalışmada üretilmedi" } else { "EPUB paketi" } },
  [ordered]@{ key = "epubcheck"; ok = (-not $epubCheckRequired -or $epubCheckStatus -eq "pass"); severity = if ($epubCheckRequired -and $epubCheckStatus -eq "fail") { "blocker" } elseif ($epubCheckRequired -and $epubCheckStatus -eq "unavailable") { "external" } else { "output" }; detail = $epubCheckStatus }
)
$blockers = @($checks | Where-Object { $_.severity -eq "blocker" -and -not $_.ok } | ForEach-Object { $_.key })
$externalReviews = @($checks | Where-Object { $_.severity -eq "external" -and -not $_.ok } | ForEach-Object { $_.key })
$packageReady = (-not $PreflightOnly -and $blockers.Count -eq 0 -and $externalReviews.Count -eq 0)
$preflight = [ordered]@{
  schema_version = "1.0.0"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  profile = $publicationProfile
  status = if ($blockers.Count) { "BLOCKED" } elseif ($externalReviews.Count) { "REVIEW_REQUIRED" } elseif ($PreflightOnly) { "PREFLIGHT_PASS" } else { "READY" }
  print_ready = [bool]($packageReady -and $interiorGenerated -and $coverGenerated)
  retailer_ready = [bool]($packageReady -and $interiorGenerated -and $coverGenerated -and (-not $epubCheckRequired -or $epubGenerated))
  preflight_only = [bool]$PreflightOnly
  checks = [object[]]$checks
  blockers = [object[]]$blockers
  external_reviews = [object[]]$externalReviews
  epubcheck_output = $epubCheckOutput
  pdf_font_output = $pdfFontOutput
  pdf_x_output = $pdfXOutput
  note = if ($publicationProfile -eq "ingram" -and -not $pdfXPassed) { "Ingram icin PDF/X-3 + CMYK donusumu gerekir (Ghostscript)." } elseif ($publicationProfile -eq "ingram") { "Ingram PDF/X-3 + CMYK donusumu Ghostscript ile yapildi; son fiziksel prova ve platform yukleme onizlemesi yine yapilmalidir." } else { "READY dosya duzeyi kontrollerin gectigini gosterir; son fiziksel prova ve platform yukleme onizlemesi yine yapilmalidir." }
}
$preflightPath = Join-Path $ProjectRoot "runtime/publication-preflight-report.json"
[IO.File]::WriteAllText($preflightPath, ($preflight | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($true))

$report = [ordered]@{
  schema_version = "1.0.0"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  title = $title
  publication_profile = $publicationProfile
  isbn = $isbn
  imprint = $imprint
  preflight_only = [bool]$PreflightOnly
  preflight_status = $preflight.status
  matter = [ordered]@{ front_count = $frontItems.Count; back_count = $backItems.Count; empty_enabled_count = $emptyMatter.Count }
  cover = $layout.cover_spec
  page_design = $pageDesign
  typography = [ordered]@{ font_family = $font; font_size_pt = $fontSize; line_spacing = $lineSpacing }
  font_embedding = $pdfFontStatus
  pdf_x = $pdfXStatus
  cover_asset = [ordered]@{ status = $coverAssetStatus; effective_dpi = $coverAssetDpi; metadata = $coverAsset }
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
