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
  Write-Utf8BomText -Path $Path -Value ($Value | ConvertTo-Json -Depth 40)
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

$projectsRoot = Join-Path $RepoRoot ".tmp/longform-scalability-gate"
$projectRoot = Join-Path $projectsRoot "besyuz-sayfa-roman-gate"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", "Besyuz Sayfa Roman Gate", "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null

  $request = @'
Kitap Adi: Sisli Defterler
Tur: Roman
Alt Tur: Tarihi gerilim
Hedef Uzunluk: 500 sayfa
Karakter Sayisi: 8 ana karakter
Konu: 1930lar Istanbulunda eski bir istihbarat dosyasi, bir ailenin gecmisi ve uluslararasi bir komplonun izleriyle birlesir.
'@
  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value $request

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novel"
    premise = "1930lar Istanbulunda eski bir istihbarat dosyasi, aile sirri ve uluslararasi komplo birbirine baglanir."
    target_length = "500 sayfa"
    target_pages = "500"
    target_reader = "Yetiskin roman okuru"
    genre = "tarihi gerilim"
    character_policy = "8 ana karakter"
    setting_period = "1930lar Istanbul"
    pov_tense = "Ucuncu tekil, gecmis zaman"
    style_tone = "Edebi, atmosferik, kontrollu gerilim"
    boundaries = "Teknik etiket yok, sahte alinti yok, bolum tekrari yok"
    publication_package = "A5 DOCX, kapak briefi, onsoz, icindekiler, kunye"
  }) -Force
  Write-Utf8BomJson -Path $briefApprovalPath -Value $briefApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
  $storyChoicePath = Join-Path $projectRoot "runtime/approvals/story-choice.json"
  $storyChoice = Read-Utf8Json -Path $storyChoicePath
  $storyChoice | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $storyChoice | Add-Member -NotePropertyName selected_option -NotePropertyValue 1 -Force
  Write-Utf8BomJson -Path $storyChoicePath -Value $storyChoice

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null

  $stateRoot = Join-Path $projectRoot "revision/_state"
  $bookPlan = Read-Utf8Json -Path (Join-Path $stateRoot "book-plan.json")
  $chapterPlan = Read-Utf8Json -Path (Join-Path $stateRoot "chapter-plan.json")
  $longformPlan = Read-Utf8Json -Path (Join-Path $stateRoot "longform-plan.json")
  $volumePlan = Read-Utf8Json -Path (Join-Path $stateRoot "volume-plan.json")
  $adapterContract = Read-Utf8Json -Path (Join-Path $stateRoot "llm-adapter-contract.json")
  $storyModel = Read-Utf8Json -Path (Join-Path $stateRoot "open-source-story-model.json")

  if ([string]$bookPlan.writing_type -ne "novel") { throw "Longform gate lost writing_type=novel." }
  if ([int]$bookPlan.target_pages -ne 500) { throw "Longform gate lost target_pages=500." }
  if ([string]$longformPlan.scale_tier -ne "epic_longform") { throw "Expected epic_longform, found $($longformPlan.scale_tier)." }
  if ([int]$longformPlan.target_chapters -lt 60) { throw "500 page novel produced too few chapters: $($longformPlan.target_chapters)." }
  if ([int]$longformPlan.max_chapters_per_batch -ne 1) { throw "Epic longform must use one chapter per generation batch." }
  if ([int]$longformPlan.audit_interval_chapters -ne 10) { throw "Epic longform audit interval must be 10 chapters." }
  if ([string]$longformPlan.structure_model -in @("short_story_arc", "chaptered_short_book")) {
    throw "500 page novel selected short-form structure model: $($longformPlan.structure_model)."
  }
  if ([string]$bookPlan.structure_model -ne [string]$longformPlan.structure_model) {
    throw "book-plan and longform-plan structure_model mismatch."
  }
  if ([int]$volumePlan.target_chapters -ne [int]$longformPlan.target_chapters) { throw "volume-plan target_chapters mismatch." }
  if (@($chapterPlan.chapters).Count -ne [int]$longformPlan.target_chapters) { throw "chapter-plan count does not match longform target_chapters." }
  if ([int]$adapterContract.max_chapters_per_batch -ne 1) { throw "LLM adapter contract did not inherit max_chapters_per_batch=1." }
  if ([string]$adapterContract.governing_story_model -ne "revision/_state/open-source-story-model.json") { throw "LLM adapter contract missing governing story model." }
  foreach ($requiredModel in @("outline_model","character_model","plot_model","world_model","cross_reference_model","export_model")) {
    if (-not ($storyModel.PSObject.Properties.Name -contains $requiredModel)) {
      throw "Open source story model missing '$requiredModel'."
    }
  }

  $bookPlanApprovalPath = Join-Path $projectRoot "runtime/approvals/book-plan-approval.json"
  $bookPlanApproval = Read-Utf8Json -Path $bookPlanApprovalPath
  $bookPlanApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_writing_type -NotePropertyValue ([string]$bookPlan.writing_type) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_genre -NotePropertyValue ([string]$bookPlan.genre) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_targets -NotePropertyValue ([ordered]@{
    target_pages = [int]$longformPlan.target_pages
    target_words = [int]$longformPlan.target_words
    target_chapters = [int]$longformPlan.target_chapters
  }) -Force
  Write-Utf8BomJson -Path $bookPlanApprovalPath -Value $bookPlanApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-small", "-ToPhase", "design-small") | Out-Null

  Assert-File (Join-Path $projectRoot "design/EP001-EP001_scene_plan.md")
  if (Test-Path -LiteralPath (Join-Path $projectRoot "design/EP001-EP003_scene_plan.md") -PathType Leaf) {
    throw "Epic longform design-small exceeded max_chapters_per_batch=1."
  }

  Write-Host "[longform-scalability-gate] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
