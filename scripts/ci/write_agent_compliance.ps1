param(
  [string]$ProjectRoot = (Get-Location).Path,
  [Parameter(Mandatory = $true)]
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [Parameter(Mandatory = $true)]
  [string]$RunId,
  [Parameter(Mandatory = $true)]
  [string[]]$RequiredAgents,
  [string[]]$AgentsExecuted = @(),
  [string[]]$RequiredReferences = @(),
  [string[]]$LoadedStateFiles = @(),
  [Parameter(Mandatory = $true)]
  [string[]]$OutputArtifacts,
  [string[]]$AgentStatuses = @(),
  [string[]]$AgentEvidence = @(),
  [ValidateSet("manual_ide_agent","provider_command","human_operator","local_adapter_scaffold")]
  [string]$PhaseAuthority = "manual_ide_agent",
  [ValidateSet("PASS","BLOCKED")]
  [string]$ContractStatus = "PASS",
  [string[]]$MissingItems = @()
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Get-FileSha256 {
  param([string]$Path)
  Ensure-File $Path
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
      $hash = $sha.ComputeHash($stream)
      return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($sha) { $sha.Dispose() }
  }
}

function Get-ContractHashRecords {
  param([string]$Root, [string]$PhaseName)

  $contractFiles = @(
    "runtime/agent-registry.json",
    "runtime/agent-status-contract.json",
    ("runtime/phase-contracts/{0}.json" -f $PhaseName)
  )
  $records = @()
  foreach ($rel in $contractFiles) {
    $path = Join-Path $Root $rel
    Ensure-File $path
    $records += [ordered]@{
      path = $rel
      sha256 = Get-FileSha256 -Path $path
    }
  }
  return $records
}

function Normalize-List {
  param([string[]]$Values)
  $out = @()
  foreach ($value in @($Values)) {
    foreach ($part in ([string]$value -split ",")) {
      $clean = $part.Trim()
      if ($clean) { $out += $clean }
    }
  }
  return @($out | Select-Object -Unique)
}

