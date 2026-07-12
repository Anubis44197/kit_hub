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

$cases = @(
  [ordered]@{ name = "Novel Type Gate"; slug = "novel-type-gate"; writing_type = "novel"; genre = "literary"; target_pages = "180"; expected = "novel" },
  [ordered]@{ name = "Story Type Gate"; slug = "story-type-gate"; writing_type = "story"; genre = "edebi hikaye"; target_pages = "12"; expected = "story" },
  [ordered]@{ name = "Novella Type Gate"; slug = "novella-type-gate"; writing_type = "novella"; genre = "gizem"; target_pages = "70"; expected = "novella" },
  [ordered]@{ name = "Essay Type Gate"; slug = "essay-type-gate"; writing_type = "essay"; genre = "deneme"; target_pages = "40"; expected = "essay" },
  [ordered]@{ name = "Biography Type Gate"; slug = "biography-type-gate"; writing_type = "biography"; genre = "biyografi"; target_pages = "120"; expected = "biography" },
  [ordered]@{ name = "Memoir Type Gate"; slug = "memoir-type-gate"; writing_type = "memoir"; genre = "ani"; target_pages = "90"; expected = "memoir" },
  [ordered]@{ name = "Research Type Gate"; slug = "research-type-gate"; writing_type = "research_book"; genre = "arastirma"; target_pages = "160"; expected = "research_book" },
  [ordered]@{ name = "Children Type Gate"; slug = "children-type-gate"; writing_type = "children_book"; genre = "cocuk kitabi"; target_pages = "32"; expected = "children_book" },
  [ordered]@{ name = "Poetry Type Gate"; slug = "poetry-type-gate"; writing_type = "poetry_collection"; genre = "siir"; target_pages = "64"; expected = "poetry_collection" },
  [ordered]@{ name = "Screenplay Type Gate"; slug = "screenplay-type-gate"; writing_type = "screenplay"; genre = "senaryo"; target_pages = "100"; expected = "screenplay" }
)

$projectsRoot = Join-Path $RepoRoot ".tmp/writing-type-profiles-gate"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }

  foreach ($case in $cases) {
    Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", ([string]$case.name), "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null
    $projectRoot = Join-Path $projectsRoot ([string]$case.slug)
    Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value ("Tur: {0}. Hedef Uzunluk: {1} sayfa. Konu: Profil kapisi icin kontrollu test." -f $case.writing_type, $case.target_pages)

    Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null

    $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
    $briefApproval = Read-Utf8Json -Path $briefApprovalPath
    $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
    $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
      writing_type = [string]$case.writing_type
      premise = "Profil kapisi icin kontrollu test."
      target_length = ("{0} sayfa" -f $case.target_pages)
      target_pages = [string]$case.target_pages
      target_reader = "Genel okur"
      genre = [string]$case.genre
      character_policy = "Ture uygun karakter veya konu kadrosu"
      setting_period = "Kullanici belirleyecek"
      pov_tense = "Ture uygun"
      style_tone = "Ture uygun, temiz Turkce"
      boundaries = "Teknik etiket yok, sahte kaynak yok"
      publication_package = "A5 DOCX"
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
    $typeProfile = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/writing-type-profile.json")
    $template = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/genre-structure-template.json")
    if ([string]$bookPlan.writing_type -ne [string]$case.expected) {
      throw "Book plan writing_type mismatch for $($case.name): $($bookPlan.writing_type)"
    }
    if ([string]$typeProfile.writing_type -ne [string]$case.expected) {
      throw "Writing type profile mismatch for $($case.name): $($typeProfile.writing_type)"
    }
    if ([string]$template.writing_type -ne [string]$case.expected) {
      throw "Genre template writing_type mismatch for $($case.name): $($template.writing_type)"
    }
  }

  Write-Host "[writing-type-profiles-gate] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
