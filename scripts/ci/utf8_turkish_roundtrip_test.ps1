param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8BomText {
  param(
    [string]$Path,
    [string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($true))
}

function Read-Utf8Text {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Assert-ContainsText {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Label
  )
  if (-not $Text.Contains($Needle)) {
    throw "UTF-8 roundtrip failed for ${Label}: expected '$Needle'."
  }
}

$projectRoot = Join-Path $RepoRoot ".tmp/utf8-turkish-roundtrip"
try {
  if (Test-Path -LiteralPath $projectRoot) {
    Remove-Item -LiteralPath $projectRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Path (Join-Path $projectRoot "runtime") | Out-Null

  $istanbul = "$([char]0x0130)stanbul'da $([char]0x015F)apkal$([char]0x0131) M$([char]0x00FC)nevver"
  $alphabet = "$([char]0x011F)$([char]0x00FC)$([char]0x015F)$([char]0x00F6)$([char]0x00E7)$([char]0x0131) $([char]0x0130)$([char]0x011E)$([char]0x00DC)$([char]0x015E)$([char]0x00D6)$([char]0x00C7)"
  $question = "ayr$([char]0x0131) m$([char]0x0131) yaz$([char]0x0131)l$([char]0x0131)r"
  $request = "$istanbul; $alphabet karakterleri bozulmadan kalmal$([char]0x0131). Soru eki ${question}?"
  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value $request

  powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/local_phase.ps1") -ProjectRoot $projectRoot -Phase intake -RunId "UTF8-ROUNDTRIP" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "local_phase intake failed during UTF-8 roundtrip test."
  }

  $briefRaw = Read-Utf8Text -Path (Join-Path $projectRoot "runtime/book-brief.json")
  $brief = $briefRaw | ConvertFrom-Json
  $sourcePrompt = [string]$brief.source_prompt
  Assert-ContainsText -Text $sourcePrompt -Needle $istanbul -Label "source_prompt"
  Assert-ContainsText -Text $sourcePrompt -Needle $alphabet -Label "Turkish alphabet"
  Assert-ContainsText -Text $sourcePrompt -Needle $question -Label "question particle text"

  $bytes = [System.IO.File]::ReadAllBytes((Join-Path $projectRoot "runtime/book-brief.json"))
  if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    throw "UTF-8 BOM missing from generated book-brief.json."
  }

  Write-Host "[utf8-turkish-roundtrip-test] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectRoot) {
    Remove-Item -LiteralPath $projectRoot -Recurse -Force
  }
}
