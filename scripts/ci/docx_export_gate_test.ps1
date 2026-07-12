param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Write-Utf8Json {
  param([string]$Path, [object]$Value)
  Write-Utf8 -Path $Path -Content ($Value | ConvertTo-Json -Depth 20)
}

function New-TestDocx {
  param(
    [string]$OutputPath,
    [string[]]$Paragraphs
  )
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("kithub-docx-test-" + [guid]::NewGuid().ToString("N"))
  try {
    New-Item -ItemType Directory -Path (Join-Path $tmp "_rels") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp "word/_rels") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp "docProps") -Force | Out-Null

    Write-Utf8 -Path (Join-Path $tmp "[Content_Types].xml") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@
    Write-Utf8 -Path (Join-Path $tmp "_rels/.rels") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@
    Write-Utf8 -Path (Join-Path $tmp "word/_rels/document.xml.rels") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>
'@
    Write-Utf8 -Path (Join-Path $tmp "word/styles.xml") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="KitHubBody"><w:name w:val="KitHub Body"/></w:style>
  <w:style w:type="paragraph" w:styleId="KitHubBodyFirst"><w:name w:val="KitHub Body First"/><w:pPr><w:ind w:firstLine="0"/></w:pPr></w:style>
  <w:style w:type="paragraph" w:styleId="KitHubBookTitle"><w:name w:val="KitHub Book Title"/></w:style>
  <w:style w:type="paragraph" w:styleId="KitHubChapterTitle"><w:name w:val="KitHub Chapter Title"/><w:pPr><w:pageBreakBefore/></w:pPr></w:style>
  <w:style w:type="paragraph" w:styleId="KitHubFrontMatter"><w:name w:val="KitHub Front Matter"/></w:style>
  <w:style w:type="paragraph" w:styleId="KitHubToc"><w:name w:val="KitHub TOC"/></w:style>
</w:styles>
'@
    $body = New-Object System.Collections.Generic.List[string]
    $idx = 0
    foreach ($p in $Paragraphs) {
      $idx++
      $safe = [System.Security.SecurityElement]::Escape($p)
      $styleId = if ($idx -eq 1) { "KitHubBookTitle" } elseif ($idx -eq 2) { "KitHubBodyFirst" } else { "KitHubBody" }
      $body.Add("<w:p><w:pPr><w:pStyle w:val=""$styleId""/></w:pPr><w:r><w:t xml:space=""preserve"">$safe</w:t></w:r></w:p>")
    }
    Write-Utf8 -Path (Join-Path $tmp "word/document.xml") -Content @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
$($body -join [Environment]::NewLine)
<w:sectPr><w:pgSz w:w="8391" w:h="11906"/><w:pgMar w:top="1440" w:right="1134" w:bottom="1440" w:left="1134" w:gutter="0"/></w:sectPr>
</w:body></w:document>
"@
    Write-Utf8 -Path (Join-Path $tmp "docProps/core.xml") -Content '<?xml version="1.0" encoding="UTF-8"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>KitHub Test</dc:title></cp:coreProperties>'
    Write-Utf8 -Path (Join-Path $tmp "docProps/app.xml") -Content '<?xml version="1.0" encoding="UTF-8"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>kit_hub test</Application></Properties>'

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
      New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
      $rootFull = [System.IO.Path]::GetFullPath($tmp)
      foreach ($file in Get-ChildItem -LiteralPath $tmp -Recurse -File) {
        $full = [System.IO.Path]::GetFullPath($file.FullName)
        $relative = $full.Substring($rootFull.Length).TrimStart("\") -replace "\\", "/"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $full, $relative) | Out-Null
      }
    }
    finally {
      $zip.Dispose()
    }
  }
  finally {
    if (Test-Path -LiteralPath $tmp) {
      Remove-Item -LiteralPath $tmp -Recurse -Force
    }
  }
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

function Assert-ThrowsLike {
  param([scriptblock]$Action, [string]$Pattern, [string]$Label)
  try {
    & $Action
  }
  catch {
    if ($_.Exception.Message -match $Pattern) {
      Write-Host "[docx-export-gate-test] PASS blocked: $Label"
      return
    }
    throw "Unexpected error for ${Label}: $($_.Exception.Message)"
  }
  throw "Expected failure did not occur: $Label"
}

$projectRoot = Join-Path $RepoRoot (".tmp/docx-export-gate-test-" + [guid]::NewGuid().ToString("N"))
try {
  $episodePath = Join-Path $projectRoot "episode/ep001.md"
  $manifestPath = Join-Path $projectRoot "revision/_workspace/export-manifest.json"
  $goodDocx = Join-Path $projectRoot "revision/export/good.docx"
  $staleDocx = Join-Path $projectRoot "revision/export/stale.docx"
  $technicalDocx = Join-Path $projectRoot "revision/export/technical.docx"

  $sourceParagraph = "Pera Palas'ın mermer merdivenlerinde yağmurun sesi usulca çoğalırken Selim, cebindeki küçük pusulanın titrediğini hissetti."
  Write-Utf8 -Path $episodePath -Content "# Mermer Merdivenlerde Yağmur`n`n$sourceParagraph`n`nNermin, lobinin aynasında kendisine değil, arkasından geçen gölgeye bakıyordu."

  New-TestDocx -OutputPath $goodDocx -Paragraphs @("Mermer Merdivenlerde Yağmur", $sourceParagraph, "Nermin, lobinin aynasında kendisine değil, arkasından geçen gölgeye bakıyordu.")
  New-TestDocx -OutputPath $staleDocx -Paragraphs @("Başka Bir Kitap", "Bu metin güncel bölümden gelmeyen eski ve ilgisiz bir dosyadır.")
  New-TestDocx -OutputPath $technicalDocx -Paragraphs @("EP001 - Mermer Merdivenlerde Yağmur", $sourceParagraph, "run_id: RUN-TEST", "VERDICT: PASS")

  Write-Utf8Json -Path $manifestPath -Value ([ordered]@{
    source_files = @("episode/ep001.md")
    output_docx_path = "revision/export/stale.docx"
  })
  Assert-ThrowsLike `
    -Label "stale DOCX content mismatch" `
    -Pattern "does not match source manuscript" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_content_match.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifestPath) | Out-Null
    }

  Write-Utf8Json -Path $manifestPath -Value ([ordered]@{
    source_files = @("episode/ep001.md")
    output_docx_path = "revision/export/technical.docx"
  })
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_content_match.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifestPath) | Out-Null
  Assert-ThrowsLike `
    -Label "technical labels and review notes in reader DOCX" `
    -Pattern "DOCX reader-clean gate failed" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_reader_clean.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifestPath) | Out-Null
    }

  Write-Utf8Json -Path $manifestPath -Value ([ordered]@{
    source_files = @("episode/ep001.md")
    output_docx_path = "revision/export/good.docx"
  })
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_integrity.ps1"), "-DocxPath", $goodDocx, "-MinSizeBytes", "512") | Out-Null
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_content_match.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifestPath) | Out-Null
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_reader_clean.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifestPath) | Out-Null

  Write-Host "[docx-export-gate-test] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectRoot) {
    Remove-Item -LiteralPath $projectRoot -Recurse -Force
  }
}
