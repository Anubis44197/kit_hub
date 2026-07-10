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

$RequiredAgents = Normalize-List -Values $RequiredAgents
$AgentsExecuted = Normalize-List -Values $AgentsExecuted
$RequiredReferences = Normalize-List -Values $RequiredReferences
$LoadedStateFiles = Normalize-List -Values $LoadedStateFiles
$OutputArtifacts = Normalize-List -Values $OutputArtifacts
$AgentStatuses = Normalize-List -Values $AgentStatuses
$MissingItems = Normalize-List -Values $MissingItems
if ($null -eq $MissingItems) {
  $MissingItems = @()
}

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
  phase_authority = $PhaseAuthority
  completed_at = (Get-Date).ToString("o")
  contract_status = $ContractStatus
  missing_items = @($MissingItems)
}

$out = Join-Path $ProjectRoot ("runtime/agent-compliance/{0}.json" -f $Phase)
Write-Utf8Bom -Path $out -Content ($payload | ConvertTo-Json -Depth 20)
Write-Host "[agent-compliance] wrote $out"
