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

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing expected file: $Path"
  }
}

function Assert-HasProperty {
  param([object]$Object, [string]$Name, [string]$Label)
  if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
    throw "$Label missing '$Name'."
  }
}

$projectsRoot = Join-Path $RepoRoot ".tmp/open-source-story-model-gate"
$projectRoot = Join-Path $projectsRoot "open-source-model-test"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", "Open Source Model Test", "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null

  $request = @'
Kitap Adi: Kayıp Rıhtım Defteri
Tur: Tarihi gizem romanı
Hedef Uzunluk: 80 sayfa
Konu: 1930'larda İstanbul limanında bulunan eski bir defter, üç ailenin sakladığı bir sırrı açığa çıkarır.
Karakter Sayisi: 4 ana karakter.
'@
  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value $request

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novel"
    premise = "1930'larda İstanbul limanında bulunan eski bir defter, üç ailenin sakladığı sırrı açığa çıkarır."
    target_length = "80 sayfa"
    target_pages = "80"
    target_reader = "Yetiskin tarihi gizem okuru"
    genre = "tarihi gizem romanı"
    character_policy = "4 ana karakter"
    setting_period = "1930'lar İstanbul limanı, rıhtım, aile evleri"
    pov_tense = "Ucuncu tekil, gecmis zaman"
    style_tone = "Edebi, gizemli, atmosferik"
    boundaries = "Sahte kaynak, teknik etiket, tekrar eden bölüm yapısı yok"
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

  $modelPath = Join-Path $projectRoot "revision/_state/open-source-story-model.json"
  Assert-File $modelPath
  $bookPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/book-plan.json")
  if ([string]$bookPlan.open_source_story_model -ne "revision/_state/open-source-story-model.json") {
    throw "Book plan does not bind open-source-story-model.json."
  }

  $model = Read-Utf8Json -Path $modelPath
  foreach ($field in @("sources", "outline_model", "character_model", "plot_model", "world_model", "cross_reference_model", "research_outline_model", "export_model")) {
    Assert-HasProperty -Object $model -Name $field -Label "open-source-story-model"
  }

  $sourceNames = @($model.sources | ForEach-Object { [string]$_.project })
  foreach ($source in @("Manuskript", "novelWriter", "bibisco", "STORM")) {
    if ($sourceNames -notcontains $source) {
      throw "open-source-story-model missing source '$source'."
    }
  }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/validate_state_reducers.ps1"), "-ProjectRoot", $projectRoot, "-Phase", "design-big") | Out-Null

  Write-Host "[open-source-story-model-gate] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
