param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Message,
    [switch]$Simple
  )
  $raw = Read-Utf8 -Path $Path
  $matched = if ($Simple) { $raw.Contains($Pattern) } else { $raw -match $Pattern }
  if (-not $matched) {
    throw $Message
  }
}

$runner = Join-Path $ProjectRoot "scripts/run_pipeline.ps1"
$localPhase = Join-Path $ProjectRoot "scripts/local_phase.ps1"
$commandTemplate = Join-Path $ProjectRoot "runtime/runner-config.template.json"
$manualTemplate = Join-Path $ProjectRoot "runtime/runner-config.ide-manual.template.json"

Assert-Contains -Path $runner -Pattern "require_turkish_diacritics" -Message "Runner missing Turkish diacritic hard gate."
Assert-Contains -Path $runner -Pattern "min_turkish_diacritic_ratio" -Message "Runner missing Turkish diacritic ratio threshold."
Assert-Contains -Path $runner -Pattern "turkishDiacriticCount" -Message "Runner missing Turkish diacritic counter."
Assert-Contains -Path $runner -Pattern "ASCII transliteration" -Message "Runner error must explain ASCII transliteration failure."
Assert-Contains -Path $runner -Pattern "replacement/question-mark encoding corruption" -Message "Runner missing question-mark encoding corruption gate."
Assert-Contains -Path $localPhase -Pattern "replacement/question-mark encoding corruption" -Message "Export local phase missing question-mark encoding corruption gate."
Assert-Contains -Path $commandTemplate -Pattern '"require_turkish_diacritics": true' -Message "Command runner template must enable Turkish diacritic gate."
Assert-Contains -Path $manualTemplate -Pattern '"require_turkish_diacritics": true' -Message "IDE manual template must enable Turkish diacritic gate."

Write-Host "[turkish-diacritics-gate] PASS"
