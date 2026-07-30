param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase = "create"
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required state file: $Path"
  }
}

function Read-StateJson {
  param([string]$Name)
  $path = Join-Path $ProjectRoot ("revision/_state/{0}" -f $Name)
  Ensure-File $path
  return Read-Utf8 -Path $path | ConvertFrom-Json
}

function Assert-UniqueStrings {
  param([string[]]$Values, [string]$Label)
  $clean = @($Values | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
  if (($clean | Sort-Object -Unique).Count -ne $clean.Count) {
    throw "State reducer conflict: duplicate $Label."
  }
}

function Get-ObjectString {
  param([object]$Obj, [string]$Field)
  if ($null -ne $Obj -and $Obj.PSObject.Properties.Name -contains $Field) {
    return [string]$Obj.$Field
  }
  return ""
}

$bookPlan = Read-StateJson -Name "book-plan.json"
$chapterPlan = Read-StateJson -Name "chapter-plan.json"
$longformPlan = Read-StateJson -Name "longform-plan.json"
$characterState = Read-StateJson -Name "character-state.json"
$plotLedger = Read-StateJson -Name "plot-ledger.json"
$chapterSummaries = Read-StateJson -Name "chapter-summaries.json"
$continuityLedger = Read-StateJson -Name "continuity-ledger.json"

foreach ($field in @("plan_id","characters","chapter_count")) {
  if (-not ($bookPlan.PSObject.Properties.Name -contains $field)) {
    throw "State reducer conflict: book-plan.json missing '$field'."
  }
}
foreach ($field in @("target_chapters","target_words","target_pages")) {
  if (-not ($longformPlan.PSObject.Properties.Name -contains $field)) {
    throw "State reducer conflict: longform-plan.json missing '$field'."
  }
}
if ([int]$bookPlan.chapter_count -ne [int]$longformPlan.target_chapters) {
  throw "State reducer conflict: book-plan chapter_count does not match longform target_chapters."
}

$bookCharacterNames = @($bookPlan.characters | ForEach-Object { Get-ObjectString -Obj $_ -Field "name" })
Assert-UniqueStrings -Values $bookCharacterNames -Label "book-plan character names"
if ($bookCharacterNames.Count -lt 1) {
  throw "State reducer conflict: book-plan has no characters."
}

if (-not ($characterState.PSObject.Properties.Name -contains "characters")) {
  throw "State reducer conflict: character-state.json missing characters."
}
$stateCharacterNames = @($characterState.characters | ForEach-Object { Get-ObjectString -Obj $_ -Field "name" })
Assert-UniqueStrings -Values $stateCharacterNames -Label "character-state names"
foreach ($name in $bookCharacterNames) {
  if ($stateCharacterNames -notcontains $name) {
    throw "State reducer conflict: character-state missing planned character '$name'."
  }
}

if (-not ($chapterPlan.PSObject.Properties.Name -contains "chapters")) {
  throw "State reducer conflict: chapter-plan.json missing chapters."
}
$chapters = @($chapterPlan.chapters)
if ($chapters.Count -ne [int]$longformPlan.target_chapters) {
  throw "State reducer conflict: chapter-plan count does not match longform target_chapters."
}
$chapterIds = @($chapters | ForEach-Object { Get-ObjectString -Obj $_ -Field "id" })
Assert-UniqueStrings -Values $chapterIds -Label "chapter ids"
foreach ($chapter in $chapters) {
  foreach ($field in @("reader_title","purpose","events","target_words")) {
    if (-not ($chapter.PSObject.Properties.Name -contains $field)) {
      throw "State reducer conflict: chapter entry missing '$field'."
    }
  }
}

if ($plotLedger.PSObject.Properties.Name -contains "open_threads" -and $plotLedger.PSObject.Properties.Name -contains "closed_threads") {
  $openThreads = @($plotLedger.open_threads | ForEach-Object { [string]$_ })
  $closedThreads = @($plotLedger.closed_threads | ForEach-Object { [string]$_ })
  foreach ($thread in $openThreads) {
    if ($closedThreads -contains $thread) {
      throw "State reducer conflict: plot thread is both open and closed: $thread"
    }
  }
}
if ($plotLedger.PSObject.Properties.Name -contains "cause_effect_chain") {
  $effects = @()
  foreach ($entry in @($plotLedger.cause_effect_chain)) {
    if ($entry -is [string]) {
      $effects += [string]$entry
    }
    else {
      $effect = Get-ObjectString -Obj $entry -Field "effect"
      if ($effect) { $effects += $effect }
    }
  }
  Assert-UniqueStrings -Values $effects -Label "plot cause/effect entries"
}

if ($continuityLedger.PSObject.Properties.Name -contains "violations") {
  $violations = @($continuityLedger.violations)
  if ($violations.Count -gt 0) {
    throw "State reducer conflict: continuity-ledger contains unresolved violations."
  }
}

if ($Phase -in @("create","polish","rewrite","export")) {
  if (-not ($chapterSummaries.PSObject.Properties.Name -contains "chapters")) {
    throw "State reducer conflict: chapter-summaries.json missing chapters."
  }
  $summaries = @($chapterSummaries.chapters)
  if ($summaries.Count -lt 1) {
    throw "State reducer conflict: chapter-summaries must contain generated chapter records after create."
  }
  $summaryIds = @($summaries | ForEach-Object { Get-ObjectString -Obj $_ -Field "id" })
  Assert-UniqueStrings -Values $summaryIds -Label "chapter summary ids"
  foreach ($summaryId in $summaryIds) {
    if ($chapterIds -notcontains $summaryId) {
      throw "State reducer conflict: chapter summary id '$summaryId' is not in chapter-plan."
    }
  }
  $summaryTexts = @($summaries | ForEach-Object { Get-ObjectString -Obj $_ -Field "summary" })
  Assert-UniqueStrings -Values $summaryTexts -Label "chapter summaries"
  $changes = @($summaries | ForEach-Object { Get-ObjectString -Obj $_ -Field "irreversible_change" } | Where-Object { $_.Trim() })
  if ($changes.Count -gt 0) {
    Assert-UniqueStrings -Values $changes -Label "irreversible changes"
  }
}

Write-Host "[state-reducers] PASS"