function Read-Json {
  param([string]$Path)
  Ensure-File $Path
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Validate-ChiefEditorEvidence {
  param(
    [string[]]$EvidenceArtifacts,
    [string[]]$OutputArtifacts,
    [string]$Phase,
    [string]$ProjectRoot
  )

  $chiefReportEvidence = @($EvidenceArtifacts | Where-Object { [string]$_ -match "chief-editor-orchestrator_report_" })
  $chiefVerdictEvidence = @($EvidenceArtifacts | Where-Object { [string]$_ -match "chief-editor-orchestrator_verdict_" })
  if ($chiefReportEvidence.Count -lt 1 -or $chiefVerdictEvidence.Count -lt 1) {
    throw "AgentEvidence for chief-editor-orchestrator must include dedicated report and verdict artifacts."
  }
  foreach ($rel in $chiefVerdictEvidence) {
    $verdict = Read-Json -Path (Join-Path $ProjectRoot $rel)
    foreach ($field in @("run_id","phase","agent","verdict","checked_output_artifacts")) {
      if (-not ($verdict.PSObject.Properties.Name -contains $field)) {
        throw "Chief editor verdict missing '$field': $rel"
      }
    }
    if ([string]$verdict.phase -ne $Phase) {
      throw "Chief editor verdict phase mismatch for '$rel'. Expected '$Phase', found '$($verdict.phase)'."
    }
    if ([string]$verdict.agent -ne "chief-editor-orchestrator") {
      throw "Chief editor verdict agent mismatch for '$rel'."
    }
    if ([string]$verdict.verdict -in @("REWRITE","BLOCKED")) {
      throw "Chief editor verdict blocks phase '$Phase': verdict=$($verdict.verdict)"
    }
    $checkedOutputArtifacts = @($verdict.checked_output_artifacts | ForEach-Object { [string]$_ })
    if ($checkedOutputArtifacts.Count -lt 1) {
      throw "Chief editor verdict must list checked_output_artifacts: $rel"
    }
    foreach ($checkedRel in $checkedOutputArtifacts) {
      if ($OutputArtifacts -notcontains $checkedRel) {
        throw "Chief editor verdict references artifact not listed in OutputArtifacts: $checkedRel"
      }
    }
    $uncheckedArtifacts = @($OutputArtifacts | Where-Object {
      ([string]$_ -notmatch "chief-editor-orchestrator_(report|verdict)_") -and
      ($checkedOutputArtifacts -notcontains [string]$_)
    })
    if ($uncheckedArtifacts.Count -gt 0) {
      throw "Chief editor verdict did not check output artifacts: $($uncheckedArtifacts -join ', ')"
    }
  }
}

$RequiredAgents = Normalize-List -Values $RequiredAgents
$AgentsExecuted = Normalize-List -Values $AgentsExecuted
$RequiredReferences = Normalize-List -Values $RequiredReferences
$LoadedStateFiles = Normalize-List -Values $LoadedStateFiles
$OutputArtifacts = Normalize-List -Values $OutputArtifacts
$AgentStatuses = Normalize-List -Values $AgentStatuses
$AgentEvidence = Normalize-List -Values $AgentEvidence
$MissingItems = Normalize-List -Values $MissingItems
if ($null -eq $MissingItems) {
  $MissingItems = @()
}

$phaseContractPath = Join-Path $ProjectRoot ("runtime/phase-contracts/{0}.json" -f $Phase)
$phaseContract = Read-Json -Path $phaseContractPath
$RequiredAgents = Normalize-List -Values @($RequiredAgents + @($phaseContract.required_agents | ForEach-Object { [string]$_ }))
$RequiredReferences = Normalize-List -Values @($RequiredReferences + @($phaseContract.required_references | ForEach-Object { [string]$_ }))
$LoadedStateFiles = Normalize-List -Values @($LoadedStateFiles + @($phaseContract.required_state_files | ForEach-Object { [string]$_ }))

if ($AgentsExecuted.Count -lt 1) {
  $AgentsExecuted = $RequiredAgents
}

foreach ($rel in $RequiredReferences) {
  Ensure-File (Join-Path $ProjectRoot $rel)
}
foreach ($rel in $LoadedStateFiles) {
  Ensure-File (Join-Path $ProjectRoot $rel)
}

$artifactHashes = @()
foreach ($rel in $OutputArtifacts) {
  if ($rel -match "[\*\?]") {
    throw "OutputArtifacts must list concrete files, not wildcard path: $rel"
  }
  $path = Join-Path $ProjectRoot $rel
  Ensure-File $path
  $artifactHashes += [ordered]@{
    path = $rel
    sha256 = Get-FileSha256 -Path $path
  }
}

if ($ContractStatus -eq "PASS" -and $MissingItems.Count -gt 0) {
  throw "PASS manifest cannot include MissingItems."
}

$agentStatusRecords = @()
$seenAgentStatus = @{}
foreach ($entry in $AgentStatuses) {
  $parts = ([string]$entry).Split("=", 2)
  if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
    throw "AgentStatuses entries must use agent=status format. Bad entry: $entry"
  }
  $agentName = $parts[0].Trim()
  $agentStatus = $parts[1].Trim()
  if ($agentStatus -notin @("completed","failed","blocked","timed_out","invalid_output")) {
    throw "Invalid agent status '$agentStatus' for '$agentName'."
  }
  if ($seenAgentStatus.ContainsKey($agentName)) {
    throw "Duplicate AgentStatuses entry for '$agentName'."
  }
  $seenAgentStatus[$agentName] = $true
  $agentStatusRecords += [ordered]@{
    agent = $agentName
    status = $agentStatus
  }
}
foreach ($agentName in $RequiredAgents) {
  if (-not $seenAgentStatus.ContainsKey($agentName)) {
    $agentStatusRecords += [ordered]@{
      agent = $agentName
      status = $(if ($ContractStatus -eq "PASS") { "completed" } else { "blocked" })
    }
  }
}

