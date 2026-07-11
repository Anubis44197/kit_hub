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

function Write-Utf8BomJson {
  param(
    [string]$Path,
    [object]$Value
  )
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

function Assert-ThrowsLike {
  param(
    [scriptblock]$Action,
    [string]$Pattern,
    [string]$Label
  )
  try {
    & $Action
  }
  catch {
    if ($_.Exception.Message -match $Pattern) {
      Write-Host "[small-e2e-user-flow-test] PASS blocked: $Label"
      return
    }
    throw "Unexpected error for ${Label}: $($_.Exception.Message)"
  }
  throw "Expected failure did not occur: $Label"
}

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing expected file: $Path"
  }
}

$projectsRoot = Join-Path $RepoRoot ".tmp/small-e2e-user-flow"
$projectName = "Small E2E User Flow"
$projectRoot = Join-Path $projectsRoot "small-e2e-user-flow"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", $projectName, "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null

  Assert-File (Join-Path $projectRoot ".kithub-project.json")
  if (Test-Path -LiteralPath (Join-Path $projectRoot ".git")) {
    throw "Small E2E project must not include application .git directory."
  }

  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value "10 sayfalik, 6 karakterli, 1930'larda Pera Palas'ta baslayan tarihsel ajan hikayesi. Ataturk tarihsel saygi cercevesinde konuya dahil olsun; sahte soz veya sahte alinti kullanilmasin."

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null
  Assert-File (Join-Path $projectRoot "runtime/book-brief.json")
  Assert-File (Join-Path $projectRoot "runtime/book-dna.json")
  Assert-File (Join-Path $projectRoot "runtime/layout-profile.json")
  Assert-File (Join-Path $projectRoot "runtime/approvals/book-brief-approval.json")

  Assert-ThrowsLike `
    -Label "propose without approved brief" `
    -Pattern "book-brief-approval|approved" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
    }

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novel"
    premise = "1930'larda Pera Palas'ta baslayan tarihsel ajan hikayesi"
    target_length = "10 sayfa"
    target_reader = "yetişkin okur"
    genre = "tarihsel ajan hikayesi"
    character_policy = "6 karakter"
    setting_period = "1930'lar Istanbul, Pera Palas"
    pov_tense = "ucuncu tekil gecmis zaman"
    style_tone = "edebi, gerilimli, donem ruhuna uygun"
    boundaries = "Ataturk icin sahte soz, sahte alinti veya dogrulanmamis belge kullanilmayacak"
    publication_package = "kapak briefi, onsoz, icindekiler, A5 DOCX"
  }) -Force
  Write-Utf8BomJson -Path $briefApprovalPath -Value $briefApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
  Assert-File (Join-Path $projectRoot "runtime/approvals/story-choice.json")

  Assert-ThrowsLike `
    -Label "design-big without selected story choice" `
    -Pattern "story-choice|selected_option|approved" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null
    }

  $storyChoicePath = Join-Path $projectRoot "runtime/approvals/story-choice.json"
  $storyChoice = Read-Utf8Json -Path $storyChoicePath
  $storyChoice | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $storyChoice | Add-Member -NotePropertyName selected_option -NotePropertyValue 1 -Force
  Write-Utf8BomJson -Path $storyChoicePath -Value $storyChoice

  Assert-ThrowsLike `
    -Label "design-big with short length depth risk not acknowledged" `
    -Pattern "Length-depth gate blocked" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null
    }

  Write-Utf8BomJson -Path (Join-Path $projectRoot "runtime/approvals/length-depth-approval.json") -Value ([ordered]@{
    title = "Length Depth Approval"
    approved = $true
    risk_acknowledged = $true
    note = "Small E2E test intentionally accepts short-form depth risk."
  })

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null
  Assert-File (Join-Path $projectRoot "design/04_book_plan.md")
  Assert-File (Join-Path $projectRoot "design/05_chapter_plan.md")
  Assert-File (Join-Path $projectRoot "design/06_layout_plan.md")
  Assert-File (Join-Path $projectRoot "runtime/approvals/book-plan-approval.json")

  Assert-ThrowsLike `
    -Label "design-small without approved book plan" `
    -Pattern "book-plan-approval|approved" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-small", "-ToPhase", "design-small") | Out-Null
    }

  $bookPlanApprovalPath = Join-Path $projectRoot "runtime/approvals/book-plan-approval.json"
  $bookPlanApproval = Read-Utf8Json -Path $bookPlanApprovalPath
  $generatedBookPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/book-plan.json")
  $generatedLongformPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/longform-plan.json")
  $bookPlanApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_writing_type -NotePropertyValue ([string]$generatedBookPlan.writing_type) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_genre -NotePropertyValue ([string]$generatedBookPlan.genre) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_targets -NotePropertyValue ([ordered]@{
    target_pages = [int]$generatedLongformPlan.target_pages
    target_words = [int]$generatedLongformPlan.target_words
    target_chapters = [int]$generatedLongformPlan.target_chapters
  }) -Force
  Write-Utf8BomJson -Path $bookPlanApprovalPath -Value $bookPlanApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-small", "-ToPhase", "design-small") | Out-Null

  $bookPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/book-plan.json")
  if ([string]$bookPlan.writing_type -ne "novel") {
    throw "Book plan did not preserve approved writing_type=novel."
  }
  if ([int]$bookPlan.target_pages -ne 10) {
    throw "Book plan did not preserve approved target_pages=10."
  }

  Write-Host "[small-e2e-user-flow-test] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
