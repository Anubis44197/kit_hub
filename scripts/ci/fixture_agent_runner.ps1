param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
if (-not $ReportPath.Trim()) {
  $ReportPath = Join-Path $ProjectRoot "runtime/fixture-reports/36-agent-fixture-report.json"
}

function Write-Utf8Json {
  param([string]$Path, [object]$Value)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($true))
}

$registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"
$goldenRoot = Join-Path $ProjectRoot "tests/golden/agents"
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Missing agent registry: $registryPath" }
if (-not (Test-Path -LiteralPath $goldenRoot -PathType Container)) { throw "Missing golden fixture root: $goldenRoot" }

$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
$results = @()
foreach ($agent in @($registry.agents)) {
  $fixtureDir = Join-Path $goldenRoot ([string]$agent.name)
  $inputPath = Join-Path $fixtureDir "input.md"
  $expectedPath = Join-Path $fixtureDir "expected.md"
  $errors = @()
  if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { $errors += "missing input.md" }
  if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { $errors += "missing expected.md" }
  foreach ($reference in @($agent.required_references)) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $reference) -PathType Leaf)) { $errors += "missing reference: $reference" }
  }
  if ($errors.Count -eq 0) {
    $expected = Get-Content -LiteralPath $expectedPath -Raw
    $input = Get-Content -LiteralPath $inputPath -Raw
    if (-not $input.Trim()) { $errors += "empty fixture input" }
    if ($expected.Length -lt 40) { $errors += "expected contract is too short" }
  }
  $results += [ordered]@{
    agent = [string]$agent.name
    phase = (@($agent.allowed_phases) -join ",")
    status = if ($errors.Count -eq 0) { "PASS" } else { "FAIL" }
    execution_claim_mode = "fixture_validation"
    input = "tests/golden/agents/$($agent.name)/input.md"
    expected = "tests/golden/agents/$($agent.name)/expected.md"
    errors = @($errors)
  }
}

$failed = @($results | Where-Object status -eq "FAIL")
$report = [ordered]@{
  schema_version = "1.0.0"
  report_type = "agent_fixture_validation"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  execution_claim_mode = "fixture_validation"
  provider_execution_proven = $false
  total_agents = @($results).Count
  passed_agents = @($results | Where-Object status -eq "PASS").Count
  failed_agents = $failed.Count
  verdict = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  notes = @(
    "This report executes deterministic golden fixture and reference-contract checks.",
    "It does not claim autonomous provider or IDE agent authorship."
  )
  agents = @($results)
}
Write-Utf8Json -Path $ReportPath -Value $report
if ($failed.Count -gt 0) {
  Write-Error "Fixture validation failed: $($failed.agent -join ', ')"
  exit 1
}
Write-Host "[fixture-agent-runner] PASS $($report.passed_agents)/$($report.total_agents)"
Write-Host "[fixture-agent-runner] report=$ReportPath"
