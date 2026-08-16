param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$marker = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw "Not a KitHub project: $ProjectRoot" }
$configPath = Join-Path $ProjectRoot "runtime/runner-config.json"
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Missing runner config: $configPath" }

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$backupRoot = Join-Path $ProjectRoot ("runtime/migrations/" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$changes = @()
function Set-Prop([object]$Object, [string]$Name, [object]$Value) {
  if (-not ($Object.PSObject.Properties.Name -contains $Name) -or [string]$Object.$Name -ne [string]$Value) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    $script:changes += $Name
  }
}
Set-Prop $config "schema_version" 2
Set-Prop $config "migration_version" "1.0.0"
if (-not $config.quality_flags) { $config | Add-Member -NotePropertyName quality_flags -NotePropertyValue ([pscustomobject]@{}) -Force }
Set-Prop $config.quality_flags "require_phase_evidence" $true
Set-Prop $config.quality_flags "enforce_phase_contracts" $true
Set-Prop $config.quality_flags "require_dictionary_provider" $true
Set-Prop $config.quality_flags "execution_claim_mode" "executed"
if (-not $config.phase_commands) { $config | Add-Member -NotePropertyName phase_commands -NotePropertyValue ([pscustomobject]@{}) -Force }
foreach ($phase in @("intake","propose","design-big","design-small","create","polish","rewrite","export")) {
  if (-not ($config.phase_commands.PSObject.Properties.Name -contains $phase)) {
    $config.phase_commands | Add-Member -NotePropertyName $phase -NotePropertyValue "" -Force
    $changes += "phase_commands.$phase"
  }
}
if (-not $config.adapter -or -not $config.adapter.command_template) {
  $adapter = [pscustomobject]@{ command_template = 'powershell -ExecutionPolicy Bypass -File scripts/local_phase.ps1 -ProjectRoot "{project_root}" -Phase {phase} -RunId "{run_id}"'; strategy = "command_template" }
  $config | Add-Member -NotePropertyName adapter -NotePropertyValue $adapter -Force
  $changes += "adapter"
}
if (-not $WhatIf) {
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
  Copy-Item -LiteralPath $configPath -Destination (Join-Path $backupRoot "runner-config.json")
  [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($true))
  $record = [ordered]@{ schema_version = "1.0.0"; migration_version = "1.0.0"; migrated_at = (Get-Date).ToString("o"); backup = "runtime/migrations/$((Split-Path $backupRoot -Leaf))/runner-config.json"; changes = @($changes) }
  [IO.File]::WriteAllText((Join-Path $ProjectRoot "runtime/config-migration.json"), ($record | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($true))
}
Write-Host "[migrate-project] changes=$($changes.Count) whatIf=$WhatIf"
