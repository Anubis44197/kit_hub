param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Assert-SequenceContract {
  param([object]$Contract)

  $phase = [string]$Contract.phase
  $requiredAgents = @($Contract.required_agents | ForEach-Object { [string]$_ })
  $sequence = @($Contract.agent_sequence | ForEach-Object { [string]$_ })

  if ($sequence.Count -ne $requiredAgents.Count) {
    throw "Agent sequence mismatch in '$phase': sequence must include every required agent exactly once."
  }
  foreach ($agent in $requiredAgents) {
    if ($sequence -notcontains $agent) {
      throw "Agent sequence mismatch in '$phase': missing '$agent'."
    }
  }
  if (($sequence | Sort-Object -Unique).Count -ne $sequence.Count) {
    throw "Agent sequence mismatch in '$phase': duplicate agents."
  }
  if ($requiredAgents -contains "chief-editor-orchestrator" -and $sequence[-1] -ne "chief-editor-orchestrator") {
    throw "Agent sequence mismatch in '$phase': chief-editor-orchestrator must be last."
  }
}

function Assert-Before {
  param([object]$Contract, [string]$First, [string]$Second)
  $sequence = @($Contract.agent_sequence | ForEach-Object { [string]$_ })
  $firstIndex = [array]::IndexOf($sequence, $First)
  $secondIndex = [array]::IndexOf($sequence, $Second)
  if ($firstIndex -lt 0 -or $secondIndex -lt 0) {
    throw "Agent sequence semantic check missing '$First' or '$Second' in '$($Contract.phase)'."
  }
  if ($firstIndex -ge $secondIndex) {
    throw "Agent sequence semantic check failed in '$($Contract.phase)': '$First' must run before '$Second'."
  }
}

$contracts = @{}
foreach ($phase in @("intake","propose","design-big","design-small","create","polish","rewrite","export")) {
  $contract = Read-Utf8Json -Path (Join-Path $ProjectRoot "runtime/phase-contracts/$phase.json")
  Assert-SequenceContract -Contract $contract
  $contracts[$phase] = $contract
}

Assert-Before -Contract $contracts["create"] -First "episode-creator" -Second "tdk-polisher"
Assert-Before -Contract $contracts["create"] -First "tdk-polisher" -Second "tdk-layout-agent"
Assert-Before -Contract $contracts["create"] -First "tdk-layout-agent" -Second "quality-verifier"
Assert-Before -Contract $contracts["create"] -First "quality-verifier" -Second "tdk-rule-auditor"

Assert-Before -Contract $contracts["polish"] -First "developmental-editor" -Second "continuity-editor"
Assert-Before -Contract $contracts["polish"] -First "line-editor" -Second "copy-editor"
Assert-Before -Contract $contracts["polish"] -First "copy-editor" -Second "tdk-polisher"
Assert-Before -Contract $contracts["polish"] -First "tdk-layout-agent" -Second "revision-reviewer"
Assert-Before -Contract $contracts["polish"] -First "revision-reviewer" -Second "final-proofreader"

Assert-Before -Contract $contracts["rewrite"] -First "revision-analyst" -Second "revision-executor"
Assert-Before -Contract $contracts["rewrite"] -First "episode-rewriter" -Second "tdk-polisher"
Assert-Before -Contract $contracts["rewrite"] -First "tdk-layout-agent" -Second "quality-verifier"

Assert-Before -Contract $contracts["export"] -First "export-approval-gate" -Second "book-exporter"
Assert-Before -Contract $contracts["export"] -First "book-exporter" -Second "export-validator"
Assert-Before -Contract $contracts["export"] -First "export-validator" -Second "tdk-rule-auditor"
Assert-Before -Contract $contracts["export"] -First "typography-layout-auditor" -Second "publication-compliance-checker"
Assert-Before -Contract $contracts["export"] -First "publication-compliance-checker" -Second "final-proofreader"

$bad = $contracts["create"] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$bad.agent_sequence = @("chief-editor-orchestrator") + @($bad.agent_sequence | Where-Object { [string]$_ -ne "chief-editor-orchestrator" })
$blocked = $false
try {
  Assert-SequenceContract -Contract $bad
}
catch {
  if ($_.Exception.Message -match "chief-editor-orchestrator must be last") {
    $blocked = $true
  }
  else {
    throw
  }
}
if (-not $blocked) {
  throw "Negative sequence test failed: chief-editor-orchestrator was allowed before specialists."
}

Write-Host "[agent-sequence-gate] PASS"
