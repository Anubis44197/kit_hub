param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)
$ErrorActionPreference = "Stop"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-jev-gate-" + [guid]::NewGuid().ToString("N"))
$reportPath = Join-Path $testRoot "reports/decision.json"
$gate = Join-Path $RepoRoot "scripts/jev_phase_gate.ps1"
$mock = Join-Path $testRoot "mock-jev.js"

function Assert-Case {
  param([string]$Name, [string]$Mode, [string]$Phase, [string]$Expected, [int]$Exit)
  $env:KITHUB_JEV_TEST_MODE = $Mode
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $gate -ProjectRoot $testRoot -RunId "test-run" -Phase $Phase -ReportPath $reportPath -ClientPath $mock
  $actualExit = $LASTEXITCODE
  if (-not (Test-Path -LiteralPath $reportPath)) { throw "$($Name): missing report" }
  $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
  if ($actualExit -ne $Exit -or $report.status -ne $Expected) {
    throw "$($Name): expected $Expected/$Exit, got $($report.status)/$actualExit. $($report.reason)"
  }
  Write-Host "[jev-phase-gate] PASS $Name"
}

try {
  New-Item -ItemType Directory -Path (Join-Path $testRoot "revision/_workspace") -Force | Out-Null
  $candidate = Join-Path $testRoot "revision/_workspace/00_chief-editor-orchestrator_create.md"
  [IO.File]::WriteAllText($candidate, ("Synthetic phase summary. " * 8), [Text.UTF8Encoding]::new($false))
  $exportCandidate = Join-Path $testRoot "revision/_workspace/00_chief-editor-orchestrator_export.md"
  [IO.File]::WriteAllText($exportCandidate, ("Synthetic export review. " * 8), [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllLines($mock, @(
    'const mode = process.env.KITHUB_JEV_TEST_MODE;'
    'const action = process.argv[2];'
    'const verdict = mode === "blocked" ? "BLOCKED" : "PASS";'
    'if (action === "gate") {'
    '  console.log(JSON.stringify(mode === "export-fallback"'
    '    ? { source: "local_fallback", isFallback: true, approved: false }'
    '    : { source: "jev", isFallback: false, approved: true }));'
    '} else {'
    '  console.log(JSON.stringify(mode === "fallback"'
    '    ? { source: "local_fallback", isFallback: true, verdict: "PASS" }'
    '    : { source: "jev", isFallback: false, verdict, rawChoice: verdict, fromCache: false }));'
    '}'
  ), [Text.UTF8Encoding]::new($false))

  Assert-Case -Name "pass" -Mode "pass" -Phase "create" -Expected "pass" -Exit 0
  Assert-Case -Name "blocked" -Mode "blocked" -Phase "create" -Expected "blocked" -Exit 2
  Assert-Case -Name "fallback" -Mode "fallback" -Phase "create" -Expected "review_required" -Exit 2
  Assert-Case -Name "export-fallback" -Mode "export-fallback" -Phase "export" -Expected "review_required" -Exit 2
  $runDir = Join-Path $testRoot "runtime/agent-runs/test-run"
  $complianceDir = Join-Path $testRoot "runtime/agent-compliance"
  New-Item -ItemType Directory -Path $runDir, $complianceDir -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $runDir "context-pack.json"), '{"files":[]}', [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $complianceDir "create.json"), '{"evidence_files":[{"path":"revision/_workspace/00_chief-editor-orchestrator_create.md"}]}', [Text.UTF8Encoding]::new($false))
  $verifier = Join-Path $RepoRoot "scripts/verify_agent_run.ps1"
  foreach ($case in @(
    @{ mode = "pass"; expected = "pass"; exit = 0 },
    @{ mode = "blocked"; expected = "revision_required"; exit = 2 }
  )) {
    $env:KITHUB_JEV_TEST_MODE = $case.mode
    $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $verifier -ProjectRoot $testRoot -RunId "test-run" -Phase "create" -JevClientPath $mock
    $exitCode = $LASTEXITCODE
    $verification = Get-Content -LiteralPath (Join-Path $runDir "verification.json") -Raw | ConvertFrom-Json
    if ($exitCode -ne $case.exit -or $verification.verdict -ne $case.expected) {
      throw "Verifier $($case.mode) expected $($case.expected)/$($case.exit), got $($verification.verdict)/$exitCode"
    }
    Write-Host "[jev-phase-gate] PASS verifier-$($case.mode)"
  }
  Remove-Item -LiteralPath $candidate -Force
  Assert-Case -Name "missing-evidence" -Mode "pass" -Phase "create" -Expected "review_required" -Exit 2
  Assert-Case -Name "noncritical" -Mode "pass" -Phase "propose" -Expected "not_applicable" -Exit 0
}
finally {
  Remove-Item Env:KITHUB_JEV_TEST_MODE -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
