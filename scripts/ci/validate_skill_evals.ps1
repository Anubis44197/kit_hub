param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string[]]$SkillNames = @("create", "polish", "export-word")
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required eval file: $Path"
  }
  return Read-Utf8 -Path $Path | ConvertFrom-Json
}

function Assert-NonEmptyString {
  param(
    [object]$Value,
    [string]$Field,
    [string]$Path
  )
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    throw "Missing or empty '$Field' in $Path"
  }
}

function Assert-TriggerEvals {
  param(
    [string]$SkillName,
    [string]$Path
  )

  $doc = Read-Json -Path $Path
  if ([string]$doc.skill_name -ne $SkillName) {
    throw "Trigger eval skill_name mismatch in $Path"
  }
  if ($null -eq $doc.queries -or @($doc.queries).Count -lt 4) {
    throw "Trigger evals must include at least 4 queries in $Path"
  }

  $positive = 0
  $negative = 0
  $ids = @()
  foreach ($query in @($doc.queries)) {
    Assert-NonEmptyString -Value $query.id -Field "queries[].id" -Path $Path
    Assert-NonEmptyString -Value $query.query -Field "queries[].query" -Path $Path
    Assert-NonEmptyString -Value $query.reason -Field "queries[].reason" -Path $Path
    if ($null -eq $query.should_trigger -or $query.should_trigger.GetType().Name -ne "Boolean") {
      throw "queries[].should_trigger must be boolean in $Path"
    }
    $ids += [string]$query.id
    if ($query.should_trigger) { $positive++ } else { $negative++ }
  }

  if (($ids | Sort-Object -Unique).Count -ne $ids.Count) {
    throw "Duplicate trigger eval id in $Path"
  }
  if ($positive -lt 2 -or $negative -lt 2) {
    throw "Trigger evals need at least 2 positive and 2 negative queries in $Path"
  }
}

function Assert-OutputEvals {
  param(
    [string]$SkillName,
    [string]$Path
  )

  $doc = Read-Json -Path $Path
  if ([string]$doc.skill_name -ne $SkillName) {
    throw "Output eval skill_name mismatch in $Path"
  }
  if ($null -eq $doc.evals -or @($doc.evals).Count -lt 2) {
    throw "Output evals must include at least 2 cases in $Path"
  }

  $ids = @()
  foreach ($eval in @($doc.evals)) {
    Assert-NonEmptyString -Value $eval.id -Field "evals[].id" -Path $Path
    Assert-NonEmptyString -Value $eval.prompt -Field "evals[].prompt" -Path $Path
    Assert-NonEmptyString -Value $eval.expected_output -Field "evals[].expected_output" -Path $Path
    if ($null -eq $eval.assertions -or @($eval.assertions).Count -lt 3) {
      throw "Each output eval must include at least 3 assertions in $Path"
    }
    foreach ($assertion in @($eval.assertions)) {
      Assert-NonEmptyString -Value $assertion -Field "evals[].assertions[]" -Path $Path
    }
    $ids += [string]$eval.id
  }

  if (($ids | Sort-Object -Unique).Count -ne $ids.Count) {
    throw "Duplicate output eval id in $Path"
  }
}

foreach ($skillName in $SkillNames) {
  $skillDir = Join-Path $ProjectRoot "skills/$skillName"
  if (-not (Test-Path -LiteralPath $skillDir -PathType Container)) {
    throw "Missing skill directory: $skillDir"
  }

  Assert-TriggerEvals -SkillName $skillName -Path (Join-Path $skillDir "evals/trigger_queries.json")
  Assert-OutputEvals -SkillName $skillName -Path (Join-Path $skillDir "evals/output_evals.json")
}

Write-Host "[skill-evals] PASS ($($SkillNames.Count) skills)"
