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

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Resolve-ProjectPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return (Join-Path $ProjectRoot $Path)
}

function Get-DocxText {
  param([string]$DocxPath)

  Ensure-File $DocxPath
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = $null
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $DocxPath))
    $entry = $zip.Entries | Where-Object { $_.FullName -eq "word/document.xml" } | Select-Object -First 1
    if (-not $entry) {
      throw "DOCX package is missing word/document.xml: $DocxPath"
    }
    $stream = $entry.Open()
    try {
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
      $xml = $reader.ReadToEnd()
    }
    finally {
      if ($reader) { $reader.Dispose() }
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($zip) { $zip.Dispose() }
  }

  $text = $xml -replace "<w:tab[^>]*/>", " "
  $text = $text -replace "</w:p>", "`n"
  $text = $text -replace "<[^>]+>", " "
  return [System.Net.WebUtility]::HtmlDecode($text)
}

function Normalize-Text {
  param([string]$Text)
  return (($Text.ToLowerInvariant() -replace "\s+", " ").Trim())
}

function Get-SourceSnippets {
  param([string]$Text)

  $snippets = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($Text -split "\r?\n")) {
    $clean = ($line -replace "^#{1,6}\s*", "" -replace "^\s*[-*]\s+", "").Trim()
    if (-not $clean) { continue }
    if ($clean -match "(?i)^\s*(run_id|step_id)\s*:") { continue }
    if ($clean -match "(?i)^ep\d{3}$|^scene\s+\d+|^sahne\s+\d+") { continue }
    if ($clean.Length -ge 45) {
      $snippets.Add($clean.Substring(0, [Math]::Min(140, $clean.Length)))
    }
    if ($snippets.Count -ge 4) { break }
  }
  return $snippets
}

$manifestFull = Resolve-ProjectPath -Path $ManifestPath
Ensure-File $manifestFull
$manifest = Read-Utf8 -Path $manifestFull | ConvertFrom-Json
foreach ($field in @("source_files","output_docx_path")) {
  if (-not ($manifest.PSObject.Properties.Name -contains $field)) {
    throw "Export manifest missing '$field': $ManifestPath"
  }
}

$docxPath = Resolve-ProjectPath -Path ([string]$manifest.output_docx_path)
$docxText = Normalize-Text -Text (Get-DocxText -DocxPath $docxPath)
if (-not $docxText) {
  throw "DOCX text is empty after extraction: $docxPath"
}

$checked = 0
$matched = 0
$missing = New-Object System.Collections.Generic.List[string]
foreach ($rel in @($manifest.source_files)) {
  $sourcePath = Resolve-ProjectPath -Path ([string]$rel)
  Ensure-File $sourcePath
  $sourceText = Read-Utf8 -Path $sourcePath
  $snippets = @(Get-SourceSnippets -Text $sourceText)
  if ($snippets.Count -lt 1) {
    throw "Source file has no usable manuscript snippet: $rel"
  }
  $checked++
  $sourceMatched = $false
  foreach ($snippet in $snippets) {
    if ($docxText.Contains((Normalize-Text -Text $snippet))) {
      $sourceMatched = $true
      break
    }
  }
  if ($sourceMatched) {
    $matched++
  }
  else {
    $missing.Add([string]$rel)
  }
}

if ($checked -lt 1) {
  throw "No source files declared in export manifest: $ManifestPath"
}
if ($missing.Count -gt 0) {
  throw "DOCX content does not match source manuscript files: $($missing -join ', '). Refusing stale/copied DOCX export."
}

Write-Host "[docx-content-match] PASS"
Write-Host "manifest=$ManifestPath"
Write-Host "docx=$docxPath"
Write-Host "source_files_checked=$checked"
Write-Host "source_files_matched=$matched"
