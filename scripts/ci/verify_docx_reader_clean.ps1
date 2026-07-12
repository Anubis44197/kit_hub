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
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$manifestFull = Resolve-ProjectPath -Path $ManifestPath
Ensure-File $manifestFull
$manifest = Read-Utf8 -Path $manifestFull | ConvertFrom-Json
if (-not ($manifest.PSObject.Properties.Name -contains "output_docx_path")) {
  throw "DOCX reader-clean gate failed: export manifest missing output_docx_path."
}

$docxPath = Resolve-ProjectPath -Path ([string]$manifest.output_docx_path)
$docxText = Get-DocxText -DocxPath $docxPath
if (-not $docxText.Trim()) {
  throw "DOCX reader-clean gate failed: reader-facing DOCX text is empty."
}

$blockedPatterns = @(
  "(?i)\bpublication\s+compliance\b",
  "(?i)\bfront\s+matter\s+report\b",
  "(?i)\bexport\s+validator\b",
  "(?i)\bfinal\s+proofreader\b",
  "(?i)\bVERDICT\s*:",
  "(?i)\bREVIEW_REQUIRED\b",
  "(?i)\bREADY_WITH_PUBLICATION_REVIEW\b",
  "(?i)\bBLOCKED\b",
  "(?i)\bblock_reasons\b",
  "(?i)\bprint_ready\b",
  "(?i)\brun_id\s*:",
  "(?i)\bstep_id\s*:",
  "(?i)\bEP\d{3}\b",
  "(?i)\bScene\s+\d+\b",
  "(?i)\bSahne\s+\d+\b",
  "(?i)ISBN.*(missing|eksik|not_assigned|placeholder|review)",
  "(?i)bandrol.*(external|eksik|review)",
  "(?i)yayı[nm]\s+not",
  "(?i)yayin\s+not",
  "(?i)inceleme\s+not",
  "(?i)test\s+dosya",
  "(?i)\bBu düğümde\s+\d+",
  "(?i)\bAyrıntı\s+\d+\s+bu sahnenin",
  "(?i)\bB[oö]l[üu]m[üu]n\s+(özgün|ozgun)\s+(ayrıntı|ayrinti)\s+alan[ıi]",
  "(?i)\bDefterin kenarında\s+\d+",
  "(?i)\bÖnceki bölümün bıraktığı iz",
  "(?i)\bBu söz .+ içinde yeni bir iz bıraktı",
  "(?i)\byanında duran Mahir, gördüğü şeyin yalnız bir eşya olmadığını anladı"
)

foreach ($pattern in $blockedPatterns) {
  if ($docxText -match $pattern) {
    throw "DOCX reader-clean gate failed: reader-facing DOCX contains review/control/technical pattern '$pattern'. Move review notes to revision/_workspace artifacts."
  }
}

Write-Host "[docx-reader-clean] PASS"
Write-Host "manifest=$ManifestPath"
Write-Host "docx=$docxPath"
