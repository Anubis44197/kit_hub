param(
  [Parameter(Mandatory = $true)]
  [string]$DocxPath,
  [int]$MinSizeBytes = 2048
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $DocxPath -PathType Leaf)) {
  throw "DOCX file not found: $DocxPath"
}

$fileInfo = Get-Item -LiteralPath $DocxPath
if ($fileInfo.Length -le 0) {
  throw "DOCX file is empty: $DocxPath"
}

if ($fileInfo.Length -lt $MinSizeBytes) {
  throw "DOCX file is too small ($($fileInfo.Length) bytes), expected >= $MinSizeBytes bytes."
}

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $DocxPath))
if ($bytes.Length -lt 4) {
  throw "DOCX file has insufficient bytes for ZIP signature check."
}

$isZipSignature = ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04)
if (-not $isZipSignature) {
  $hex = ($bytes[0..([Math]::Min(7, $bytes.Length - 1))] | ForEach-Object { $_.ToString("X2") }) -join " "
  throw "Invalid DOCX signature. Expected '50 4B 03 04', got '$hex'."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = $null
try {
  $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $DocxPath))
  $entry = $zip.Entries | Where-Object { $_.FullName -eq "word/document.xml" } | Select-Object -First 1
  if (-not $entry) {
    throw "DOCX package is missing required entry: word/document.xml"
  }
}
finally {
  if ($zip) { $zip.Dispose() }
}

Write-Host "[docx-integrity] PASS"
Write-Host "path=$DocxPath"
Write-Host "size_bytes=$($fileInfo.Length)"
Write-Host "signature=50 4B 03 04"
Write-Host "contains=word/document.xml"
