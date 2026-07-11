param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8BomText {
  param([string]$Path, [string]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf8BomJson {
  param([string]$Path, [object]$Value)
  Write-Utf8BomText -Path $Path -Value ($Value | ConvertTo-Json -Depth 30)
}

function Read-Utf8Json {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

$projectsRoot = Join-Path $RepoRoot ".tmp/design-plan-specificity"
$projectRoot = Join-Path $projectsRoot "bozkirda-son-mektup-specificity"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", "Bozkirda Son Mektup Specificity", "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null

  $request = @'
Kitap Adi: Bozkirda Son Mektup
Tur: Edebi dram / tarihsel kurmaca
Hedef Uzunluk: 30-60 sayfa
Donem: 1940lar Anadolu
Ana Konu: Genc bir koy ogretmeni, yillar once cepheye gidip donmeyen bir askerin mektuplarini bulur.
Karakter Sayisi: 5 ana karakter.
'@
  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value $request
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novel"
    premise = "Genc bir koy ogretmeni kayip askerin mektuplariyla kasabanin suskunlugunu acar."
    target_length = "30-60 sayfa"
    target_pages = "45"
    target_reader = "Yetiskin edebi kurmaca okuru"
    genre = "edebi dram / tarihsel kurmaca"
    character_policy = "5 ana karakter"
    setting_period = "1940lar Anadolu, koy okulu, istasyon, aile arsivi"
    pov_tense = "Ucuncu tekil, gecmis zaman"
    style_tone = "Edebi, sade, atmosferik, duygu derinligi yuksek"
    boundaries = "Sahte alinti yok, teknik etiket yok, melodram abartisi yok"
    publication_package = "Kapak briefi, onsoz, icindekiler, A5 DOCX"
  }) -Force
  Write-Utf8BomJson -Path $briefApprovalPath -Value $briefApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
  $storyChoicePath = Join-Path $projectRoot "runtime/approvals/story-choice.json"
  $storyChoice = Read-Utf8Json -Path $storyChoicePath
  $storyChoice | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $storyChoice | Add-Member -NotePropertyName selected_option -NotePropertyValue 1 -Force
  Write-Utf8BomJson -Path $storyChoicePath -Value $storyChoice

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null

  $bookPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/book-plan.json")
  $chapterPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/chapter-plan.json")
  if ([string]$bookPlan.title_working -ne "Bozkirda Son Mektup") {
    throw "Design specificity failed: title_working='$($bookPlan.title_working)'"
  }
  if ([int]$bookPlan.target_pages -ne 45) {
    throw "Design specificity failed: target_pages=$($bookPlan.target_pages), expected 45."
  }
  if (@($bookPlan.characters).Count -ne 5) {
    throw "Design specificity failed: expected 5 planned characters, found $(@($bookPlan.characters).Count)."
  }
  if (@($chapterPlan.chapters).Count -lt 8) {
    throw "Design specificity failed: chapter plan too thin."
  }
  $genericTitles = @($chapterPlan.chapters | Where-Object { [string]$_.reader_title -match "^Bölüm\s+\d+$|^Bolum\s+\d+$" })
  if ($genericTitles.Count -gt 0) {
    throw "Design specificity failed: generic reader-facing chapter titles remain."
  }
  Write-Host "[design-plan-specificity-test] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
