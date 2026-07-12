param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Message
  )
  $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  if ($raw -notmatch $Pattern) {
    throw $Message
  }
}

$providerScript = Join-Path $RepoRoot "scripts/provider_phase.ps1"
$providerConfig = Join-Path $RepoRoot "runtime/runner-config.provider.template.json"

Assert-File $providerScript
Assert-File $providerConfig
Assert-Contains -Path $providerScript -Pattern "KITHUB_PROVIDER_EXE" -Message "Provider wrapper must require KITHUB_PROVIDER_EXE."
Assert-Contains -Path $providerScript -Pattern "Provider phase blocked" -Message "Provider wrapper must fail closed when provider is absent."
Assert-Contains -Path $providerScript -Pattern "runtime/phase-contracts" -Message "Provider prompt must bind phase contracts."
Assert-Contains -Path $providerScript -Pattern "agent_sequence" -Message "Provider prompt must require agent sequence."
Assert-Contains -Path $providerConfig -Pattern '"execution_claim_mode"\s*:\s*"executed"' -Message "Provider config must use executed claim mode."
Assert-Contains -Path $providerConfig -Pattern '"require_executed_claims_for_critical_phases"\s*:\s*true' -Message "Provider config must require executed critical phases."
Assert-Contains -Path (Join-Path $RepoRoot "README.md") -Pattern "Automatic Provider Mode" -Message "README must document automatic provider mode."
Assert-Contains -Path (Join-Path $RepoRoot "docs/RUNNER_USAGE.md") -Pattern "Automatic Provider Mode" -Message "Runner docs must document automatic provider mode."

Write-Host "[provider-mode-gate-test] PASS"
