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

function Get-ObjectStringAny {
  param([object]$Obj, [string[]]$Fields)
  foreach ($field in $Fields) {
    $value = Get-ObjectString -Obj $Obj -Field $field
    if ($value.Trim()) { return $value }
  }
  return ""
}

function Get-CharacterAliases {
  param([string]$Name)
  $titleWords = @("Doktor","Dr","Madam","Bay","Bayan","Hanım","Hanim","Bey")
  $parts = @($Name -split "\s+" | Where-Object { $_ -and $_.Trim() })
  $aliases = @()
  if ($Name.Trim()) { $aliases += $Name.Trim() }
  foreach ($part in $parts) {
    $clean = $part.Trim()
    if ($clean -and $titleWords -notcontains $clean) {
      $aliases += $clean
      break
    }
  }
  return @($aliases | Select-Object -Unique)
}

$bookPlan = Read-StateJson -Name "book-plan.json"
$chapterPlan = Read-StateJson -Name "chapter-plan.json"
$longformPlan = Read-StateJson -Name "longform-plan.json"
$characterState = Read-StateJson -Name "character-state.json"
$plotLedger = Read-StateJson -Name "plot-ledger.json"
$chapterSummaries = Read-StateJson -Name "chapter-summaries.json"
$continuityLedger = Read-StateJson -Name "continuity-ledger.json"
$writingProfile = Read-StateJson -Name "writing-type-profile.json"
$structureTemplate = Read-StateJson -Name "genre-structure-template.json"
$claimLedger = Read-StateJson -Name "claim-ledger.json"
$sourceLedger = Read-StateJson -Name "source-ledger.json"
$termGlossary = Read-StateJson -Name "term-glossary.json"
$argumentLedger = Read-StateJson -Name "argument-ledger.json"
$writingType = if ($bookPlan.PSObject.Properties.Name -contains "writing_type") { [string]$bookPlan.writing_type } else { "" }
$fictionWritingTypes = @("novel","story","novella","children_book","young_adult","screenplay")
$nonfictionWritingTypes = @("essay","memoir","biography","research_book","self_help","business_book","academic")
$relationshipGraphPath = Join-Path $ProjectRoot "revision/_state/relationship-graph.json"
$relationshipGraph = $null
if (Test-Path -LiteralPath $relationshipGraphPath -PathType Leaf) {
  $relationshipGraph = Read-Utf8 -Path $relationshipGraphPath | ConvertFrom-Json
}

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
if (($fictionWritingTypes -contains $writingType) -and $bookCharacterNames.Count -lt 1) {
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
foreach ($name in $stateCharacterNames) {
  if ($bookCharacterNames -notcontains $name) {
    throw "State reducer conflict: character-state contains unplanned character '$name'."
  }
}

if ($relationshipGraph -and ($relationshipGraph.PSObject.Properties.Name -contains "nodes")) {
  $graphCharacterNames = @($relationshipGraph.nodes | ForEach-Object { Get-ObjectStringAny -Obj $_ -Fields @("name","label") } | Where-Object { $_.Trim() })
  Assert-UniqueStrings -Values $graphCharacterNames -Label "relationship-graph character names"
  foreach ($name in $bookCharacterNames) {
    if ($graphCharacterNames -notcontains $name) {
      throw "State reducer conflict: relationship-graph missing planned character '$name'."
    }
  }
  foreach ($name in $graphCharacterNames) {
    if ($bookCharacterNames -notcontains $name) {
      throw "State reducer conflict: relationship-graph contains unplanned character '$name'."
    }
  }
}

foreach ($field in @("writing_type","structure_model","continuity_policy","completion_criteria")) {
  if (-not ($writingProfile.PSObject.Properties.Name -contains $field) -or -not ([string]$writingProfile.$field).Trim()) {
    throw "State reducer conflict: writing-type-profile.json missing concrete '$field'."
  }
}
$supportedWritingTypes = @("novel","story","novella","children_book","young_adult","essay","memoir","biography","research_book","self_help","business_book","academic","poetry_collection","screenplay")
if ($supportedWritingTypes -notcontains ([string]$writingProfile.writing_type)) {
  throw "State reducer conflict: unsupported writing_type '$($writingProfile.writing_type)'."
}
if ([string]$bookPlan.writing_type -ne [string]$writingProfile.writing_type) {
  throw "State reducer conflict: book-plan writing_type does not match writing-type-profile."
}

if (-not ($structureTemplate.PSObject.Properties.Name -contains "mandatory_ledgers")) {
  throw "State reducer conflict: genre-structure-template.json missing mandatory_ledgers."
}
$mandatoryLedgers = @($structureTemplate.mandatory_ledgers | ForEach-Object { [string]$_ })
foreach ($ledger in @("chapter-summaries.json","continuity-ledger.json")) {
  if ($mandatoryLedgers -notcontains $ledger) {
    throw "State reducer conflict: mandatory_ledgers missing '$ledger'."
  }
}

if ($nonfictionWritingTypes -contains ([string]$writingProfile.writing_type)) {
  foreach ($ledger in @("claim-ledger.json","source-ledger.json","term-glossary.json","argument-ledger.json")) {
    if ($mandatoryLedgers -notcontains $ledger) {
      throw "State reducer conflict: nonfiction profile missing mandatory ledger '$ledger'."
    }
  }
}
foreach ($pair in @(
  @{ name = "claim-ledger.json"; obj = $claimLedger; fields = @("claims","unsupported_claims","rule") },
  @{ name = "source-ledger.json"; obj = $sourceLedger; fields = @("sources","missing_sources","rule") },
  @{ name = "term-glossary.json"; obj = $termGlossary; fields = @("terms","rule") },
  @{ name = "argument-ledger.json"; obj = $argumentLedger; fields = @("chapter_arguments","counterarguments","rule") }
)) {
  foreach ($field in $pair.fields) {
    if (-not ($pair.obj.PSObject.Properties.Name -contains $field)) {
      throw "State reducer conflict: $($pair.name) missing '$field'."
    }
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
  if (($fictionWritingTypes -contains $writingType) -and $chapter.PSObject.Properties.Name -contains "character_focus") {
    $focus = [string]($chapter.character_focus -join " ")
    $allowedAliases = @()
    foreach ($name in $bookCharacterNames) { $allowedAliases += Get-CharacterAliases -Name $name }
    $mentionsKnownCharacter = $false
    foreach ($alias in $allowedAliases) {
      if ($focus -match "(?<!\p{L})$([regex]::Escape($alias))(?!\p{L})") { $mentionsKnownCharacter = $true }
    }
    $genericFocus = $focus -match "(?i)(ana karakter|başkarakter|baskarakter|protagonist|karakter)"
    if (-not $mentionsKnownCharacter -and -not $genericFocus -and $focus -match "\b[A-ZÇĞİÖŞÜ][a-zçğıöşü]{2,}\b") {
      throw "State reducer conflict: chapter character_focus appears to name a character but does not match planned characters."
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
