param(
  [string]$EngineRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$EngineRoot = (Resolve-Path -LiteralPath $EngineRoot).Path
$localPhaseScript = Join-Path $EngineRoot "scripts/local_phase.ps1"
if (-not (Test-Path -LiteralPath $localPhaseScript -PathType Leaf)) { throw "Local phase script not found: $localPhaseScript" }

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kithub-intake-test-" + [guid]::NewGuid().ToString("N"))
$runtimeDir = Join-Path $testRoot "runtime"

function Copy-EngineFile {
  param([string]$RelativePath)
  $source = Join-Path $EngineRoot $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required engine file missing: $RelativePath" }
  $target = Join-Path $testRoot $RelativePath
  $targetDir = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }
  Copy-Item -LiteralPath $source -Destination $target -Force
}

function Write-Request {
  param([string]$Text)
  [System.IO.File]::WriteAllText((Join-Path $runtimeDir "book-request.md"), $Text, [System.Text.UTF8Encoding]::new($true))
}

function Run-Intake {
  param([string]$RunId)
  & powershell -NoProfile -ExecutionPolicy Bypass -File $localPhaseScript -ProjectRoot $testRoot -Phase intake -RunId $RunId | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Local intake failed with exit code $LASTEXITCODE." }
  return Get-Content -LiteralPath (Join-Path $runtimeDir "book-brief.json") -Raw | ConvertFrom-Json
}

$completeRequest = @"
# Kitap İsteği

- Tür: Psikolojik gizem romanı
- Hedef sayfa: 24
- Hedef okur: Yetişkin psikolojik gizem okurları
- Konu: Şifreli bir defter aile sırrını açığa çıkarır.
- Karakterler: Defne Aral, Cem ve Nermin.
- Dönem ve mekân: Günümüz İstanbul'u; Beyoğlu ve Balat.
- Anlatıcı: Üçüncü tekil sınırlı, geçmiş zaman.
- Final: Defne annesiyle yüzleşir.
- Üslup: Edebi, akıcı ve gerilim odaklı.
- Sınırlar: Grafik şiddet ve gerçek kişi iddiası yok.
- Yayın paketi: A5 DOCX, başlık sayfası, içindekiler ve kapak briefi.
"@

# Keep the fixture ASCII-only so Windows PowerShell 5.1 parses the script
# consistently even when the host's legacy code page is not UTF-8.
$completeRequest = @"
# Kitap Istegi

- Tur: Psikolojik gizem romani
- Hedef sayfa: 24
- Hedef okur: Yetiskin psikolojik gizem okurlari
- Konu: Sifreli bir defter aile sirrini aciga cikarir.
- Karakterler: Defne Aral, Cem ve Nermin.
- Donem ve mekan: Gunumuz Istanbul'u; Beyoglu ve Balat.
- Anlatici: Ucuncu tekil sinirli, gecmis zaman.
- Final: Defne annesiyle yuzlesir.
- Uslup: Edebi, akici ve gerilim odakli.
- Sinirlar: Grafik siddet ve gercek kisi iddiasi yok.
- Yayin paketi: A5 DOCX, baslik sayfasi, icindekiler ve kapak briefi.
"@

try {
  New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
  foreach ($relative in @(
    "runtime/agent-registry.json",
    "runtime/agent-status-contract.json",
    "runtime/phase-contracts/intake.json",
    "skills/intake/SKILL.md",
    "skills/polish/references/writing-type-profiles.md",
    "skills/polish/references/docx-professional-style-contract.md"
  )) {
    Copy-EngineFile -RelativePath $relative
  }

  Write-Request -Text $completeRequest
  $completeBrief = Run-Intake -RunId "RUN-INTAKE-COMPLETE"
  $completeDna = Get-Content -LiteralPath (Join-Path $runtimeDir "book-dna.json") -Raw | ConvertFrom-Json
  $completeProfile = Get-Content -LiteralPath (Join-Path $runtimeDir "layout-profile.json") -Raw | ConvertFrom-Json
  $approval = Get-Content -LiteralPath (Join-Path $runtimeDir "approvals/book-brief-approval.json") -Raw | ConvertFrom-Json
  if ($completeBrief.brief_status -ne "READY_FOR_APPROVAL") { throw "Complete request did not become READY_FOR_APPROVAL." }
  if ($completeDna.answers_complete -ne $true) { throw "Complete request did not set book DNA answers_complete=true." }
  if ($completeProfile.profile_status -ne "READY_FOR_APPROVAL") { throw "Complete request did not ready the layout profile." }
  if ($approval.approved -eq $true) { throw "Intake must not auto-approve the user gate." }

  $incompleteRequest = $completeRequest -replace '(?m)^- Hedef okur:.*\r?\n', ''
  Write-Request -Text $incompleteRequest
  $incompleteBrief = Run-Intake -RunId "RUN-INTAKE-INCOMPLETE"
  $incompleteDna = Get-Content -LiteralPath (Join-Path $runtimeDir "book-dna.json") -Raw | ConvertFrom-Json
  if ($incompleteBrief.brief_status -ne "QUESTIONS_PENDING") { throw "Incomplete request did not remain QUESTIONS_PENDING." }
  if ($incompleteDna.answers_complete -eq $true) { throw "Incomplete request incorrectly set answers_complete=true." }
  if ([string]$incompleteBrief.answers.target_reader) { throw "Missing target reader was not preserved as an empty answer." }

  Write-Host "[local-intake-status] PASS complete=READY_FOR_APPROVAL incomplete=QUESTIONS_PENDING approval=false"
}
finally {
  if (Test-Path -LiteralPath $testRoot -PathType Container) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
