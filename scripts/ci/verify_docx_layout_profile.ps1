param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [string]$ManifestPath
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Resolve-ProjectPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return (Join-Path $ProjectRoot $Path)
}

function Get-ZipEntryText {
  param([string]$DocxPath, [string]$EntryName)
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($DocxPath)
  try {
    $entry = $zip.GetEntry($EntryName)
    if (-not $entry) { throw "DOCX missing required entry: $EntryName" }
    $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() }
    finally { $reader.Dispose() }
  }
  finally {
    $zip.Dispose()
  }
}

function Assert-ZipEntry {
  param([string]$DocxPath, [string]$EntryName)
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($DocxPath)
  try {
    $entry = $zip.GetEntry($EntryName)
    if (-not $entry) { throw "DOCX missing required entry: $EntryName" }
    if ($entry.Length -lt 1) { throw "DOCX required entry is empty: $EntryName" }
  }
  finally {
    $zip.Dispose()
  }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$manifestFull = Resolve-ProjectPath -Path $ManifestPath
if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) {
  throw "Manifest not found: $ManifestPath"
}

$manifest = Read-Utf8 -Path $manifestFull | ConvertFrom-Json
foreach ($field in @("output_docx_path","docx_style_profile")) {
  if (-not ($manifest.PSObject.Properties.Name -contains $field)) {
    throw "Export manifest missing '$field'."
  }
}

$docxPath = Resolve-ProjectPath -Path ([string]$manifest.output_docx_path)
$styleProfilePath = Resolve-ProjectPath -Path ([string]$manifest.docx_style_profile)
if (-not (Test-Path -LiteralPath $docxPath -PathType Leaf)) {
  throw "DOCX not found: $docxPath"
}
if (-not (Test-Path -LiteralPath $styleProfilePath -PathType Leaf)) {
  throw "DOCX style profile not found: $styleProfilePath"
}

foreach ($entryName in @("[Content_Types].xml","_rels/.rels","word/document.xml","word/styles.xml","word/_rels/document.xml.rels","docProps/core.xml","docProps/app.xml")) {
  Assert-ZipEntry -DocxPath $docxPath -EntryName $entryName
}

$styleProfile = Read-Utf8 -Path $styleProfilePath | ConvertFrom-Json
$style = $styleProfile.style_profile
foreach ($field in @("page_width_twip","page_height_twip","margin_top_twip","margin_bottom_twip","margin_left_twip","margin_right_twip","font_family","font_size_pt")) {
  if (-not ($style.PSObject.Properties.Name -contains $field)) {
    throw "DOCX style profile missing '$field'."
  }
}

$documentXml = Get-ZipEntryText -DocxPath $docxPath -EntryName "word/document.xml"
$stylesXml = Get-ZipEntryText -DocxPath $docxPath -EntryName "word/styles.xml"
$rootRelsXml = Get-ZipEntryText -DocxPath $docxPath -EntryName "_rels/.rels"
$contentTypesXml = Get-ZipEntryText -DocxPath $docxPath -EntryName "[Content_Types].xml"

if ($rootRelsXml -notmatch 'officeDocument/2006/relationships/officeDocument' -or $rootRelsXml -notmatch 'Target="word/document.xml"') {
  throw "DOCX root relationships do not point to word/document.xml."
}
if ($contentTypesXml -notmatch 'PartName="/word/document.xml"' -or $contentTypesXml -notmatch 'PartName="/word/styles.xml"') {
  throw "DOCX content types missing document or styles overrides."
}
foreach ($styleId in @("KitHubBody","KitHubChapterTitle","KitHubFrontMatter","KitHubToc")) {
  if ($stylesXml -notmatch "w:styleId=`"$styleId`"") {
    throw "DOCX styles.xml missing paragraph style '$styleId'."
  }
}
if ($documentXml -notmatch 'w:pStyle w:val="KitHubBody"') {
  throw "DOCX document.xml does not reference KitHubBody style."
}
if ($documentXml -notmatch 'w:pStyle w:val="KitHubChapterTitle"') {
  throw "DOCX document.xml does not reference KitHubChapterTitle style."
}

$pageWidth = [regex]::Match($documentXml, 'w:pgSz[^>]*w:w="(\d+)"').Groups[1].Value
$pageHeight = [regex]::Match($documentXml, 'w:pgSz[^>]*w:h="(\d+)"').Groups[1].Value
$marginTop = [regex]::Match($documentXml, 'w:pgMar[^>]*w:top="(\d+)"').Groups[1].Value
$marginRight = [regex]::Match($documentXml, 'w:pgMar[^>]*w:right="(\d+)"').Groups[1].Value
$marginBottom = [regex]::Match($documentXml, 'w:pgMar[^>]*w:bottom="(\d+)"').Groups[1].Value
$marginLeft = [regex]::Match($documentXml, 'w:pgMar[^>]*w:left="(\d+)"').Groups[1].Value

$expected = @{
  page_width_twip = [int]$style.page_width_twip
  page_height_twip = [int]$style.page_height_twip
  margin_top_twip = [int]$style.margin_top_twip
  margin_bottom_twip = [int]$style.margin_bottom_twip
  margin_left_twip = [int]$style.margin_left_twip
  margin_right_twip = [int]$style.margin_right_twip
}
$actual = @{
  page_width_twip = [int]$pageWidth
  page_height_twip = [int]$pageHeight
  margin_top_twip = [int]$marginTop
  margin_bottom_twip = [int]$marginBottom
  margin_left_twip = [int]$marginLeft
  margin_right_twip = [int]$marginRight
}

foreach ($key in $expected.Keys) {
  if ([Math]::Abs($actual[$key] - $expected[$key]) -gt 2) {
    throw "DOCX layout mismatch for $key. Expected $($expected[$key]), actual $($actual[$key])."
  }
}

Write-Host "[docx-layout-profile] PASS"
Write-Host "manifest=$ManifestPath"
Write-Host "docx=$docxPath"
Write-Host "style_profile=$styleProfilePath"
