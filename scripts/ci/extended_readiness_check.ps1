param(
  [string]$ConfigPath = "tests/fixtures/sample-project/novel-config.md"
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
  param([string]$ScriptPath, [string[]]$Arguments = @())
  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Missing required script: $ScriptPath"
  }
  & powershell -ExecutionPolicy Bypass -File $ScriptPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$ScriptPath failed with exit code: $LASTEXITCODE"
  }
}

Write-Host "[extended-readiness-ps] running final readiness..."
Invoke-Checked -ScriptPath "scripts/ci/final_readiness_check.ps1" -Arguments @("-ConfigPath", $ConfigPath)

Write-Host "[extended-readiness-ps] running full writing type profile gate..."
Invoke-Checked -ScriptPath "scripts/ci/writing_type_profiles_gate_test.ps1"

Write-Host "[extended-readiness-ps] done"
