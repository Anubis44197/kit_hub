param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [ValidateSet("codex","claude","gemini","ollama")]
  [string]$Provider = "codex",
  [string]$Model = "qwen2.5:0.5b",
  [int]$MaxAgents = 36,
  [switch]$AllowExternalProviderData
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
if (-not $AllowExternalProviderData -and $Provider -ne "ollama") {
  throw "Provider execution requires explicit -AllowExternalProviderData because fixture content is sent to an external agent service."
}

$registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"
$goldenRoot = Join-Path $ProjectRoot "tests/golden/agents"
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Missing agent registry: $registryPath" }
if (-not (Test-Path -LiteralPath $goldenRoot -PathType Container)) { throw "Missing golden fixture root: $goldenRoot" }
$providerCommand = Get-Command $Provider -ErrorAction SilentlyContinue
if (-not $providerCommand) { throw "Provider CLI is not installed: $Provider" }

$reportRoot = Join-Path $ProjectRoot "runtime/provider-fixture-reports"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
$agents = @($registry.agents | Select-Object -First $MaxAgents)
$results = @()
foreach ($agent in $agents) {
  $name = [string]$agent.name
  $fixtureDir = Join-Path $goldenRoot $name
  $inputPath = Join-Path $fixtureDir "input.md"
  $expectedPath = Join-Path $fixtureDir "expected.md"
  $outputPath = Join-Path $reportRoot "$name.output.md"
  $started = Get-Date
  $errors = @()
  $exitCode = -1
  if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { $errors += "missing input.md" }
  if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { $errors += "missing expected.md" }
  if ($errors.Count -eq 0) {
    $input = Get-Content -LiteralPath $inputPath -Raw
    $expected = Get-Content -LiteralPath $expectedPath -Raw
    $prompt = @"
You are the KitHub agent '$name'. This is a read-only deterministic fixture execution.
Do not edit files, run commands, browse, or claim work you did not perform.
Return only a concise response that follows the agent contract and addresses the fixture.

FIXTURE INPUT:
$input

EXPECTED CONTRACT:
$expected
"@
    try {
      $previousErrorAction = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      switch ($Provider) {
        "codex" {
          $result = & $providerCommand.Source exec --ephemeral --sandbox read-only --skip-git-repo-check -C $ProjectRoot -o $outputPath $prompt 2>&1
          $exitCode = $LASTEXITCODE
          if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true)) }
        }
        "claude" {
          $result = & $providerCommand.Source -p $prompt --no-session-persistence --permission-mode plan 2>&1
          $exitCode = $LASTEXITCODE
          [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true))
        }
        "gemini" {
          $result = & $providerCommand.Source -p $prompt --approval-mode plan --skip-trust 2>&1
          $exitCode = $LASTEXITCODE
          [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true))
        }
        "ollama" {
          $requestBody = @{ model = $Model; prompt = $prompt; stream = $false } | ConvertTo-Json -Depth 10
          $ollamaResponse = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json" -Body $requestBody
          $exitCode = 0
          [IO.File]::WriteAllText($outputPath,[string]$ollamaResponse.response,[Text.UTF8Encoding]::new($true))
        }
      }
    }
    catch { $errors += $_.Exception.Message }
    finally { $ErrorActionPreference = $previousErrorAction }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { $errors += "provider output missing" }
    else {
      $output = Get-Content -LiteralPath $outputPath -Raw
      if ($output.Trim().Length -lt 10) { $errors += "provider output too short" }
      if ($output -match '(?i)authentication|unauthorized|rate limit|cannot connect|no such model') { $errors += "provider reported unavailable execution" }
    }
  }
  $results += [ordered]@{
    agent = $name
    phase = (@($agent.allowed_phases) -join ",")
    status = if ($errors.Count -eq 0 -and $exitCode -eq 0) { "PASS" } else { "FAIL" }
    execution_claim_mode = "provider_execution"
    provider = $Provider
    model = $Model
    exit_code = $exitCode
    duration_seconds = [math]::Round(((Get-Date)-$started).TotalSeconds,2)
    output = "runtime/provider-fixture-reports/$name.output.md"
    errors = @($errors)
  }
}
$failed = @($results | Where-Object status -eq "FAIL")
$report = [ordered]@{
  schema_version = "1.0.0"
  report_type = "provider_agent_fixture_execution"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  execution_claim_mode = "provider_execution"
  provider = $Provider
  model = $Model
  provider_execution_proven = ($failed.Count -eq 0 -and $results.Count -eq $agents.Count)
  total_agents = $results.Count
  passed_agents = @($results | Where-Object status -eq "PASS").Count
  failed_agents = $failed.Count
  verdict = if ($failed.Count -eq 0 -and $results.Count -eq $agents.Count) { "PASS" } else { "FAIL" }
  agents = @($results)
}
$reportPath = Join-Path $reportRoot "$Provider-36-agent-report.json"
[IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
if ($failed.Count -gt 0 -or $results.Count -ne [math]::Min($MaxAgents,@($registry.agents).Count)) { throw "Provider fixture execution failed: $($failed.agent -join ', ')" }
Write-Host "[provider-agent-runner] PASS $($report.passed_agents)/$($report.total_agents) provider=$Provider"
Write-Host "[provider-agent-runner] report=$reportPath"