$agentEvidenceRecords = @()
$seenAgentEvidence = @{}
foreach ($entry in $AgentEvidence) {
  $parts = ([string]$entry).Split("=", 2)
  if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
    throw "AgentEvidence entries must use agent=artifact1|artifact2 format. Bad entry: $entry"
  }
  $agentName = $parts[0].Trim()
  if ($seenAgentEvidence.ContainsKey($agentName)) {
    throw "Duplicate AgentEvidence entry for '$agentName'."
  }
  $evidenceArtifacts = @($parts[1].Split("|") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($evidenceArtifacts.Count -lt 1) {
    throw "AgentEvidence for '$agentName' must list at least one artifact."
  }
  foreach ($rel in $evidenceArtifacts) {
    if ($OutputArtifacts -notcontains $rel) {
      throw "AgentEvidence for '$agentName' references artifact not listed in OutputArtifacts: $rel"
    }
  }
  if ($agentName -eq "chief-editor-orchestrator") {
    Validate-ChiefEditorEvidence -EvidenceArtifacts $evidenceArtifacts -OutputArtifacts $OutputArtifacts -Phase $Phase -ProjectRoot $ProjectRoot
  }
  $seenAgentEvidence[$agentName] = $true
  $agentEvidenceRecords += [ordered]@{
    agent = $agentName
    status = $(if ($ContractStatus -eq "PASS") { "completed" } else { "blocked" })
    evidence_artifacts = $evidenceArtifacts
    checks_performed = @("phase-contract-artifact-review")
    verdict = $(if ($ContractStatus -eq "PASS") { "PASS" } else { "BLOCKED" })
  }
}
foreach ($agentName in $RequiredAgents) {
  if (-not $seenAgentEvidence.ContainsKey($agentName)) {
    $agentPattern = [regex]::Escape([string]$agentName)
    $matchedEvidence = @($OutputArtifacts | Where-Object { ([string]$_ -match $agentPattern) -and -not ([string]$_ -match "[\*\?]") })
    if ([string]$agentName -eq "chief-editor-orchestrator") {
      Validate-ChiefEditorEvidence -EvidenceArtifacts $matchedEvidence -OutputArtifacts $OutputArtifacts -Phase $Phase -ProjectRoot $ProjectRoot
    }
    $evidenceArtifacts = if ($matchedEvidence.Count -gt 0) { $matchedEvidence } else { @($OutputArtifacts | Select-Object -First 1) }
    $agentEvidenceRecords += [ordered]@{
      agent = $agentName
      status = $(if ($ContractStatus -eq "PASS") { "completed" } else { "blocked" })
      evidence_artifacts = $evidenceArtifacts
      checks_performed = @("phase-contract-artifact-review")
      verdict = $(if ($ContractStatus -eq "PASS") { "PASS" } else { "BLOCKED" })
      notes = "Auto-filled by compliance writer; provide explicit AgentEvidence for stricter audits."
    }
  }
}

$payload = [ordered]@{
  run_id = $RunId
  phase = $Phase
  required_agents = $RequiredAgents
  agents_executed = $AgentsExecuted
  required_references = $RequiredReferences
  loaded_state_files = $LoadedStateFiles
  output_artifacts = $OutputArtifacts
  artifact_hashes = $artifactHashes
  contract_hashes = @(Get-ContractHashRecords -Root $ProjectRoot -PhaseName $Phase)
  agent_statuses = $agentStatusRecords
  agent_evidence = $agentEvidenceRecords
  phase_authority = $PhaseAuthority
  completed_at = (Get-Date).ToString("o")
  contract_status = $ContractStatus
  missing_items = @($MissingItems)
}

$out = Join-Path $ProjectRoot ("runtime/agent-compliance/{0}.json" -f $Phase)
Write-Utf8Bom -Path $out -Content ($payload | ConvertTo-Json -Depth 20)
Write-Host "[agent-compliance] wrote $out"
