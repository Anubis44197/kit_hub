param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Read-Json {
  param([string]$Path)
  Ensure-File $Path
  return Read-Utf8 -Path $Path | ConvertFrom-Json
}

$registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"
$statusPath = Join-Path $ProjectRoot "runtime/agent-status-contract.json"
$contractsDir = Join-Path $ProjectRoot "runtime/phase-contracts"

$registry = Read-Json -Path $registryPath
$status = Read-Json -Path $statusPath

if (@($registry.agents).Count -lt 1) {
  throw "Agent registry is empty."
}

$validStatuses = @($status.valid_status_values | ForEach-Object { [string]$_ })
foreach ($requiredStatus in @("completed","failed","blocked","timed_out","invalid_output")) {
  if ($validStatuses -notcontains $requiredStatus) {
    throw "Agent status contract missing '$requiredStatus'."
  }
}

$agentNames = @($registry.agents | ForEach-Object { [string]$_.name })
if (($agentNames | Sort-Object -Unique).Count -ne $agentNames.Count) {
  throw "Agent registry contains duplicate names."
}

foreach ($agent in @($registry.agents)) {
  foreach ($field in @("name","allowed_phases","required_references","allowed_write_roots","timeout_seconds","max_turns")) {
    if (-not ($agent.PSObject.Properties.Name -contains $field)) {
      throw "Agent '$($agent.name)' missing '$field'."
    }
  }
  Ensure-File (Join-Path $ProjectRoot ("agents/{0}.md" -f $agent.name))
  foreach ($ref in @($agent.required_references)) {
    Ensure-File (Join-Path $ProjectRoot ([string]$ref))
  }
}

foreach ($phase in @("propose","design-big","design-small","create","polish","rewrite","export")) {
  $contractPath = Join-Path $contractsDir "$phase.json"
  $contract = Read-Json -Path $contractPath
  if ([string]$contract.phase -ne $phase) {
    throw "Phase contract mismatch in $contractPath"
  }
  foreach ($field in @("required_agents","required_references","required_state_files","allowed_output_patterns","denied_output_patterns","status_contract")) {
    if (-not ($contract.PSObject.Properties.Name -contains $field)) {
      throw "Phase contract '$phase' missing '$field'."
    }
  }
  foreach ($agentName in @($contract.required_agents)) {
    if ($agentNames -notcontains $agentName) {
      throw "Phase '$phase' references unknown agent '$agentName'."
    }
    $agent = @($registry.agents | Where-Object { $_.name -eq $agentName } | Select-Object -First 1)[0]
    if (@($agent.allowed_phases) -notcontains $phase) {
      throw "Agent '$agentName' is not allowed in phase '$phase'."
    }
  }
  foreach ($ref in @($contract.required_references)) {
    Ensure-File (Join-Path $ProjectRoot ([string]$ref))
  }
}

Write-Host "[agent-governance] PASS"
